package com.payflex.backend.service;

import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

@Service
public class ClientAdhesionService {

    public static final int ADHESION_FEE_FCFA = 250;
    public static final String STATUS_AWAITING_ADHESION = "valide";
    public static final String STATUS_ADHERED = "adhere";

    private final JdbcTemplate jdbcTemplate;
    private final AdminAuditService auditService;
    private final ContributionWorkflowService contributionWorkflowService;
    private final UserInboxNotificationService inboxNotifications;

    public ClientAdhesionService(
        JdbcTemplate jdbcTemplate,
        AdminAuditService auditService,
        ContributionWorkflowService contributionWorkflowService,
        UserInboxNotificationService inboxNotifications
    ) {
        this.jdbcTemplate = jdbcTemplate;
        this.auditService = auditService;
        this.contributionWorkflowService = contributionWorkflowService;
        this.inboxNotifications = inboxNotifications;
    }

    public long countOpenAdhesionDisputes() {
        Long n = jdbcTemplate.queryForObject(
            """
            SELECT COUNT(*) FROM users u
            INNER JOIN roles r ON r.id = u.role_id AND r.code = 'client'
            WHERE u.adhesion_dispute_open = TRUE AND u.adhesion_dispute_resolved_at IS NULL
            """,
            Long.class
        );
        return n == null ? 0L : n;
    }

    public List<Map<String, Object>> listOpenDisputes(int limit) {
        int lim = Math.min(Math.max(limit, 1), 50);
        return jdbcTemplate.queryForList(
            """
            SELECT u.id, u.full_name, u.phone, u.status, u.adhesion_fee_paid,
                   u.adhesion_dispute_at, u.adhesion_dispute_note,
                   ag.full_name AS agent_name
            FROM users u
            INNER JOIN roles r ON r.id = u.role_id AND r.code = 'client'
            LEFT JOIN users ag ON ag.id = u.assigned_agent_user_id
            WHERE u.adhesion_dispute_open = TRUE AND u.adhesion_dispute_resolved_at IS NULL
            ORDER BY u.adhesion_dispute_at DESC
            LIMIT ?
            """,
            lim
        );
    }

    @Transactional
    public void markAdhesionPaidByAgent(long clientUserId, long agentUserId) {
        ensureClient(clientUserId);
        if (!isAgent(agentUserId)) {
            throw new IllegalArgumentException("Seul un agent peut confirmer l'encaissement espèces.");
        }
        Long assigned = jdbcTemplate.queryForObject(
            "SELECT assigned_agent_user_id FROM users WHERE id = ?",
            Long.class,
            clientUserId
        );
        if (assigned == null || assigned <= 0) {
            throw new IllegalArgumentException(
                "Aucun agent parrain assigné à ce client. L'inscription doit indiquer l'agent invitant, ou le centre doit assigner un agent."
            );
        }
        if (!assigned.equals(agentUserId)) {
            throw new IllegalArgumentException(
                "Seul l'agent parrain assigné à ce client peut confirmer l'adhésion (250 FCFA)."
            );
        }
        int n = jdbcTemplate.update(
            """
            UPDATE users SET
              adhesion_fee_paid = TRUE,
              adhesion_paid_at = NOW(),
              adhesion_collected_by_user_id = ?,
              status = ?,
              adhesion_dispute_open = FALSE,
              adhesion_dispute_resolved_at = CASE WHEN adhesion_dispute_open THEN NOW() ELSE adhesion_dispute_resolved_at END
            WHERE id = ? AND adhesion_fee_paid = FALSE
            """,
            agentUserId,
            STATUS_ADHERED,
            clientUserId
        );
        if (n == 0) {
            Boolean already = jdbcTemplate.queryForObject(
                "SELECT adhesion_fee_paid FROM users WHERE id = ?",
                Boolean.class,
                clientUserId
            );
            if (Boolean.TRUE.equals(already)) {
                return;
            }
            throw new IllegalArgumentException("Adhésion déjà réglée ou client introuvable.");
        }
        auditService.logAgent(agentUserId, "A confirmé l'adhésion " + ADHESION_FEE_FCFA + " FCFA (espèces) pour le client #" + clientUserId + ".");
        auditService.logClient(clientUserId, "Adhésion PayFlex (" + ADHESION_FEE_FCFA + " FCFA) enregistrée par votre agent.");
        recalcAssiduityBadge(clientUserId);
    }

