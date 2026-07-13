package com.payflex.backend.service;

import java.time.YearMonth;
import java.time.LocalDate;
import java.time.format.DateTimeFormatter;
import java.time.format.TextStyle;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.dao.DuplicateKeyException;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.support.TransactionTemplate;

/**
 * Épargne bonus client : chaque mois civil, 1 jour de cotisation est prélevé et partagé
 * 50 % épargne client / 50 % PayFlex — quel que soit le nombre de jours réellement cotisés
 * (ex. 20 jours sur 31 : on prélève toujours 1 jour entier au tarif journalier).
 */
@Service
public class ClientBonusSavingsService {

    private static final Logger log = LoggerFactory.getLogger(ClientBonusSavingsService.class);
    private static final DateTimeFormatter YM = DateTimeFormatter.ofPattern("yyyy-MM");
    public static final String NOTIF_TYPE_BONUS_CREDIT = "bonus_savings_credited";

    private final JdbcTemplate jdbcTemplate;
    private final ClientProductSelectionService productSelectionService;
    private final UserInboxNotificationService inboxNotifications;
    private final AdminAuditService auditService;
    private final TransactionTemplate transactionTemplate;

    public ClientBonusSavingsService(
        JdbcTemplate jdbcTemplate,
        ClientProductSelectionService productSelectionService,
        UserInboxNotificationService inboxNotifications,
        AdminAuditService auditService,
        PlatformTransactionManager transactionManager
    ) {
        this.jdbcTemplate = jdbcTemplate;
        this.productSelectionService = productSelectionService;
        this.inboxNotifications = inboxNotifications;
        this.auditService = auditService;
        this.transactionTemplate = new TransactionTemplate(transactionManager);
    }

    public int officialDaysInMonth(int year, int month) {
        int days = YearMonth.of(year, month).lengthOfMonth();
        return Math.max(0, days - 1);
    }

    public double monthlyClientBonus(double dailyContribution) {
        return dailyContribution > 0 ? dailyContribution / 2.0 : 0;
    }

    public double monthlyLineBonus(double dailyMin, int quantity) {
        if (dailyMin <= 0 || quantity <= 0) {
            return 0;
        }
        return (dailyMin * quantity) / 2.0;
    }

    public double resolveDailyContribution(long clientUserId) {
        double daily = productSelectionService.getDailyContribution(clientUserId);
        if (daily <= 0) {
            double total = productSelectionService.totalProjectAmount(clientUserId);
            if (total > 0) {
                daily = Math.max(200, Math.round(total / 365.0));
            }
        }
        return daily;
    }

    public double accruedBonusFromDb(long clientUserId) {
        if (clientUserId <= 0) {
            return 0;
        }
        Double v = jdbcTemplate.queryForObject(
            "SELECT COALESCE(bonus_savings_fcfa, 0) FROM users WHERE id = ?",
            Double.class,
            clientUserId
        );
        return v == null ? 0 : v;
    }

    public int creditedMonthsCount(long clientUserId) {
        if (clientUserId <= 0) {
            return 0;
        }
        Integer n = jdbcTemplate.queryForObject(
            "SELECT COUNT(*) FROM client_bonus_monthly_credits WHERE user_id = ?",
            Integer.class,
            clientUserId
        );
        return n == null ? 0 : n;
    }

    public boolean isMonthAlreadyCredited(long clientUserId, String yearMonth) {
        List<Long> ids = jdbcTemplate.query(
            "SELECT id FROM client_bonus_monthly_credits WHERE user_id = ? AND `year_month` = ? LIMIT 1",
            (rs, i) -> rs.getLong(1),
            clientUserId,
            yearMonth
        );
        return !ids.isEmpty();
    }

    /**
     * Au moins une cotisation validée dans le mois (même partielle : 20/31 jours suffisent).
     */
    public int validatedContributionsInMonth(long clientUserId, String yearMonth) {
        Integer n = jdbcTemplate.queryForObject(
            """
            SELECT COUNT(*)
            FROM contributions
            WHERE user_id = ? AND status = 'validated'
              AND DATE_FORMAT(COALESCE(paid_at, created_at), '%Y-%m') = ?
            """,
            Integer.class,
            clientUserId,
            yearMonth
        );
        return n == null ? 0 : n;
    }

