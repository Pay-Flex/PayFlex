package com.payflex.backend.service;

import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.springframework.dao.EmptyResultDataAccessException;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

@Service
public class AgentMobileService {

    private static final List<String> WEEK_DAYS = List.of("lun", "mar", "mer", "jeu", "ven", "sam", "dim");

    private final JdbcTemplate jdbcTemplate;
    private final ClientProductSelectionService productSelectionService;
    private final CredentialHashService credentialHashService;
    private final ClientBonusSavingsService clientBonusSavingsService;
    private final ProductDeliveryService productDeliveryService;

    public AgentMobileService(
        JdbcTemplate jdbcTemplate,
        ClientProductSelectionService productSelectionService,
        CredentialHashService credentialHashService,
        ClientBonusSavingsService clientBonusSavingsService,
        ProductDeliveryService productDeliveryService
    ) {
        this.jdbcTemplate = jdbcTemplate;
        this.productSelectionService = productSelectionService;
        this.credentialHashService = credentialHashService;
        this.clientBonusSavingsService = clientBonusSavingsService;
        this.productDeliveryService = productDeliveryService;
    }

    public Map<String, Object> dashboard(long agentUserId) {
        Map<String, Object> out = new LinkedHashMap<>();
        Long agentRowId = findAgentRowId(agentUserId);
        if (agentRowId == null) {
            out.put("hasData", false);
            return out;
        }
        try {
            String dashboardSql = """
                SELECT
                  COALESCE(z.name, a.zone) AS zone_name,
                  (%s) AS terrain_objective,
                  COALESCE((
                """.formatted(AdminCrudService.terrainObjectiveSqlFragment("a")) + """
                    SELECT SUM(c.amount)
                    FROM contributions c
                    WHERE c.agent_id = a.id AND c.status = 'validated'
                      AND c.paid_at IS NOT NULL AND DATE(c.paid_at) = CURDATE()
                  ), 0) AS today_collected,
                  COALESCE((
                    SELECT SUM(c.amount)
                    FROM contributions c
                    WHERE c.agent_id = a.id AND c.status = 'validated'
                  ), 0) AS total_collected,
                  (
                    SELECT COUNT(*)
                    FROM users cu
                    INNER JOIN roles cr ON cr.id = cu.role_id AND cr.code = 'client'
                    WHERE cu.assigned_agent_user_id = a.user_id
                  ) AS clients_count,
                  COALESCE((
                    SELECT COUNT(*) FROM contributions c2 WHERE c2.agent_id = a.id AND c2.status = 'validated'
                  ), 0) AS validated_count,
                  COALESCE((
                    SELECT COUNT(*) FROM contributions c3 WHERE c3.agent_id = a.id AND c3.status = 'pending'
                  ), 0) AS pending_count
                FROM agents a
                LEFT JOIN zones z ON z.id = a.zone_id
                WHERE a.user_id = ?
                LIMIT 1
                """;
            Map<String, Object> row = jdbcTemplate.queryForMap(dashboardSql, agentUserId);
            double objective = toDouble(row.get("terrain_objective"));
            double today = toDouble(row.get("today_collected"));
            double total = toDouble(row.get("total_collected"));
            long validated = toLong(row.get("validated_count"));
            long pending = toLong(row.get("pending_count"));
            long clients = toLong(row.get("clients_count"));
            double recoveryPct = validated + pending > 0
                ? Math.round(100.0 * validated / (validated + pending))
                : 0;

            out.put("hasData", true);
            out.put("zoneName", row.get("zone_name"));
            out.put("todayCollectedFcfa", Math.round(today));
            out.put("dailyObjectiveFcfa", Math.round(objective > 0 ? objective / 30.0 : 0));
            out.put("terrainObjectiveFcfa", Math.round(objective));
            out.put("totalCollectedFcfa", Math.round(total));
            out.put("clientsCount", clients);
            out.put("recoveryPercent", recoveryPct);
            out.put("validatedContributions", validated);
            out.put("pendingContributions", pending);
            if (objective > 0) {
                out.put("todayProgressPercent", Math.min(100, Math.round(100.0 * today / (objective / 30.0))));
            } else {
                out.put("todayProgressPercent", 0);
            }
        } catch (EmptyResultDataAccessException ex) {
            out.put("hasData", false);
        }
        return out;
    }

