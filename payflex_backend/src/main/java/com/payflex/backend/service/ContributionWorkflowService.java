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

    private final JdbcTemplate jdbcTemplate;
    private final PermissionService permissionService;
    private final AdminAuditService auditService;
    private final ContributionValidationAlertService alertService;
    private final PayflexProperties payflexProperties;
    private final UserInboxNotificationService inboxNotifications;
    private final ProductDeliveryService productDeliveryService;

    public ContributionWorkflowService(
        JdbcTemplate jdbcTemplate,
        PermissionService permissionService,
        AdminAuditService auditService,
        ContributionValidationAlertService alertService,
        PayflexProperties payflexProperties,
        UserInboxNotificationService inboxNotifications,
        ProductDeliveryService productDeliveryService
    ) {
        this.jdbcTemplate = jdbcTemplate;
        this.permissionService = permissionService;
        this.auditService = auditService;
        this.alertService = alertService;
        this.payflexProperties = payflexProperties;
        this.inboxNotifications = inboxNotifications;
        this.productDeliveryService = productDeliveryService;
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
    public void validateByFedaPay(long contributionId, String fedapayTransactionId) {
        Map<String, Object> row = loadContribution(contributionId);
        if (row == null) {
            throw new IllegalArgumentException("Cotisation introuvable.");
        }
        if (!"pending".equals(row.get("status"))) {
            return;
        }
        String tx = Objects.toString(row.get("fedapay_transaction_id"), "");
        if (!tx.isBlank() && fedapayTransactionId != null && !fedapayTransactionId.equals(tx)) {
            throw new IllegalArgumentException("Transaction FedaPay non concordante.");
        }
        jdbcTemplate.update(
            "UPDATE contributions SET payment_provider = 'fedapay' WHERE id = ?",
            contributionId
        );
        applyValidation(contributionId, null, "fedapay");
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
              AND (fedapay_transaction_id IS NULL OR fedapay_transaction_id = '')
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
              AND (fedapay_transaction_id IS NULL OR fedapay_transaction_id = '')
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
        int stillPendingCount
    ) {}

    private record PendingCashLine(long id, double amount, Long agentUserId) {}

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
            return new CashReconcileResult(0, 0, 0, Math.round(collectedFcfa), 0, 0);
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
            stillPending
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
        jdbcTemplate.update(
            """
            UPDATE contributions
            SET status = 'validated', paid_at = NOW(), validated_by_user_id = ?, rejection_reason = NULL
            WHERE id = ?
            """,
            validatorUserId,
            contributionId
        );
        long clientUserId = ((Number) row.get("user_id")).longValue();
        double amount = ((Number) row.get("amount")).doubleValue();
        String ref = Objects.toString(row.get("reference_code"), "");
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
        } else if ("fedapay".equals(actor)) {
            clientMsg = "FedaPay a confirmé votre versement de " + amt + " FCFA" + refSuffix;
            agentMsg = "Paiement FedaPay confirmé pour {client} (" + amt + " FCFA).";
            auditService.logEquipe(
                "fedapay",
                "Validation FedaPay cotisation #" + contributionId + " (" + amt + " FCFA)."
            );
            auditService.logClient(clientUserId, "Cotisation confirmée via FedaPay (" + amt + " FCFA).");
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

        inboxNotifications.notifyUser(
            clientUserId,
            NOTIF_TYPE_VALIDATED,
            clientTitle,
            clientMsg,
            contributionId
        );
        if (validatorUserId != null && validatorUserId > 0) {
            inboxNotifications.notifyAssignedAgentOnly(
                clientUserId,
                "contribution_validated",
                agentTitle,
                agentMsg,
                contributionId
            );
        } else {
            inboxNotifications.notifyAssignedAgentOnly(
                clientUserId,
                "contribution_validated",
                agentTitle,
                agentMsg,
                contributionId
            );
        }
        maybeNotifyGoalReached(clientUserId, contributionId);
    }

    /** Refus paiement FedaPay (webhook annulation / expiration). */
    public void notifyFedaPayContributionCanceled(long contributionId) {
        Map<String, Object> row = loadContribution(contributionId);
        if (row == null) {
            return;
        }
        long clientUserId = ((Number) row.get("user_id")).longValue();
        double amount = ((Number) row.get("amount")).doubleValue();
        String motif = "Paiement FedaPay annulé ou expiré. Vous pouvez réessayer depuis l’application.";
        inboxNotifications.notifyUser(
            clientUserId,
            NOTIF_TYPE_REJECTED,
            "Paiement non abouti",
            "Votre versement de " + Math.round(amount) + " FCFA via FedaPay n’a pas abouti : " + motif,
            contributionId
        );
        inboxNotifications.notifyAssignedAgentOnly(
            clientUserId,
            "contribution_rejected",
            "Paiement FedaPay — {client}",
            "Le paiement FedaPay de {client} (" + Math.round(amount) + " FCFA) a été annulé ou a expiré.",
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
