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
    private final ProductDeliveryService productDeliveryService;

    public AdminNavService(
        JdbcTemplate jdbcTemplate,
        ClientAdhesionService clientAdhesionService,
        ProductDeliveryService productDeliveryService
    ) {
        this.jdbcTemplate = jdbcTemplate;
        this.clientAdhesionService = clientAdhesionService;
        this.productDeliveryService = productDeliveryService;
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

    /** Montant total des cotisations espèces encore en attente (rapprochement fin de journée). */
    public long pendingCashContributionsTotalFcfa() {
        Double n = jdbcTemplate.queryForObject(
            """
            SELECT COALESCE(SUM(amount), 0)
            FROM contributions
            WHERE status = 'pending' AND LOWER(payment_mode) = 'cash'
            """,
            Double.class
        );
        return n == null ? 0L : Math.round(n);
    }

    /** Conversations avec au moins un message client (fil actif). */
    public long pendingDeletionRequests() {
        Long n = jdbcTemplate.queryForObject(
            "SELECT COUNT(*) FROM admin_deletion_requests WHERE status = 'pending'",
            Long.class
        );
        return n == null ? 0L : n;
    }

    /** Dossiers clôture + livraison en attente d’action centre. */
    public long pendingDeliveries() {
        return productDeliveryService.countAwaitingClosure()
            + productDeliveryService.countAwaitingDelivery();
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
