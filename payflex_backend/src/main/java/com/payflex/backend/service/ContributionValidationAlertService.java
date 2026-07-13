package com.payflex.backend.service;

import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;

import java.util.List;
import java.util.Map;

@Service
public class ContributionValidationAlertService {

    public static final String TYPE_AUTO_TIMEOUT = "auto_validated_timeout";
    public static final String TYPE_PAYDUNYA_APPROVED = "paydunya_approved";
    public static final String TYPE_PAYDUNYA_CANCELED = "paydunya_canceled";
    public static final String TYPE_AGENT_CASH_DEBT = "agent_cash_debt";

    private final JdbcTemplate jdbcTemplate;

    public ContributionValidationAlertService(JdbcTemplate jdbcTemplate) {
        this.jdbcTemplate = jdbcTemplate;
    }

    public void create(long contributionId, String alertType, String message) {
        jdbcTemplate.update(
            """
            INSERT INTO contribution_validation_alerts (contribution_id, alert_type, message)
            VALUES (?, ?, ?)
            """,
            contributionId,
            alertType,
            message
        );
    }

    /** Alerte centre sans cotisation liée (ex. dette de caisse constatée sur un agent). */
    public void createGeneral(String alertType, String message) {
        jdbcTemplate.update(
            """
            INSERT INTO contribution_validation_alerts (contribution_id, alert_type, message)
            VALUES (NULL, ?, ?)
            """,
            alertType,
            message
        );
    }

    public long countUnread() {
        Long n = jdbcTemplate.queryForObject(
            "SELECT COUNT(*) FROM contribution_validation_alerts WHERE read_at IS NULL",
            Long.class
        );
        return n == null ? 0L : n;
    }

    public void markAllRead() {
        jdbcTemplate.update("UPDATE contribution_validation_alerts SET read_at = NOW() WHERE read_at IS NULL");
    }

    public List<Map<String, Object>> listUnread(int limit) {
        return jdbcTemplate.queryForList(
            """
            SELECT a.id, a.contribution_id, a.alert_type, a.message, a.created_at
            FROM contribution_validation_alerts a
            WHERE a.read_at IS NULL
            ORDER BY a.created_at DESC
            LIMIT ?
            """,
            Math.max(1, Math.min(limit, 50))
        );
    }
}