    public boolean isClientEligible(long clientUserId) {
        if (clientUserId <= 0) {
            return false;
        }
        List<Boolean> rows = jdbcTemplate.query(
            """
            SELECT u.adhesion_fee_paid
            FROM users u
            INNER JOIN roles r ON r.id = u.role_id AND r.code = 'client'
            WHERE u.id = ?
            LIMIT 1
            """,
            (rs, i) -> rs.getBoolean("adhesion_fee_paid"),
            clientUserId
        );
        if (rows.isEmpty() || !Boolean.TRUE.equals(rows.get(0))) {
            return false;
        }
        return resolveDailyContribution(clientUserId) > 0
            && productSelectionService.totalProjectAmount(clientUserId) > 0;
    }

    public boolean creditMonthIfEligible(long clientUserId, YearMonth month) {
        if (clientUserId <= 0 || month == null) {
            return false;
        }
        Boolean ok = transactionTemplate.execute(status -> doCreditMonthIfEligible(clientUserId, month));
        return Boolean.TRUE.equals(ok);
    }

    private boolean doCreditMonthIfEligible(long clientUserId, YearMonth month) {
        String ym = month.format(YM);
        if (isMonthAlreadyCredited(clientUserId, ym)) {
            return false;
        }
        if (!isClientEligible(clientUserId)) {
            return false;
        }
        int contribCount = validatedContributionsInMonth(clientUserId, ym);
        if (contribCount <= 0) {
            return false;
        }

        double daily = resolveDailyContribution(clientUserId);
        double clientShare = monthlyClientBonus(daily);
        double companyShare = clientShare;
        if (clientShare <= 0) {
            return false;
        }

        double balanceBefore = accruedBonusFromDb(clientUserId);

        try {
            jdbcTemplate.update(
                """
                INSERT INTO client_bonus_monthly_credits (
                    user_id, `year_month`, daily_contribution_fcfa,
                    client_share_fcfa, company_share_fcfa, validated_contributions_count
                ) VALUES (?, ?, ?, ?, ?, ?)
                """,
                clientUserId,
                ym,
                daily,
                clientShare,
                companyShare,
                contribCount
            );
        } catch (DuplicateKeyException ex) {
            return false;
        }

        jdbcTemplate.update(
            "UPDATE users SET bonus_savings_fcfa = COALESCE(bonus_savings_fcfa, 0) + ? WHERE id = ?",
            clientShare,
            clientUserId
        );

        double balanceAfter = accruedBonusFromDb(clientUserId);
        notifyBonusCredit(
            clientUserId,
            month,
            balanceBefore,
            balanceAfter,
            clientShare,
            companyShare,
            contribCount
        );
        return true;
    }

