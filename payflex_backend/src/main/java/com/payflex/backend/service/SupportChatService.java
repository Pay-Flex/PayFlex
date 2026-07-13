package com.payflex.backend.service;

import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.multipart.MultipartFile;

import java.io.IOException;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;

@Service
public class SupportChatService {

    /** Comptes clients actifs (en attente d'adhésion ou adhérents) — exclus : pending, bloque. */
    private static final String CLIENT_BROADCAST_ELIGIBLE =
        "u.status IN ('" + ClientAdhesionService.STATUS_AWAITING_ADHESION + "', '"
            + ClientAdhesionService.STATUS_ADHERED + "')";

    private final JdbcTemplate jdbcTemplate;
    private final ContributionWorkflowService contributionWorkflowService;
    private final UserInboxNotificationService inboxNotifications;
    private final SupportChatAttachmentStorage attachmentStorage;
    private final AdminWebPushService adminWebPushService;

    public SupportChatService(
        JdbcTemplate jdbcTemplate,
        ContributionWorkflowService contributionWorkflowService,
        UserInboxNotificationService inboxNotifications,
        SupportChatAttachmentStorage attachmentStorage,
        AdminWebPushService adminWebPushService
    ) {
        this.jdbcTemplate = jdbcTemplate;
        this.contributionWorkflowService = contributionWorkflowService;
        this.inboxNotifications = inboxNotifications;
        this.attachmentStorage = attachmentStorage;
        this.adminWebPushService = adminWebPushService;
    }

    public List<Map<String, Object>> listThreads() {
        return jdbcTemplate.queryForList(
            """
            SELECT u.id AS user_id, u.full_name, u.phone,
              (SELECT m.body FROM support_chat_messages m WHERE m.user_id = u.id ORDER BY m.id DESC LIMIT 1) AS last_body,
              (SELECT m.created_at FROM support_chat_messages m WHERE m.user_id = u.id ORDER BY m.id DESC LIMIT 1) AS last_at,
              (SELECT COUNT(*) FROM support_chat_messages m WHERE m.user_id = u.id AND m.sender = 'client') AS client_messages_count,
              (SELECT COUNT(*) FROM support_chat_messages m WHERE m.user_id = u.id) AS messages_total
            FROM users u
            WHERE EXISTS (SELECT 1 FROM support_chat_messages m WHERE m.user_id = u.id)
            ORDER BY last_at DESC
            """
        );
    }

    public List<Map<String, Object>> listClientTargetsForBroadcast() {
        return jdbcTemplate.queryForList(
            """
            SELECT u.id, u.full_name, u.phone, z.name AS zone_name
            FROM users u
            INNER JOIN roles r ON r.id = u.role_id AND r.code = 'client'
            LEFT JOIN users ag ON ag.id = u.assigned_agent_user_id
            LEFT JOIN agents a ON a.user_id = ag.id
            LEFT JOIN zones z ON z.id = a.zone_id
            WHERE %s
            ORDER BY u.full_name ASC
            """.formatted(CLIENT_BROADCAST_ELIGIBLE)
        );
    }

    public List<Map<String, Object>> listZonesForBroadcast() {
        return jdbcTemplate.queryForList(
            """
            SELECT z.id, z.name,
                   (SELECT COUNT(DISTINCT u.id)
                    FROM users u
                    INNER JOIN roles r ON r.id = u.role_id AND r.code = 'client'
                    LEFT JOIN users ag ON ag.id = u.assigned_agent_user_id
                    LEFT JOIN agents a ON a.user_id = ag.id
                    WHERE %s AND a.zone_id = z.id) AS clients_count
            FROM zones z
            WHERE z.active = TRUE
            ORDER BY z.name ASC
            """.formatted(CLIENT_BROADCAST_ELIGIBLE)
        );
    }

