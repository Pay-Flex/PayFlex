package com.payflex.backend.config;

import com.payflex.backend.service.AdminAuditService;
import com.payflex.backend.service.ClientBonusSavingsService;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.stereotype.Component;

/**
 * Au démarrage : crédite rétroactivement les mois passés non encore enregistrés.
 */
@Component
public class ClientBonusSavingsBackfillRunner implements ApplicationRunner {

    private static final Logger log = LoggerFactory.getLogger(ClientBonusSavingsBackfillRunner.class);

    private final ClientBonusSavingsService clientBonusSavingsService;
    private final AdminAuditService auditService;

    public ClientBonusSavingsBackfillRunner(
        ClientBonusSavingsService clientBonusSavingsService,
        AdminAuditService auditService
    ) {
        this.clientBonusSavingsService = clientBonusSavingsService;
        this.auditService = auditService;
    }

    @Override
    public void run(ApplicationArguments args) {
        try {
            int n = clientBonusSavingsService.backfillMissingMonthlyCredits();
            if (n > 0) {
                log.info("Backfill épargne bonus : {} crédit(s) mensuel(s) ajouté(s).", n);
                auditService.logSystem(
                    "Épargne bonus — rattrapage automatique au démarrage : "
                        + n
                        + " crédit(s) mensuel(s) appliqué(s). Clients et agents notifiés (solde avant/après)."
                );
            }
            clientBonusSavingsService.reconcileUserBalances();
        } catch (Exception ex) {
            log.warn("Backfill épargne bonus ignoré : {}", ex.getMessage());
        }
    }
}