    @Transactional
    public void markAdhesionPaidByFedaPay(long clientUserId, String fedapayTransactionId) {
        ensureClient(clientUserId);
        int n = jdbcTemplate.update(
            """
            UPDATE users SET
              adhesion_fee_paid = TRUE,
              adhesion_paid_at = NOW(),
              adhesion_fedapay_transaction_id = ?,
              status = ?,
              adhesion_dispute_open = FALSE,
              adhesion_dispute_resolved_at = CASE WHEN adhesion_dispute_open THEN NOW() ELSE adhesion_dispute_resolved_at END
            WHERE id = ? AND adhesion_fee_paid = FALSE
            """,
            fedapayTransactionId,
            STATUS_ADHERED,
            clientUserId
        );
        if (n == 0) {
            Boolean already = jdbcTemplate.queryForObject(
                "SELECT adhesion_fee_paid FROM users WHERE id = ?",
                Boolean.class,
                clientUserId
            );
            if (Boolean.TRUE.equals(already)) {
                return;
            }
            throw new IllegalArgumentException("Adhésion déjà réglée ou client introuvable.");
        }
        auditService.logClient(
            clientUserId,
            "Adhésion PayFlex (" + ADHESION_FEE_FCFA + " FCFA) réglée par mobile money (FedaPay)."
        );
        notifyAdhesionConfirmed(clientUserId);
        recalcAssiduityBadge(clientUserId);
    }

    @Transactional
    public void markAdhesionPaidByAdmin(long clientUserId, String adminUsername) {
        ensureClient(clientUserId);
        jdbcTemplate.update(
            """
            UPDATE users SET
              adhesion_fee_paid = TRUE,
              adhesion_paid_at = NOW(),
              status = ?,
              adhesion_dispute_open = FALSE,
              adhesion_dispute_resolved_at = CASE WHEN adhesion_dispute_open THEN NOW() ELSE adhesion_dispute_resolved_at END
            WHERE id = ?
            """,
            STATUS_ADHERED,
            clientUserId
        );
        auditService.logEquipe(adminUsername, "Adhésion client #" + clientUserId + " confirmée manuellement (centre).");
        notifyAdhesionConfirmed(clientUserId);
        recalcAssiduityBadge(clientUserId);
    }

    @Transactional
    public void reportAdhesionDispute(long clientUserId, String note) {
        ensureClient(clientUserId);
        Boolean paid = jdbcTemplate.queryForObject(
            "SELECT adhesion_fee_paid FROM users WHERE id = ?",
            Boolean.class,
            clientUserId
        );
        String status = jdbcTemplate.queryForObject("SELECT status FROM users WHERE id = ?", String.class, clientUserId);
        if (Boolean.TRUE.equals(paid) && STATUS_ADHERED.equals(status)) {
            throw new IllegalArgumentException("Votre compte est déjà adhérent. Contactez le support si besoin.");
        }
        jdbcTemplate.update(
            """
            UPDATE users SET
              adhesion_dispute_open = TRUE,
              adhesion_dispute_at = NOW(),
              adhesion_dispute_note = ?
            WHERE id = ?
            """,
            truncate(note, 600),
            clientUserId
        );
        auditService.logClient(clientUserId, "Signalement urgent : adhésion payée mais statut non mis à jour.");
    }

    @Transactional
    public void resolveDispute(long clientUserId, boolean markAsPaid, String adminUsername, String adminNote) {
        ensureClient(clientUserId);
        if (markAsPaid) {
            markAdhesionPaidByAdmin(clientUserId, adminUsername);
        } else {
            jdbcTemplate.update(
                """
                UPDATE users SET
                  adhesion_dispute_open = FALSE,
                  adhesion_dispute_resolved_at = NOW()
                WHERE id = ?
                """,
                clientUserId
            );
            auditService.logEquipe(
                adminUsername,
                "Litige adhésion client #" + clientUserId + " classé sans paiement."
                + (adminNote != null && !adminNote.isBlank() ? " Note : " + adminNote.trim() : "")
            );
        }
    }