    public List<Map<String, Object>> messagesForUser(long userId, int limit) {
        int lim = Math.max(1, Math.min(limit, 500));
        return jdbcTemplate.queryForList(
            """
            SELECT id, user_id, sender, body, created_at, read_at, broadcast_batch_id,
                   attachment_url, attachment_kind, attachment_name, attachment_mime
            FROM support_chat_messages
            WHERE user_id = ?
            ORDER BY id ASC
            LIMIT ?
            """,
            userId, lim
        );
    }

    public long addMessage(long userId, String sender, String body) {
        return addMessageInternal(userId, sender, body, null, null, null, null, true);
    }

    public long addAdminMessage(long userId, String body) {
        return addMessageInternal(userId, "admin", body, null, null, null, null, true);
    }

    public long addClientAttachment(long userId, MultipartFile file, String caption) throws IOException {
        SupportChatAttachmentStorage.StoredFile stored = attachmentStorage.store(file, userId);
        String body = buildAttachmentBody(stored.kind(), stored.originalName(), caption);
        return addMessageInternal(
            userId,
            "client",
            body,
            stored.relativeUrl(),
            stored.kind(),
            stored.originalName(),
            stored.mime(),
            true
        );
    }

    private static String buildAttachmentBody(String kind, String originalName, String caption) {
        String trimmedCaption = caption == null ? "" : caption.trim();
        if (!trimmedCaption.isBlank()) {
            return trimmedCaption.length() > 4000 ? trimmedCaption.substring(0, 4000) : trimmedCaption;
        }
        String label = switch (kind) {
            case "image" -> "Image";
            case "audio" -> "Message vocal";
            default -> "Document";
        };
        String name = originalName == null || originalName.isBlank() ? "" : " — " + originalName;
        return label + name;
    }

    private long addMessageInternal(
        long userId,
        String sender,
        String body,
        String attachmentUrl,
        String attachmentKind,
        String attachmentName,
        String attachmentMime,
        boolean notifyClient
    ) {
        String broadcastBatchId = null;
        return addMessageInternal(
            userId,
            sender,
            body,
            attachmentUrl,
            attachmentKind,
            attachmentName,
            attachmentMime,
            broadcastBatchId,
            notifyClient
        );
    }

    private long addMessageInternal(
        long userId,
        String sender,
        String body,
        String attachmentUrl,
        String attachmentKind,
        String attachmentName,
        String attachmentMime,
        String broadcastBatchId,
        boolean notifyClient
    ) {
        if (body == null || body.isBlank()) {
            throw new IllegalArgumentException("Message vide");
        }
        if (!"client".equals(sender) && !"admin".equals(sender)) {
            throw new IllegalArgumentException("Expéditeur invalide");
        }
        String trimmed = body.length() > 4000 ? body.substring(0, 4000) : body;
        jdbcTemplate.update(
            """
            INSERT INTO support_chat_messages (
              user_id, sender, body, broadcast_batch_id,
              attachment_url, attachment_kind, attachment_name, attachment_mime
            )
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            """,
            userId,
            sender,
            trimmed,
            broadcastBatchId,
            attachmentUrl,
            attachmentKind,
            attachmentName,
            attachmentMime
        );
        Long id = jdbcTemplate.queryForObject("SELECT LAST_INSERT_ID()", Long.class);
        long messageId = id == null ? 0L : id;

        if ("admin".equals(sender) && notifyClient) {
            String title = broadcastBatchId != null ? "Message PayFlex" : "Support PayFlex";
            String preview = trimmed.length() > 180 ? trimmed.substring(0, 177) + "…" : trimmed;
            contributionWorkflowService.notifyClientInbox(
                userId,
                "admin_message",
                title,
                preview,
                null
            );
        } else if ("client".equals(sender)) {
            String preview = trimmed.length() > 180 ? trimmed.substring(0, 177) + "…" : trimmed;
            inboxNotifications.notifyAssignedAgentOnly(
                userId,
                "client_chat",
                "Message de {client}",
                "{client} vous a écrit : " + preview,
                null
            );
            // Web Push temps réel vers les postes admin/support (ignoré si VAPID non configuré).
            String clientName = inboxNotifications.clientDisplayName(userId);
            adminWebPushService.notifyAllAdmins(
                "Nouveau message support",
                clientName + " : " + preview,
                "/admin/support-chat?user=" + userId
            );
        }
        return messageId;
    }

