package com.payflex.backend.service;

import com.payflex.backend.config.PayflexProperties;
import org.springframework.dao.EmptyResultDataAccessException;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Objects;

/**
 * Validation des cotisations déclarées depuis l'app client (smartphone) :
 * agent rattaché en priorité, sinon gestionnaire / admin via le tableau de bord.
 */
@Service
public class ContributionWorkflowService {

    public static final String NOTIF_TYPE_VALIDATED = "contribution_validated";
    public static final String NOTIF_TYPE_REJECTED = "contribution_rejected";
    /** Paiement confirmé mais réparti automatiquement sur plusieurs produits (excédent > reste à payer). */
    public static final String NOTIF_TYPE_ALLOCATED_MULTI = "contribution_allocated_multi";
    public static final String GOAL_REACHED_MESSAGE = "Objectif atteint pour ce produit, cotisation bloquée.";

    private final JdbcTemplate jdbcTemplate;
    private final PermissionService permissionService;
    private final AdminAuditService auditService;
    private final ContributionValidationAlertService alertService;
    private final PayflexProperties payflexProperties;
    private final UserInboxNotificationService inboxNotifications;
    private final ProductDeliveryService productDeliveryService;
    private final AdminWebPushService adminWebPushService;
    private final ContributionAllocationService contributionAllocationService;

    public ContributionWorkflowService(
        JdbcTemplate jdbcTemplate,
        PermissionService permissionService,
        AdminAuditService auditService,
        ContributionValidationAlertService alertService,
        PayflexProperties payflexProperties,
        UserInboxNotificationService inboxNotifications,
        ProductDeliveryService productDeliveryService,
        AdminWebPushService adminWebPushService,
        ContributionAllocationService contributionAllocationService
    ) {
        this.jdbcTemplate = jdbcTemplate;
        this.permissionService = permissionService;
        this.auditService = auditService;
        this.alertService = alertService;
        this.payflexProperties = payflexProperties;
        this.inboxNotifications = inboxNotifications;
        this.productDeliveryService = productDeliveryService;
        this.adminWebPushService = adminWebPushService;
        this.contributionAllocationService = contributionAllocationService;
    }

    /**
     * @deprecated Ancien garde-fou bloquant (rejette toute cotisation qui dépasserait le solde
     * restant du produit visé). Depuis l'introduction de la répartition automatique de l'excédent
     * ({@link ContributionAllocationService}), ce blocage n'est plus appelé par le flux normal :
     * un montant excédentaire n'est plus rejeté, il est réparti sur les autres produits actifs du
     * client (ou tracé comme « surplus non affecté » si aucun produit ne peut l'absorber — jamais
     * rejeté silencieusement). Méthode conservée uniquement pour compatibilité / usage manuel
     * ponctuel (ex. script de contrôle), NE PAS la réintroduire dans le flux de déclaration/validation.
     */
    @Deprecated
    public void assertProductGoalNotReached(long clientUserId, Long productId) {
        assertProductGoalNotReached(clientUserId, productId, 0);
    }

    /**
     * @deprecated Voir {@link #assertProductGoalNotReached(long, Long)}.
     */
    @Deprecated
    public void assertProductGoalNotReached(long clientUserId, Long productId, double proposedAmount) {
        if (clientUserId <= 0 || productId == null || productId <= 0) {
            return;
        }
        Double target;
        try {
            target = jdbcTemplate.queryForObject(
                """
                SELECT COALESCE(p.price, 0) * COALESCE(NULLIF(cps.quantity, 0), 1)
                FROM products p
                LEFT JOIN client_product_selections cps ON cps.product_id = p.id AND cps.user_id = ?
                WHERE p.id = ?
                LIMIT 1
                """,
                Double.class,
                clientUserId,
                productId
            );
        } catch (EmptyResultDataAccessException ex) {
            return;
        }
        if (target == null || target <= 0) {
            return;
        }
        Double validated = jdbcTemplate.queryForObject(
            """
            SELECT COALESCE(SUM(amount), 0) FROM contributions
            WHERE user_id = ? AND product_id = ? AND status = 'validated'
            """,
            Double.class,
            clientUserId,
            productId
        );
        double validatedTotal = validated == null ? 0 : validated;
        if (validatedTotal >= target - 0.009) {
            throw new IllegalArgumentException(GOAL_REACHED_MESSAGE);
        }
        if (proposedAmount > 0 && validatedTotal + proposedAmount > target + 0.009) {
            long remaining = Math.round(Math.max(0, target - validatedTotal));
            throw new IllegalArgumentException(
                "Montant trop élevé : il ne reste que " + remaining + " FCFA à cotiser pour atteindre l'objectif de ce produit."
            );
        }
    }

    public Long findAgentRowIdForClient(long clientUserId) {
        try {
            Long assignedUserId = jdbcTemplate.queryForObject(
                "SELECT assigned_agent_user_id FROM users WHERE id = ?",
                Long.class,
                clientUserId
            );
            if (assignedUserId == null || assignedUserId <= 0) {
                return null;
            }
            return jdbcTemplate.queryForObject(
                "SELECT id FROM agents WHERE user_id = ? LIMIT 1",
                Long.class,
                assignedUserId
            );
        } catch (EmptyResultDataAccessException ex) {
            return null;
        }
    }

    public List<Map<String, Object>> listPendingForAgentValidator(long agentUserId) {
        Long agentRowId = findAgentRowIdByUserId(agentUserId);
        if (agentRowId == null) {
            return List.of();
        }
        return jdbcTemplate.queryForList(
            """
            SELECT c.id, c.user_id, c.amount, c.payment_mode, c.reference_code, c.created_at,
                   u.full_name AS client_name, u.phone AS client_phone,
                   p.name AS product_name
            FROM contributions c
            JOIN users u ON u.id = c.user_id
            LEFT JOIN products p ON p.id = c.product_id
            WHERE c.status = 'pending'
              AND LOWER(c.payment_mode) <> 'cash'
              AND (
                u.assigned_agent_user_id = ?
                OR c.agent_id = ?
              )
            ORDER BY c.created_at ASC
            """,
            agentUserId,
            agentRowId
        );
    }

    public List<Map<String, Object>> listNotificationsForClient(long clientUserId, boolean unreadOnly) {
        String sql = """
            SELECT id, type, title, body, contribution_id, related_client_user_id, read_at, pinned, created_at
            FROM client_notifications
            WHERE user_id = ?
            """;
        if (unreadOnly) {
            sql += " AND read_at IS NULL";
        }
        sql += " ORDER BY pinned DESC, created_at DESC LIMIT 50";
        List<Map<String, Object>> rows = jdbcTemplate.queryForList(sql, clientUserId);
        List<Map<String, Object>> out = new ArrayList<>();
        for (Map<String, Object> row : rows) {
            out.add(enrichNotificationRow(row));
        }
        return out;
    }

