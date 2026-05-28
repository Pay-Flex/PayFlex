package com.payflex.backend.service;

import org.springframework.dao.EmptyResultDataAccessException;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;

import java.util.List;

/**
 * Journal d'activité pour l'admin : messages en français clair, profils équipe / agent / client / visiteur.
 */
@Service
public class AdminAuditService {

    public static final String PROFILE_EQUIPE = "equipe";
    public static final String PROFILE_GESTIONNAIRE = "gestionnaire";
    public static final String PROFILE_AGENT = "agent";
    public static final String PROFILE_CLIENT = "client";
    public static final String PROFILE_VISITEUR = "visiteur";

    public static final String ACTION_CREATE = "CREATE";
    public static final String ACTION_UPDATE = "UPDATE";
    public static final String ACTION_DELETE = "DELETE";
    public static final String ACTION_DELETE_REQUEST = "DELETE_REQUEST";
    public static final String ACTION_UPDATE_STATUS = "UPDATE_STATUS";
    public static final String ACTION_DECIDE = "DECIDE";

    private final JdbcTemplate jdbcTemplate;

    public AdminAuditService(JdbcTemplate jdbcTemplate) {
        this.jdbcTemplate = jdbcTemplate;
    }

    /** @deprecated Utiliser {@link #logEquipe(String, String)} — conservé pour compatibilité éventuelle. */
    @Deprecated
    public void log(String adminUsername, String actionType, String entityType, Long entityId, String details) {
        logEquipe(adminUsername, legacyToMessage(actionType, details));
    }

    private static String legacyToMessage(String actionType, String details) {
        String base = switch (actionType != null ? actionType : "") {
            case "CREATE" -> "Une création a été effectuée.";
            case "UPDATE" -> "Une fiche a été mise à jour.";
            case "DELETE" -> "Un élément a été supprimé.";
            case "UPDATE_STATUS" -> "Un statut a été changé.";
            case "DECIDE" -> "Une décision a été prise sur une inscription.";
            default -> "Une action a été enregistrée.";
        };
        if (details != null && !details.isBlank()) {
            return base + " " + details;
        }
        return base;
    }

    public void logEquipe(String loginGestionnaire, String message) {
        jdbcTemplate.update(
            """
            INSERT INTO activity_journal (profile, actor_display, actor_username, message)
            VALUES (?, ?, ?, ?)
            """,
            PROFILE_EQUIPE,
            loginGestionnaire == null ? "Équipe" : loginGestionnaire,
            loginGestionnaire,
            message
        );
    }

    /** Journal dédié au compte gestionnaire (visible par l'administrateur principal). */
    public void logGestionnaire(
        String username,
        String actionKind,
        String entityType,
        Long entityId,
        String message,
        String reason
    ) {
        String display = username == null || username.isBlank() ? "Gestionnaire" : username;
        String full = message;
        if (reason != null && !reason.isBlank()) {
            full = full + " — Motif : " + reason.trim();
        }
        jdbcTemplate.update(
            """
            INSERT INTO activity_journal (
              profile, actor_display, actor_username, action_kind, entity_type, entity_id, reason, message
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            """,
            PROFILE_GESTIONNAIRE,
            display,
            username,
            actionKind,
            entityType,
            entityId,
            reason == null || reason.isBlank() ? null : reason.trim(),
            full
        );
    }

    public void logAgent(long userId, String message) {
        String name = resolveUserDisplay(userId);
        jdbcTemplate.update(
            "INSERT INTO activity_journal (profile, actor_display, message) VALUES (?, ?, ?)",
            PROFILE_AGENT,
            name,
            message
        );
    }

    public void logClient(long userId, String message) {
        String name = resolveUserDisplay(userId);
        jdbcTemplate.update(
            "INSERT INTO activity_journal (profile, actor_display, message) VALUES (?, ?, ?)",
            PROFILE_CLIENT,
            name,
            message
        );
    }

    /** Inscription depuis l'app avant existence du compte (pas encore client PayFlex). */
    public void logVisiteur(String nomOuTelephone, String message) {
        jdbcTemplate.update(
            "INSERT INTO activity_journal (profile, actor_display, message) VALUES (?, ?, ?)",
            PROFILE_VISITEUR,
            nomOuTelephone == null || nomOuTelephone.isBlank() ? "Personne non encore cliente" : nomOuTelephone,
            message
        );
    }

    private String resolveUserDisplay(long userId) {
        try {
            return jdbcTemplate.queryForObject(
                "SELECT full_name FROM users WHERE id = ?",
                String.class,
                userId
            );
        } catch (EmptyResultDataAccessException e) {
            return "Utilisateur n° " + userId;
        }
    }

    public List<JournalRow> latest(int limit) {
        return jdbcTemplate.query(
            """
            SELECT id, profile, actor_display, actor_username, action_kind, entity_type, entity_id, reason, message, created_at
            FROM activity_journal
            ORDER BY created_at DESC
            LIMIT ?
            """,
            (rs, rowNum) -> mapRow(rs),
            limit
        );
    }

