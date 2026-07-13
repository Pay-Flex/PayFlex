package com.payflex.backend.service;

import org.springframework.dao.EmptyResultDataAccessException;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;

import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

@Service
public class LegalDocumentService {

    public static final String CODE_CGU = "cgu";
    public static final String CODE_PRIVACY = "privacy";

    private final JdbcTemplate jdbcTemplate;

    public LegalDocumentService(JdbcTemplate jdbcTemplate) {
        this.jdbcTemplate = jdbcTemplate;
    }

    public record LegalDocumentRow(
        String code,
        String title,
        String content,
        String updatedAt,
        String updatedBy
    ) {}

    public List<LegalDocumentRow> listAll() {
        return jdbcTemplate.query(
            """
            SELECT code, title, content,
                   DATE_FORMAT(updated_at, '%Y-%m-%d %H:%i') AS updated_at,
                   COALESCE(updated_by, '') AS updated_by
            FROM legal_documents
            ORDER BY FIELD(code, 'cgu', 'privacy'), code
            """,
            (rs, i) -> new LegalDocumentRow(
                rs.getString("code"),
                rs.getString("title"),
                rs.getString("content"),
                rs.getString("updated_at"),
                rs.getString("updated_by")
            )
        );
    }

    public LegalDocumentRow getRequired(String code) {
        try {
            return jdbcTemplate.queryForObject(
                """
                SELECT code, title, content,
                       DATE_FORMAT(updated_at, '%Y-%m-%d %H:%i') AS updated_at,
                       COALESCE(updated_by, '') AS updated_by
                FROM legal_documents WHERE code = ?
                """,
                (rs, i) -> new LegalDocumentRow(
                    rs.getString("code"),
                    rs.getString("title"),
                    rs.getString("content"),
                    rs.getString("updated_at"),
                    rs.getString("updated_by")
                ),
                code
            );
        } catch (EmptyResultDataAccessException ex) {
            throw new IllegalArgumentException("Document juridique introuvable.");
        }
    }

    public void update(String code, String title, String content, String updatedBy) {
        if (code == null || code.isBlank()) {
            throw new IllegalArgumentException("Code document manquant.");
        }
        if (title == null || title.isBlank()) {
            throw new IllegalArgumentException("Titre requis.");
        }
        if (content == null || content.isBlank()) {
            throw new IllegalArgumentException("Contenu requis.");
        }
        int n = jdbcTemplate.update(
            """
            UPDATE legal_documents
            SET title = ?, content = ?, updated_at = NOW(), updated_by = ?
            WHERE code = ?
            """,
            title.trim(),
            content.trim(),
            updatedBy,
            code.trim()
        );
        if (n == 0) {
            throw new IllegalArgumentException("Document introuvable.");
        }
    }

    public List<Map<String, Object>> listForMobile() {
        return jdbcTemplate.query(
            """
            SELECT code, title, content,
                   DATE_FORMAT(updated_at, '%Y-%m-%dT%H:%i:%s') AS updatedAt
            FROM legal_documents
            ORDER BY FIELD(code, 'cgu', 'privacy'), code
            """,
            (rs, i) -> {
                Map<String, Object> row = new LinkedHashMap<>();
                row.put("code", rs.getString("code"));
                row.put("title", rs.getString("title"));
                row.put("content", rs.getString("content"));
                row.put("updatedAt", rs.getString("updatedAt"));
                return row;
            }
        );
    }
}
