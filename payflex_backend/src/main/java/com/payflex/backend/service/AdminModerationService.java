package com.payflex.backend.service;

import org.springframework.security.access.AccessDeniedException;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.GrantedAuthority;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.stereotype.Service;

import java.security.Principal;
import java.util.Optional;

/**
 * Droits différenciés admin principal vs gestionnaire : journal détaillé, suppressions sur validation admin.
 */
@Service
public class AdminModerationService {

    private static final String ROLE_ADMIN = "ROLE_ADMIN";
    private static final String ROLE_GESTIONNAIRE = "ROLE_GESTIONNAIRE";

    private final AdminAuditService auditService;
    private final AdminDeletionRequestService deletionRequestService;

    public AdminModerationService(AdminAuditService auditService, AdminDeletionRequestService deletionRequestService) {
        this.auditService = auditService;
        this.deletionRequestService = deletionRequestService;
    }

    public boolean isAdmin() {
        return hasAuthority(ROLE_ADMIN);
    }

    public boolean isGestionnaire() {
        return hasAuthority(ROLE_GESTIONNAIRE) && !isAdmin();
    }

    public boolean requiresDeletionApproval() {
        return isGestionnaire();
    }

    public Optional<String> validateChangeReason(String changeReason) {
        if (!isGestionnaire()) {
            return Optional.empty();
        }
        if (changeReason == null || changeReason.trim().length() < 5) {
            return Optional.of("En tant que gestionnaire, indiquez un motif de modification (au moins 5 caractères).");
        }
        return Optional.empty();
    }

    public Optional<String> validateDeletionReason(String reason) {
        if (!isGestionnaire()) {
            return Optional.empty();
        }
        if (reason == null || reason.trim().length() < 5) {
            return Optional.of("Indiquez le motif de la suppression demandée (au moins 5 caractères).");
        }
        return Optional.empty();
    }

    public void logAction(
        Principal principal,
        String actionKind,
        String entityType,
        Long entityId,
        String message,
        String changeReason
    ) {
        String login = principal != null ? principal.getName() : "inconnu";
        if (isGestionnaire()) {
            auditService.logGestionnaire(login, actionKind, entityType, entityId, message, changeReason);
        } else {
            String full = message;
            if (changeReason != null && !changeReason.isBlank()) {
                full = full + " Motif : " + changeReason.trim();
            }
            auditService.logEquipe(login, full);
        }
    }

    /**
     * Admin : suppression immédiate. Gestionnaire : demande en attente de validation admin.
     */
    public DeletionOutcome handleDeletion(
        String entityType,
        long entityId,
        String entityLabel,
        String reason,
        Principal principal,
        Runnable executeImmediateDelete
    ) {
        if (isAdmin()) {
            executeImmediateDelete.run();
            logAction(
                principal,
                AdminAuditService.ACTION_DELETE,
                entityType,
                entityId,
                "Suppression définitive : " + entityLabel + ".",
                reason
            );
            return DeletionOutcome.immediate();
        }
        if (isGestionnaire()) {
            Optional<String> err = validateDeletionReason(reason);
            if (err.isPresent()) {
                return DeletionOutcome.error(err.get());
            }
            deletionRequestService.submit(entityType, entityId, entityLabel, reason, principal.getName());
            logAction(
                principal,
                AdminAuditService.ACTION_DELETE_REQUEST,
                entityType,
                entityId,
                "Demande de suppression (en attente validation admin) : " + entityLabel + ".",
                reason
            );
            return DeletionOutcome.pendingApproval();
        }
        throw new AccessDeniedException("Action non autorisée");
    }

    public void denyIfGestionnaire(String action) {
        if (isGestionnaire()) {
            throw new AccessDeniedException("Action réservée à l'administrateur principal : " + action);
        }
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

    public record DeletionOutcome(boolean immediateDelete, boolean deletionRequested, String errorMessage) {
        static DeletionOutcome immediate() {
            return new DeletionOutcome(true, false, null);
        }

        static DeletionOutcome pendingApproval() {
            return new DeletionOutcome(false, true, null);
        }

        static DeletionOutcome error(String msg) {
            return new DeletionOutcome(false, false, msg);
        }
    }
}