    public void setSelfManaged(long clientUserId, boolean selfManaged, String actor) {
        jdbcTemplate.update("UPDATE users SET self_managed = ? WHERE id = ?", selfManaged, clientUserId);
        auditService.logEquipe(actor, "Client #" + clientUserId + (selfManaged ? " : mode autonome (sans agent)." : " : réattachement agent possible."));
    }

    public void recalcAssiduityBadge(long clientUserId) {
        Map<String, Object> stats = jdbcTemplate.queryForMap(
            """
            SELECT
              COALESCE(SUM(CASE WHEN c.status = 'validated' AND c.created_at >= DATE_SUB(NOW(), INTERVAL 90 DAY) THEN 1 ELSE 0 END), 0) AS v90,
              COALESCE(u.catchup_pending_cached, 0) AS catchup
            FROM users u
            LEFT JOIN contributions c ON c.user_id = u.id
            WHERE u.id = ?
            GROUP BY u.id, u.catchup_pending_cached
            """,
            clientUserId
        );
        long v90 = ((Number) stats.get("v90")).longValue();
        int catchup = ((Number) stats.get("catchup")).intValue();
        String badge = "standard";
        if (v90 >= 24 && catchup == 0) {
            badge = "or";
        } else if (v90 >= 14 && catchup <= 1) {
            badge = "argent";
        } else if (v90 >= 7 && catchup <= 2) {
            badge = "bronze";
        }
        jdbcTemplate.update("UPDATE users SET assiduity_badge = ? WHERE id = ?", badge, clientUserId);
    }

    public void recalcAllClientAssiduityBadges() {
        List<Long> ids = jdbcTemplate.query(
            """
            SELECT u.id FROM users u
            INNER JOIN roles r ON r.id = u.role_id AND r.code = 'client'
            WHERE u.status = 'adhere'
            """,
            (rs, i) -> rs.getLong("id")
        );
        for (Long id : ids) {
            recalcAssiduityBadge(id);
        }
    }

    public List<Map<String, Object>> listAgentClients(long agentUserId) {
        return jdbcTemplate.queryForList(
            """
            SELECT u.id, u.full_name, u.phone, u.city, u.status, u.adhesion_fee_paid,
                   u.adhesion_dispute_open, u.assiduity_badge, u.self_managed,
                   COALESCE(SUM(CASE WHEN c.status = 'validated' THEN c.amount ELSE 0 END), 0) AS total_collected
            FROM users u
            INNER JOIN roles r ON r.id = u.role_id AND r.code = 'client'
            LEFT JOIN contributions c ON c.user_id = u.id
            WHERE u.assigned_agent_user_id = ?
            GROUP BY u.id, u.full_name, u.phone, u.city, u.status, u.adhesion_fee_paid,
                     u.adhesion_dispute_open, u.assiduity_badge, u.self_managed
            ORDER BY u.full_name ASC
            """,
            agentUserId
        );
    }

    @Transactional
    public void assignAgentToClient(long clientUserId, Long agentUserId, String adminUsername) {
        ensureClient(clientUserId);
        if (agentUserId != null && agentUserId > 0 && !isAgent(agentUserId)) {
            throw new IllegalArgumentException("Agent invalide ou inactif.");
        }
        jdbcTemplate.update(
            "UPDATE users SET assigned_agent_user_id = ? WHERE id = ?",
            agentUserId,
            clientUserId
        );
        auditService.logEquipe(
            adminUsername,
            "Client #" + clientUserId + " : agent parrain "
                + (agentUserId != null && agentUserId > 0 ? "#" + agentUserId : "retiré")
                + " (remplacement possible par admin/gestionnaire)."
        );
        if (agentUserId != null && agentUserId > 0) {
            notifyAgentAssigned(clientUserId, agentUserId);
        }
    }