    public List<Map<String, Object>> listNotificationsAfterId(long clientUserId, long afterId) {
        List<Map<String, Object>> rows = jdbcTemplate.queryForList(
            """
            SELECT id, type, title, body, contribution_id, related_client_user_id, read_at, pinned, created_at
            FROM client_notifications
            WHERE user_id = ? AND id > ?
            ORDER BY id ASC
            LIMIT 30
            """,
            clientUserId,
            Math.max(0L, afterId)
        );
        List<Map<String, Object>> out = new ArrayList<>();
        for (Map<String, Object> row : rows) {
            out.add(enrichNotificationRow(row));
        }
        return out;
    }

    private Map<String, Object> enrichNotificationRow(Map<String, Object> row) {
        Map<String, Object> m = new LinkedHashMap<>(row);
        Object ts = row.get("created_at");
        if (ts != null) {
            m.put("created_at", ts.toString());
        }
        m.put("read", row.get("read_at") != null);
        m.put("pinned", isPinnedRow(row.get("pinned")));
        return m;
    }

    private static boolean isPinnedRow(Object pinned) {
        if (pinned == null) {
            return false;
        }
        if (pinned instanceof Boolean b) {
            return b;
        }
        if (pinned instanceof Number n) {
            return n.intValue() != 0;
        }
        return "1".equals(pinned.toString()) || "true".equalsIgnoreCase(pinned.toString());
    }

    public long latestNotificationId(long clientUserId) {
        try {
            Long id = jdbcTemplate.queryForObject(
                "SELECT COALESCE(MAX(id), 0) FROM client_notifications WHERE user_id = ?",
                Long.class,
                clientUserId
            );
            return id == null ? 0L : id;
        } catch (org.springframework.dao.EmptyResultDataAccessException ex) {
            return 0L;
        }
    }

    public int countUnreadNotifications(long clientUserId) {
        Long n = jdbcTemplate.queryForObject(
            "SELECT COUNT(*) FROM client_notifications WHERE user_id = ? AND read_at IS NULL",
            Long.class,
            clientUserId
        );
        return n == null ? 0 : n.intValue();
    }

    public void markNotificationsRead(long clientUserId, List<Long> notificationIds) {
        if (notificationIds == null || notificationIds.isEmpty()) {
            jdbcTemplate.update(
                "UPDATE client_notifications SET read_at = NOW() WHERE user_id = ? AND read_at IS NULL",
                clientUserId
            );
            return;
        }
        String placeholders = String.join(",", notificationIds.stream().map(id -> "?").toList());
        List<Object> args = new ArrayList<>();
        args.add(clientUserId);
        args.addAll(notificationIds);
        jdbcTemplate.update(
            "UPDATE client_notifications SET read_at = NOW() WHERE user_id = ? AND id IN (" + placeholders + ")",
            args.toArray()
        );
    }

    public void markNotificationsUnread(long clientUserId, List<Long> notificationIds) {
        if (notificationIds == null || notificationIds.isEmpty()) {
            return;
        }
        String placeholders = String.join(",", notificationIds.stream().map(id -> "?").toList());
        List<Object> args = new ArrayList<>();
        args.add(clientUserId);
        args.addAll(notificationIds);
        jdbcTemplate.update(
            "UPDATE client_notifications SET read_at = NULL WHERE user_id = ? AND id IN (" + placeholders + ")",
            args.toArray()
        );
    }

    public boolean deleteNotification(long clientUserId, long notificationId) {
        if (notificationId <= 0) {
            return false;
        }
        int n = jdbcTemplate.update(
            "DELETE FROM client_notifications WHERE user_id = ? AND id = ?",
            clientUserId,
            notificationId
        );
        return n > 0;
    }

    public boolean setNotificationPinned(long clientUserId, long notificationId, boolean pinned) {
        if (notificationId <= 0) {
            return false;
        }
        int n = jdbcTemplate.update(
            "UPDATE client_notifications SET pinned = ? WHERE user_id = ? AND id = ?",
            pinned,
            clientUserId,
            notificationId
        );
        return n > 0;
    }

    @Transactional
    public void validateByAgent(long contributionId, long agentUserId) {
        if (!permissionService.userHasPermission(agentUserId, PermissionService.MOBILE_CONTRIBUTION_VALIDATE)) {
            throw new IllegalArgumentException("Votre profil ne permet pas de valider des cotisations.");
        }
        if (!canAgentValidateContribution(contributionId, agentUserId)) {
            throw new IllegalArgumentException("Cette cotisation n'est pas rattachée à votre portefeuille clients.");
        }
        applyValidation(contributionId, agentUserId, "agent");
    }

    @Transactional
    public void rejectByAgent(long contributionId, long agentUserId, String reason) {
        if (!permissionService.userHasPermission(agentUserId, PermissionService.MOBILE_CONTRIBUTION_VALIDATE)) {
            throw new IllegalArgumentException("Votre profil ne permet pas de refuser des cotisations.");
        }
        if (!canAgentValidateContribution(contributionId, agentUserId)) {
            throw new IllegalArgumentException("Cette cotisation n'est pas rattachée à votre portefeuille clients.");
        }
        applyRejection(contributionId, agentUserId, reason, "agent");
    }

    @Transactional
    public void validateByBackoffice(long contributionId, String actorLogin) {
        requirePendingMobileDeclaration(contributionId);
        applyValidation(contributionId, null, actorLogin == null ? "centre" : actorLogin);
    }

    @Transactional
    public void rejectByBackoffice(long contributionId, String reason, String actorLogin) {
        requirePendingMobileDeclaration(contributionId);
        applyRejection(contributionId, null, reason, actorLogin == null ? "centre" : actorLogin);
    }

    /**
     * Collecte espèces enregistrée par l'agent : validation immédiate uniquement si activée dans la config.
     *
     * @return true si la cotisation est passée à « validated », false si elle reste en attente (rapprochement centre).
     */
    @Transactional
    public boolean validateAgentCashCollection(long contributionId, long agentUserId) {
        Map<String, Object> row = loadContribution(contributionId);
        if (row == null) {
            throw new IllegalArgumentException("Cotisation introuvable.");
        }
        if (!"pending".equals(row.get("status"))) {
            throw new IllegalArgumentException("Cette cotisation n'est plus en attente.");
        }
        String mode = Objects.toString(row.get("payment_mode"), "");
        if (!"cash".equalsIgnoreCase(mode)) {
            throw new IllegalArgumentException("Seules les collectes espèces agent peuvent être validées ainsi.");
        }
        if (!payflexProperties.getContributions().isAgentCashAutoValidate()) {
            return false;
        }
        applyValidation(contributionId, agentUserId, "agent");
        return true;
    }

