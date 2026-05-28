package com.payflex.backend.service;

import com.payflex.backend.dto.AdminDashboardResponse;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.dao.DataAccessException;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;

import java.util.Collections;
import java.util.List;
import java.util.Map;

@Service
public class AdminDashboardService {

    private static final Logger log = LoggerFactory.getLogger(AdminDashboardService.class);

    private final JdbcTemplate jdbcTemplate;

    public AdminDashboardService(JdbcTemplate jdbcTemplate) {
        this.jdbcTemplate = jdbcTemplate;
    }

    public AdminDashboardResponse buildDashboard() {
        long totalUsers = queryLong("SELECT COUNT(*) FROM users");
        long activeAgents = queryLong("SELECT COUNT(*) FROM agents WHERE active = TRUE");
        long totalClients = queryLong(
            """
            SELECT COUNT(*) FROM users u
            INNER JOIN roles r ON r.id = u.role_id
            WHERE r.code = 'client'
            """
        );
        long totalProducts = queryLong("SELECT COUNT(*) FROM products");
        double totalCollected = queryDouble("SELECT COALESCE(SUM(amount), 0) FROM contributions WHERE status = 'validated'");
        long pendingContributions = queryLong("SELECT COUNT(*) FROM contributions WHERE status = 'pending'");
        long pendingRegistrations = queryLong("SELECT COUNT(*) FROM registration_requests WHERE status = 'pending'");

        var metrics = new AdminDashboardResponse.Metrics(
            totalUsers,
            activeAgents,
            totalClients,
            totalProducts,
            totalCollected,
            pendingContributions,
            pendingRegistrations
        );

        Map<String, Double> weeklyMap = jdbcTemplate.query(
            """
            SELECT DAYOFWEEK(created_at) AS dow, COALESCE(SUM(amount), 0) AS total
            FROM contributions
            WHERE created_at >= DATE_SUB(NOW(), INTERVAL 7 DAY)
            GROUP BY DAYOFWEEK(created_at)
            """,
            rs -> {
                var m = new java.util.HashMap<String, Double>();
                while (rs.next()) {
                    int dow = rs.getInt("dow");
                    // MySQL: 1=Sunday ... 7=Saturday
                    String key = switch (dow) {
                        case 2 -> "Lun";
                        case 3 -> "Mar";
                        case 4 -> "Mer";
                        case 5 -> "Jeu";
                        case 6 -> "Ven";
                        case 7 -> "Sam";
                        default -> "Dim";
                    };
                    m.put(key, rs.getDouble("total"));
                }
                return m;
            }
        );
        var weekly = List.of("Lun", "Mar", "Mer", "Jeu", "Ven", "Sam", "Dim").stream()
            .map(day -> new AdminDashboardResponse.PaymentPoint(day, weeklyMap.getOrDefault(day, 0.0)))
            .toList();

        List<AdminDashboardResponse.AgentPerformance> agents;
        try {
            // Requête avancée objective terrain (peut échouer sur certaines variantes MySQL legacy).
            String objAg = AdminCrudService.terrainObjectiveSqlFragment("ag");
            String agentsSql = """
                SELECT u.full_name AS agent_name,
                       COUNT(DISTINCT c.user_id) AS clients_count,
                       COALESCE(SUM(c.amount), 0) AS collected_amount,
                       CASE
                         WHEN COALESCE(obj.terrain_objective, 0) <= 0 THEN 0
                         ELSE LEAST((COALESCE(SUM(c.amount), 0) / NULLIF(obj.terrain_objective, 0)) * 100, 100)
                       END AS objective_percent
                FROM agents a
                JOIN users u ON u.id = a.user_id
                LEFT JOIN contributions c ON c.agent_id = a.id
                LEFT JOIN (
                    SELECT ag.id AS aid,
                           (%s) AS terrain_objective
                    FROM agents ag
                ) obj ON obj.aid = a.id
                GROUP BY a.id, u.full_name, obj.terrain_objective
                ORDER BY collected_amount DESC
                LIMIT 5
                """.formatted(objAg);
            agents = jdbcTemplate.query(
                agentsSql,
                (rs, rowNum) -> new AdminDashboardResponse.AgentPerformance(
                    rs.getString("agent_name"),
                    rs.getLong("clients_count"),
                    rs.getDouble("collected_amount"),
                    rs.getDouble("objective_percent")
                )
            );
        } catch (DataAccessException ex) {
            log.warn("Top agents: fallback SQL simplifie (raison: {})", ex.getMessage());
            agents = jdbcTemplate.query(
                """
                SELECT u.full_name AS agent_name,
                       COUNT(DISTINCT c.user_id) AS clients_count,
                       COALESCE(SUM(c.amount), 0) AS collected_amount
                FROM agents a
                JOIN users u ON u.id = a.user_id
                LEFT JOIN contributions c ON c.agent_id = a.id
                GROUP BY a.id, u.full_name
                ORDER BY collected_amount DESC
                LIMIT 5
                """,
                (rs, rowNum) -> new AdminDashboardResponse.AgentPerformance(
                    rs.getString("agent_name"),
                    rs.getLong("clients_count"),
                    rs.getDouble("collected_amount"),
                    0.0
                )
            );
        }

        var users = jdbcTemplate.query(
            """
            SELECT u.id, u.full_name, r.code AS role, u.city, u.status
            FROM users u
            JOIN roles r ON r.id = u.role_id
            ORDER BY u.created_at DESC
            LIMIT 7
            """,
            (rs, rowNum) -> new AdminDashboardResponse.UserSummary(
                rs.getLong("id"),
                rs.getString("full_name"),
                rs.getString("role"),
                rs.getString("city"),
                rs.getString("status")
            )
        );

        var products = jdbcTemplate.query(
            """
            SELECT p.code, p.name, pc.label AS category, p.price, p.availability
            FROM products p
            JOIN product_categories pc ON pc.id = p.category_id
            ORDER BY p.created_at DESC
            LIMIT 7
            """,
            (rs, rowNum) -> new AdminDashboardResponse.ProductSummary(
                rs.getString("code"),
                rs.getString("name"),
                rs.getString("category"),
                rs.getDouble("price"),
                rs.getString("availability")
            )
        );

        return new AdminDashboardResponse(metrics, weekly, agents, users, products);
    }

