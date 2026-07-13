package com.payflex.backend.service;

import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

@Service
public class ClientProductSelectionService {

    private final JdbcTemplate jdbcTemplate;

    public ClientProductSelectionService(JdbcTemplate jdbcTemplate) {
        this.jdbcTemplate = jdbcTemplate;
    }

    @Transactional
    public void addProductsIncremental(long clientUserId, long agentUserId, List<ProductLine> lines) {
        if (clientUserId <= 0 || lines == null || lines.isEmpty()) {
            return;
        }
        for (ProductLine line : lines) {
            if (line.productId() <= 0 || line.quantity() <= 0) {
                continue;
            }
            jdbcTemplate.update(
                """
                INSERT INTO client_product_selections (user_id, product_id, quantity, selected_by_agent_user_id)
                VALUES (?, ?, ?, ?)
                ON DUPLICATE KEY UPDATE
                  quantity = quantity + VALUES(quantity),
                  selected_by_agent_user_id = VALUES(selected_by_agent_user_id),
                  updated_at = CURRENT_TIMESTAMP
                """,
                clientUserId,
                line.productId(),
                line.quantity(),
                agentUserId > 0 ? agentUserId : null
            );
        }
    }

    @Transactional
    public void saveSelections(long clientUserId, long agentUserId, List<ProductLine> lines) {
        if (clientUserId <= 0 || lines == null || lines.isEmpty()) {
            return;
        }
        for (ProductLine line : lines) {
            if (line.productId() <= 0 || line.quantity() <= 0) {
                continue;
            }
            jdbcTemplate.update(
                """
                INSERT INTO client_product_selections (user_id, product_id, quantity, selected_by_agent_user_id)
                VALUES (?, ?, ?, ?)
                ON DUPLICATE KEY UPDATE quantity = VALUES(quantity), selected_by_agent_user_id = VALUES(selected_by_agent_user_id)
                """,
                clientUserId,
                line.productId(),
                line.quantity(),
                agentUserId > 0 ? agentUserId : null
            );
        }
    }

    public List<Map<String, Object>> listForClient(long clientUserId) {
        if (clientUserId <= 0) {
            return List.of();
        }
        return jdbcTemplate.queryForList(
            """
            SELECT cps.product_id, cps.quantity, p.name, p.price, p.image_url,
                   p.min_daily_contribution AS daily_min,
                   (cps.quantity * p.price) AS line_total
            FROM client_product_selections cps
            INNER JOIN products p ON p.id = cps.product_id
            WHERE cps.user_id = ?
            ORDER BY p.name ASC
            """,
            clientUserId
        );
    }

    public double totalProjectAmount(long clientUserId) {
        if (clientUserId <= 0) {
            return 0;
        }
        Double sum = jdbcTemplate.queryForObject(
            """
            SELECT COALESCE(SUM(p.price * cps.quantity), 0)
            FROM client_product_selections cps
            INNER JOIN products p ON p.id = cps.product_id
            WHERE cps.user_id = ?
            """,
            Double.class,
            clientUserId
        );
        return sum == null ? 0 : sum;
    }

    public List<ProductLine> parseJson(String json) {
        if (json == null || json.isBlank()) {
            return List.of();
        }
        try {
            ObjectMapper om = new ObjectMapper();
            List<Map<String, Object>> list = om.readValue(json, new TypeReference<>() {});
            return parseLines(list);
        } catch (Exception ex) {
            return List.of();
        }
    }

    public static List<ProductLine> parseLines(Object raw) {
        List<ProductLine> out = new ArrayList<>();
        if (!(raw instanceof List<?> list)) {
            return out;
        }
        for (Object item : list) {
            if (!(item instanceof Map<?, ?> m)) {
                continue;
            }
            long productId = toLong(m.get("productId"));
            if (productId <= 0) {
                productId = toLong(m.get("product_id"));
            }
            int qty = (int) toLong(m.get("quantity"));
            if (qty <= 0) {
                qty = 1;
            }
            if (productId > 0) {
                out.add(new ProductLine(productId, qty));
            }
        }
        return out;
    }

    private static long toLong(Object v) {
        if (v == null) {
            return 0L;
        }
        try {
            return Long.parseLong(v.toString());
        } catch (NumberFormatException ex) {
            return 0L;
        }
    }

    public void saveDailyContribution(long clientUserId, double dailyContribution) {
        if (clientUserId <= 0 || dailyContribution <= 0) {
            return;
        }
        jdbcTemplate.update(
            "UPDATE users SET daily_contribution = ? WHERE id = ?",
            dailyContribution,
            clientUserId
        );
    }

    public double getDailyContribution(long clientUserId) {
        if (clientUserId <= 0) {
            return 0;
        }
        try {
            Double v = jdbcTemplate.queryForObject(
                "SELECT daily_contribution FROM users WHERE id = ?",
                Double.class,
                clientUserId
            );
            return v == null || v <= 0 ? 0 : v;
        } catch (org.springframework.dao.EmptyResultDataAccessException ex) {
            return 0;
        }
    }

    public record ProductLine(long productId, int quantity) {}
}
