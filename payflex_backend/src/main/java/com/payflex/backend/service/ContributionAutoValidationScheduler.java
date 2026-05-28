package com.payflex.backend.service;

import com.payflex.backend.config.PayflexProperties;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

@Component
public class ContributionAutoValidationScheduler {

    private static final Logger log = LoggerFactory.getLogger(ContributionAutoValidationScheduler.class);

    private final ContributionWorkflowService contributionWorkflowService;
    private final PayflexProperties payflexProperties;

    public ContributionAutoValidationScheduler(
        ContributionWorkflowService contributionWorkflowService,
        PayflexProperties payflexProperties
    ) {
        this.contributionWorkflowService = contributionWorkflowService;
        this.payflexProperties = payflexProperties;
    }

    /** Toutes les heures : mobile money en attente depuis X h sans action agent. */
    @Scheduled(cron = "0 15 * * * *")
    public void autoValidateStaleMobileMoney() {
        int hours = payflexProperties.getContributions().getAutoValidateMobileMoneyHours();
        if (hours <= 0) {
            return;
        }
        try {
            int n = contributionWorkflowService.autoValidateStaleMobileDeclarations(hours);
            if (n > 0) {
                log.info("Validation automatique : {} cotisation(s) mobile money après {} h.", n, hours);
            }
        } catch (Exception ex) {
            log.warn("Échec validation automatique cotisations : {}", ex.getMessage());
        }
    }
}