    private void notifyBonusCredit(
        long clientUserId,
        YearMonth month,
        double balanceBefore,
        double balanceAfter,
        double clientShare,
        double companyShare,
        int contribCount
    ) {
        long beforeFcfa = Math.round(balanceBefore);
        long creditFcfa = Math.round(clientShare);
        long afterFcfa = Math.round(balanceAfter);
        long companyFcfa = Math.round(companyShare);
        long expectedAfter = beforeFcfa + creditFcfa;
        boolean balanceOk = afterFcfa == expectedAfter;

        String monthLabel = formatMonthLabel(month);
        String clientName = inboxNotifications.clientDisplayName(clientUserId);

        if (!balanceOk) {
            log.warn(
                "Épargne bonus : solde incohérent client #{} {} — avant {} + {} ≠ après {} (attendu {}).",
                clientUserId,
                monthLabel,
                beforeFcfa,
                creditFcfa,
                afterFcfa,
                expectedAfter
            );
            auditService.logSystem(
                "ANOMALIE épargne bonus — "
                    + clientName
                    + " ("
                    + monthLabel
                    + ") : solde attendu "
                    + expectedAfter
                    + " FCFA, obtenu "
                    + afterFcfa
                    + " FCFA (avant "
                    + beforeFcfa
                    + ", crédit +"
                    + creditFcfa
                    + ")."
            );
        }

        String clientBody =
            "Crédit automatique pour "
                + monthLabel
                + " : +"
                + creditFcfa
                + " FCFA ajoutés à votre épargne bonus (50 % d'un jour de cotisation). "
                + "Solde avant : "
                + beforeFcfa
                + " FCFA → après : "
                + afterFcfa
                + " FCFA"
                + (balanceOk ? "." : " — le centre vérifie votre compte.")
                + " ("
                + contribCount
                + " cotisation(s) validée(s) ce mois).";

        inboxNotifications.notifyClientAndAssignedAgent(
            clientUserId,
            NOTIF_TYPE_BONUS_CREDIT,
            "Épargne bonus créditée",
            clientBody,
            "Épargne bonus — {client}",
            "Crédit auto "
                + monthLabel
                + " pour {client} : +"
                + creditFcfa
                + " FCFA (solde "
                + beforeFcfa
                + " → "
                + afterFcfa
                + " FCFA).",
            null
        );

        auditService.logClient(
            clientUserId,
            "Épargne bonus créditée ("
                + monthLabel
                + ") : +"
                + creditFcfa
                + " FCFA — solde "
                + beforeFcfa
                + " → "
                + afterFcfa
                + " FCFA."
        );
        auditService.logSystem(
            "Épargne bonus auto — "
                + clientName
                + " ("
                + monthLabel
                + ") : +"
                + creditFcfa
                + " FCFA client, part PayFlex "
                + companyFcfa
                + " FCFA — solde vérifié "
                + beforeFcfa
                + " → "
                + afterFcfa
                + " FCFA."
        );
    }

    private static String formatMonthLabel(YearMonth month) {
        if (month == null) {
            return "";
        }
        String name = month.getMonth().getDisplayName(TextStyle.FULL_STANDALONE, Locale.FRENCH);
        if (name != null && !name.isEmpty()) {
            return Character.toUpperCase(name.charAt(0)) + name.substring(1) + " " + month.getYear();
        }
        return month.format(YM);
    }

    public int creditMonthForAllEligibleClients(YearMonth month) {
        if (month == null) {
            return 0;
        }
        String ym = month.format(YM);
        List<Long> clientIds = jdbcTemplate.query(
            """
            SELECT DISTINCT c.user_id
            FROM contributions c
            INNER JOIN users u ON u.id = c.user_id
            INNER JOIN roles r ON r.id = u.role_id AND r.code = 'client'
            WHERE c.status = 'validated'
              AND DATE_FORMAT(COALESCE(c.paid_at, c.created_at), '%Y-%m') = ?
            """,
            (rs, i) -> rs.getLong(1),
            ym
        );
        int credited = 0;
        for (Long clientId : clientIds) {
            if (creditMonthIfEligible(clientId, month)) {
                credited++;
            }
        }
        return credited;
    }

    /**
     * Rétroactive : chaque couple (client, mois) avec cotisations validées et sans crédit existant.
     */
    public int backfillMissingMonthlyCredits() {
        List<Map<String, Object>> pairs = jdbcTemplate.queryForList(
            """
            SELECT DISTINCT c.user_id AS user_id,
                   DATE_FORMAT(COALESCE(c.paid_at, c.created_at), '%Y-%m') AS ym
            FROM contributions c
            INNER JOIN users u ON u.id = c.user_id
            INNER JOIN roles r ON r.id = u.role_id AND r.code = 'client'
            WHERE c.status = 'validated'
            ORDER BY ym ASC
            """
        );
        YearMonth current = YearMonth.now();
        int credited = 0;
        for (Map<String, Object> row : pairs) {
            long userId = toLong(row.get("user_id"));
            String ym = row.get("ym") == null ? null : row.get("ym").toString();
            if (userId <= 0 || ym == null || ym.isBlank()) {
                continue;
            }
            YearMonth month = YearMonth.parse(ym, YM);
            if (!month.isBefore(current)) {
                continue;
            }
            if (creditMonthIfEligible(userId, month)) {
                credited++;
            }
        }
        return credited;
    }