    @Transactional
    public void validateByPaydunya(long contributionId, String paydunyaToken) {
        Map<String, Object> row = loadContribution(contributionId);
        if (row == null) {
            throw new IllegalArgumentException("Cotisation introuvable.");
        }
        if (!"pending".equals(row.get("status"))) {
            return;
        }
        String token = Objects.toString(row.get("paydunya_token"), "");
        if (!token.isBlank() && paydunyaToken != null && !paydunyaToken.equals(token)) {
            throw new IllegalArgumentException("Jeton PayDunya non concordant.");
        }
        jdbcTemplate.update(
            "UPDATE contributions SET payment_provider = 'paydunya' WHERE id = ?",
            contributionId
        );
        applyValidation(contributionId, null, "paydunya");
    }

    /**
     * Valide automatiquement les déclarations mobile money en attente depuis plus de {@code hours} heures.
     */
    @Transactional
    public int autoValidateStaleMobileDeclarations(int hours) {
        if (hours <= 0) {
            return 0;
        }
        List<Long> ids = jdbcTemplate.query(
            """
            SELECT id FROM contributions
            WHERE status = 'pending'
              AND LOWER(payment_mode) = 'mobile_money'
              AND (paydunya_token IS NULL OR paydunya_token = '')
              AND created_at < DATE_SUB(NOW(), INTERVAL ? HOUR)
            ORDER BY created_at ASC
            LIMIT 200
            """,
            (rs, i) -> rs.getLong(1),
            hours
        );
        int n = 0;
        for (Long id : ids) {
            try {
                applyAutoValidation(id, hours);
                n++;
            } catch (IllegalArgumentException ignored) {
                // ignoré si déjà traitée
            }
        }
        return n;
    }

    @Transactional
    public int bulkValidatePendingMobileDeclarations(String actorLogin) {
        List<Long> ids = jdbcTemplate.query(
            """
            SELECT id FROM contributions
            WHERE status = 'pending' AND LOWER(payment_mode) <> 'cash'
              AND (paydunya_token IS NULL OR paydunya_token = '')
            """,
            (rs, i) -> rs.getLong(1)
        );
        int n = 0;
        for (Long id : ids) {
            applyValidation(id, null, actorLogin == null ? "centre" : actorLogin);
            n++;
        }
        return n;
    }

    public record CashReconcileResult(
        int validatedCount,
        long validatedAmountFcfa,
        long expectedTotalFcfa,
        long collectedAmountFcfa,
        long debtRecordedFcfa,
        int stillPendingCount,
        long surplusFcfa
    ) {}

    private record PendingCashLine(long id, double amount, Long agentUserId) {}

    /** Ligne du tableau « Caisse par agent » : espèces en attente de rapprochement pour un agent. */
    public record PendingCashAgentRow(
        long agentId,
        long agentUserId,
        String fullName,
        long pendingCount,
        long expectedFcfa,
        long cashDebtFcfa
    ) {}

    /**
     * Rapprochement fin de journée : valide les espèces reçues en caisse (FIFO).
     * Si le montant compté est inférieur au total attendu, le reliquat est porté en dette agent (à rembourser).
     */
    @Transactional
    public CashReconcileResult reconcilePendingCash(double collectedFcfa, String actorLogin) {
        if (collectedFcfa < 0) {
            throw new IllegalArgumentException("Montant compté invalide.");
        }
        List<PendingCashLine> lines = jdbcTemplate.query(
            """
            SELECT c.id, c.amount, a.user_id AS agent_user_id
            FROM contributions c
            LEFT JOIN agents a ON a.id = c.agent_id
            WHERE c.status = 'pending' AND LOWER(c.payment_mode) = 'cash'
            ORDER BY c.created_at ASC, c.id ASC
            """,
            (rs, i) -> new PendingCashLine(
                rs.getLong("id"),
                rs.getDouble("amount"),
                rs.getObject("agent_user_id") == null ? null : rs.getLong("agent_user_id")
            )
        );
        if (lines.isEmpty()) {
            return new CashReconcileResult(0, 0, 0, Math.round(collectedFcfa), 0, 0, Math.round(collectedFcfa));
        }

        double totalExpected = lines.stream().mapToDouble(PendingCashLine::amount).sum();
        long expectedRounded = Math.round(totalExpected);
        long collectedRounded = Math.round(collectedFcfa);
        String actor = actorLogin == null ? "centre" : actorLogin;

        Map<Long, Double> agentTotals = new HashMap<>();
        for (PendingCashLine line : lines) {
            if (line.agentUserId() != null && line.agentUserId() > 0) {
                agentTotals.merge(line.agentUserId(), line.amount, Double::sum);
            }
        }

        double budget = collectedFcfa;
        int validated = 0;
        long validatedAmt = 0;
        for (PendingCashLine line : lines) {
            if (line.amount() <= budget + 0.009) {
                applyValidation(line.id(), null, actor);
                budget -= line.amount();
                validated++;
                validatedAmt += Math.round(line.amount());
            } else {
                break;
            }
        }

        int stillPending = lines.size() - validated;
        long debtRecorded = 0;
        if (collectedRounded < expectedRounded) {
            double shortfall = totalExpected - collectedFcfa;
            debtRecorded = Math.max(0, Math.round(shortfall));
            if (debtRecorded > 0 && !agentTotals.isEmpty()) {
                for (Map.Entry<Long, Double> entry : agentTotals.entrySet()) {
                    double share = entry.getValue() / totalExpected;
                    long agentDebt = Math.round(shortfall * share);
                    if (agentDebt > 0) {
                        recordAgentCashDebt(
                            entry.getKey(),
                            agentDebt,
                            collectedRounded,
                            expectedRounded,
                            "Rapprochement caisse incomplet — reliquat à rembourser au centre.",
                            actor
                        );
                    }
                }
            }
            auditService.logEquipe(
                actor,
                "Rapprochement espèces incomplet : "
                    + validated
                    + " cotisation(s) validée(s) pour "
                    + collectedRounded
                    + " FCFA sur "
                    + expectedRounded
                    + " FCFA attendus. Dette agent : "
                    + debtRecorded
                    + " FCFA."
            );
        } else {
            auditService.logEquipe(
                actor,
                "Rapprochement espèces complet : " + validated + " cotisation(s) validée(s) pour " + expectedRounded + " FCFA."
            );
        }

        return new CashReconcileResult(
            validated,
            validatedAmt,
            expectedRounded,
            collectedRounded,
            debtRecorded,
            stillPending,
            Math.max(0, collectedRounded - expectedRounded)
        );
    }