    public Map<String, Object> profile(long agentUserId) {
        Map<String, Object> out = new LinkedHashMap<>();
        try {
            Map<String, Object> row = jdbcTemplate.queryForMap(
                """
                SELECT
                  u.full_name, u.phone, u.city, u.status,
                  COALESCE(z.name, a.zone) AS zone_name,
                  z.description AS zone_description,
                  a.matricule, a.hire_date, a.contract_type,
                  a.supervisor_name, a.supervisor_phone,
                  a.weekly_schedule_json,
                  COALESCE(a.cash_debt_fcfa, 0) AS cash_debt_fcfa,
                  (
                    SELECT COUNT(*)
                    FROM users cu
                    INNER JOIN roles cr ON cr.id = cu.role_id AND cr.code = 'client'
                    WHERE cu.assigned_agent_user_id = a.user_id
                  ) AS clients_count,
                  COALESCE((
                    SELECT COUNT(*) FROM contributions c2 WHERE c2.agent_id = a.id AND c2.status = 'validated'
                  ), 0) AS validated_count,
                  COALESCE((
                    SELECT COUNT(*) FROM contributions c3 WHERE c3.agent_id = a.id AND c3.status = 'pending'
                  ), 0) AS pending_count
                FROM agents a
                JOIN users u ON u.id = a.user_id
                LEFT JOIN zones z ON z.id = a.zone_id
                WHERE a.user_id = ?
                LIMIT 1
                """,
                agentUserId
            );
            long validated = toLong(row.get("validated_count"));
            long pending = toLong(row.get("pending_count"));
            double recoveryPct = validated + pending > 0
                ? Math.round(100.0 * validated / (validated + pending))
                : 0;

            out.put("hasData", true);
            out.put("fullName", row.get("full_name"));
            out.put("phone", row.get("phone"));
            out.put("city", row.get("city"));
            out.put("status", row.get("status"));
            out.put("zoneName", row.get("zone_name"));
            out.put("zoneDescription", row.get("zone_description"));
            List<String> sectors = listCollectSectors(agentUserId);
            out.put("collectSectors", sectors);
            out.put("collectSectorsLabel", formatSectorsLabel(sectors, row.get("zone_name")));
            Map<String, String> schedule = parseWeeklySchedule(row.get("weekly_schedule_json"));
            out.put("weeklySchedule", schedule);
            out.put("weeklyScheduleSummary", weeklyScheduleSummary(schedule));
            out.put("matricule", row.get("matricule"));
            out.put("hireDate", row.get("hire_date"));
            out.put("contractType", row.get("contract_type"));
            out.put("supervisorName", row.get("supervisor_name"));
            out.put("supervisorPhone", row.get("supervisor_phone"));
            out.put("clientsCount", toLong(row.get("clients_count")));
            out.put("recoveryPercent", recoveryPct);
            out.put("cashDebtFcfa", Math.round(toDouble(row.get("cash_debt_fcfa"))));
        } catch (EmptyResultDataAccessException ex) {
            out.put("hasData", false);
        }
        return out;
    }

