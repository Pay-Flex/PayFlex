package com.payflex.backend.service;

import com.payflex.backend.config.PayflexProperties;
import org.springframework.dao.EmptyResultDataAccessException;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.ArrayList;
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

    public ContributionWorkflowService(
        JdbcTemplate jdbcTemplate,
        PermissionService permissionService,
        AdminAuditService auditService,
        ContributionValidationAlertService alertService,
        PayflexProperties payflexProperties
    ) {
        this.jdbcTemplate = jdbcTemplate;
        this.permissionService = permissionService;
        this.auditService = auditService;
        this.alertService = alertService;
        this.payflexProperties = payflexProperties;
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
            SELECT id, type, title, body, contribution_id, read_at, created_at
            FROM client_notifications
            WHERE user_id = ?
            """;
        if (unreadOnly) {
            sql += " AND read_at IS NULL";
        }
        sql += " ORDER BY created_at DESC LIMIT 50";
        List<Map<String, Object>> rows = jdbcTemplate.queryForList(sql, clientUserId);
        List<Map<String, Object>> out = new ArrayList<>();
        for (Map<String, Object> row : rows) {
            Map<String, Object> m = new LinkedHashMap<>(row);
            Object ts = row.get("created_at");
            if (ts != null) {
                m.put("created_at", ts.toString());
            }
            m.put("read", row.get("read_at") != null);
            out.add(m);
        }
        return out;
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
     * Collecte espèces enregistrée par l'agent : validation immédiate si activée dans la config.
     */
    @Transactional
    public void validateAgentCashCollection(long contributionId, long agentUserId) {
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
            return;
        }
        applyValidation(contributionId, agentUserId, "agent");
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
        notifyClient(
            clientUserId,
            NOTIF_TYPE_VALIDATED,
            "Cotisation confirmée",
            "Votre versement de " + Math.round(amount) + " FCFA a été validé"
                + (ref.isBlank() ? "." : " (réf. " + ref + ")."),
            contributionId
        );
        if (validatorUserId != null && validatorUserId > 0) {
            auditService.logAgent(
                validatorUserId,
                "A validé la cotisation mobile de " + Math.round(amount) + " FCFA pour le client #"
                    + clientUserId + "."
            );
            auditService.logClient(
                clientUserId,
                "Cotisation de " + Math.round(amount) + " FCFA confirmée par votre agent PayFlex."
            );
        } else {
            auditService.logEquipe(
                actorLabel,
                "Validation centre de la cotisation #" + contributionId + " (" + Math.round(amount) + " FCFA)."
            );
            auditService.logClient(
                clientUserId,
                "Cotisation de " + Math.round(amount) + " FCFA confirmée par le centre PayFlex."
            );
        }
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
        notifyClient(
            clientUserId,
            NOTIF_TYPE_REJECTED,
            "Cotisation refusée",
            "Votre versement de " + Math.round(amount) + " FCFA n'a pas été confirmé : " + motif,
            contributionId
        );
        if (validatorUserId != null && validatorUserId > 0) {
            auditService.logAgent(validatorUserId, "A refusé une cotisation mobile (" + motif + ").");
            auditService.logClient(clientUserId, "Cotisation refusée par votre agent : " + motif);
        } else {
            auditService.logEquipe(actorLabel, "Refus centre de la cotisation #" + contributionId + ".");
            auditService.logClient(clientUserId, "Cotisation refusée par le centre : " + motif);
        }
    }

    public void notifyClientInbox(long clientUserId, String type, String title, String body, Long contributionId) {
        jdbcTemplate.update(
            """
            INSERT INTO client_notifications (user_id, type, title, body, contribution_id)
            VALUES (?, ?, ?, ?, ?)
            """,
            clientUserId,
            type,
            title,
            body,
            contributionId
        );
    }

    private void notifyClient(long clientUserId, String type, String title, String body, long contributionId) {
        notifyClientInbox(clientUserId, type, title, body, contributionId);
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