    public AdminCrudService.PageResult<JournalRow> page(
        String profileFilter,
        String q,
        String dateFrom,
        String dateTo,
        int page,
        int size
    ) {
        size = AdminCrudService.normalizePageSize(size);
        StringBuilder where = new StringBuilder(" WHERE 1=1 ");
        java.util.ArrayList<Object> args = new java.util.ArrayList<>();
        if (profileFilter != null && !profileFilter.isBlank() && !"tous".equalsIgnoreCase(profileFilter)) {
            if ("gestionnaire".equalsIgnoreCase(profileFilter)) {
                where.append(" AND profile = ? ");
                args.add(PROFILE_GESTIONNAIRE);
            } else {
                where.append(" AND profile = ? ");
                args.add(profileFilter);
            }
        }
        if (q != null && !q.isBlank()) {
            where.append(" AND (message LIKE ? OR actor_display LIKE ? OR profile LIKE ?) ");
            String like = "%" + q.trim() + "%";
            args.add(like);
            args.add(like);
            args.add(like);
        }
        if (dateFrom != null && !dateFrom.isBlank()) {
            where.append(" AND created_at >= ? ");
            args.add(dateFrom.trim() + " 00:00:00");
        }
        if (dateTo != null && !dateTo.isBlank()) {
            where.append(" AND created_at <= ? ");
            args.add(dateTo.trim() + " 23:59:59");
        }

        Long total = jdbcTemplate.queryForObject(
            "SELECT COUNT(*) FROM activity_journal " + where,
            Long.class,
            args.toArray()
        );
        long totalLong = total != null ? total : 0;

        java.util.ArrayList<Object> pageArgs = new java.util.ArrayList<>(args);
        pageArgs.add(size);
        pageArgs.add(page * size);

        List<JournalRow> items = jdbcTemplate.query(
            """
            SELECT id, profile, actor_display, actor_username, action_kind, entity_type, entity_id, reason, message, created_at
            FROM activity_journal
            """
                + where + " ORDER BY created_at DESC LIMIT ? OFFSET ?",
            pageArgs.toArray(),
            (rs, rowNum) -> mapRow(rs)
        );
        return AdminCrudService.PageResult.of(items, page, size, totalLong);
    }

    /** Suppression complète du journal (réservée au profil administrateur principal). */
    public void clearAll() {
        jdbcTemplate.update("DELETE FROM activity_journal");
    }

    private JournalRow mapRow(java.sql.ResultSet rs) throws java.sql.SQLException {
        return new JournalRow(
            rs.getLong("id"),
            rs.getString("profile"),
            rs.getString("actor_display"),
            rs.getString("actor_username"),
            rs.getString("action_kind"),
            rs.getString("entity_type"),
            rs.getObject("entity_id") == null ? null : rs.getLong("entity_id"),
            rs.getString("reason"),
            rs.getString("message"),
            rs.getString("created_at")
        );
    }

    public record JournalRow(
        long id,
        String profile,
        String actorDisplay,
        String actorUsername,
        String actionKind,
        String entityType,
        Long entityId,
        String reason,
        String message,
        String createdAt
    ) {

        public String profileLabel() {
            return switch (profile == null ? "" : profile) {
                case PROFILE_EQUIPE -> "Équipe PayFlex";
                case PROFILE_GESTIONNAIRE -> "Gestionnaire";
                case PROFILE_AGENT -> "Agent terrain";
                case PROFILE_CLIENT -> "Client";
                case PROFILE_VISITEUR -> "Demande depuis l'application";
                default -> "Autre";
            };
        }

        public String actionKindLabel() {
            if (actionKind == null || actionKind.isBlank()) {
                return "";
            }
            return switch (actionKind) {
                case ACTION_CREATE -> "Création";
                case ACTION_UPDATE -> "Modification";
                case ACTION_DELETE -> "Suppression";
                case ACTION_DELETE_REQUEST -> "Demande suppression";
                case ACTION_UPDATE_STATUS -> "Changement statut";
                case ACTION_DECIDE -> "Décision";
                default -> actionKind;
            };
        }
    }

    /** Libellés français pour les écrans admin et les messages du journal */
    public static String statutCompte(String code) {
        if (code == null || code.isBlank()) return "non précisé";
        return switch (code) {
            case "pending" -> "en attente";
            case "valide" -> "validé";
            case "bloque" -> "bloqué";
            default -> code;
        };
    }

    public static String statutCotisation(String code) {
        if (code == null || code.isBlank()) return "non précisé";
        return switch (code) {
            case "pending" -> "en attente de confirmation";
            case "validated" -> "confirmée";
            case "rejected" -> "refusée";
            default -> code;
        };
    }

    public static String modePaiement(String code) {
        if (code == null || code.isBlank()) return "non précisé";
        return switch (code) {
            case "mobile_money" -> "mobile money";
            case "cash" -> "espèces";
            case "agent" -> "via agent";
            default -> code.replace('_', ' ');
        };
    }

    public static String decisionInscription(String code) {
        if (code == null) return "";
        return switch (code) {
            case "approved" -> "acceptée";
            case "rejected" -> "refusée";
            default -> code;
        };
    }

    public static String disponibiliteProduit(String code) {
        if (code == null) return "";
        return switch (code) {
            case "in_stock" -> "en stock";
            case "on_order" -> "sur commande";
            default -> code.replace('_', ' ');
        };
    }
}