    public Map<String, Object> clientDetail(long agentUserId, long clientUserId) {
        Map<String, Object> out = new LinkedHashMap<>();
        if (!isClientAssignedToAgent(clientUserId, agentUserId)) {
            out.put("hasData", false);
            out.put("message", "Client non rattaché à votre agent.");
            return out;
        }
        try {
            Map<String, Object> client = jdbcTemplate.queryForMap(
                """
                SELECT u.id, u.full_name, u.phone, u.city, u.profession, u.status,
                       u.adhesion_fee_paid, u.adhesion_paid_at, u.unique_code, u.self_managed,
                       u.daily_contribution, u.assiduity_badge,
                       COALESCE(u.catchup_pending_cached, 0) AS catchup_pending_cached
                FROM users u
                INNER JOIN roles r ON r.id = u.role_id AND r.code = 'client'
                WHERE u.id = ?
                LIMIT 1
                """,
                clientUserId
            );
            double totalProject = productSelectionService.totalProjectAmount(clientUserId);
            Double collected = jdbcTemplate.queryForObject(
                """
                SELECT COALESCE(SUM(amount), 0)
                FROM contributions
                WHERE user_id = ? AND status = 'validated'
                """,
                Double.class,
                clientUserId
            );
            double collectedAmt = collected == null ? 0 : collected;
            if (totalProject <= 0) {
                Double fromContrib = jdbcTemplate.queryForObject(
                    """
                    SELECT COALESCE(SUM(DISTINCT pr.price), 0)
                    FROM contributions c
                    INNER JOIN products pr ON pr.id = c.product_id
                    WHERE c.user_id = ? AND c.product_id IS NOT NULL
                    """,
                    Double.class,
                    clientUserId
                );
                if (fromContrib != null && fromContrib > 0) {
                    totalProject = fromContrib;
                }
            }

            List<Map<String, Object>> products = enrichProductsWithProgress(clientUserId, productSelectionService.listForClient(clientUserId));
            List<Map<String, Object>> history = jdbcTemplate.queryForList(
                """
                SELECT c.id, c.amount, c.status, c.payment_mode, c.paid_at, c.created_at,
                       c.catchup_year, c.catchup_month, c.catchup_day,
                       c.product_id, p.name AS product_name
                FROM contributions c
                LEFT JOIN products p ON p.id = c.product_id
                WHERE c.user_id = ?
                ORDER BY COALESCE(c.paid_at, c.created_at) DESC
                LIMIT 120
                """,
                clientUserId
            );
            Map<String, Object> lastPay = history.isEmpty() ? Map.of() : history.get(0);

            out.put("hasData", true);
            out.put("id", client.get("id"));
            out.put("fullName", client.get("full_name"));
            out.put("phone", client.get("phone"));
            out.put("city", client.get("city"));
            out.put("profession", client.get("profession"));
            out.put("status", client.get("status"));
            out.put("adhesionFeePaid", client.get("adhesion_fee_paid"));
            out.put("uniqueCode", client.get("unique_code"));
            out.put("selfManaged", client.get("self_managed"));
            double dailyContribution = toDouble(client.get("daily_contribution"));
            if (dailyContribution <= 0 && totalProject > 0) {
                dailyContribution = Math.max(200, Math.round(totalProject / 365.0));
            }

            out.put("totalProjectFcfa", Math.round(totalProject));
            out.put("collectedFcfa", Math.round(collectedAmt));
            out.put("remainingFcfa", Math.max(0, Math.round(totalProject - collectedAmt)));
            out.put("dailyContributionFcfa", Math.round(dailyContribution));
            out.put("progressPercent", totalProject > 0
                ? Math.min(100, Math.round(100.0 * collectedAmt / totalProject))
                : 0);
            long catchupPending = toLong(client.get("catchup_pending_cached"));
            out.put("catchupPendingDays", catchupPending);
            double remaining = Math.max(0, totalProject - collectedAmt);
            long estimatedDays = dailyContribution > 0 ? (long) Math.ceil(remaining / dailyContribution) : 0;
            out.put("estimatedDaysRemaining", estimatedDays);
            if (estimatedDays > 0) {
                out.put("estimatedEndDate", LocalDate.now().plusDays(estimatedDays).toString());
            } else {
                out.put("estimatedEndDate", null);
            }
            LocalDate today = LocalDate.now();
            out.put("calendarYear", today.getYear());
            out.put("calendarMonth", today.getMonthValue());
            out.put("paidDaysThisMonth", paidDaysForMonth(clientUserId, today.getYear(), today.getMonthValue(), null));
            out.put("catchupDaysThisMonth", catchupDaysForMonth(clientUserId, today.getYear(), today.getMonthValue()));
            out.put("products", products);
            out.put("contributions", history);
            out.put("lastPaymentAt", lastPay.get("paid_at") != null ? lastPay.get("paid_at") : lastPay.get("created_at"));
            out.put("lastPaymentAmount", lastPay.get("amount"));
            out.put("bonusSavings", clientBonusSavingsService.summary(clientUserId, dailyContribution));
            out.put("assiduityBadge", client.get("assiduity_badge"));
            out.put("adhesionPaidAt", client.get("adhesion_paid_at"));
            out.put("hasSmartphone", client.get("phone") != null && !client.get("phone").toString().isBlank());
            Map<String, Object> deliveryCtx = new LinkedHashMap<>();
            deliveryCtx.put("id", clientUserId);
            deliveryCtx.put("role", "client");
            productDeliveryService.enrichProfileMap(deliveryCtx);
            out.put("deliveryStatus", deliveryCtx.get("deliveryStatus"));
            out.put("deliveryProductName", deliveryCtx.get("deliveryProductName"));
            out.put("deliveryProductPrice", deliveryCtx.get("deliveryProductPrice"));
            out.put("deliveryTotalValidated", deliveryCtx.get("deliveryTotalValidated"));
            out.put("deliveryId", deliveryCtx.get("deliveryId"));
        } catch (EmptyResultDataAccessException ex) {
            out.put("hasData", false);
        }
        return out;
    }

