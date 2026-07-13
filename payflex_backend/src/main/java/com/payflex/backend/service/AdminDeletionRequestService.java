package com.payflex.backend.service;

import org.springframework.dao.DataAccessException;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.Optional;

@Service
public class AdminDeletionRequestService {

    public static final String STATUS_PENDING = "pending";
    public static final String STATUS_APPROVED = "approved";
    public static final String STATUS_REJECTED = "rejected";

    private final JdbcTemplate jdbcTemplate;

    public AdminDeletionRequestService(JdbcTemplate jdbcTemplate) {
        this.jdbcTemplate = jdbcTemplate;
    }

    public long countPending() {
        Long n = jdbcTemplate.queryForObject(
            "SELECT COUNT(*) FROM admin_deletion_requests WHERE status = ?",
            Long.class,
            STATUS_PENDING
        );
        return n == null ? 0L : n;
    }

    public List<DeletionRequestRow> listPending() {
        return jdbcTemplate.query(
            """
            SELECT id, entity_type, entity_id, entity_label, reason, status,
                   requested_by, requested_at, reviewed_by, reviewed_at, review_note
            FROM admin_deletion_requests
            WHERE status = ?
            ORDER BY requested_at ASC
            """,
            (rs, i) -> mapRow(rs),
            STATUS_PENDING
        );
    }

    public long submit(String entityType, long entityId, String entityLabel, String reason, String requestedBy) {
        if (entityType == null || entityType.isBlank()) {
            throw new IllegalArgumentException("Type d'élément invalide.");
        }
        if (reason == null || reason.trim().length() < 5) {
            throw new IllegalArgumentException("Le motif de suppression doit contenir au moins 5 caractères.");
        }
        Long existing = jdbcTemplate.queryForObject(
            """
            SELECT COUNT(*) FROM admin_deletion_requests
            WHERE entity_type = ? AND entity_id = ? AND status = ?
            """,
            Long.class,
            entityType.trim(),
            entityId,
            STATUS_PENDING
        );
        if (existing != null && existing > 0) {
            throw new IllegalArgumentException("Une demande de suppression est déjà en attente pour cet élément.");
        }
        jdbcTemplate.update(
            """
            INSERT INTO admin_deletion_requests (entity_type, entity_id, entity_label, reason, requested_by)
            VALUES (?, ?, ?, ?, ?)
            """,
            entityType.trim(),
            entityId,
            entityLabel == null || entityLabel.isBlank() ? entityType + " #" + entityId : entityLabel.trim(),
            reason.trim(),
            requestedBy
        );
        Long id = jdbcTemplate.queryForObject("SELECT LAST_INSERT_ID()", Long.class);
        return id == null ? 0L : id;
    }

    public Optional<DeletionRequestRow> findById(long id) {
        List<DeletionRequestRow> rows = jdbcTemplate.query(
            """
            SELECT id, entity_type, entity_id, entity_label, reason, status,
                   requested_by, requested_at, reviewed_by, reviewed_at, review_note
            FROM admin_deletion_requests WHERE id = ?
            """,
            (rs, i) -> mapRow(rs),
            id
        );
        return rows.isEmpty() ? Optional.empty() : Optional.of(rows.get(0));
    }

    @Transactional
    public void markApproved(long requestId, String reviewedBy) {
        int n = jdbcTemplate.update(
            """
            UPDATE admin_deletion_requests
            SET status = ?, reviewed_by = ?, reviewed_at = NOW()
            WHERE id = ? AND status = ?
            """,
            STATUS_APPROVED,
            reviewedBy,
            requestId,
            STATUS_PENDING
        );
        if (n == 0) {
            throw new IllegalArgumentException("Demande introuvable ou déjà traitée.");
        }
    }

    @Transactional
    public void markRejected(long requestId, String reviewedBy, String reviewNote) {
        int n = jdbcTemplate.update(
            """
            UPDATE admin_deletion_requests
            SET status = ?, reviewed_by = ?, reviewed_at = NOW(), review_note = ?
            WHERE id = ? AND status = ?
            """,
            STATUS_REJECTED,
            reviewedBy,
            reviewNote == null ? "" : reviewNote.trim(),
            requestId,
            STATUS_PENDING
        );
        if (n == 0) {
            throw new IllegalArgumentException("Demande introuvable ou déjà traitée.");
        }
    }

    private static DeletionRequestRow mapRow(java.sql.ResultSet rs) throws java.sql.SQLException {
        return new DeletionRequestRow(
            rs.getLong("id"),
            rs.getString("entity_type"),
            rs.getLong("entity_id"),
            rs.getString("entity_label"),
            rs.getString("reason"),
            rs.getString("status"),
            rs.getString("requested_by"),
            rs.getString("requested_at"),
            rs.getString("reviewed_by"),
            rs.getString("reviewed_at"),
            rs.getString("review_note")
        );
    }

    public record DeletionRequestRow(
        long id,
        String entityType,
        long entityId,
        String entityLabel,
        String reason,
        String status,
        String requestedBy,
        String requestedAt,
        String reviewedBy,
        String reviewedAt,
        String reviewNote
    ) {
        public String entityTypeLabel() {
            return switch (entityType == null ? "" : entityType) {
                case "user" -> "Compte utilisateur";
                case "agent" -> "Agent";
                case "product" -> "Produit";
                case "product_category" -> "Catégorie produit";
                case "zone" -> "Zone";
                case "contribution" -> "Cotisation";
                case "registration" -> "Demande d'inscription";
                default -> entityType;
            };
        }
    }
}