    /**
     * Rapprochement fin de journée : confirme toutes les collectes espèces (montant compté = total attendu).
     */
    @Transactional
    public int bulkValidatePendingCashCollections(String actorLogin) {
        CashReconcileResult r = reconcilePendingCash(pendingCashExpectedTotal(), actorLogin);
        return r.validatedCount();
    }

    /** Agents ayant des collectes espèces en attente de rapprochement (tableau « Caisse par agent »). */
    public List<PendingCashAgentRow> listPendingCashByAgent() {
        return jdbcTemplate.query(
            """
            SELECT a.id AS agent_id, a.user_id AS agent_user_id, u.full_name,
                   COUNT(c.id) AS pending_count,
                   COALESCE(SUM(c.amount), 0) AS expected_fcfa,
                   COALESCE(a.cash_debt_fcfa, 0) AS cash_debt_fcfa
            FROM contributions c
            JOIN agents a ON a.id = c.agent_id
            JOIN users u ON u.id = a.user_id
            WHERE c.status = 'pending' AND LOWER(c.payment_mode) = 'cash'
            GROUP BY a.id, a.user_id, u.full_name, a.cash_debt_fcfa
            ORDER BY expected_fcfa DESC
            """,
            (rs, i) -> new PendingCashAgentRow(
                rs.getLong("agent_id"),
                rs.getLong("agent_user_id"),
                rs.getString("full_name"),
                rs.getLong("pending_count"),
                Math.round(rs.getDouble("expected_fcfa")),
                Math.round(rs.getDouble("cash_debt_fcfa"))
            )
        );
    }

    /** Espèces en attente d'un agent donné : {@code count} + {@code totalFcfa} (bloc Caisse fiche agent). */
    public Map<String, Object> pendingCashSummaryForAgent(long agentId) {
        Map<String, Object> row = jdbcTemplate.queryForMap(
            """
            SELECT COUNT(*) AS pending_count, COALESCE(SUM(amount), 0) AS expected_fcfa
            FROM contributions
            WHERE status = 'pending' AND LOWER(payment_mode) = 'cash' AND agent_id = ?
            """,
            agentId
        );
        Map<String, Object> out = new LinkedHashMap<>();
        out.put("count", ((Number) row.get("pending_count")).longValue());
        out.put("totalFcfa", Math.round(((Number) row.get("expected_fcfa")).doubleValue()));
        return out;
    }

    /** Nombre de collectes espèces en attente sans agent rattaché (rapprochement global de secours). */
    public long countPendingCashWithoutAgent() {
        Long n = jdbcTemplate.queryForObject(
            """
            SELECT COUNT(*) FROM contributions
            WHERE status = 'pending' AND LOWER(payment_mode) = 'cash' AND agent_id IS NULL
            """,
            Long.class
        );
        return n == null ? 0L : n;
    }

    /**
     * Rapprochement de caisse PAR AGENT : valide les collectes espèces en attente de cet agent (FIFO)
     * à hauteur du montant compté. En cas de manque, la dette est portée sur cet agent uniquement.
     * Si le montant compté dépasse le total attendu, tout est validé et l'excédent est signalé
     * dans le résultat (aucun crédit fictif enregistré en base).
     */
    @Transactional
    public CashReconcileResult reconcilePendingCashForAgent(long agentId, double collectedFcfa, String actorLogin) {
        if (collectedFcfa < 0) {
            throw new IllegalArgumentException("Montant compté invalide.");
        }
        Long agentUserId;
        try {
            agentUserId = jdbcTemplate.queryForObject(
                "SELECT user_id FROM agents WHERE id = ?",
                Long.class,
                agentId
            );
        } catch (EmptyResultDataAccessException ex) {
            throw new IllegalArgumentException("Agent introuvable.");
        }
        if (agentUserId == null || agentUserId <= 0) {
            throw new IllegalArgumentException("Agent introuvable.");
        }
        String agentName = agentDisplayName(agentUserId);
        List<PendingCashLine> lines = jdbcTemplate.query(
            """
            SELECT c.id, c.amount, a.user_id AS agent_user_id
            FROM contributions c
            JOIN agents a ON a.id = c.agent_id
            WHERE c.status = 'pending' AND LOWER(c.payment_mode) = 'cash' AND c.agent_id = ?
            ORDER BY c.created_at ASC, c.id ASC
            """,
            (rs, i) -> new PendingCashLine(
                rs.getLong("id"),
                rs.getDouble("amount"),
                rs.getObject("agent_user_id") == null ? null : rs.getLong("agent_user_id")
            ),
            agentId
        );
        long collectedRounded = Math.round(collectedFcfa);
        if (lines.isEmpty()) {
            return new CashReconcileResult(0, 0, 0, collectedRounded, 0, 0, collectedRounded);
        }

        double totalExpected = lines.stream().mapToDouble(PendingCashLine::amount).sum();
        long expectedRounded = Math.round(totalExpected);
        String actor = actorLogin == null ? "centre" : actorLogin;

        double budget = collectedFcfa;
        int validated = 0;
        long validatedAmt = 0;
        for (PendingCashLine line : lines) {
            if (line.amount() <= budget + 0.009) {
                applyValidation(line.id(), null, actor);
                budget -= line.amount();
                validated++;
                validatedAmt += Math.round(line.amount());
            } else {
                break;
            }
        }

        int stillPending = lines.size() - validated;
        long debtRecorded = 0;
        long surplus = Math.max(0, collectedRounded - expectedRounded);
        if (collectedRounded < expectedRounded) {
            debtRecorded = Math.max(0, Math.round(totalExpected - collectedFcfa));
            if (debtRecorded > 0) {
                recordAgentCashDebt(
                    agentUserId,
                    debtRecorded,
                    collectedRounded,
                    expectedRounded,
                    "Rapprochement caisse agent incomplet — reliquat à rembourser au centre.",
                    actor
                );
            }
            auditService.logEquipe(
                actor,
                "Rapprochement caisse agent « " + agentName + " » incomplet : "
                    + validated + " cotisation(s) validée(s) pour "
                    + collectedRounded + " FCFA sur "
                    + expectedRounded + " FCFA attendus. Dette agent : "
                    + debtRecorded + " FCFA."
            );
        } else {
            String surplusSuffix = surplus > 0
                ? " Excédent compté de " + surplus + " FCFA à vérifier (non enregistré)."
                : "";
            auditService.logEquipe(
                actor,
                "Rapprochement caisse agent « " + agentName + " » complet : "
                    + validated + " cotisation(s) validée(s) pour "
                    + expectedRounded + " FCFA." + surplusSuffix
            );
        }

        return new CashReconcileResult(
            validated,
            validatedAmt,
            expectedRounded,
            collectedRounded,
            debtRecorded,
            stillPending,
            surplus
        );
    }