    public Map<String, Object> contributionRegistry(long agentUserId) {
        Map<String, Object> out = new LinkedHashMap<>();
        Long agentRowId = findAgentRowId(agentUserId);
        if (agentRowId == null) {
            out.put("hasData", false);
            return out;
        }
        List<Map<String, Object>> items = jdbcTemplate.queryForList(
            """
            SELECT c.id, c.amount, c.status, c.payment_mode,
                   COALESCE(c.paid_at, c.created_at) AS when_at,
                   c.catchup_year, c.catchup_month, c.catchup_day,
                   c.product_id, p.name AS product_name,
                   u.id AS client_id, u.full_name AS client_name, u.phone AS client_phone
            FROM contributions c
            INNER JOIN users u ON u.id = c.user_id
            INNER JOIN roles r ON r.id = u.role_id AND r.code = 'client'
            LEFT JOIN products p ON p.id = c.product_id
            WHERE u.assigned_agent_user_id = ?
            ORDER BY COALESCE(c.paid_at, c.created_at) DESC
            LIMIT 120
            """,
            agentUserId
        );
        out.put("hasData", true);
        out.put("items", items);
        out.put("totalCount", items.size());
        long validated = items.stream().filter(r -> "validated".equals(String.valueOf(r.get("status")))).count();
        long pending = items.stream().filter(r -> "pending".equals(String.valueOf(r.get("status")))).count();
        out.put("validatedCount", validated);
        out.put("pendingCount", pending);
        return out;
    }

    public Map<String, Object> zoneTour(long agentUserId) {
        Map<String, Object> out = new LinkedHashMap<>();
        Long agentRowId = findAgentRowId(agentUserId);
        if (agentRowId == null) {
            out.put("hasData", false);
            return out;
        }
        try {
            Map<String, Object> row = jdbcTemplate.queryForMap(
                """
                SELECT COALESCE(z.name, a.zone) AS zone_name, z.description AS zone_description,
                       a.zone_id
                FROM agents a
                LEFT JOIN zones z ON z.id = a.zone_id
                WHERE a.user_id = ?
                LIMIT 1
                """,
                agentUserId
            );
            List<String> sectors = listCollectSectors(agentUserId);
            List<Map<String, Object>> clients = jdbcTemplate.queryForList(
                """
                SELECT u.id, u.full_name, u.phone, u.city, u.status
                FROM users u
                INNER JOIN roles r ON r.id = u.role_id AND r.code = 'client'
                WHERE u.assigned_agent_user_id = ?
                ORDER BY u.full_name ASC
                LIMIT 200
                """,
                agentUserId
            );
            out.put("hasData", true);
            out.put("zoneName", row.get("zone_name"));
            out.put("zoneDescription", row.get("zone_description"));
            out.put("zoneId", row.get("zone_id"));
            out.put("collectSectors", sectors);
            out.put("collectSectorsLabel", formatSectorsLabel(sectors, row.get("zone_name")));
            out.put("clientsCount", clients.size());
            out.put("clients", clients);
        } catch (EmptyResultDataAccessException ex) {
            out.put("hasData", false);
        }
        return out;
    }