    /**
     * Compte client ouvert après inscription mobile (sans validation admin).
     */
    public void onClientAccountOpened(long clientUserId, Long agentUserId) {
        if (clientUserId <= 0) {
            return;
        }
        String body = agentUserId != null && agentUserId > 0
            ? "Bienvenue sur PayFlex ! Finalisez votre adhésion (250 FCFA) auprès de votre agent parrain ou payez en mobile money depuis l’application."
            : "Bienvenue sur PayFlex ! Finalisez votre adhésion (250 FCFA) en mobile money depuis l’application pour activer les cotisations et paiements.";
        if (agentUserId != null && agentUserId > 0) {
            notifyAgentAssigned(clientUserId, agentUserId);
        } else {
            inboxNotifications.notifyUser(
                clientUserId,
                "welcome",
                "Bienvenue sur PayFlex",
                body,
                null
            );
        }
    }

    /**
     * Texte prêt à copier (SMS / WhatsApp) après assignation d’un agent par l’admin.
     */
    public String buildClientOutreachMessage(long clientUserId, long agentUserId) {
        Map<String, Object> client = jdbcTemplate.queryForMap(
            "SELECT full_name, phone FROM users WHERE id = ?",
            clientUserId
        );
        Map<String, Object> agent = jdbcTemplate.queryForMap(
            "SELECT full_name, phone FROM users WHERE id = ?",
            agentUserId
        );
        String clientName = String.valueOf(client.get("full_name"));
        String agentName = String.valueOf(agent.get("full_name"));
        String agentPhone = agent.get("phone") != null ? agent.get("phone").toString() : "";
        return "Bonjour "
            + clientName
            + ",\n\nVotre compte PayFlex est actif. Votre agent parrain est "
            + agentName
            + (agentPhone.isBlank() ? "." : " (" + agentPhone + ").")
            + "\n\nAdhésion PayFlex : "
            + ADHESION_FEE_FCFA
            + " FCFA en espèces auprès de votre agent, ou paiement mobile money dans l’application PayFlex.\n\n"
            + "Après l’adhésion, vous pourrez cotiser et accéder au catalogue.\n\n— L’équipe PayFlex";
    }

    private void notifyAgentAssigned(long clientUserId, long agentUserId) {
        Map<String, Object> client;
        Map<String, Object> agent;
        try {
            client = jdbcTemplate.queryForMap(
                "SELECT full_name, phone FROM users WHERE id = ?",
                clientUserId
            );
            agent = jdbcTemplate.queryForMap(
                "SELECT full_name, phone FROM users WHERE id = ?",
                agentUserId
            );
        } catch (org.springframework.dao.EmptyResultDataAccessException ex) {
            return;
        }
        String clientName = String.valueOf(client.get("full_name"));
        String agentName = String.valueOf(agent.get("full_name"));
        String agentPhone = agent.get("phone") != null ? agent.get("phone").toString() : "";

        inboxNotifications.notifyClientAndAssignedAgent(
            clientUserId,
            "agent_assigned",
            "Votre agent PayFlex",
            "Votre agent parrain est "
                + agentName
                + (agentPhone.isBlank() ? "." : " — " + agentPhone + ".")
                + " Adhésion "
                + ADHESION_FEE_FCFA
                + " FCFA en espèces auprès de lui, ou paiement mobile money dans l’app.",
            "Nouveau client — {client}",
            "Le client {client} vous a été assigné comme parrain. Pensez à l’accompagner pour l’adhésion ("
                + ADHESION_FEE_FCFA
                + " FCFA).",
            null
        );
        auditService.logClient(
            clientUserId,
            "Agent parrain assigné : " + agentName + (agentPhone.isBlank() ? "" : " (" + agentPhone + ")")
        );
    }

    private void notifyAdhesionConfirmed(long clientUserId) {
        inboxNotifications.notifyClientAndAssignedAgent(
            clientUserId,
            "adhesion_paid",
            "Adhésion confirmée",
            "Votre adhésion PayFlex (" + ADHESION_FEE_FCFA + " FCFA) est enregistrée. Cotisations et paiements sont activés.",
            "Adhésion confirmée — {client}",
            "Votre client {client} a finalisé son adhésion PayFlex (" + ADHESION_FEE_FCFA + " FCFA).",
            null
        );
    }