    /** Historique des écarts de caisse (dettes) d'un agent — journal {@code agent_cash_debt_events}. */
    public List<Map<String, Object>> listAgentCashDebtEvents(long agentUserId, int limit) {
        return jdbcTemplate.queryForList(
            """
            SELECT id, amount_fcfa, collected_fcfa, expected_fcfa, note, created_by, created_at
            FROM agent_cash_debt_events
            WHERE agent_user_id = ?
            ORDER BY created_at DESC, id DESC
            LIMIT ?
            """,
            agentUserId,
            Math.max(1, Math.min(limit, 100))
        );
    }

    /** Historique des remboursements de dette d'un agent — table {@code agent_debt_repayments}. */
    public List<Map<String, Object>> listAgentDebtRepayments(long agentUserId, int limit) {
        return jdbcTemplate.queryForList(
            """
            SELECT id, amount_fcfa, note, created_by, created_at
            FROM agent_debt_repayments
            WHERE agent_user_id = ?
            ORDER BY created_at DESC, id DESC
            LIMIT ?
            """,
            agentUserId,
            Math.max(1, Math.min(limit, 100))
        );
    }

    /**
     * Remboursement (total ou partiel) de la dette de caisse d'un agent, encaissé au centre.
     */
    @Transactional
    public void recordAgentDebtRepayment(long agentId, long amountFcfa, String note, String adminUser) {
        Long agentUserId;
        try {
            agentUserId = jdbcTemplate.queryForObject(
                "SELECT user_id FROM agents WHERE id = ?",
                Long.class,
                agentId
            );
        } catch (EmptyResultDataAccessException ex) {
            throw new IllegalArgumentException("Agent introuvable.");
        }
        if (agentUserId == null || agentUserId <= 0) {
            throw new IllegalArgumentException("Agent introuvable.");
        }
        if (amountFcfa <= 0) {
            throw new IllegalArgumentException("Montant de remboursement invalide.");
        }
        Double debt = jdbcTemplate.queryForObject(
            "SELECT COALESCE(cash_debt_fcfa, 0) FROM agents WHERE id = ?",
            Double.class,
            agentId
        );
        long currentDebt = debt == null ? 0 : Math.round(debt);
        if (currentDebt <= 0) {
            throw new IllegalArgumentException("Cet agent n'a aucune dette de caisse à rembourser.");
        }
        if (amountFcfa > currentDebt) {
            throw new IllegalArgumentException(
                "Le remboursement (" + amountFcfa + " FCFA) dépasse la dette actuelle (" + currentDebt + " FCFA)."
            );
        }
        String actor = adminUser == null ? "centre" : adminUser;
        String cleanNote = note == null || note.isBlank() ? null : note.trim();
        jdbcTemplate.update(
            "UPDATE agents SET cash_debt_fcfa = cash_debt_fcfa - ? WHERE id = ?",
            amountFcfa,
            agentId
        );
        jdbcTemplate.update(
            """
            INSERT INTO agent_debt_repayments (agent_user_id, amount_fcfa, note, created_by)
            VALUES (?, ?, ?, ?)
            """,
            agentUserId,
            amountFcfa,
            cleanNote,
            actor
        );
        long remaining = currentDebt - amountFcfa;
        auditService.logEquipe(
            actor,
            "Remboursement dette caisse de " + amountFcfa + " FCFA encaissé pour l'agent « "
                + agentDisplayName(agentUserId) + " ». Dette restante : " + remaining + " FCFA."
        );
        auditService.logAgent(
            agentUserId,
            "Dette caisse -" + amountFcfa + " FCFA (remboursement au centre). Restant : " + remaining + " FCFA."
        );
        String inboxBody = remaining > 0
            ? "Votre remboursement de " + amountFcfa + " FCFA a bien été enregistré au centre. "
                + "Il vous reste " + remaining + " FCFA à régulariser."
            : "Votre remboursement de " + amountFcfa + " FCFA a bien été enregistré au centre. "
                + "Votre dette de caisse est entièrement soldée. Merci.";
        inboxNotifications.notifyUser(
            agentUserId,
            "debt_repayment_recorded",
            "Remboursement enregistré",
            inboxBody,
            null
        );
    }

    private String agentDisplayName(long agentUserId) {
        try {
            String name = jdbcTemplate.queryForObject(
                "SELECT full_name FROM users WHERE id = ?",
                String.class,
                agentUserId
            );
            return name != null && !name.isBlank() ? name.trim() : "Agent n° " + agentUserId;
        } catch (EmptyResultDataAccessException ex) {
            return "Agent n° " + agentUserId;
        }
    }

    private double pendingCashExpectedTotal() {
        Double total = jdbcTemplate.queryForObject(
            """
            SELECT COALESCE(SUM(amount), 0)
            FROM contributions
            WHERE status = 'pending' AND LOWER(payment_mode) = 'cash'
            """,
            Double.class
        );
        return total == null ? 0 : total;
    }