    @Transactional
    public Map<String, Object> updateWeeklySchedule(long agentUserId, Map<String, String> schedule) {
        Map<String, Object> out = new LinkedHashMap<>();
        Long agentRowId = findAgentRowId(agentUserId);
        if (agentRowId == null) {
            out.put("ok", false);
            out.put("message", "Fiche agent introuvable.");
            return out;
        }
        Map<String, String> normalized = new LinkedHashMap<>();
        for (String day : WEEK_DAYS) {
            String v = schedule == null ? "" : schedule.getOrDefault(day, "").trim();
            normalized.put(day, v);
        }
        String json;
        try {
            json = new ObjectMapper().writeValueAsString(normalized);
        } catch (Exception ex) {
            out.put("ok", false);
            out.put("message", "Planning invalide.");
            return out;
        }
        jdbcTemplate.update(
            "UPDATE agents SET weekly_schedule_json = ? WHERE user_id = ?",
            json,
            agentUserId
        );
        out.put("ok", true);
        out.put("weeklySchedule", normalized);
        out.put("weeklyScheduleSummary", weeklyScheduleSummary(normalized));
        out.put("message", "Planning hebdomadaire enregistré.");
        return out;
    }

    @Transactional
    public Map<String, Object> changeAgentPin(long agentUserId, String currentPin, String newPin) {
        Map<String, Object> out = new LinkedHashMap<>();
        if (currentPin == null || currentPin.isBlank() || newPin == null || newPin.isBlank()) {
            out.put("ok", false);
            out.put("message", "Ancien et nouveau code PIN requis.");
            return out;
        }
        try {
            credentialHashService.validateMobilePin(newPin);
        } catch (IllegalArgumentException ex) {
            out.put("ok", false);
            out.put("message", ex.getMessage());
            return out;
        }
        try {
            String stored = jdbcTemplate.queryForObject(
                "SELECT pin FROM users WHERE id = ? LIMIT 1",
                String.class,
                agentUserId
            );
            if (!credentialHashService.matchesMobilePin(currentPin.trim(), stored)) {
                out.put("ok", false);
                out.put("message", "Code PIN actuel incorrect.");
                return out;
            }
            String hashed = credentialHashService.hashMobilePin(newPin.trim());
            jdbcTemplate.update(
                "UPDATE users SET pin = ?, secret_code = ? WHERE id = ?",
                hashed,
                hashed,
                agentUserId
            );
            out.put("ok", true);
            out.put("message", "Code PIN agent mis à jour.");
        } catch (EmptyResultDataAccessException ex) {
            out.put("ok", false);
            out.put("message", "Compte introuvable.");
        }
        return out;
    }

    public Map<String, Object> addClientProducts(
        long agentUserId,
        long clientUserId,
        List<ClientProductSelectionService.ProductLine> lines,
        double dailyContribution
    ) {
        Map<String, Object> out = new LinkedHashMap<>();
        if (!isClientAssignedToAgent(clientUserId, agentUserId)) {
            out.put("ok", false);
            out.put("message", "Client non rattaché à votre agent.");
            return out;
        }
        if (lines == null || lines.isEmpty()) {
            out.put("ok", false);
            out.put("message", "Sélectionnez au moins un produit.");
            return out;
        }
        productSelectionService.addProductsIncremental(clientUserId, agentUserId, lines);

        double currentDaily = productSelectionService.getDailyContribution(clientUserId);
        double newDaily = dailyContribution > 0 ? dailyContribution : currentDaily;
        if (newDaily <= 0) {
            double total = productSelectionService.totalProjectAmount(clientUserId);
            newDaily = total > 0 ? Math.max(200, Math.round(total / 365.0)) : 200;
        }
        productSelectionService.saveDailyContribution(clientUserId, newDaily);

        Map<String, Object> detail = clientDetail(agentUserId, clientUserId);
        out.put("ok", true);
        out.put("message", "Produit(s) ajouté(s) au dossier client.");
        out.put("client", detail);
        return out;
    }

