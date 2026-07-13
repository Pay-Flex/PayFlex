package com.payflex.backend.service;

import org.springframework.dao.EmptyResultDataAccessException;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;

import java.time.YearMonth;

/**
 * Boîte de réception mobile (clients et agents) — push pull sans Firebase.
 * Table {@code client_notifications} : une ligne par utilisateur destinataire ({@code user_id}).
 */
@Service
public class UserInboxNotificationService {

    private final JdbcTemplate jdbcTemplate;
    private final FcmPushService fcmPushService;

    public UserInboxNotificationService(JdbcTemplate jdbcTemplate, FcmPushService fcmPushService) {
        this.jdbcTemplate = jdbcTemplate;
        this.fcmPushService = fcmPushService;
    }

    public void notifyUser(
        long recipientUserId,
        String type,
        String title,
        String body,
        Long contributionId,
        Long relatedClientUserId
    ) {
        if (recipientUserId <= 0 || title == null || title.isBlank()) {
            return;
        }
        String safeBody = body == null ? "" : body.trim();
        if (safeBody.isEmpty()) {
            safeBody = title;
        }
        String finalType = type == null ? "info" : type;
        String finalBody = safeBody.length() > 2000 ? safeBody.substring(0, 1997) + "…" : safeBody;
        jdbcTemplate.update(
            """
            INSERT INTO client_notifications (user_id, type, title, body, contribution_id, related_client_user_id)
            VALUES (?, ?, ?, ?, ?, ?)
            """,
            recipientUserId,
            finalType,
            title.trim(),
            finalBody,
            contributionId,
            relatedClientUserId != null && relatedClientUserId > 0 ? relatedClientUserId : null
        );
        // Push FCM temps réel en plus de l'inbox « pull » (ignoré si Firebase non configuré).
        java.util.Map<String, String> data = new java.util.HashMap<>();
        data.put("type", finalType);
        if (contributionId != null) {
            data.put("contribution_id", String.valueOf(contributionId));
        }
        if (relatedClientUserId != null && relatedClientUserId > 0) {
            data.put("related_client_user_id", String.valueOf(relatedClientUserId));
        }
        fcmPushService.sendToUser(recipientUserId, title.trim(), finalBody, data);
    }

    public void notifyUser(long recipientUserId, String type, String title, String body, Long contributionId) {
        notifyUser(recipientUserId, type, title, body, contributionId, null);
    }

    /** Notifie le client puis son agent parrain (si assigné). */
    public void notifyClientAndAssignedAgent(
        long clientUserId,
        String type,
        String clientTitle,
        String clientBody,
        String agentTitle,
        String agentBody,
        Long contributionId
    ) {
        notifyUser(clientUserId, type, clientTitle, clientBody, contributionId, null);
        Long agentId = findAssignedAgentUserId(clientUserId);
        if (agentId == null) {
            return;
        }
        String name = clientDisplayName(clientUserId);
        String aTitle = agentTitle != null && !agentTitle.isBlank()
            ? agentTitle.replace("{client}", name)
            : "Client " + name;
        String aBody = agentBody != null && !agentBody.isBlank()
            ? agentBody.replace("{client}", name)
            : clientBody;
        notifyUser(agentId, agentNotificationType(type), aTitle, aBody, contributionId, clientUserId);
    }

    public void notifyAssignedAgentOnly(
        long clientUserId,
        String type,
        String agentTitle,
        String agentBody,
        Long contributionId
    ) {
        Long agentId = findAssignedAgentUserId(clientUserId);
        if (agentId == null) {
            return;
        }
        String name = clientDisplayName(clientUserId);
        String aTitle = agentTitle != null ? agentTitle.replace("{client}", name) : "Client " + name;
        String aBody = agentBody != null ? agentBody.replace("{client}", name) : "";
        notifyUser(agentId, agentNotificationType(type), aTitle, aBody, contributionId, clientUserId);
    }

    /** Type inbox agent (évite {@code agent_agent_assigned} quand le type client est déjà {@code agent_assigned}). */
    private static String agentNotificationType(String clientType) {
        if (clientType == null || clientType.isBlank()) {
            return "agent_info";
        }
        if ("agent_assigned".equals(clientType)) {
            return "agent_client_assigned";
        }
        return clientType.startsWith("agent_") ? clientType : "agent_" + clientType;
    }