    private void recordAgentCashDebt(
        long agentUserId,
        long amountFcfa,
        long collectedFcfa,
        long expectedFcfa,
        String note,
        String actor
    ) {
        jdbcTemplate.update(
            "UPDATE agents SET cash_debt_fcfa = COALESCE(cash_debt_fcfa, 0) + ? WHERE user_id = ?",
            amountFcfa,
            agentUserId
        );
        jdbcTemplate.update(
            """
            INSERT INTO agent_cash_debt_events
              (agent_user_id, amount_fcfa, collected_fcfa, expected_fcfa, note, created_by)
            VALUES (?, ?, ?, ?, ?, ?)
            """,
            agentUserId,
            amountFcfa,
            collectedFcfa,
            expectedFcfa,
            note,
            actor
        );
        auditService.logAgent(
            agentUserId,
            "Dette caisse +" + amountFcfa + " FCFA (rapprochement incomplet — à rembourser)."
        );
        String agentName = agentDisplayName(agentUserId);
        // Alerte centre (page cotisations) + Web Push admin + inbox agent.
        alertService.createGeneral(
            ContributionValidationAlertService.TYPE_AGENT_CASH_DEBT,
            "Dette de caisse : manque de " + amountFcfa + " FCFA constaté pour l'agent " + agentName
                + " (compté " + collectedFcfa + " FCFA sur " + expectedFcfa + " FCFA attendus)."
        );
        adminWebPushService.notifyAllAdmins(
            "Dette de caisse agent",
            "Manque de " + amountFcfa + " FCFA constaté pour " + agentName + " lors du comptage de caisse.",
            "/admin/contributions?status=pending&paymentMode=cash"
        );
        inboxNotifications.notifyUser(
            agentUserId,
            "cash_debt_recorded",
            "Écart de caisse constaté",
            "Un manque de " + amountFcfa + " FCFA a été constaté lors du comptage de caisse. "
                + "Merci de régulariser au centre.",
            null
        );
    }

    private void requirePendingMobileDeclaration(long contributionId) {
        Map<String, Object> row = loadContribution(contributionId);
        if (row == null) {
            throw new IllegalArgumentException("Cotisation introuvable.");
        }
        if (!"pending".equals(row.get("status"))) {
            throw new IllegalArgumentException("Cette cotisation n'est plus en attente.");
        }
    }

    private boolean canAgentValidateContribution(long contributionId, long agentUserId) {
        Long agentRowId = findAgentRowIdByUserId(agentUserId);
        if (agentRowId == null) {
            return false;
        }
        Long n = jdbcTemplate.queryForObject(
            """
            SELECT COUNT(*)
            FROM contributions c
            JOIN users u ON u.id = c.user_id
            WHERE c.id = ? AND c.status = 'pending' AND LOWER(c.payment_mode) <> 'cash'
              AND (u.assigned_agent_user_id = ? OR c.agent_id = ?)
            """,
            Long.class,
            contributionId,
            agentUserId,
            agentRowId
        );
        return n != null && n > 0;
    }

    private void applyAutoValidation(long contributionId, int hours) {
        Map<String, Object> row = loadContribution(contributionId);
        if (row == null || !"pending".equals(row.get("status"))) {
            throw new IllegalArgumentException("Cotisation non éligible.");
        }
        String reason = "Validation automatique après " + hours + " h sans réponse agent.";
        jdbcTemplate.update(
            """
            UPDATE contributions
            SET auto_validated_at = NOW(), auto_validated_reason = ?
            WHERE id = ?
            """,
            reason,
            contributionId
        );
        applyValidation(contributionId, null, "auto-centre");
        alertService.create(
            contributionId,
            ContributionValidationAlertService.TYPE_AUTO_TIMEOUT,
            reason + " Cotisation #" + contributionId + "."
        );
        auditService.logEquipe(
            "auto-centre",
            "Validation automatique cotisation #" + contributionId + " (" + reason + ")."
        );
    }

    private void applyValidation(long contributionId, Long validatorUserId, String actorLabel) {
        Map<String, Object> row = loadContribution(contributionId);
        if (row == null) {
            throw new IllegalArgumentException("Cotisation introuvable.");
        }
        if (!"pending".equals(row.get("status"))) {
            throw new IllegalArgumentException("Cette cotisation n'est plus en attente.");
        }
        long clientUserId = ((Number) row.get("user_id")).longValue();
        double amount = ((Number) row.get("amount")).doubleValue();
        String ref = Objects.toString(row.get("reference_code"), "");

        // Transition pending → validated + répartition automatique de l'éventuel excédent sur
        // les autres produits actifs du client (voir ContributionAllocationService).
        ContributionAllocationService.AllocationOutcome outcome =
            contributionAllocationService.allocateAndValidate(contributionId);

        if (outcome.wasSplit()) {
            jdbcTemplate.update(
                "UPDATE contributions SET validated_by_user_id = ?, rejection_reason = NULL WHERE id = ? OR allocation_group_id = ?",
                validatorUserId,
                contributionId,
                outcome.allocationGroupId()
            );
        } else {
            jdbcTemplate.update(
                "UPDATE contributions SET validated_by_user_id = ?, rejection_reason = NULL WHERE id = ?",
                validatorUserId,
                contributionId
            );
        }

        long amt = Math.round(amount);
        String refSuffix = ref.isBlank() ? "." : " (réf. " + ref + ").";
        String actor = actorLabel == null ? "" : actorLabel.trim().toLowerCase();

        String clientTitle = "Cotisation confirmée";
        String clientMsg;
        String agentTitle = "Cotisation validée — {client}";
        String agentMsg;

        if (validatorUserId != null && validatorUserId > 0) {
            clientMsg = "Votre versement de " + amt + " FCFA a été validé" + refSuffix;
            agentTitle = "Confirmation — {client}";
            agentMsg = "Vous avez validé la cotisation de {client} (" + amt + " FCFA).";
            auditService.logAgent(
                validatorUserId,
                "A validé la cotisation mobile de " + amt + " FCFA pour le client #" + clientUserId + "."
            );
            auditService.logClient(
                clientUserId,
                "Cotisation de " + amt + " FCFA confirmée par votre agent PayFlex."
            );
        } else if ("paydunya".equals(actor)) {
            clientMsg = "PayDunya a confirmé votre versement de " + amt + " FCFA" + refSuffix;
            agentMsg = "Paiement PayDunya confirmé pour {client} (" + amt + " FCFA).";
            auditService.logEquipe(
                "paydunya",
                "Validation PayDunya cotisation #" + contributionId + " (" + amt + " FCFA)."
            );
            auditService.logClient(clientUserId, "Cotisation confirmée via PayDunya (" + amt + " FCFA).");
        } else if ("auto-centre".equals(actor)) {
            int hours = payflexProperties.getContributions().getAutoValidateMobileMoneyHours();
            clientMsg = "Votre versement de "
                + amt
                + " FCFA a été validé automatiquement après "
                + hours
                + " h sans réponse de l’agent"
                + refSuffix;
            agentMsg =
                "La cotisation de {client} (" + amt + " FCFA) a été validée automatiquement (délai dépassé).";
            auditService.logEquipe(
                actorLabel,
                "Validation automatique cotisation #" + contributionId + " (" + amt + " FCFA)."
            );
            auditService.logClient(
                clientUserId,
                "Cotisation validée automatiquement par le centre (" + amt + " FCFA)."
            );
        } else {
            clientMsg = "Votre versement de " + amt + " FCFA a été validé par le centre PayFlex" + refSuffix;
            agentMsg = "Le centre PayFlex a validé la cotisation de {client} (" + amt + " FCFA).";
            auditService.logEquipe(
                actorLabel,
                "Validation centre de la cotisation #" + contributionId + " (" + amt + " FCFA)."
            );
            auditService.logClient(
                clientUserId,
                "Cotisation de " + amt + " FCFA confirmée par le centre PayFlex."
            );
        }

        if (outcome.wasSplit()) {
            // Remplace le message « validation simple » par le récapitulatif de répartition
            // (une seule notification claire listant chaque produit et montant, comme demandé).
            clientMsg = buildAllocationClientMessage(outcome);
            agentMsg = buildAllocationAgentMessage(outcome);
            inboxNotifications.notifyUser(
                clientUserId,
                NOTIF_TYPE_ALLOCATED_MULTI,
                "Paiement réparti automatiquement",
                clientMsg,
                contributionId
            );
            inboxNotifications.notifyAssignedAgentOnly(
                clientUserId,
                NOTIF_TYPE_ALLOCATED_MULTI,
                "Paiement réparti — {client}",
                agentMsg,
                contributionId
            );
            if (outcome.unallocatedSurplusFcfa() > 0.009) {
                notifyUnallocatedSurplus(outcome);
            }
        } else {
            inboxNotifications.notifyUser(
                clientUserId,
                NOTIF_TYPE_VALIDATED,
                clientTitle,
                clientMsg,
                contributionId
            );
            inboxNotifications.notifyAssignedAgentOnly(
                clientUserId,
                "contribution_validated",
                agentTitle,
                agentMsg,
                contributionId
            );
        }

        if (outcome.wasSplit()) {
            // Répartition sur plusieurs produits : un même paiement peut faire atteindre
            // l'objectif de PLUSIEURS produits à la fois (ex. cascade qui complète B puis C) —
            // on notifie individuellement chaque produit concerné.
            for (ContributionAllocationService.AllocationLine line : outcome.lines()) {
                if (line.goalReachedNow()) {
                    maybeNotifyGoalReached(clientUserId, line.contributionId());
                }
            }
        } else {
            // Cas non réparti : comportement historique inchangé (la logique interne revérifie
            // elle-même si l'objectif est atteint ; sans effet sinon).
            maybeNotifyGoalReached(clientUserId, contributionId);
        }
    }