    public List<Map<String, Object>> enrichedClientList(long agentUserId) {
        List<Map<String, Object>> base = jdbcTemplate.queryForList(
            """
            SELECT u.id, u.full_name, u.phone, u.city, u.profession, u.status,
                   u.adhesion_fee_paid, u.adhesion_dispute_open, u.assiduity_badge, u.self_managed,
                   u.unique_code,
                   COALESCE(SUM(CASE WHEN c.status = 'validated' THEN c.amount ELSE 0 END), 0) AS total_collected,
                   MAX(CASE WHEN c.status = 'validated' THEN COALESCE(c.paid_at, c.created_at) END) AS last_payment_at
            FROM users u
            INNER JOIN roles r ON r.id = u.role_id AND r.code = 'client'
            LEFT JOIN contributions c ON c.user_id = u.id
            WHERE u.assigned_agent_user_id = ?
            GROUP BY u.id, u.full_name, u.phone, u.city, u.profession, u.status, u.adhesion_fee_paid,
                     u.adhesion_dispute_open, u.assiduity_badge, u.self_managed, u.unique_code
            ORDER BY u.full_name ASC
            """,
            agentUserId
        );
        for (Map<String, Object> row : base) {
            row.put("displayZone", row.get("city") != null && !String.valueOf(row.get("city")).isBlank()
                ? row.get("city")
                : (row.get("profession") != null ? row.get("profession") : null));
            Object phone = row.get("phone");
            row.put("hasPhone", phone != null && !String.valueOf(phone).isBlank());
        }
        return base;
    }

    private boolean isClientAssignedToAgent(long clientUserId, long agentUserId) {
        Long assigned = jdbcTemplate.query(
            "SELECT assigned_agent_user_id FROM users WHERE id = ?",
            rs -> rs.next() ? rs.getLong(1) : null,
            clientUserId
        );
        return assigned != null && assigned.equals(agentUserId);
    }

    private Long findAgentRowId(long agentUserId) {
        try {
            return jdbcTemplate.queryForObject(
                "SELECT id FROM agents WHERE user_id = ? LIMIT 1",
                Long.class,
                agentUserId
            );
        } catch (EmptyResultDataAccessException ex) {
            return null;
        }
    }

    private static double toDouble(Object v) {
        if (v == null) {
            return 0;
        }
        if (v instanceof Number n) {
            return n.doubleValue();
        }
        try {
            return Double.parseDouble(v.toString());
        } catch (NumberFormatException ex) {
            return 0;
        }
    }

    private List<String> listCollectSectors(long agentUserId) {
        return jdbcTemplate.queryForList(
            """
            SELECT DISTINCT TRIM(u.city) AS sector
            FROM users u
            INNER JOIN roles r ON r.id = u.role_id AND r.code = 'client'
            WHERE u.assigned_agent_user_id = ?
              AND u.city IS NOT NULL AND TRIM(u.city) <> ''
            ORDER BY sector ASC
            LIMIT 12
            """,
            String.class,
            agentUserId
        );
    }

    private static String formatSectorsLabel(List<String> sectors, Object zoneName) {
        if (sectors != null && !sectors.isEmpty()) {
            return String.join(", ", sectors);
        }
        if (zoneName != null && !zoneName.toString().isBlank()) {
            return zoneName.toString().trim();
        }
        return "Non défini";
    }