    public List<AssiduousClientRow> listAssiduousClientsForPrint(String badgeFilter) {
        String badge = badgeFilter == null || badgeFilter.isBlank() ? "or" : badgeFilter.trim();
        return jdbcTemplate.query(
            """
            SELECT u.id, u.full_name, u.phone, u.city, u.assiduity_badge, u.self_managed,
                   ag.full_name AS agent_name, ag.phone AS agent_phone
            FROM users u
            INNER JOIN roles r ON r.id = u.role_id AND r.code = 'client'
            LEFT JOIN users ag ON ag.id = u.assigned_agent_user_id AND u.self_managed = FALSE
            WHERE u.status = 'adhere' AND u.assiduity_badge = ?
            ORDER BY u.full_name ASC
            """,
            (rs, i) -> new AssiduousClientRow(
                rs.getLong("id"),
                rs.getString("full_name"),
                rs.getString("phone"),
                rs.getString("city"),
                rs.getString("assiduity_badge"),
                rs.getBoolean("self_managed"),
                rs.getString("agent_name"),
                rs.getString("agent_phone")
            ),
            badge
        );
    }

    public Map<String, Object> clientAdhesionSummary(long clientUserId) {
        try {
            Map<String, Object> row = jdbcTemplate.queryForMap(
                """
                SELECT u.adhesion_fee_paid, u.adhesion_paid_at, u.status,
                       u.adhesion_dispute_open, u.adhesion_dispute_at, u.adhesion_dispute_note,
                       u.adhesion_dispute_resolved_at, u.assiduity_badge, u.self_managed,
                       col.full_name AS collected_by_name
                FROM users u
                LEFT JOIN users col ON col.id = u.adhesion_collected_by_user_id
                WHERE u.id = ?
                """,
                clientUserId
            );
            row.put("adhesion_fee_fcfa", ADHESION_FEE_FCFA);
            row.put("is_adherent", STATUS_ADHERED.equals(String.valueOf(row.get("status"))));
            return row;
        } catch (org.springframework.dao.EmptyResultDataAccessException ex) {
            return Map.of();
        }
    }

    public void enrichProfileMap(Map<String, Object> profile) {
        if (profile == null || profile.isEmpty()) {
            return;
        }
        Object idObj = profile.get("id");
        if (!(idObj instanceof Number n)) {
            return;
        }
        long uid = n.longValue();
        try {
            Map<String, Object> row = jdbcTemplate.queryForMap(
                """
                SELECT adhesion_fee_paid, status, adhesion_dispute_open, assiduity_badge, self_managed
                FROM users WHERE id = ?
                """,
                uid
            );
            profile.putAll(row);
        } catch (org.springframework.dao.EmptyResultDataAccessException ignored) {
            // noop
        }
        profile.put("adhesion_fee_fcfa", ADHESION_FEE_FCFA);
        profile.put("is_adherent", STATUS_ADHERED.equals(String.valueOf(profile.get("status"))));
        profile.put("can_report_adhesion_dispute", canReportDispute(uid));
    }

    private boolean canReportDispute(long clientUserId) {
        try {
            Map<String, Object> row = jdbcTemplate.queryForMap(
                "SELECT adhesion_fee_paid, status, adhesion_dispute_open FROM users WHERE id = ?",
                clientUserId
            );
            boolean paid = Boolean.TRUE.equals(row.get("adhesion_fee_paid"));
            String status = String.valueOf(row.get("status"));
            boolean open = Boolean.TRUE.equals(row.get("adhesion_dispute_open"));
            return !open && (!paid || !STATUS_ADHERED.equals(status));
        } catch (org.springframework.dao.EmptyResultDataAccessException ex) {
            return false;
        }
    }

    private void ensureClient(long userId) {
        Long n = jdbcTemplate.queryForObject(
            """
            SELECT COUNT(*) FROM users u
            INNER JOIN roles r ON r.id = u.role_id AND r.code = 'client'
            WHERE u.id = ?
            """,
            Long.class,
            userId
        );
        if (n == null || n == 0) {
            throw new IllegalArgumentException("Client introuvable.");
        }
    }

    private boolean isAgent(long userId) {
        Long n = jdbcTemplate.queryForObject(
            """
            SELECT COUNT(*) FROM users u
            INNER JOIN roles r ON r.id = u.role_id AND r.code = 'agent'
            WHERE u.id = ? AND u.status = 'valide'
            """,
            Long.class,
            userId
        );
        return n != null && n > 0;
    }