    /** Message client : récapitulatif clair de la répartition automatique d'un paiement. */
    private String buildAllocationClientMessage(ContributionAllocationService.AllocationOutcome outcome) {
        long total = Math.round(outcome.originalAmountFcfa());
        List<ContributionAllocationService.AllocationLine> lines = outcome.lines();
        StringBuilder sb = new StringBuilder();
        if (lines.isEmpty()) {
            sb.append("Votre versement de ")
                .append(total)
                .append(" FCFA a été confirmé, mais n'a pu être affecté à aucun produit (tous vos objectifs en cours sont déjà atteints).");
        } else if (lines.size() == 1) {
            ContributionAllocationService.AllocationLine only = lines.get(0);
            sb.append("Votre versement de ")
                .append(total)
                .append(" FCFA a été affecté à « ")
                .append(only.productName())
                .append(" »")
                .append(only.goalReachedNow() ? " — objectif atteint !" : ".");
        } else {
            sb.append("Votre paiement de ").append(total).append(" FCFA a été réparti automatiquement : ");
            List<String> parts = new ArrayList<>();
            for (ContributionAllocationService.AllocationLine line : lines) {
                parts.add(
                    Math.round(line.amountFcfa())
                        + " FCFA pour « " + line.productName() + " »"
                        + (line.goalReachedNow() ? " (objectif atteint)" : "")
                );
            }
            sb.append(String.join(", ", parts)).append(".");
        }
        if (outcome.unallocatedSurplusFcfa() > 0.009) {
            sb.append(" ")
                .append(Math.round(outcome.unallocatedSurplusFcfa()))
                .append(" FCFA n'ont pas pu être affectés à un produit actif (aucun produit en cours disponible) : ")
                .append("ce montant est conservé et le centre PayFlex vous contactera pour l'affecter manuellement.");
        }
        return sb.toString();
    }

    /** Message agent (parrain) : même récapitulatif, formulation courte à la 3e personne. */
    private String buildAllocationAgentMessage(ContributionAllocationService.AllocationOutcome outcome) {
        long total = Math.round(outcome.originalAmountFcfa());
        List<ContributionAllocationService.AllocationLine> lines = outcome.lines();
        List<String> parts = new ArrayList<>();
        for (ContributionAllocationService.AllocationLine line : lines) {
            parts.add(Math.round(line.amountFcfa()) + " FCFA → « " + line.productName() + " »");
        }
        String detail = parts.isEmpty() ? "aucun produit disponible" : String.join(", ", parts);
        String suffix = outcome.unallocatedSurplusFcfa() > 0.009
            ? " (" + Math.round(outcome.unallocatedSurplusFcfa()) + " FCFA non affectés — à régulariser au centre)"
            : "";
        return "Le paiement de {client} (" + total + " FCFA) a été réparti automatiquement : " + detail + suffix + ".";
    }

    /** Surplus qu'aucun produit actif ne peut absorber : traçable, jamais perdu — alerte centre + notif client dédiée. */
    private void notifyUnallocatedSurplus(ContributionAllocationService.AllocationOutcome outcome) {
        long surplus = Math.round(outcome.unallocatedSurplusFcfa());
        alertService.createGeneral(
            ContributionValidationAlertService.TYPE_UNALLOCATED_SURPLUS,
            "Surplus non affecté de " + surplus + " FCFA pour le client #" + outcome.clientUserId()
                + " (groupe de répartition #" + outcome.allocationGroupId() + ") — aucun produit actif disponible. "
                + "Affectation manuelle requise (nouvelle sélection produit ou remboursement)."
        );
        adminWebPushService.notifyAllAdmins(
            "Surplus de cotisation non affecté",
            surplus + " FCFA n'ont pas pu être affectés à un produit pour le client #" + outcome.clientUserId() + ".",
            "/admin/contributions?status=validated"
        );
    }