    private static Map<String, String> parseWeeklySchedule(Object raw) {
        Map<String, String> empty = new LinkedHashMap<>();
        for (String day : WEEK_DAYS) {
            empty.put(day, "");
        }
        if (raw == null || raw.toString().isBlank()) {
            return empty;
        }
        try {
            Map<String, String> parsed = new ObjectMapper().readValue(
                raw.toString(),
                new TypeReference<LinkedHashMap<String, String>>() {}
            );
            Map<String, String> out = new LinkedHashMap<>();
            for (String day : WEEK_DAYS) {
                out.put(day, parsed.getOrDefault(day, "").trim());
            }
            return out;
        } catch (Exception ex) {
            return empty;
        }
    }

    private static String weeklyScheduleSummary(Map<String, String> schedule) {
        if (schedule == null || schedule.isEmpty()) {
            return "Non défini";
        }
        long filled = schedule.values().stream().filter(v -> v != null && !v.isBlank()).count();
        if (filled == 0) {
            return "Non défini";
        }
        if (filled >= 5) {
            return "Planning complet";
        }
        return "Légères modifications";
    }

    private static long toLong(Object v) {
        if (v == null) {
            return 0L;
        }
        if (v instanceof Number n) {
            return n.longValue();
        }
        try {
            return Long.parseLong(v.toString());
        } catch (NumberFormatException ex) {
            return 0L;
        }
    }

    private List<Map<String, Object>> enrichProductsWithProgress(long clientUserId, List<Map<String, Object>> products) {
        List<Map<String, Object>> out = new ArrayList<>();
        for (Map<String, Object> row : products) {
            Map<String, Object> copy = new LinkedHashMap<>(row);
            long productId = toLong(row.get("product_id"));
            double lineTotal = toDouble(row.get("line_total"));
            Double collected = jdbcTemplate.queryForObject(
                """
                SELECT COALESCE(SUM(amount), 0)
                FROM contributions
                WHERE user_id = ? AND product_id = ? AND status = 'validated'
                """,
                Double.class,
                clientUserId,
                productId
            );
            double collectedAmt = collected == null ? 0 : collected;
            double remaining = Math.max(0, lineTotal - collectedAmt);
            copy.put("collected_fcfa", Math.round(collectedAmt));
            copy.put("remaining_fcfa", Math.round(remaining));
            copy.put("progress_percent", lineTotal > 0
                ? Math.min(100, Math.round(100.0 * collectedAmt / lineTotal))
                : 0);
            copy.put("paid_days_this_month", paidDaysForMonth(clientUserId, LocalDate.now().getYear(), LocalDate.now().getMonthValue(), productId));
            out.add(copy);
        }
        return out;
    }

    private List<Integer> paidDaysForMonth(long clientUserId, int year, int month, Long productId) {
        String sql = """
            SELECT DISTINCT DAY(COALESCE(c.paid_at, c.created_at)) AS d
            FROM contributions c
            WHERE c.user_id = ? AND c.status = 'validated'
              AND YEAR(COALESCE(c.paid_at, c.created_at)) = ?
              AND MONTH(COALESCE(c.paid_at, c.created_at)) = ?
            """;
        List<Object> args = new ArrayList<>(List.of(clientUserId, year, month));
        if (productId != null && productId > 0) {
            sql += " AND c.product_id = ?";
            args.add(productId);
        }
        sql += " ORDER BY d ASC";
        return jdbcTemplate.queryForList(sql, Integer.class, args.toArray());
    }

    private List<Integer> catchupDaysForMonth(long clientUserId, int year, int month) {
        LocalDate today = LocalDate.now();
        List<Integer> paid = paidDaysForMonth(clientUserId, year, month, null);
        List<Integer> catchup = new ArrayList<>();
        int lastDay = today.getMonthValue() == month && today.getYear() == year
            ? today.getDayOfMonth()
            : LocalDate.of(year, month, 1).lengthOfMonth();
        for (int d = 1; d <= lastDay; d++) {
            if (!paid.contains(d)) {
                catchup.add(d);
            }
        }
        return catchup;
    }
}