    private static String truncate(String s, int max) {
        if (s == null) {
            return null;
        }
        String t = s.trim();
        return t.length() <= max ? t : t.substring(0, max - 1) + "…";
    }

    public AdminCrudService.PageResult<ClientAdminRow> clientsPage(
        String q,
        String city,
        String status,
        String adhesionFilter,
        String assiduityBadge,
        int page,
        int size
    ) {
        size = AdminCrudService.normalizePageSize(size);
        StringBuilder where = new StringBuilder(
            " WHERE u.role_id = (SELECT id FROM roles WHERE code = 'client' LIMIT 1) "
        );
        List<Object> args = new ArrayList<>();
        if (q != null && !q.isBlank()) {
            where.append(" AND (u.full_name LIKE ? OR u.phone LIKE ? OR u.profession LIKE ?) ");
            String like = "%" + q.trim() + "%";
            args.add(like);
            args.add(like);
            args.add(like);
        }
        if (city != null && !city.isBlank()) {
            where.append(" AND u.city LIKE ? ");
            args.add("%" + city.trim() + "%");
        }
        if (status != null && !status.isBlank()) {
            where.append(" AND u.status = ? ");
            args.add(status);
        }
        if ("unpaid".equalsIgnoreCase(adhesionFilter)) {
            where.append(" AND u.adhesion_fee_paid = FALSE ");
        } else if ("paid".equalsIgnoreCase(adhesionFilter)) {
            where.append(" AND u.adhesion_fee_paid = TRUE ");
        } else if ("dispute".equalsIgnoreCase(adhesionFilter)) {
            where.append(" AND u.adhesion_dispute_open = TRUE AND u.adhesion_dispute_resolved_at IS NULL ");
        }
        if (assiduityBadge != null && !assiduityBadge.isBlank() && !"all".equalsIgnoreCase(assiduityBadge)) {
            where.append(" AND u.assiduity_badge = ? ");
            args.add(assiduityBadge.trim());
        }
        String from = """
            FROM users u
            INNER JOIN roles r ON r.id = u.role_id
            LEFT JOIN users ag ON ag.id = u.assigned_agent_user_id AND u.self_managed = FALSE
            """;
        long total = jdbcTemplate.queryForObject(
            "SELECT COUNT(*) " + from + where,
            args.toArray(),
            Long.class
        );
        List<Object> pageArgs = new ArrayList<>(args);
        pageArgs.add(size);
        pageArgs.add(page * size);
        List<ClientAdminRow> items = jdbcTemplate.query(
            """
            SELECT u.id, u.full_name, u.phone, u.city, u.profession, u.status,
                   u.adhesion_fee_paid, u.adhesion_dispute_open, u.assiduity_badge, u.self_managed,
                   ag.full_name AS agent_name
            """ + from + where + " ORDER BY u.adhesion_dispute_open DESC, u.full_name ASC LIMIT ? OFFSET ?",
            pageArgs.toArray(),
            (rs, i) -> new ClientAdminRow(
                rs.getLong("id"),
                rs.getString("full_name"),
                rs.getString("phone"),
                rs.getString("city"),
                rs.getString("profession"),
                rs.getString("status"),
                rs.getBoolean("adhesion_fee_paid"),
                rs.getBoolean("adhesion_dispute_open"),
                rs.getString("assiduity_badge"),
                rs.getBoolean("self_managed"),
                rs.getString("agent_name")
            )
        );
        return AdminCrudService.PageResult.of(items, page, size, total);
    }

    public record ClientAdminRow(
        long id,
        String fullName,
        String phone,
        String city,
        String profession,
        String status,
        boolean adhesionFeePaid,
        boolean adhesionDisputeOpen,
        String assiduityBadge,
        boolean selfManaged,
        String agentName
    ) {}

    public record AssiduousClientRow(
        long id,
        String fullName,
        String phone,
        String city,
        String assiduityBadge,
        boolean selfManaged,
        String agentName,
        String agentPhone
    ) {}
}