    public void reconcileUserBalances() {
        jdbcTemplate.update(
            """
            UPDATE users u
            SET bonus_savings_fcfa = COALESCE((
                SELECT SUM(c.client_share_fcfa)
                FROM client_bonus_monthly_credits c
                WHERE c.user_id = u.id
            ), 0)
            WHERE u.id IN (SELECT DISTINCT user_id FROM client_bonus_monthly_credits)
            """
        );
    }

    public List<Map<String, Object>> bonusLinesForClient(long clientUserId) {
        List<Map<String, Object>> products = productSelectionService.listForClient(clientUserId);
        List<Map<String, Object>> lines = new ArrayList<>();
        for (Map<String, Object> p : products) {
            double dailyMin = toDouble(p.get("daily_min"));
            int qty = (int) toLong(p.get("quantity"));
            if (qty <= 0) {
                qty = 1;
            }
            Map<String, Object> line = new LinkedHashMap<>();
            line.put("productId", p.get("product_id"));
            line.put("productName", p.get("name"));
            line.put("quantity", qty);
            line.put("unitDailyMinFcfa", Math.round(dailyMin));
            line.put("monthlyBonusFcfa", Math.round(monthlyLineBonus(dailyMin, qty)));
            lines.add(line);
        }
        return lines;
    }

    public Map<String, Object> summary(long clientUserId, double dailyContribution) {
        Map<String, Object> out = new LinkedHashMap<>();
        LocalDate today = LocalDate.now();
        int officialDays = officialDaysInMonth(today.getYear(), today.getMonthValue());
        double daily = dailyContribution > 0 ? dailyContribution : resolveDailyContribution(clientUserId);
        double monthly = monthlyClientBonus(daily);
        double accrued = accruedBonusFromDb(clientUserId);
        int months = creditedMonthsCount(clientUserId);
        String currentYm = YearMonth.now().format(YM);
        String lastYm = jdbcTemplate.query(
            """
            SELECT `year_month` FROM client_bonus_monthly_credits
            WHERE user_id = ?
            ORDER BY `year_month` DESC
            LIMIT 1
            """,
            (rs, i) -> rs.getString(1),
            clientUserId
        ).stream().findFirst().orElse(null);

        out.put("bonusSavingsFcfa", Math.round(accrued));
        out.put("bonusSavingsMonthlyFcfa", Math.round(monthly));
        out.put("companyShareMonthlyFcfa", Math.round(monthly));
        out.put("activeMonthsCount", months);
        out.put("officialDaysThisMonth", officialDays);
        out.put("calendarDaysThisMonth", today.lengthOfMonth());
        out.put("dailyContributionFcfa", Math.round(daily));
        out.put("bonusLines", bonusLinesForClient(clientUserId));
        out.put("lastCreditedYearMonth", lastYm);
        out.put("currentMonthCredited", isMonthAlreadyCredited(clientUserId, currentYm));
        out.put("ruleHeadline", "1 jour / mois partagé — 50 % pour vous");
        out.put(
            "ruleLabel",
            "Le plan officiel compte " + officialDays
                + " jours par mois. Même si vous cotisez moins (ex. 20 jours sur 31), "
                + "1 jour entier de cotisation est partagé chaque mois : la moitié est épargnée pour vous, "
                + "l'autre moitié est la part PayFlex."
        );
        out.put("creditedInDatabase", true);
        return out;
    }

    private static double toDouble(Object v) {
        if (v == null) {
            return 0;
        }
        try {
            return Double.parseDouble(v.toString());
        } catch (NumberFormatException ex) {
            return 0;
        }
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
}