    @Transactional
    public int sendBroadcast(String targetType, Long zoneId, List<Long> userIds, String title, String body, String sentBy) {
        if (body == null || body.isBlank()) {
            throw new IllegalArgumentException("Le message est requis.");
        }
        String type = targetType == null ? "" : targetType.trim().toLowerCase();
        List<Long> recipients = resolveRecipients(type, zoneId, userIds);
        if (recipients.isEmpty()) {
            throw new IllegalArgumentException("Aucun client cible pour cet envoi.");
        }
        String batchId = "BC-" + UUID.randomUUID();
        String notifTitle = title == null || title.isBlank() ? "Message de PayFlex" : title.trim();

        jdbcTemplate.update(
            """
            INSERT INTO admin_message_broadcasts (target_type, zone_id, title, body, recipient_count, sent_by)
            VALUES (?, ?, ?, ?, ?, ?)
            """,
            type,
            zoneId,
            notifTitle,
            body.trim(),
            recipients.size(),
            sentBy
        );

        for (Long uid : recipients) {
            addMessageInternal(uid, "admin", body.trim(), null, null, null, null, batchId, true);
        }
        return recipients.size();
    }

    private List<Long> resolveRecipients(String targetType, Long zoneId, List<Long> userIds) {
        return switch (targetType) {
            case "all" -> jdbcTemplate.query(
                """
                SELECT u.id FROM users u
                INNER JOIN roles r ON r.id = u.role_id AND r.code = 'client'
                WHERE %s
                """.formatted(CLIENT_BROADCAST_ELIGIBLE),
                (rs, i) -> rs.getLong(1)
            );
            case "zone" -> {
                if (zoneId == null || zoneId <= 0) {
                    throw new IllegalArgumentException("Zone requise pour un envoi par zone.");
                }
                yield jdbcTemplate.query(
                    """
                    SELECT DISTINCT u.id
                    FROM users u
                    INNER JOIN roles r ON r.id = u.role_id AND r.code = 'client'
                    LEFT JOIN users ag ON ag.id = u.assigned_agent_user_id
                    LEFT JOIN agents a ON a.user_id = ag.id
                    WHERE %s AND a.zone_id = ?
                    """.formatted(CLIENT_BROADCAST_ELIGIBLE),
                    (rs, i) -> rs.getLong(1),
                    zoneId
                );
            }
            case "individual" -> {
                if (userIds == null || userIds.isEmpty()) {
                    throw new IllegalArgumentException("Sélectionnez au moins un client.");
                }
                List<Long> out = new ArrayList<>();
                for (Long id : userIds) {
                    if (id != null && id > 0) {
                        Long n = jdbcTemplate.queryForObject(
                            """
                            SELECT COUNT(*) FROM users u
                            INNER JOIN roles r ON r.id = u.role_id AND r.code = 'client'
                            WHERE u.id = ? AND %s
                            """.formatted(CLIENT_BROADCAST_ELIGIBLE),
                            Long.class,
                            id
                        );
                        if (n != null && n > 0) {
                            out.add(id);
                        }
                    }
                }
                yield out;
            }
            default -> throw new IllegalArgumentException("Type de ciblage invalide.");
        };
    }

    public int countUnreadAdminMessages(long userId) {
        Long n = jdbcTemplate.queryForObject(
            """
            SELECT COUNT(*) FROM support_chat_messages
            WHERE user_id = ? AND sender = 'admin' AND read_at IS NULL
            """,
            Long.class,
            userId
        );
        return n == null ? 0 : n.intValue();
    }

