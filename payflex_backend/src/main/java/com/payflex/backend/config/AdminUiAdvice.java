package com.payflex.backend.config;

import com.payflex.backend.service.AdminNavService;
import com.payflex.backend.service.ContributionValidationAlertService;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.GrantedAuthority;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.web.bind.annotation.ControllerAdvice;
import org.springframework.web.bind.annotation.ModelAttribute;

/**
 * Attributs UI admin : distinguer administrateur principal vs gestionnaire.
 */
@ControllerAdvice(basePackages = "com.payflex.backend.controller")
public class AdminUiAdvice {

    private static final String ROLE_ADMIN = "ROLE_ADMIN";

    private final AdminNavService adminNavService;
    private final ContributionValidationAlertService contributionValidationAlertService;

    public AdminUiAdvice(
        AdminNavService adminNavService,
        ContributionValidationAlertService contributionValidationAlertService
    ) {
        this.adminNavService = adminNavService;
        this.contributionValidationAlertService = contributionValidationAlertService;
    }

    @ModelAttribute("navPendingRegistrations")
    public long navPendingRegistrations() {
        return adminNavService.pendingRegistrations();
    }

    @ModelAttribute("navPendingContributions")
    public long navPendingContributions() {
        return adminNavService.pendingContributions();
    }

    @ModelAttribute("navPendingCashContributions")
    public long navPendingCashContributions() {
        return adminNavService.pendingCashContributions();
    }

    @ModelAttribute("navSupportThreads")
    public long navSupportThreads() {
        return adminNavService.supportThreadsWithClientMessages();
    }

    @ModelAttribute("adminFullAccess")
    public boolean adminFullAccess() {
        return hasAuthority(ROLE_ADMIN);
    }

    @ModelAttribute("adminIsGestionnaire")
    public boolean adminIsGestionnaire() {
        return hasAuthority("ROLE_GESTIONNAIRE") && !hasAuthority(ROLE_ADMIN);
    }

    @ModelAttribute("adminRequiresChangeReason")
    public boolean adminRequiresChangeReason() {
        return hasAuthority("ROLE_GESTIONNAIRE") && !hasAuthority(ROLE_ADMIN);
    }

    @ModelAttribute("navPendingDeletionRequests")
    public long navPendingDeletionRequests() {
        if (!hasAuthority(ROLE_ADMIN)) {
            return 0L;
        }
        return adminNavService.pendingDeletionRequests();
    }

    @ModelAttribute("navAdhesionUrgencies")
    public long navAdhesionUrgencies() {
        return adminNavService.adhesionUrgencies();
    }

    @ModelAttribute("navContributionAlerts")
    public long navContributionAlerts() {
        return contributionValidationAlertService.countUnread();
    }

    @ModelAttribute("adminPrincipalName")
    public String adminPrincipalName() {
        Authentication auth = SecurityContextHolder.getContext().getAuthentication();
        return auth != null && auth.isAuthenticated() ? auth.getName() : "";
    }

    /**
     * Libellé lisible pour le badge en-tête (non technique).
     */
    @ModelAttribute("adminRoleLabel")
    public String adminRoleLabel() {
        return hasAuthority(ROLE_ADMIN) ? "Administrateur" : "Gestionnaire";
    }

    private static boolean hasAuthority(String authority) {
        Authentication auth = SecurityContextHolder.getContext().getAuthentication();
        if (auth == null || !auth.isAuthenticated()) {
            return false;
        }
        for (GrantedAuthority ga : auth.getAuthorities()) {
            if (authority.equals(ga.getAuthority())) {
                return true;
            }
        }
        return false;
    }
}