    public Long findAssignedAgentUserId(long clientUserId) {
        if (clientUserId <= 0) {
            return null;
        }
        try {
            Long id = jdbcTemplate.queryForObject(
                """
                SELECT assigned_agent_user_id FROM users
                WHERE id = ? AND assigned_agent_user_id IS NOT NULL AND assigned_agent_user_id > 0
                  AND (self_managed IS NULL OR self_managed = FALSE)
                """,
                Long.class,
                clientUserId
            );
            return id != null && id > 0 ? id : null;
        } catch (EmptyResultDataAccessException ex) {
            return null;
        }
    }

    /**
     * Alerte rattrapage carnet (max une fois par mois calendaire si seuil atteint).
     */
    public void maybeNotifyCatchupAlert(long clientUserId, int orangeDays, String yearMonth, int threshold) {
        if (clientUserId <= 0 || threshold <= 0) {
            return;
        }
        String ym = yearMonth != null && !yearMonth.isBlank()
            ? yearMonth.trim()
            : YearMonth.now().toString();
        if (orangeDays < threshold) {
            jdbcTemplate.update(
                "UPDATE users SET catchup_alert_sent_month = NULL WHERE id = ?",
                clientUserId
            );
            return;
        }
        String alreadySent;
        try {
            alreadySent = jdbcTemplate.queryForObject(
                "SELECT catchup_alert_sent_month FROM users WHERE id = ?",
                String.class,
                clientUserId
            );
        } catch (EmptyResultDataAccessException ex) {
            return;
        }
        if (ym.equals(alreadySent)) {
            return;
        }
        notifyClientAndAssignedAgent(
            clientUserId,
            "catchup_alert",
            "Rattrapage carnet",
            "Vous avez "
                + orangeDays
                + " jour(s) à régulariser sur votre carnet PayFlex. Ouvrez « Combler les trous » pour rattraper.",
            "Rattrapage — {client}",
            "Votre client {client} a "
                + orangeDays
                + " jour(s) de rattrapage sur son carnet. Accompagnez-le pour régulariser.",
            null
        );
        jdbcTemplate.update(
            "UPDATE users SET catchup_alert_sent_month = ? WHERE id = ?",
            ym,
            clientUserId
        );
    }

    /** Changement de statut compte par l’admin (client uniquement). */
    public void notifyAccountStatusChange(long clientUserId, String newStatus) {
        if (clientUserId <= 0 || newStatus == null) {
            return;
        }
        String st = newStatus.trim().toLowerCase();
        if ("bloque".equals(st)) {
            notifyClientAndAssignedAgent(
                clientUserId,
                "account_blocked",
                "Compte suspendu",
                "Votre compte PayFlex a été suspendu par le centre. Contactez le support pour plus d’informations.",
                "Client suspendu — {client}",
                "Le compte de {client} a été suspendu par le centre PayFlex.",
                null
            );
        } else if ("valide".equals(st) || "adhere".equals(st)) {
            notifyClientAndAssignedAgent(
                clientUserId,
                "account_reactivated",
                "Compte réactivé",
                "Votre compte PayFlex est à nouveau actif. Vous pouvez vous connecter et continuer vos cotisations.",
                "Compte réactivé — {client}",
                "Le compte de {client} a été réactivé par le centre PayFlex.",
                null
            );
        }
    }

    public boolean isClientUser(long userId) {
        if (userId <= 0) {
            return false;
        }
        try {
            String code = jdbcTemplate.queryForObject(
                """
                SELECT r.code FROM users u
                JOIN roles r ON r.id = u.role_id
                WHERE u.id = ?
                """,
                String.class,
                userId
            );
            return "client".equalsIgnoreCase(code);
        } catch (EmptyResultDataAccessException ex) {
            return false;
        }
    }

    public String clientDisplayName(long clientUserId) {
        if (clientUserId <= 0) {
            return "Client";
        }
        try {
            String name = jdbcTemplate.queryForObject(
                "SELECT full_name FROM users WHERE id = ?",
                String.class,
                clientUserId
            );
            return name != null && !name.isBlank() ? name.trim() : "Client";
        } catch (EmptyResultDataAccessException ex) {
            return "Client";
        }
    }
}
