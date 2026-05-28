package com.payflex.backend.service;

import org.springframework.dao.DataAccessException;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;

import java.util.List;
import java.util.Locale;
import java.util.Optional;

@Service
public class ProductCategoryService {

    private final JdbcTemplate jdbcTemplate;

    public ProductCategoryService(JdbcTemplate jdbcTemplate) {
        this.jdbcTemplate = jdbcTemplate;
    }

    public List<AdminCrudService.ProductCategoryRow> listAll() {
        return jdbcTemplate.query(
            """
            SELECT pc.id, pc.code, pc.label, pc.sort_order,
                   (SELECT COUNT(*) FROM products p WHERE p.category_id = pc.id) AS product_count
            FROM product_categories pc
            ORDER BY pc.sort_order ASC, pc.label ASC
            """,
            (rs, i) -> new AdminCrudService.ProductCategoryRow(
                rs.getLong("id"),
                rs.getString("code"),
                rs.getString("label"),
                rs.getInt("sort_order"),
                rs.getLong("product_count")
            )
        );
    }

    public Optional<AdminCrudService.ProductCategoryRow> findById(long id) {
        List<AdminCrudService.ProductCategoryRow> rows = jdbcTemplate.query(
            """
            SELECT pc.id, pc.code, pc.label, pc.sort_order,
                   (SELECT COUNT(*) FROM products p WHERE p.category_id = pc.id) AS product_count
            FROM product_categories pc WHERE pc.id = ?
            """,
            (rs, i) -> new AdminCrudService.ProductCategoryRow(
                rs.getLong("id"),
                rs.getString("code"),
                rs.getString("label"),
                rs.getInt("sort_order"),
                rs.getLong("product_count")
            ),
            id
        );
        return rows.isEmpty() ? Optional.empty() : Optional.of(rows.get(0));
    }

    public long create(String label, Integer sortOrder) {
        String lbl = normalizeLabel(label);
        String code = generateUniqueCode(lbl);
        int order = sortOrder == null ? 100 : sortOrder;
        jdbcTemplate.update(
            "INSERT INTO product_categories (code, label, sort_order) VALUES (?, ?, ?)",
            code,
            lbl,
            order
        );
        Long id = jdbcTemplate.queryForObject("SELECT LAST_INSERT_ID()", Long.class);
        return id == null ? 0L : id;
    }

    public void update(long id, String label, Integer sortOrder) {
        if (id <= 0) {
            throw new IllegalArgumentException("Catégorie introuvable.");
        }
        String lbl = normalizeLabel(label);
        int order = sortOrder == null ? 100 : sortOrder;
        int n = jdbcTemplate.update(
            "UPDATE product_categories SET label = ?, sort_order = ? WHERE id = ?",
            lbl,
            order,
            id
        );
        if (n == 0) {
            throw new IllegalArgumentException("Catégorie introuvable.");
        }
    }

    public void delete(long id) {
        if (id <= 0) {
            throw new IllegalArgumentException("Catégorie introuvable.");
        }
        Long used = jdbcTemplate.queryForObject(
            "SELECT COUNT(*) FROM products WHERE category_id = ?",
            Long.class,
            id
        );
        if (used != null && used > 0) {
            throw new IllegalArgumentException("Impossible de supprimer : des produits utilisent encore cette catégorie.");
        }
        String code = jdbcTemplate.queryForObject(
            "SELECT code FROM product_categories WHERE id = ?",
            String.class,
            id
        );
        if ("client".equals(code) || "agent".equals(code) || "autre".equals(code)) {
            throw new IllegalArgumentException("Cette catégorie système ne peut pas être supprimée.");
        }
        try {
            jdbcTemplate.update("DELETE FROM product_categories WHERE id = ?", id);
        } catch (DataAccessException ex) {
            throw new IllegalArgumentException("Suppression impossible (références actives).");
        }
    }

    private static String normalizeLabel(String label) {
        if (label == null || label.isBlank()) {
            throw new IllegalArgumentException("Le libellé de la catégorie est requis.");
        }
        return label.trim();
    }

    private String generateUniqueCode(String label) {
        String base = label.toLowerCase(Locale.ROOT)
            .replaceAll("[^a-z0-9]+", "_")
            .replaceAll("^_|_$", "");
        if (base.isBlank()) {
            base = "cat";
        }
        if (base.length() > 40) {
            base = base.substring(0, 40);
        }
        for (int i = 0; i < 20; i++) {
            String candidate = i == 0 ? base : base + "_" + i;
            Long n = jdbcTemplate.queryForObject(
                "SELECT COUNT(*) FROM product_categories WHERE code = ?",
                Long.class,
                candidate
            );
            if (n != null && n == 0) {
                return candidate;
            }
        }
        return base + "_" + System.currentTimeMillis();
    }
}