    public List<StatPoint> topProducts() {
        return jdbcTemplate.query(
            """
            SELECT COALESCE(p.name, 'Sans produit') AS label, COUNT(*) AS value
            FROM contributions c
            LEFT JOIN products p ON p.id = c.product_id
            GROUP BY COALESCE(p.name, 'Sans produit')
            ORDER BY value DESC
            LIMIT 6
            """,
            (rs, rowNum) -> new StatPoint(rs.getString("label"), rs.getDouble("value"))
        );
    }

    public List<StatPoint> topClients() {
        return jdbcTemplate.query(
            """
            SELECT u.full_name AS label, COALESCE(SUM(c.amount), 0) AS value
            FROM users u
            LEFT JOIN contributions c ON c.user_id = u.id
            WHERE u.role_id = (SELECT id FROM roles WHERE code = 'client' LIMIT 1)
            GROUP BY u.id, u.full_name
            ORDER BY value DESC
            LIMIT 6
            """,
            (rs, rowNum) -> new StatPoint(rs.getString("label"), rs.getDouble("value"))
        );
    }

    public List<StatPoint> monthlyCollections() {
        return jdbcTemplate.query(
            """
            SELECT DATE_FORMAT(created_at, '%Y-%m') AS label, COALESCE(SUM(amount), 0) AS value
            FROM contributions
            WHERE created_at >= DATE_SUB(NOW(), INTERVAL 6 MONTH)
            GROUP BY DATE_FORMAT(created_at, '%Y-%m')
            ORDER BY label
            """,
            (rs, rowNum) -> new StatPoint(rs.getString("label"), rs.getDouble("value"))
        );
    }

    private long queryLong(String sql) {
        Long value = jdbcTemplate.queryForObject(sql, Long.class);
        return value != null ? value : 0L;
    }

    private double queryDouble(String sql) {
        Double value = jdbcTemplate.queryForObject(sql, Double.class);
        return value != null ? value : 0.0;
    }

    public record StatPoint(String label, double value) {}

    /** Clients avec trop de jours de rattrapage signalés par l’application (snapshot mensuel). */
    public List<Map<String, Object>> clientsWithHighCatchup(int threshold) {
        try {
            return jdbcTemplate.queryForList(
                """
                SELECT u.id AS user_id, u.full_name AS full_name, u.phone AS phone,
                       COALESCE(u.catchup_pending_cached, 0) AS orange_days,
                       u.catchup_snapshot_month AS snapshot_month
                FROM users u
                JOIN roles r ON r.id = u.role_id
                WHERE r.code = 'client' AND COALESCE(u.catchup_pending_cached, 0) >= ?
                ORDER BY u.catchup_pending_cached DESC
                LIMIT 35
                """,
                threshold
            );
        } catch (DataAccessException ex) {
            log.warn(
                "Alertes rattrapage ignorées (schéma ou requête). Vérifiez Flyway V19 / colonnes users.catchup_* : {}",
                ex.getMessage()
            );
            return Collections.emptyList();
        }
    }
}
