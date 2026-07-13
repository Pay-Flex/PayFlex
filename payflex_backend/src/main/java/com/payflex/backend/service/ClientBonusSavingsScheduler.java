package com.payflex.backend.service;

import java.time.YearMonth;
import java.time.format.TextStyle;
import java.util.Locale;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

/**
 * Crédite l'épargne bonus le 1er de chaque mois pour le mois civil précédent.
 */
@Component
public class ClientBonusSavingsScheduler {

    private static final Logger log = LoggerFactory.getLogger(ClientBonusSavingsScheduler.class);

    private final ClientBonusSavingsService clientBonusSavingsService;
    private final AdminAuditService auditService;

    public ClientBonusSavingsScheduler(
        ClientBonusSavingsService clientBonusSavingsService,
        AdminAuditService auditService
    ) {
        this.clientBonusSavingsService = clientBonusSavingsService;
        this.auditService = auditService;
    }

    /** Le 1er de chaque mois à 05:05 — partage du « jour hors plan » du mois précédent. */
    @Scheduled(cron = "0 5 1 * * *")
    public void creditPreviousMonth() {
        YearMonth previous = YearMonth.now().minusMonths(1);
        try {
            int n = clientBonusSavingsService.creditMonthForAllEligibleClients(previous);
            if (n > 0) {
                String monthLabel = formatMonthLabel(previous);
                log.info("Épargne bonus : {} crédit(s) client pour {}.", n, previous);
                auditService.logSystem(
                    "Épargne bonus — "
                        + monthLabel
                        + " : "
                        + n
                        + " client(s) crédité(s) automatiquement. Chaque client et l'équipe ont été notifiés (solde avant/après)."
                );
            }
        } catch (Exception ex) {
            log.warn("Échec crédit épargne bonus {} : {}", previous, ex.getMessage());
        }
    }

    private static String formatMonthLabel(YearMonth month) {
        String name = month.getMonth().getDisplayName(TextStyle.FULL_STANDALONE, Locale.FRENCH);
        if (name != null && !name.isEmpty()) {
            return Character.toUpperCase(name.charAt(0)) + name.substring(1) + " " + month.getYear();
        }
        return month.toString();
    }
}
