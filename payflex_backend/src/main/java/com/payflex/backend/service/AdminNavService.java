package com.payflex.backend.service;

import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;

/**
 * Compteurs pour badges menu admin (sidebar).
 */
@Service
public class AdminNavService {

    private final JdbcTemplate jdbcTemplate;
    private final ClientAdhesionService clientAdhesionService;

    public AdminNavService(JdbcTemplate jdbcTemplate, ClientAdhesionService clientAdhesionService) {
        this.jdbcTemplate = jdbcTemplate;
        this.clientAdhesionService = clientAdhesionService;
    }

    public long adhesionUrgencies() {
        return clientAdhesionService.countOpenAdhesionDisputes();
    }

    public long pendingRegistrations() {
        Long n = jdbcTemplate.queryForObject(
            "SELECT COUNT(*) FROM registration_requests WHERE status = 'pending'",
            Long.class
        );
        return n == null ? 0L : n;
    }

    public long pendingContributions() {
        Long n = jdbcTemplate.queryForObject(
            "SELECT COUNT(*) FROM contributions WHERE status = 'pending'",
            Long.class
        );
        return n == null ? 0L : n;
    }

    /** Espèces terrain / centre encore en attente de rapprochement caisse. */
    public long pendingCashContributions() {
        Long n = jdbcTemplate.queryForObject(
            """
            SELECT COUNT(*) FROM contributions
            WHERE status = 'pending' AND LOWER(payment_mode) = 'cash'
            """,
            Long.class
        );
        return n == null ? 0L : n;
    }

    /** Conversations avec au moins un message client (fil actif). */
    public long pendingDeletionRequests() {
        Long n = jdbcTemplate.queryForObject(
            "SELECT COUNT(*) FROM admin_deletion_requests WHERE status = 'pending'",
            Long.class
        );
        return n == null ? 0L : n;
    }

    public long supportThreadsWithClientMessages() {
        Long n = jdbcTemplate.queryForObject(
            """
            SELECT COUNT(DISTINCT user_id)
            FROM support_chat_messages
            WHERE sender = 'client'
            """,
            Long.class
        );
        return n == null ? 0L : n;
    }
}
