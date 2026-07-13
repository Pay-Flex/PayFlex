package com.payflex.backend.service;

import java.time.LocalDate;
import java.time.YearMonth;
import java.time.format.DateTimeFormatter;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;

@Service
public class AdminRevenueService {

    private static final DateTimeFormatter YM = DateTimeFormatter.ofPattern("yyyy-MM");

    private final JdbcTemplate jdbcTemplate;

    public AdminRevenueService(JdbcTemplate jdbcTemplate) {
        this.jdbcTemplate = jdbcTemplate;
    }

    public Map<String, Object> buildSummary() {
        Map<String, Object> out = new LinkedHashMap<>();
        long adhesionPaid = countAdhesionPaid(null);
        long adhesionPaidMonth = countAdhesionPaid(currentYearMonth());
        double adhesionTotal = adhesionPaid * ClientAdhesionService.ADHESION_FEE_FCFA;
        double adhesionMonth = adhesionPaidMonth * ClientAdhesionService.ADHESION_FEE_FCFA;

        double bonusTotal = bonusDayRevenueFromCredits(null);
        double bonusMonth = bonusDayRevenueFromCredits(currentYearMonth());

        double total = adhesionTotal + bonusTotal;
        double totalMonth = adhesionMonth + bonusMonth;

        out.put("adhesionFeeFcfa", ClientAdhesionService.ADHESION_FEE_FCFA);
        out.put("adhesionPaidCount", adhesionPaid);
        out.put("adhesionPaidThisMonth", adhesionPaidMonth);
        out.put("adhesionRevenueFcfa", Math.round(adhesionTotal));
        out.put("adhesionRevenueThisMonthFcfa", Math.round(adhesionMonth));
        out.put("bonusDayRevenueFcfa", Math.round(bonusTotal));
        out.put("bonusDayRevenueThisMonthFcfa", Math.round(bonusMonth));
        out.put("activeClientMonths", countCreditedClientMonths(null));
        out.put("activeClientMonthsThisMonth", countCreditedClientMonths(currentYearMonth()));
        out.put("totalRevenueFcfa", Math.round(total));
        out.put("totalRevenueThisMonthFcfa", Math.round(totalMonth));
        out.put("monthlyBreakdown", monthlyBreakdown(8));
        out.put(
            "ruleLabel",
            "Adhésions (" + ClientAdhesionService.ADHESION_FEE_FCFA
                + " FCFA/client) + 1 jour/mois crédité en base (50 % PayFlex)"
        );
        return out;
    }

    private String currentYearMonth() {
        return YearMonth.now().format(YM);
    }

    private long countAdhesionPaid(String yearMonth) {
        String sql = """
            SELECT COUNT(*)
            FROM users u
            INNER JOIN roles r ON r.id = u.role_id AND r.code = 'client'
            WHERE u.adhesion_fee_paid = TRUE
            """;
        List<Object> args = new ArrayList<>();
        if (yearMonth != null && !yearMonth.isBlank()) {
            sql += " AND DATE_FORMAT(COALESCE(u.adhesion_paid_at, u.created_at), '%Y-%m') = ?";
            args.add(yearMonth);
        }
        Long n = jdbcTemplate.queryForObject(sql, Long.class, args.toArray());
        return n == null ? 0L : n;
    }

    /** Part PayFlex enregistrée dans {@code client_bonus_monthly_credits}. */
    private double bonusDayRevenueFromCredits(String yearMonth) {
        String sql = "SELECT COALESCE(SUM(company_share_fcfa), 0) FROM client_bonus_monthly_credits";
        List<Object> args = new ArrayList<>();
        if (yearMonth != null && !yearMonth.isBlank()) {
            sql += " WHERE `year_month` = ?";
            args.add(yearMonth);
        }
        Double v = jdbcTemplate.queryForObject(sql, Double.class, args.toArray());
        return v == null ? 0 : v;
    }

    private long countCreditedClientMonths(String yearMonth) {
        String sql = "SELECT COUNT(*) FROM client_bonus_monthly_credits";
        List<Object> args = new ArrayList<>();
        if (yearMonth != null && !yearMonth.isBlank()) {
            sql += " WHERE `year_month` = ?";
            args.add(yearMonth);
        }
        Long n = jdbcTemplate.queryForObject(sql, Long.class, args.toArray());
        return n == null ? 0L : n;
    }

    public List<Map<String, Object>> monthlyBreakdown(int months) {
        int span = Math.min(Math.max(months, 3), 24);
        LocalDate start = YearMonth.now().minusMonths(span - 1L).atDay(1);
        List<Map<String, Object>> out = new ArrayList<>();
        YearMonth cursor = YearMonth.from(start);
        YearMonth end = YearMonth.now();
        while (!cursor.isAfter(end)) {
            String ym = cursor.format(YM);
            long adhesions = countAdhesionPaid(ym);
            double adhesionRev = adhesions * ClientAdhesionService.ADHESION_FEE_FCFA;
            double bonusRev = bonusDayRevenueFromCredits(ym);
            Map<String, Object> row = new LinkedHashMap<>();
            row.put("label", ym);
            row.put("adhesionRevenueFcfa", Math.round(adhesionRev));
            row.put("bonusDayRevenueFcfa", Math.round(bonusRev));
            row.put("totalRevenueFcfa", Math.round(adhesionRev + bonusRev));
            row.put("adhesionCount", adhesions);
            out.add(row);
            cursor = cursor.plusMonths(1);
        }
        return out;
    }
}