    public Map<String, Object> latestUnreadAdminMessage(long userId) {
        List<Map<String, Object>> rows = jdbcTemplate.queryForList(
            """
            SELECT id, body, created_at
            FROM support_chat_messages
            WHERE user_id = ? AND sender = 'admin' AND read_at IS NULL
            ORDER BY id DESC
            LIMIT 1
            """,
            userId
        );
        return rows.isEmpty() ? Map.of() : rows.get(0);
    }

    public void markAdminMessagesRead(long userId) {
        jdbcTemplate.update(
            """
            UPDATE support_chat_messages SET read_at = NOW()
            WHERE user_id = ? AND sender = 'admin' AND read_at IS NULL
            """,
            userId
        );
    }

    /**
     * Supprime un message du fil support. Si {@code ownerUserId} est renseigné, le message doit appartenir à ce client.
     *
     * @return nombre de lignes supprimées (0 ou 1)
     */
    public int deleteMessage(long messageId, Long ownerUserId) {
        if (messageId <= 0) {
            return 0;
        }
        String attachmentUrl = findAttachmentUrl(messageId, ownerUserId);
        int n;
        if (ownerUserId != null && ownerUserId > 0) {
            n = jdbcTemplate.update(
                "DELETE FROM support_chat_messages WHERE id = ? AND user_id = ?",
                messageId, ownerUserId
            );
        } else {
            n = jdbcTemplate.update("DELETE FROM support_chat_messages WHERE id = ?", messageId);
        }
        if (n > 0) {
            attachmentStorage.deleteIfPresent(attachmentUrl);
        }
        return n;
    }

    /**
     * Supprime toute la conversation support d'un client.
     *
     * @return nombre de messages supprimés
     */
    public int deleteThread(long userId) {
        if (userId <= 0) {
            return 0;
        }
        List<String> urls = jdbcTemplate.query(
            "SELECT attachment_url FROM support_chat_messages WHERE user_id = ? AND attachment_url IS NOT NULL",
            (rs, i) -> rs.getString(1),
            userId
        );
        int n = jdbcTemplate.update("DELETE FROM support_chat_messages WHERE user_id = ?", userId);
        for (String url : urls) {
            attachmentStorage.deleteIfPresent(url);
        }
        return n;
    }

    private String findAttachmentUrl(long messageId, Long ownerUserId) {
        if (ownerUserId != null && ownerUserId > 0) {
            List<String> rows = jdbcTemplate.query(
                """
                SELECT attachment_url FROM support_chat_messages
                WHERE id = ? AND user_id = ? AND attachment_url IS NOT NULL
                """,
                (rs, i) -> rs.getString(1),
                messageId,
                ownerUserId
            );
            return rows.isEmpty() ? null : rows.get(0);
        }
        List<String> rows = jdbcTemplate.query(
            """
            SELECT attachment_url FROM support_chat_messages
            WHERE id = ? AND attachment_url IS NOT NULL
            """,
            (rs, i) -> rs.getString(1),
            messageId
        );
        return rows.isEmpty() ? null : rows.get(0);
    }

    public Map<String, Object> inboxSummary(long userId) {
        int chatUnread = countUnreadAdminMessages(userId);
        int notifUnread = contributionWorkflowService.countUnreadNotifications(userId);
        Map<String, Object> summary = new LinkedHashMap<>();
        summary.put("chatUnread", chatUnread);
        summary.put("notificationsUnread", notifUnread);
        summary.put("totalUnread", chatUnread + notifUnread);
        if (chatUnread > 0) {
            Map<String, Object> latest = latestUnreadAdminMessage(userId);
            summary.put("bannerTitle", "Nouveau message PayFlex");
            summary.put("bannerBody", latest.get("body"));
            summary.put("bannerType", "chat");
        } else if (notifUnread > 0) {
            List<Map<String, Object>> notifs = contributionWorkflowService.listNotificationsForClient(userId, true);
            if (!notifs.isEmpty()) {
                summary.put("bannerTitle", notifs.get(0).get("title"));
                summary.put("bannerBody", notifs.get(0).get("body"));
                summary.put("bannerType", "notification");
            }
        }
        return summary;
    }
}