    public void notifyPaydunyaContributionCanceled(long contributionId) {
        Map<String, Object> row = loadContribution(contributionId);
        if (row == null) {
            return;
        }
        long clientUserId = ((Number) row.get("user_id")).longValue();
        double amount = ((Number) row.get("amount")).doubleValue();
        String motif = "Paiement PayDunya annulé ou expiré. Vous pouvez réessayer depuis l’application.";
        inboxNotifications.notifyUser(
            clientUserId,
            NOTIF_TYPE_REJECTED,
            "Paiement non abouti",
            "Votre versement de " + Math.round(amount) + " FCFA via PayDunya n’a pas abouti : " + motif,
            contributionId
        );
        inboxNotifications.notifyAssignedAgentOnly(
            clientUserId,
            "contribution_rejected",
            "Paiement PayDunya — {client}",
            "Le paiement PayDunya de {client} (" + Math.round(amount) + " FCFA) a été annulé ou a expiré.",
            contributionId
        );
    }

    private void maybeNotifyGoalReached(long clientUserId, long contributionId) {
        if (clientUserId <= 0) {
            return;
        }
        Map<String, Object> row;
        try {
            row = jdbcTemplate.queryForMap(
                """
                SELECT c.product_id, p.name AS product_name, p.price AS product_price
                FROM contributions c
                LEFT JOIN products p ON p.id = c.product_id
                WHERE c.id = ?
                """,
                contributionId
            );
        } catch (EmptyResultDataAccessException ex) {
            return;
        }
        Object productIdObj = row.get("product_id");
        if (productIdObj == null) {
            return;
        }
        long productId = ((Number) productIdObj).longValue();
        double price = row.get("product_price") instanceof Number n ? n.doubleValue() : 0;
        if (price <= 0) {
            return;
        }
        Long already;
        try {
            already = jdbcTemplate.queryForObject(
                "SELECT goal_notified_for_product_id FROM users WHERE id = ?",
                Long.class,
                clientUserId
            );
        } catch (EmptyResultDataAccessException ex) {
            return;
        }
        if (already != null && already == productId) {
            return;
        }
        Double total = jdbcTemplate.queryForObject(
            """
            SELECT COALESCE(SUM(amount), 0) FROM contributions
            WHERE user_id = ? AND product_id = ? AND status = 'validated'
            """,
            Double.class,
            clientUserId,
            productId
        );
        if (total == null || total < price) {
            return;
        }
        String productName = Objects.toString(row.get("product_name"), "votre produit");
        inboxNotifications.notifyClientAndAssignedAgent(
            clientUserId,
            "goal_reached",
            "Objectif atteint !",
            "Félicitations ! Vous avez atteint l’objectif pour « "
                + productName
                + " ». Le centre PayFlex vous contactera pour la suite (livraison / retrait).",
            "Objectif atteint — {client}",
            "Votre client {client} a atteint son objectif PayFlex (« " + productName + " »).",
            null
        );
        jdbcTemplate.update(
            "UPDATE users SET goal_notified_for_product_id = ? WHERE id = ?",
            productId,
            clientUserId
        );
        productDeliveryService.ensureAwaitingClosure(clientUserId, productId);
    }

    private void applyRejection(long contributionId, Long validatorUserId, String reason, String actorLabel) {
        Map<String, Object> row = loadContribution(contributionId);
        if (row == null) {
            throw new IllegalArgumentException("Cotisation introuvable.");
        }
        if (!"pending".equals(row.get("status"))) {
            throw new IllegalArgumentException("Cette cotisation n'est plus en attente.");
        }
        String motif = reason == null || reason.isBlank()
            ? "Versement non confirmé. Contactez votre agent ou le centre PayFlex."
            : reason.trim();
        jdbcTemplate.update(
            """
            UPDATE contributions
            SET status = 'rejected', paid_at = NULL, validated_by_user_id = ?, rejection_reason = ?
            WHERE id = ?
            """,
            validatorUserId,
            motif,
            contributionId
        );
        long clientUserId = ((Number) row.get("user_id")).longValue();
        double amount = ((Number) row.get("amount")).doubleValue();
        inboxNotifications.notifyUser(
            clientUserId,
            NOTIF_TYPE_REJECTED,
            "Cotisation refusée",
            "Votre versement de " + Math.round(amount) + " FCFA n'a pas été confirmé : " + motif,
            contributionId
        );
        if (validatorUserId != null && validatorUserId > 0) {
            auditService.logAgent(validatorUserId, "A refusé une cotisation mobile (" + motif + ").");
            auditService.logClient(clientUserId, "Cotisation refusée par votre agent : " + motif);
            inboxNotifications.notifyAssignedAgentOnly(
                clientUserId,
                "contribution_rejected",
                "Refus enregistré — {client}",
                "Vous avez refusé la cotisation de {client} : " + motif,
                contributionId
            );
        } else {
            auditService.logEquipe(actorLabel, "Refus centre de la cotisation #" + contributionId + ".");
            auditService.logClient(clientUserId, "Cotisation refusée par le centre : " + motif);
            inboxNotifications.notifyAssignedAgentOnly(
                clientUserId,
                "contribution_rejected",
                "Cotisation refusée — {client}",
                "Le centre a refusé la cotisation de {client} : " + motif,
                contributionId
            );
        }
    }

    public void notifyClientInbox(long clientUserId, String type, String title, String body, Long contributionId) {
        inboxNotifications.notifyUser(clientUserId, type, title, body, contributionId);
    }

    /** Client : nouvelle cotisation mobile money en attente + alerte agent parrain. */
    public void notifyContributionPendingDeclaration(long clientUserId, long contributionId, double amount, String paymentMode) {
        String modeLabel = "cash".equalsIgnoreCase(paymentMode) ? "espèces" : "mobile money";
        long amt = Math.round(amount);
        inboxNotifications.notifyClientAndAssignedAgent(
            clientUserId,
            "contribution_pending",
            "Cotisation en attente",
            "Votre versement de " + amt + " FCFA (" + modeLabel + ") est enregistré. "
                + "Vous serez notifié après validation.",
            "À valider — {client}",
            "Votre client {client} a déclaré " + amt + " FCFA (" + modeLabel + "). "
                + "Merci de valider ou refuser dans l'application agent.",
            contributionId
        );
    }

    private Map<String, Object> loadContribution(long id) {
        try {
            return jdbcTemplate.queryForMap(
                "SELECT id, user_id, amount, status, reference_code, payment_mode FROM contributions WHERE id = ?",
                id
            );
        } catch (EmptyResultDataAccessException ex) {
            return null;
        }
    }

    private Long findAgentRowIdByUserId(long agentUserId) {
        try {
            return jdbcTemplate.queryForObject(
                "SELECT id FROM agents WHERE user_id = ? LIMIT 1",
                Long.class,
                agentUserId
            );
        } catch (EmptyResultDataAccessException ex) {
            return null;
        }
    }
}
