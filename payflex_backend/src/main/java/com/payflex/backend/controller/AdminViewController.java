package com.payflex.backend.controller;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.payflex.backend.service.AdminDashboardService;
import com.payflex.backend.service.AdminRevenueService;
import com.payflex.backend.service.AdminCrudService;
import com.payflex.backend.service.AdminGestionnaireService;
import com.payflex.backend.service.AdminAuditService;
import com.payflex.backend.service.AdminDeletionRequestService;
import com.payflex.backend.service.AdminModerationService;
import com.payflex.backend.service.ClientAdhesionService;
import com.payflex.backend.config.PayflexProperties;
import com.payflex.backend.service.ContributionValidationAlertService;
import com.payflex.backend.service.ContributionWorkflowService;
import com.payflex.backend.service.ProductCategoryService;
import com.payflex.backend.service.RegistrationService;
import com.payflex.backend.service.RoleManagementService;
import com.payflex.backend.service.SupportChatService;
import com.payflex.backend.service.UserInboxNotificationService;
import com.payflex.backend.service.ProductDeliveryService;
import com.payflex.backend.service.AdminClientCredentialService;
import com.payflex.backend.service.JobOfferService;
import com.payflex.backend.service.LegalDocumentService;
import com.payflex.backend.service.SurplusRegularizationService;
import org.springframework.core.io.FileSystemResource;
import org.springframework.core.io.Resource;
import org.springframework.dao.DataAccessException;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseBody;
import org.springframework.web.multipart.MultipartFile;
import org.springframework.web.servlet.mvc.support.RedirectAttributes;

import java.io.IOException;
import java.net.URLEncoder;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.security.Principal;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;

/**
 * {@code ROLE_ADMIN} : accès complet, suppressions définitives, validation des demandes gestionnaire.
 * {@code ROLE_GESTIONNAIRE} : gestion quotidienne limitée ; suppressions = demandes ; modifications journalisées avec motif.
 */
@Controller
public class AdminViewController {

    private final AdminDashboardService dashboardService;
    private final AdminCrudService adminCrudService;
    private final AdminAuditService adminAuditService;
    private final ProductCategoryService productCategoryService;
    private final ContributionWorkflowService contributionWorkflowService;
    private final RegistrationService registrationService;
    private final RoleManagementService roleManagementService;
    private final SupportChatService supportChatService;
    private final ObjectMapper objectMapper;
    private final AdminModerationService moderationService;
    private final AdminDeletionRequestService deletionRequestService;
    private final AdminGestionnaireService gestionnaireService;
    private final ClientAdhesionService clientAdhesionService;
    private final ContributionValidationAlertService contributionValidationAlertService;
    private final PayflexProperties payflexProperties;
    private final UserInboxNotificationService inboxNotifications;
    private final ProductDeliveryService productDeliveryService;
    private final AdminClientCredentialService adminClientCredentialService;
    private final LegalDocumentService legalDocumentService;
    private final JobOfferService jobOfferService;
    private final AdminRevenueService adminRevenueService;
    private final SurplusRegularizationService surplusRegularizationService;

    public AdminViewController(
        AdminDashboardService dashboardService,
        AdminCrudService adminCrudService,
        AdminAuditService adminAuditService,
        ProductCategoryService productCategoryService,
        ContributionWorkflowService contributionWorkflowService,
        RegistrationService registrationService,
        RoleManagementService roleManagementService,
        SupportChatService supportChatService,
        ObjectMapper objectMapper,
        AdminModerationService moderationService,
        AdminDeletionRequestService deletionRequestService,
        AdminGestionnaireService gestionnaireService,
        ClientAdhesionService clientAdhesionService,
        ContributionValidationAlertService contributionValidationAlertService,
        PayflexProperties payflexProperties,
        UserInboxNotificationService inboxNotifications,
        ProductDeliveryService productDeliveryService,
        AdminClientCredentialService adminClientCredentialService,
        LegalDocumentService legalDocumentService,
        JobOfferService jobOfferService,
        AdminRevenueService adminRevenueService,
        SurplusRegularizationService surplusRegularizationService
    ) {
        this.dashboardService = dashboardService;
        this.adminCrudService = adminCrudService;
        this.adminAuditService = adminAuditService;
        this.productCategoryService = productCategoryService;
        this.contributionWorkflowService = contributionWorkflowService;
        this.registrationService = registrationService;
        this.roleManagementService = roleManagementService;
        this.supportChatService = supportChatService;
        this.objectMapper = objectMapper;
        this.moderationService = moderationService;
        this.deletionRequestService = deletionRequestService;
        this.gestionnaireService = gestionnaireService;
        this.clientAdhesionService = clientAdhesionService;
        this.contributionValidationAlertService = contributionValidationAlertService;
        this.payflexProperties = payflexProperties;
        this.inboxNotifications = inboxNotifications;
        this.productDeliveryService = productDeliveryService;
        this.adminClientCredentialService = adminClientCredentialService;
        this.legalDocumentService = legalDocumentService;
        this.jobOfferService = jobOfferService;
        this.adminRevenueService = adminRevenueService;
        this.surplusRegularizationService = surplusRegularizationService;
    }

    @GetMapping({"/", "/admin"})
    public String admin(Model model) {
        model.addAttribute("activePage", "dashboard");
        model.addAttribute("dashboard", dashboardService.buildDashboard());
        model.addAttribute("topProducts", dashboardService.topProducts());
        model.addAttribute("topClients", dashboardService.topClients());
        model.addAttribute("monthlyCollections", dashboardService.monthlyCollections());
        model.addAttribute("latestAudit", adminAuditService.latest(8));
        model.addAttribute("catchupAlerts", dashboardService.clientsWithHighCatchup(5));
        model.addAttribute("revenue", adminRevenueService.buildSummary());
        return "dashboard";
    }

    @GetMapping("/admin/users")
    public String users(
        Model model,
        @RequestParam(defaultValue = "0") int page,
        @RequestParam(defaultValue = "80") int size,
        @RequestParam(required = false) String q,
        @RequestParam(required = false) String role,
        @RequestParam(required = false) String status
    ) {
        model.addAttribute("activePage", "users");
        model.addAttribute("usersPage", adminCrudService.getUsersPage(q, role, status, page, size));
        model.addAttribute("roles", roleManagementService.listRoles());
        model.addAttribute("agentOptions", registrationService.agentOptions());
        model.addAttribute("zoneChoices", adminCrudService.listActiveZoneChoices());
        model.addAttribute("q", q);
        model.addAttribute("role", role);
        model.addAttribute("status", status);
        putFilterQuery(model, "q", q, "role", role, "status", status);
        return "users";
    }

    @GetMapping("/admin/users/{userId}")
    public String userDetail(@PathVariable long userId, Model model) {
        return adminCrudService.findUserById(userId)
            .map(u -> {
                model.addAttribute("activePage", "users");
                model.addAttribute("u", u);
                return "user-detail";
            })
            .orElse("redirect:/admin/users");
    }

    @PreAuthorize("hasRole('ADMIN')")
    @GetMapping("/admin/roles-permissions")
    public String rolePermissions(
        Model model,
        @RequestParam(required = false) Long edit
    ) {
        model.addAttribute("activePage", "roles-permissions");
        var rolesList = roleManagementService.listRoles();
        model.addAttribute("roles", rolesList);
        model.addAttribute("roleUserCounts", roleManagementService.userCountsForRoles(rolesList));
        model.addAttribute("permissions", roleManagementService.listPermissions());
        model.addAttribute("permissionMatrix", roleManagementService.permissionMatrix());
        if (edit != null && edit > 0) {
            model.addAttribute("editRole", roleManagementService.findRoleById(edit).orElse(null));
        }
        return "role-permissions";
    }

    @PreAuthorize("hasRole('ADMIN')")
    @PostMapping("/admin/roles")
    public String createRole(
        @RequestParam(required = false) String code,
        @RequestParam String label,
        @RequestParam(required = false) String description,
        Principal principal
    ) {
        try {
            roleManagementService.createRole(code, label, description);
            adminAuditService.logEquipe(
                principal.getName(),
                "Cr\u00e9ation d'un groupe (profil m\u00e9tier) : \u00ab " + label.trim() + " \u00bb."
            );
            return "redirect:/admin/roles-permissions?success=role_created";
        } catch (IllegalArgumentException ex) {
            return "redirect:/admin/roles-permissions?roleError=" + ex.getMessage();
        }
    }

    @PreAuthorize("hasRole('ADMIN')")
    @PostMapping("/admin/roles/update")
    public String updateRole(
        @RequestParam long id,
        @RequestParam String label,
        @RequestParam(required = false) String description,
        Principal principal
    ) {
        try {
            roleManagementService.updateRole(id, label, description);
            adminAuditService.logEquipe(
                principal.getName(),
                "Modification du groupe (profil m\u00e9tier) \u00ab " + label.trim() + " \u00bb."
            );
            return "redirect:/admin/roles-permissions?success=role_updated";
        } catch (IllegalArgumentException ex) {
            return "redirect:/admin/roles-permissions?roleError=" + ex.getMessage() + "&edit=" + id;
        }
    }

    @PreAuthorize("hasRole('ADMIN')")
    @PostMapping("/admin/roles/delete")
    public String deleteRole(@RequestParam long id, Principal principal) {
        try {
            var role = roleManagementService.findRoleById(id).orElse(null);
            roleManagementService.deleteRole(id);
            if (role != null) {
                adminAuditService.logEquipe(
                    principal.getName(),
                    "Suppression du groupe (profil m\u00e9tier) \u00ab " + role.label() + " \u00bb."
                );
            }
            return "redirect:/admin/roles-permissions?success=role_deleted";
        } catch (IllegalArgumentException ex) {
            return "redirect:/admin/roles-permissions?roleError=" + ex.getMessage();
        }
    }

    @PreAuthorize("hasRole('ADMIN')")
    @PostMapping("/admin/roles-permissions/toggle")
    public String toggleRolePermission(
        @RequestParam long roleId,
        @RequestParam long permissionId,
        @RequestParam boolean grant,
        Principal principal
    ) {
        roleManagementService.setPermissionGranted(roleId, permissionId, grant);
        adminAuditService.logEquipe(
            principal.getName(),
            grant
                ? "Autorisation ajoutée pour un groupe d'utilisateurs (profil métier)."
                : "Autorisation retirée pour un groupe d'utilisateurs (profil métier)."
        );
        return "redirect:/admin/roles-permissions?success=1";
    }

    @PostMapping(value = "/admin/users", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    public String createUser(
        RedirectAttributes redirectAttributes,
        Principal principal,
        @RequestParam String profileKey,
        @RequestParam String fullName,
        @RequestParam(required = false) String phone,
        @RequestParam(required = false) String email,
        @RequestParam(required = false) String city,
        @RequestParam(required = false) String profession,
        @RequestParam(required = false) String gender,
        @RequestParam(defaultValue = "pending") String status,
        @RequestParam(required = false) String username,
        @RequestParam(required = false) String password,
        @RequestParam(required = false) String passwordConfirm,
        @RequestParam(required = false) String mobilePin,
        @RequestParam(required = false) String mobilePinConfirm,
        @RequestParam(required = false) String accountPassword,
        @RequestParam(required = false) String accountPasswordConfirm,
        @RequestParam(required = false) Long assignedAgentUserId,
        @RequestParam(required = false) String workplaceName,
        @RequestParam(required = false) String workplaceAddress,
        @RequestParam(required = false) String bossName,
        @RequestParam(required = false) String bossPhone,
        @RequestParam(required = false) Long zoneId,
        @RequestParam(required = false) String personalAddress,
        @RequestParam(required = false) String hireDate,
        @RequestParam(required = false) String contractType,
        @RequestParam(required = false) String matricule,
        @RequestParam(required = false) String contractSignedDate,
        @RequestParam(required = false) String jobTitle,
        @RequestParam(required = false) String emergencyContactName,
        @RequestParam(required = false) String emergencyContactPhone,
        @RequestParam(required = false) String emergencyContactRelation,
        @RequestParam(required = false) String notifyContactName,
        @RequestParam(required = false) String notifyContactPhone,
        @RequestParam(required = false) String notifyContactRelation,
        @RequestParam(required = false) String guarantorName,
        @RequestParam(required = false) String guarantorPhone,
        @RequestParam(required = false) String guarantorRelation,
        @RequestParam(required = false) String secondaryContactName,
        @RequestParam(required = false) String secondaryContactPhone,
        @RequestParam(required = false) String supervisorName,
        @RequestParam(required = false) String supervisorPhone,
        @RequestParam(required = false) String referencesNotes,
        @RequestParam(required = false) String internalNotes,
        @RequestParam(required = false) MultipartFile idDocument,
        @RequestParam(required = false) MultipartFile contractDocument,
        @RequestParam(required = false) MultipartFile photo
    ) {
        try {
            if (profileKey == null || profileKey.isBlank()) {
                throw new IllegalArgumentException("Choisissez un profil ou un rôle.");
            }
            if (profileKey.startsWith("team:")) {
                if (password == null || !password.equals(passwordConfirm)) {
                    throw new IllegalArgumentException("Les mots de passe ne correspondent pas.");
                }
                String teamKind = profileKey.substring("team:".length());
                if ("admin".equals(teamKind)) {
                    if (!moderationService.isAdmin()) {
                        throw new IllegalArgumentException("Seul un administrateur peut créer un compte administrateur.");
                    }
                    gestionnaireService.createAdministrateur(
                        username, password, fullName, email, phone, gender, city, personalAddress,
                        matricule, hireDate, contractType, contractSignedDate, jobTitle,
                        emergencyContactName, emergencyContactPhone, emergencyContactRelation,
                        notifyContactName, notifyContactPhone, notifyContactRelation,
                        guarantorName, guarantorPhone, guarantorRelation,
                        secondaryContactName, secondaryContactPhone,
                        supervisorName, supervisorPhone,
                        referencesNotes, internalNotes,
                        idDocument, contractDocument, photo
                    );
                    adminAuditService.logEquipe(
                        principal.getName(),
                        "Création du compte administrateur « " + username.trim().toLowerCase() + " »."
                    );
                    return "redirect:/admin/gestionnaires/" + username.trim().toLowerCase() + "?created=1";
                }
                if ("gestionnaire".equals(teamKind)) {
                    if (!moderationService.isAdmin()) {
                        throw new IllegalArgumentException("Seul un administrateur peut créer un compte gestionnaire.");
                    }
                    gestionnaireService.createGestionnaire(
                        username, password, fullName, email, phone, gender, city, personalAddress,
                        matricule, hireDate, contractType, contractSignedDate,
                        jobTitle == null || jobTitle.isBlank() ? "Gestionnaire PayFlex" : jobTitle,
                        emergencyContactName, emergencyContactPhone, emergencyContactRelation,
                        notifyContactName, notifyContactPhone, notifyContactRelation,
                        guarantorName, guarantorPhone, guarantorRelation,
                        secondaryContactName, secondaryContactPhone,
                        supervisorName, supervisorPhone,
                        referencesNotes, internalNotes,
                        idDocument, contractDocument, photo
                    );
                    adminAuditService.logEquipe(
                        principal.getName(),
                        "Création du compte gestionnaire « " + username.trim().toLowerCase() + " »."
                    );
                    return "redirect:/admin/gestionnaires/" + username.trim().toLowerCase() + "?created=1";
                }
                throw new IllegalArgumentException("Profil équipe inconnu.");
            }
            if (!profileKey.startsWith("role:")) {
                throw new IllegalArgumentException("Profil invalide.");
            }
            long roleId = Long.parseLong(profileKey.substring("role:".length()));
            String roleCode = roleManagementService.findRoleById(roleId)
                .map(r -> r.code())
                .orElseThrow(() -> new IllegalArgumentException("Rôle introuvable."));
            if ("client".equals(roleCode)) {
                if (mobilePin == null || !mobilePin.equals(mobilePinConfirm)) {
                    throw new IllegalArgumentException("Les codes PIN ne correspondent pas.");
                }
                validateAccountPasswordPair(accountPassword, accountPasswordConfirm);
                long clientId = adminCrudService.createClientUser(
                    fullName, phone, email, roleId, city, profession, gender, status,
                    mobilePin, accountPassword, assignedAgentUserId,
                    workplaceName, workplaceAddress, bossName, bossPhone
                );
                adminAuditService.logEquipe(
                    principal.getName(),
                    "Création du client « " + fullName + " » (n° " + clientId + ")."
                );
                return "redirect:/admin/clients/" + clientId + "?created=1";
            }
            if ("agent".equals(roleCode)) {
                if (mobilePin == null || !mobilePin.equals(mobilePinConfirm)) {
                    throw new IllegalArgumentException("Les codes PIN ne correspondent pas.");
                }
                validateAccountPasswordPair(accountPassword, accountPasswordConfirm);
                String prof = profession == null || profession.isBlank() ? "Agent de collecte PayFlex" : profession.trim();
                long agentId = adminCrudService.hireAgentDossier(
                    fullName, phone, mobilePin, accountPassword, city, prof,
                    zoneId == null ? 0L : zoneId,
                    gender, email, personalAddress, hireDate, contractType, matricule,
                    emergencyContactName, emergencyContactPhone, emergencyContactRelation,
                    supervisorName, supervisorPhone,
                    secondaryContactName, secondaryContactPhone,
                    referencesNotes, internalNotes,
                    idDocument, contractDocument, photo
                );
                adminAuditService.logEquipe(
                    principal.getName(),
                    "Embauche agent « " + fullName + " » (fiche n° " + agentId + ")."
                );
                return "redirect:/admin/agents/" + agentId + "?created=1";
            }
            adminCrudService.createUser(fullName, phone, email, roleId, city, profession, status);
            adminAuditService.logEquipe(
                principal.getName(),
                "Création d'une fiche pour « " + fullName + " », compte " + AdminAuditService.statutCompte(status) + "."
            );
            return "redirect:/admin/users?success=1";
        } catch (IllegalArgumentException ex) {
            redirectAttributes.addFlashAttribute("errorMessage", ex.getMessage());
            return "redirect:/admin/users";
        } catch (Exception ex) {
            redirectAttributes.addFlashAttribute("errorMessage", "Enregistrement impossible : " + ex.getMessage());
            return "redirect:/admin/users";
        }
    }

    @PostMapping("/admin/users/status")
    public String updateUserStatus(
        @RequestParam long id,
        @RequestParam String status,
        @RequestParam(required = false) String changeReason,
        Principal principal
    ) {
        Optional<String> reasonErr = moderationService.validateChangeReason(changeReason);
        if (reasonErr.isPresent()) {
            return redirectError("/admin/users", reasonErr.get());
        }
        adminCrudService.updateUserStatus(id, status);
        if (inboxNotifications.isClientUser(id)) {
            inboxNotifications.notifyAccountStatusChange(id, status);
        }
        moderationService.logAction(
            principal,
            AdminAuditService.ACTION_UPDATE_STATUS,
            "user",
            id,
            "Mise à jour du statut utilisateur : « " + AdminAuditService.statutCompte(status) + " ».",
            changeReason
        );
        return "redirect:/admin/users?success=1";
    }

    @PostMapping("/admin/users/update")
    public String updateUser(
        @RequestParam long id,
        @RequestParam String fullName,
        @RequestParam String phone,
        @RequestParam long roleId,
        @RequestParam(required = false) String city,
        @RequestParam(required = false) String profession,
        @RequestParam(defaultValue = "pending") String status,
        @RequestParam(required = false) String changeReason,
        Principal principal
    ) {
        Optional<String> reasonErr = moderationService.validateChangeReason(changeReason);
        if (reasonErr.isPresent()) {
            return redirectError("/admin/users", reasonErr.get());
        }
        adminCrudService.updateUser(id, fullName, phone, roleId, city, profession, status);
        moderationService.logAction(
            principal,
            AdminAuditService.ACTION_UPDATE,
            "user",
            id,
            "Modification de la fiche de « " + fullName + " » (" + AdminAuditService.statutCompte(status) + ").",
            changeReason
        );
        return "redirect:/admin/users?success=1";
    }

    @PostMapping("/admin/users/delete")
    public String deleteUser(
        @RequestParam long id,
        @RequestParam(required = false) String reason,
        Principal principal
    ) {
        try {
            return handleDeletionRedirect(
                "user",
                id,
                "Compte utilisateur #" + id,
                reason,
                principal,
                "/admin/users",
                () -> adminCrudService.deleteUser(id)
            );
        } catch (IllegalArgumentException ex) {
            return "redirect:/admin/users?error=user_not_found";
        } catch (DataAccessException ex) {
            return "redirect:/admin/users?error=user_delete_failed";
        }
    }

    @GetMapping("/admin/products")
    public String products(
        Model model,
        @RequestParam(defaultValue = "0") int page,
        @RequestParam(defaultValue = "80") int size,
        @RequestParam(required = false) String q,
        @RequestParam(required = false) Long categoryId,
        @RequestParam(required = false) String availability
    ) {
        model.addAttribute("activePage", "products");
        model.addAttribute("productsPage", adminCrudService.getProductsPage(q, categoryId, availability, page, size));
        putFilterQuery(
            model,
            "q", q,
            "categoryId", categoryId == null ? null : String.valueOf(categoryId),
            "availability", availability
        );
        List<AdminCrudService.ProductCategoryRow> categories = adminCrudService.listProductCategories();
        model.addAttribute("productCategories", categories);
        model.addAttribute("productCategoriesJson", toCategoriesJson(categories));
        model.addAttribute("productCategoriesJs", toCategoriesJsList(categories));
        model.addAttribute("q", q);
        model.addAttribute("categoryId", categoryId);
        model.addAttribute("availability", availability);
        return "products";
    }

    @GetMapping("/admin/product-categories")
    public String productCategories(Model model) {
        model.addAttribute("activePage", "product-categories");
        model.addAttribute("categories", productCategoryService.listAll());
        return "product-categories";
    }

    @PostMapping("/admin/product-categories")
    public String createProductCategory(
        @RequestParam String label,
        @RequestParam(required = false) Integer sortOrder,
        Principal principal
    ) {
        try {
            productCategoryService.create(label, sortOrder);
            adminAuditService.logEquipe(principal.getName(), "Ajout de la catégorie catalogue « " + label.trim() + " ».");
            return "redirect:/admin/product-categories?success=1";
        } catch (IllegalArgumentException ex) {
            return "redirect:/admin/product-categories?error=" + URLEncoder.encode(ex.getMessage(), StandardCharsets.UTF_8);
        }
    }

    @PostMapping("/admin/product-categories/update")
    public String updateProductCategory(
        @RequestParam long id,
        @RequestParam String label,
        @RequestParam(required = false) Integer sortOrder,
        Principal principal
    ) {
        try {
            productCategoryService.update(id, label, sortOrder);
            adminAuditService.logEquipe(principal.getName(), "Mise à jour de la catégorie catalogue « " + label.trim() + " ».");
            return "redirect:/admin/product-categories?success=updated";
        } catch (IllegalArgumentException ex) {
            return "redirect:/admin/product-categories?error=" + URLEncoder.encode(ex.getMessage(), StandardCharsets.UTF_8);
        }
    }

    @GetMapping("/admin/job-offers")
    public String jobOffers(Model model) {
        model.addAttribute("activePage", "job-offers");
        model.addAttribute("offers", jobOfferService.listAllForAdmin());
        model.addAttribute("attachmentsByOfferId", jobOfferService.attachmentsGroupedByOfferId());
        return "job-offers";
    }

    @PostMapping("/admin/job-offers/create")
    public String createJobOffer(
        @RequestParam String title,
        @RequestParam(required = false) String summary,
        @RequestParam String description,
        @RequestParam(required = false) String location,
        @RequestParam(required = false) String profileRequirements,
        @RequestParam(required = false) String startsAt,
        @RequestParam(required = false) String endsAt,
        @RequestParam(defaultValue = "true") boolean active,
        @RequestParam(required = false) Integer sortOrder,
        Principal principal,
        RedirectAttributes redirectAttributes
    ) {
        try {
            long id = jobOfferService.create(
                title, summary, description, location, profileRequirements,
                startsAt, endsAt, active, sortOrder, principal.getName()
            );
            adminAuditService.logEquipe(principal.getName(), "Création offre d'emploi #" + id + " — " + title.trim());
            redirectAttributes.addFlashAttribute("success", true);
            redirectAttributes.addFlashAttribute("successText", "Offre créée.");
        } catch (IllegalArgumentException ex) {
            redirectAttributes.addFlashAttribute("error", true);
            redirectAttributes.addFlashAttribute("errorText", ex.getMessage());
        }
        return "redirect:/admin/job-offers";
    }

    @PostMapping("/admin/job-offers/update")
    public String updateJobOffer(
        @RequestParam long id,
        @RequestParam String title,
        @RequestParam(required = false) String summary,
        @RequestParam String description,
        @RequestParam(required = false) String location,
        @RequestParam(required = false) String profileRequirements,
        @RequestParam(required = false) String startsAt,
        @RequestParam(required = false) String endsAt,
        @RequestParam(defaultValue = "true") boolean active,
        @RequestParam(required = false) Integer sortOrder,
        Principal principal,
        RedirectAttributes redirectAttributes
    ) {
        try {
            jobOfferService.update(
                id, title, summary, description, location, profileRequirements,
                startsAt, endsAt, active, sortOrder, principal.getName()
            );
            adminAuditService.logEquipe(principal.getName(), "Mise à jour offre d'emploi #" + id);
            redirectAttributes.addFlashAttribute("success", true);
            redirectAttributes.addFlashAttribute("successText", "Offre enregistrée.");
        } catch (IllegalArgumentException ex) {
            redirectAttributes.addFlashAttribute("error", true);
            redirectAttributes.addFlashAttribute("errorText", ex.getMessage());
        }
        return "redirect:/admin/job-offers";
    }

    @PostMapping("/admin/job-offers/toggle-active")
    public String toggleJobOfferActive(
        @RequestParam long id,
        Principal principal,
        RedirectAttributes redirectAttributes
    ) {
        try {
            jobOfferService.toggleActive(id, principal.getName());
            adminAuditService.logEquipe(principal.getName(), "Activation/désactivation offre #" + id);
            redirectAttributes.addFlashAttribute("success", true);
            redirectAttributes.addFlashAttribute("successText", "Statut de publication mis à jour.");
        } catch (IllegalArgumentException ex) {
            redirectAttributes.addFlashAttribute("error", true);
            redirectAttributes.addFlashAttribute("errorText", ex.getMessage());
        }
        return "redirect:/admin/job-offers";
    }

    @PostMapping("/admin/job-offers/delete")
    public String deleteJobOffer(
        @RequestParam long id,
        Principal principal,
        RedirectAttributes redirectAttributes
    ) {
        try {
            jobOfferService.delete(id);
            adminAuditService.logEquipe(principal.getName(), "Suppression offre d'emploi #" + id);
            redirectAttributes.addFlashAttribute("success", true);
            redirectAttributes.addFlashAttribute("successText", "Offre supprimée.");
        } catch (IllegalArgumentException ex) {
            redirectAttributes.addFlashAttribute("error", true);
            redirectAttributes.addFlashAttribute("errorText", ex.getMessage());
        }
        return "redirect:/admin/job-offers";
    }

    @PostMapping("/admin/job-offers/attachment/add")
    public String addJobOfferAttachment(
        @RequestParam long offerId,
        @RequestParam("file") MultipartFile file,
        Principal principal,
        RedirectAttributes redirectAttributes
    ) {
        try {
            jobOfferService.addAttachment(offerId, file);
            adminAuditService.logEquipe(principal.getName(), "Document ajouté à l'offre #" + offerId);
            redirectAttributes.addFlashAttribute("success", true);
            redirectAttributes.addFlashAttribute("successText", "Document ajouté.");
        } catch (IllegalArgumentException ex) {
            redirectAttributes.addFlashAttribute("error", true);
            redirectAttributes.addFlashAttribute("errorText", ex.getMessage());
        } catch (Exception ex) {
            redirectAttributes.addFlashAttribute("error", true);
            redirectAttributes.addFlashAttribute("errorText", "Import du document impossible.");
        }
        return "redirect:/admin/job-offers";
    }

    @PostMapping("/admin/job-offers/attachment/delete")
    public String deleteJobOfferAttachment(
        @RequestParam long attachmentId,
        Principal principal,
        RedirectAttributes redirectAttributes
    ) {
        try {
            jobOfferService.deleteAttachment(attachmentId);
            adminAuditService.logEquipe(principal.getName(), "Document offre supprimé #" + attachmentId);
            redirectAttributes.addFlashAttribute("success", true);
            redirectAttributes.addFlashAttribute("successText", "Document supprimé.");
        } catch (IllegalArgumentException ex) {
            redirectAttributes.addFlashAttribute("error", true);
            redirectAttributes.addFlashAttribute("errorText", ex.getMessage());
        }
        return "redirect:/admin/job-offers";
    }

    @GetMapping("/admin/legal-documents")
    public String legalDocuments(Model model) {
        model.addAttribute("activePage", "legal-documents");
        model.addAttribute("documents", legalDocumentService.listAll());
        return "legal-documents";
    }

    @PostMapping("/admin/legal-documents/save")
    public String saveLegalDocument(
        @RequestParam String code,
        @RequestParam String title,
        @RequestParam String content,
        Principal principal,
        RedirectAttributes redirectAttributes
    ) {
        try {
            legalDocumentService.update(code, title, content, principal.getName());
            adminAuditService.logEquipe(
                principal.getName(),
                "Mise à jour document juridique « " + code + " »."
            );
            redirectAttributes.addFlashAttribute("success", true);
            redirectAttributes.addFlashAttribute("successText", "Document enregistré.");
        } catch (IllegalArgumentException ex) {
            redirectAttributes.addFlashAttribute("error", true);
            redirectAttributes.addFlashAttribute("errorText", ex.getMessage());
        }
        return "redirect:/admin/legal-documents";
    }

    @PostMapping("/admin/product-categories/delete")
    public String deleteProductCategory(
        @RequestParam long id,
        @RequestParam(required = false) String reason,
        Principal principal
    ) {
        try {
            var cat = productCategoryService.findById(id).orElse(null);
            String label = cat != null ? cat.label() : "Catégorie #" + id;
            return handleDeletionRedirect(
                "product_category",
                id,
                label,
                reason,
                principal,
                "/admin/product-categories",
                () -> productCategoryService.delete(id)
            );
        } catch (IllegalArgumentException ex) {
            return redirectError("/admin/product-categories", ex.getMessage());
        }
    }

    private String toCategoriesJson(List<AdminCrudService.ProductCategoryRow> categories) {
        try {
            return objectMapper.writeValueAsString(toCategoriesJsList(categories));
        } catch (JsonProcessingException ex) {
            return "[]";
        }
    }

    private List<Map<String, Object>> toCategoriesJsList(List<AdminCrudService.ProductCategoryRow> categories) {
        return categories.stream()
            .map(c -> {
                Map<String, Object> m = new LinkedHashMap<>();
                m.put("id", c.id());
                m.put("label", c.label());
                return m;
            })
            .toList();
    }

    @PostMapping(value = "/admin/products", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    public String createProduct(
        @RequestParam String name,
        @RequestParam long categoryId,
        @RequestParam double price,
        @RequestParam double minDailyContribution,
        @RequestParam(defaultValue = "in_stock") String availability,
        @RequestParam(required = false) String description,
        @RequestParam(required = false) MultipartFile imageMain,
        @RequestParam(required = false) MultipartFile imageDetail1,
        @RequestParam(required = false) MultipartFile imageDetail2,
        @RequestParam(required = false) Boolean featured,
        Principal principal
    ) {
        boolean feat = Boolean.TRUE.equals(featured);
        try {
            adminCrudService.createProduct(
                name, categoryId, price, minDailyContribution, availability, description,
                imageMain, imageDetail1, imageDetail2, feat
            );
        } catch (Exception ex) {
            String msg = ex.getMessage() == null ? "Erreur lors de la création du produit." : ex.getMessage();
            return "redirect:/admin/products?error=" + URLEncoder.encode(msg, StandardCharsets.UTF_8);
        }
        adminAuditService.logEquipe(
            principal.getName(),
            "Ajout au catalogue du produit « " + name + " » (" + AdminAuditService.disponibiliteProduit(availability) + ")."
        );
        return "redirect:/admin/products?success=1";
    }

    @PostMapping(value = "/admin/products/update", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    public String updateProduct(
        @RequestParam long id,
        @RequestParam String name,
        @RequestParam long categoryId,
        @RequestParam double price,
        @RequestParam double minDailyContribution,
        @RequestParam(defaultValue = "in_stock") String availability,
        @RequestParam(required = false) String description,
        @RequestParam(required = false) MultipartFile imageMain,
        @RequestParam(required = false) MultipartFile imageDetail1,
        @RequestParam(required = false) MultipartFile imageDetail2,
        @RequestParam(required = false) Boolean featured,
        @RequestParam(required = false) String changeReason,
        Principal principal
    ) {
        boolean feat = Boolean.TRUE.equals(featured);
        Optional<String> reasonErr = moderationService.validateChangeReason(changeReason);
        if (reasonErr.isPresent()) {
            return redirectError("/admin/products", reasonErr.get());
        }
        try {
            adminCrudService.updateProduct(
                id, name, categoryId, price, minDailyContribution, availability, description,
                imageMain, imageDetail1, imageDetail2, feat
            );
        } catch (Exception ex) {
            String msg = ex.getMessage() == null ? "Erreur lors de la mise à jour du produit." : ex.getMessage();
            return redirectError("/admin/products", msg);
        }
        moderationService.logAction(
            principal,
            AdminAuditService.ACTION_UPDATE,
            "product",
            id,
            "Mise à jour du produit « " + name + " » dans le catalogue.",
            changeReason
        );
        return "redirect:/admin/products?success=1";
    }

    @PostMapping("/admin/products/delete")
    public String deleteProduct(
        @RequestParam long id,
        @RequestParam(required = false) String reason,
        Principal principal
    ) {
        return handleDeletionRedirect(
            "product",
            id,
            "Produit #" + id,
            reason,
            principal,
            "/admin/products",
            () -> adminCrudService.deleteProduct(id)
        );
    }

    @GetMapping("/admin/agents")
    public String agents(
        Model model,
        @RequestParam(defaultValue = "0") int page,
        @RequestParam(defaultValue = "80") int size,
        @RequestParam(required = false) String q,
        @RequestParam(required = false) String zone,
        @RequestParam(required = false) Boolean active
    ) {
        model.addAttribute("activePage", "agents");
        model.addAttribute("agentsPage", adminCrudService.getAgentsPage(q, zone, active, page, size));
        putFilterQuery(
            model,
            "q", q,
            "zone", zone,
            "active", active == null ? null : active.toString()
        );
        model.addAttribute("agentCandidates", adminCrudService.getAgentCandidates());
        model.addAttribute("zoneChoices", adminCrudService.listActiveZoneChoices());
        model.addAttribute("q", q);
        model.addAttribute("zone", zone);
        model.addAttribute("active", active);
        return "agents";
    }

    @PostMapping("/admin/agents")
    public String createAgent(
        @RequestParam long userId,
        @RequestParam long zoneId,
        Principal principal
    ) {
        try {
            adminCrudService.createAgent(userId, zoneId);
        } catch (IllegalArgumentException ex) {
            return "redirect:/admin/agents?error=validation";
        }
        adminAuditService.logEquipe(
            principal.getName(),
            "Attribution d'une fiche agent à un collaborateur (zone n° " + zoneId + ")."
        );
        return "redirect:/admin/agents?success=1";
    }

    @GetMapping("/admin/agents/nouveau")
    public String agentHireForm(Model model) {
        model.addAttribute("activePage", "agents");
        model.addAttribute("zoneChoices", adminCrudService.listActiveZoneChoices());
        return "agent-hire";
    }

    @PostMapping(value = "/admin/agents/embauche", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    public String hireAgentDossier(
        RedirectAttributes redirectAttributes,
        Principal principal,
        @RequestParam String fullName,
        @RequestParam String phone,
        @RequestParam String mobilePin,
        @RequestParam String mobilePinConfirm,
        @RequestParam String accountPassword,
        @RequestParam String accountPasswordConfirm,
        @RequestParam(required = false) String city,
        @RequestParam(required = false) String profession,
        @RequestParam long zoneId,
        @RequestParam(required = false) String gender,
        @RequestParam(required = false) String email,
        @RequestParam(required = false) String personalAddress,
        @RequestParam(required = false) String hireDate,
        @RequestParam(required = false) String contractType,
        @RequestParam(required = false) String matricule,
        @RequestParam(required = false) String emergencyContactName,
        @RequestParam(required = false) String emergencyContactPhone,
        @RequestParam(required = false) String emergencyContactRelation,
        @RequestParam(required = false) String supervisorName,
        @RequestParam(required = false) String supervisorPhone,
        @RequestParam(required = false) String secondaryContactName,
        @RequestParam(required = false) String secondaryContactPhone,
        @RequestParam(required = false) String referencesNotes,
        @RequestParam(required = false) String internalNotes,
        @RequestParam(required = false) MultipartFile idDocument,
        @RequestParam(required = false) MultipartFile contractDocument,
        @RequestParam(required = false) MultipartFile photo
    ) {
        String prof = profession == null || profession.isBlank() ? "Agent de collecte PayFlex" : profession.trim();
        if (mobilePin == null || !mobilePin.equals(mobilePinConfirm)) {
            redirectAttributes.addFlashAttribute("errorMessage", "Les deux codes PIN ne correspondent pas.");
            return "redirect:/admin/agents/nouveau";
        }
        try {
            validateAccountPasswordPair(accountPassword, accountPasswordConfirm);
        } catch (IllegalArgumentException ex) {
            redirectAttributes.addFlashAttribute("errorMessage", ex.getMessage());
            return "redirect:/admin/agents/nouveau";
        }
        try {
            long agentId = adminCrudService.hireAgentDossier(
                fullName,
                phone,
                mobilePin,
                accountPassword,
                city,
                prof,
                zoneId,
                gender,
                email,
                personalAddress,
                hireDate,
                contractType,
                matricule,
                emergencyContactName,
                emergencyContactPhone,
                emergencyContactRelation,
                supervisorName,
                supervisorPhone,
                secondaryContactName,
                secondaryContactPhone,
                referencesNotes,
                internalNotes,
                idDocument,
                contractDocument,
                photo
            );
            adminAuditService.logEquipe(
                principal.getName(),
                "Embauche agent : « " + fullName.trim() + " » — fiche n° " + agentId + "."
            );
            return "redirect:/admin/agents/" + agentId + "?hired=1";
        } catch (IllegalArgumentException ex) {
            redirectAttributes.addFlashAttribute("errorMessage", ex.getMessage());
            return "redirect:/admin/agents/nouveau";
        } catch (Exception ex) {
            redirectAttributes.addFlashAttribute("errorMessage", "Enregistrement impossible : " + ex.getMessage());
            return "redirect:/admin/agents/nouveau";
        }
    }

    @PostMapping("/admin/agents/update")
    public String updateAgent(
        @RequestParam long id,
        @RequestParam(required = false) Long zoneId,
        @RequestParam String zone,
        @RequestParam(defaultValue = "false") boolean active,
        Principal principal
    ) {
        adminCrudService.updateAgent(id, zoneId, zone, active);
        adminAuditService.logEquipe(
            principal.getName(),
            "Mise à jour de la zone ou du statut actif d'un agent."
        );
        return "redirect:/admin/agents?success=1";
    }

    @PostMapping("/admin/agents/delete")
    public String deleteAgent(
        @RequestParam long id,
        @RequestParam(required = false) String reason,
        Principal principal
    ) {
        return handleDeletionRedirect(
            "agent",
            id,
            "Agent #" + id,
            reason,
            principal,
            "/admin/agents",
            () -> adminCrudService.deleteAgent(id)
        );
    }

    @GetMapping("/admin/zones")
    public String zonesList(Model model) {
        model.addAttribute("activePage", "zones");
        model.addAttribute("pageTitle", "Zones d'activité");
        model.addAttribute("pageSubtitle", "Référentiel pour l'affectation des agents");
        model.addAttribute("zonesList", adminCrudService.listZonesWithCounts());
        return "zones";
    }

    @GetMapping("/admin/zones/{zoneId}")
    public String zoneDetail(@PathVariable long zoneId, Model model) {
        return adminCrudService.findZone(zoneId)
            .map(z -> {
                model.addAttribute("activePage", "zones");
                model.addAttribute("zone", z);
                model.addAttribute("zoneAgents", adminCrudService.listAgentsInZone(zoneId));
                model.addAttribute("zoneClients", adminCrudService.listClientsInZone(zoneId));
                return "zone-detail";
            })
            .orElse("redirect:/admin/zones?error=notfound");
    }

    @PostMapping("/admin/zones")
    public String createZone(
        @RequestParam String name,
        @RequestParam(required = false) String description,
        Principal principal
    ) {
        try {
            adminCrudService.createZone(name, description);
            adminAuditService.logEquipe(principal.getName(), "Création d'une zone : « " + name.trim() + " ».");
            return "redirect:/admin/zones?success=1";
        } catch (IllegalArgumentException ex) {
            return "redirect:/admin/zones?error=" + URLEncoder.encode(ex.getMessage(), StandardCharsets.UTF_8);
        }
    }

    @PostMapping("/admin/zones/update")
    public String updateZone(
        @RequestParam long id,
        @RequestParam String name,
        @RequestParam(required = false) String description,
        @RequestParam(defaultValue = "false") boolean active,
        Principal principal
    ) {
        try {
            adminCrudService.updateZone(id, name, description, active);
            adminAuditService.logEquipe(principal.getName(), "Mise à jour de la zone « " + name.trim() + " ».");
            return "redirect:/admin/zones/" + id + "?success=1";
        } catch (IllegalArgumentException ex) {
            return "redirect:/admin/zones/" + id + "?error=" + URLEncoder.encode(ex.getMessage(), StandardCharsets.UTF_8);
        }
    }

    @PostMapping("/admin/zones/delete")
    public String deleteZone(
        @RequestParam long id,
        @RequestParam(required = false) String reason,
        Principal principal
    ) {
        try {
            return handleDeletionRedirect(
                "zone",
                id,
                "Zone #" + id,
                reason,
                principal,
                "/admin/zones",
                () -> adminCrudService.deleteZone(id)
            );
        } catch (IllegalArgumentException ex) {
            return redirectError("/admin/zones", ex.getMessage());
        }
    }

    @GetMapping("/admin/contributions")
    public String contributions(
        Model model,
        @RequestParam(defaultValue = "0") int page,
        @RequestParam(defaultValue = "80") int size,
        @RequestParam(required = false) String q,
        @RequestParam(required = false) String status,
        @RequestParam(required = false) String paymentMode
    ) {
        model.addAttribute("activePage", "contributions");
        model.addAttribute("contributionsPage", adminCrudService.getContributionsPage(q, status, paymentMode, page, size));
        model.addAttribute("users", adminCrudService.getUserChoices());
        model.addAttribute("products", adminCrudService.getProductChoices());
        model.addAttribute("agents", adminCrudService.getAgentChoices());
        model.addAttribute("q", q);
        model.addAttribute("status", status);
        model.addAttribute("paymentMode", paymentMode);
        putFilterQuery(model, "q", q, "status", status, "paymentMode", paymentMode);
        if (contributionValidationAlertService.countUnread() > 0) {
            model.addAttribute("contributionAlerts", contributionValidationAlertService.listUnread(15));
        }
        model.addAttribute("cashByAgent", contributionWorkflowService.listPendingCashByAgent());
        model.addAttribute("pendingCashUnassigned", contributionWorkflowService.countPendingCashWithoutAgent());
        return "contributions";
    }

    @PostMapping("/admin/contributions/alerts/dismiss")
    public String dismissContributionAlerts() {
        contributionValidationAlertService.markAllRead();
        return "redirect:/admin/contributions";
    }

    @PostMapping("/admin/contributions")
    public String createContribution(
        @RequestParam long userId,
        @RequestParam(required = false) Long productId,
        @RequestParam(required = false) Long agentId,
        @RequestParam double amount,
        @RequestParam String paymentMode,
        @RequestParam(defaultValue = "pending") String status,
        @RequestParam(required = false) String referenceCode,
        Principal principal
    ) {
        adminCrudService.createContribution(userId, productId, agentId, amount, paymentMode, status, referenceCode);
        adminAuditService.logEquipe(
            principal.getName(),
            "Saisie d'un versement de " + Math.round(amount) + " FCFA pour un client (" + AdminAuditService.modePaiement(paymentMode) + ")."
        );
        return "redirect:/admin/contributions?success=1";
    }

    @PostMapping("/admin/contributions/run-auto-validate")
    public String runAutoValidateContributions(Principal principal) {
        int hours = payflexProperties.getContributions().getAutoValidateMobileMoneyHours();
        if (hours <= 0) {
            return redirectError("/admin/contributions", "Validation automatique désactivée (heures = 0).");
        }
        int n = contributionWorkflowService.autoValidateStaleMobileDeclarations(hours);
        adminAuditService.logEquipe(
            principal.getName(),
            "Lancement manuel validation auto : " + n + " cotisation(s) mobile money après " + hours + " h."
        );
        return "redirect:/admin/contributions?success=1&auto=" + n;
    }

    @PostMapping("/admin/contributions/bulk-validate")
    public String bulkValidateContributions(Principal principal) {
        int n = contributionWorkflowService.bulkValidatePendingMobileDeclarations(principal.getName());
        adminAuditService.logEquipe(
            principal.getName(),
            "Validation groupée mobile money : " + n + " versement(s) confirmé(s)."
        );
        return "redirect:/admin/contributions?success=bulk&count=" + n + "&status=pending";
    }

    @PostMapping("/admin/contributions/bulk-validate-cash")
    public String bulkValidateCashContributions(Principal principal) {
        int n = contributionWorkflowService.bulkValidatePendingCashCollections(principal.getName());
        return "redirect:/admin/contributions?success=bulkCash&count=" + n + "&status=pending&paymentMode=cash";
    }

    @PostMapping("/admin/contributions/reconcile-cash")
    public String reconcileCashContributions(
        @RequestParam double collectedFcfa,
        Principal principal
    ) {
        try {
            ContributionWorkflowService.CashReconcileResult r = contributionWorkflowService.reconcilePendingCash(
                collectedFcfa,
                principal.getName()
            );
            return "redirect:/admin/contributions?success=reconcile"
                + "&validated=" + r.validatedCount()
                + "&debt=" + r.debtRecordedFcfa()
                + "&pending=" + r.stillPendingCount()
                + "&collected=" + r.collectedAmountFcfa()
                + "&expected=" + r.expectedTotalFcfa()
                + "&status=pending&paymentMode=cash";
        } catch (IllegalArgumentException ex) {
            return redirectError("/admin/contributions", ex.getMessage());
        }
    }

    /**
     * Rapprochement de caisse PAR AGENT (flux principal) : le montant compté ne couvre que
     * les collectes de cet agent ; un manque devient une dette de cet agent uniquement.
     * {@code from=agent} : retour sur la fiche agent au lieu de la liste des cotisations.
     */
    @PostMapping("/admin/agents/{agentId}/reconcile-cash")
    public String reconcileCashForAgent(
        @PathVariable long agentId,
        @RequestParam double collectedFcfa,
        @RequestParam(required = false) String from,
        Principal principal
    ) {
        String base = "agent".equals(from) ? "/admin/agents/" + agentId : "/admin/contributions";
        try {
            ContributionWorkflowService.CashReconcileResult r =
                contributionWorkflowService.reconcilePendingCashForAgent(agentId, collectedFcfa, principal.getName());
            adminAuditService.logEquipe(
                principal.getName(),
                "Rapprochement caisse agent #" + agentId + " : " + r.validatedCount()
                    + " cotisation(s) validée(s), compté " + r.collectedAmountFcfa()
                    + " FCFA / attendu " + r.expectedTotalFcfa() + " FCFA"
                    + (r.debtRecordedFcfa() > 0 ? ", dette " + r.debtRecordedFcfa() + " FCFA" : "")
                    + (r.surplusFcfa() > 0 ? ", excédent signalé " + r.surplusFcfa() + " FCFA" : "")
                    + "."
            );
            return "redirect:" + base + "?success=reconcileAgent"
                + "&validated=" + r.validatedCount()
                + "&debt=" + r.debtRecordedFcfa()
                + "&pending=" + r.stillPendingCount()
                + "&collected=" + r.collectedAmountFcfa()
                + "&expected=" + r.expectedTotalFcfa()
                + "&surplus=" + r.surplusFcfa();
        } catch (IllegalArgumentException ex) {
            return redirectError(base, ex.getMessage());
        }
    }

    /** Remboursement (total ou partiel) de la dette de caisse d'un agent, encaissé au centre. */
    @PostMapping("/admin/agents/{agentId}/debt-repayment")
    public String recordAgentDebtRepayment(
        @PathVariable long agentId,
        @RequestParam long amountFcfa,
        @RequestParam(required = false) String note,
        Principal principal
    ) {
        String base = "/admin/agents/" + agentId;
        try {
            contributionWorkflowService.recordAgentDebtRepayment(agentId, amountFcfa, note, principal.getName());
            return "redirect:" + base + "?success=repayment&amount=" + amountFcfa;
        } catch (IllegalArgumentException ex) {
            return redirectError(base, ex.getMessage());
        }
    }

    /**
     * Surplus de cotisation non affectés à un produit (aucun produit actif disponible au moment
     * de la validation) — voir {@link SurplusRegularizationService}. Tous clients confondus.
     */
    @GetMapping("/admin/surplus")
    public String surplus(Model model) {
        model.addAttribute("activePage", "surplus");
        List<SurplusRegularizationService.UnresolvedSurplus> rows = surplusRegularizationService.listUnresolved();
        model.addAttribute("surplusRows", rows);
        model.addAttribute("surplusProductChoices", surplusRegularizationService.activeProductChoicesByClient(rows));
        return "surplus";
    }

    @PostMapping("/admin/surplus/{surplusId}/reallocate")
    public String reallocateSurplus(
        @PathVariable long surplusId,
        @RequestParam long targetProductId,
        Principal principal
    ) {
        try {
            surplusRegularizationService.reallocateToProduct(surplusId, targetProductId, principal.getName());
            adminAuditService.logEquipe(
                principal.getName(),
                "Régularisation d'un surplus de cotisation (#" + surplusId + ") par réaffectation au produit #" + targetProductId + "."
            );
            return "redirect:/admin/surplus?success=reallocated";
        } catch (IllegalArgumentException ex) {
            return redirectError("/admin/surplus", ex.getMessage());
        }
    }

    @PostMapping("/admin/surplus/{surplusId}/refund")
    public String refundSurplus(
        @PathVariable long surplusId,
        @RequestParam(required = false) String note,
        Principal principal
    ) {
        try {
            surplusRegularizationService.markRefundedOutOfSystem(surplusId, note, principal.getName());
            adminAuditService.logEquipe(
                principal.getName(),
                "Régularisation d'un surplus de cotisation (#" + surplusId + ") — traité hors système."
            );
            return "redirect:/admin/surplus?success=refunded";
        } catch (IllegalArgumentException ex) {
            return redirectError("/admin/surplus", ex.getMessage());
        }
    }

    @PostMapping("/admin/contributions/status")
    public String updateContributionStatus(
        @RequestParam long id,
        @RequestParam String status,
        @RequestParam(required = false) String rejectionReason,
        @RequestParam(required = false) String changeReason,
        Principal principal
    ) {
        Optional<String> reasonErr = moderationService.validateChangeReason(changeReason);
        if (reasonErr.isPresent()) {
            return redirectError("/admin/contributions", reasonErr.get());
        }
        try {
            if ("validated".equals(status)) {
                contributionWorkflowService.validateByBackoffice(id, principal.getName());
            } else if ("rejected".equals(status)) {
                contributionWorkflowService.rejectByBackoffice(id, rejectionReason, principal.getName());
            } else {
                adminCrudService.updateContributionStatus(id, status);
                moderationService.logAction(
                    principal,
                    AdminAuditService.ACTION_UPDATE_STATUS,
                    "contribution",
                    id,
                    "Changement du suivi d'un versement : « " + AdminAuditService.statutCotisation(status) + " ».",
                    changeReason
                );
            }
        } catch (IllegalArgumentException ex) {
            return redirectError("/admin/contributions", ex.getMessage());
        }
        return "redirect:/admin/contributions?success=1";
    }

    @PostMapping("/admin/contributions/update")
    public String updateContribution(
        @RequestParam long id,
        @RequestParam double amount,
        @RequestParam String paymentMode,
        @RequestParam String status,
        @RequestParam(required = false) String referenceCode,
        Principal principal
    ) {
        adminCrudService.updateContribution(id, amount, paymentMode, status, referenceCode);
        adminAuditService.logEquipe(principal.getName(), "Correction des informations d'un versement ou d'une cotisation.");
        return "redirect:/admin/contributions?success=1";
    }

    @PostMapping("/admin/contributions/delete")
    public String deleteContribution(
        @RequestParam long id,
        @RequestParam(required = false) String reason,
        Principal principal
    ) {
        return handleDeletionRedirect(
            "contribution",
            id,
            "Cotisation #" + id,
            reason,
            principal,
            "/admin/contributions",
            () -> adminCrudService.deleteContribution(id)
        );
    }

    /** Évite la page d'erreur si l'URL de suppression est ouverte en GET (lien direct / rafraîchissement). */
    @GetMapping({
        "/admin/contributions/delete",
        "/admin/clients/delete",
        "/admin/users/delete",
        "/admin/registrations/delete"
    })
    public String deletionMustBePost(jakarta.servlet.http.HttpServletRequest request) {
        String path = request.getServletPath();
        String redirectBase = switch (path) {
            case "/admin/clients/delete" -> "/admin/clients";
            case "/admin/users/delete" -> "/admin/users";
            case "/admin/contributions/delete" -> "/admin/contributions";
            default -> "/admin/registrations";
        };
        return redirectError(
            redirectBase,
            "Action invalide : utilisez le bouton Supprimer sur la liste (pas l’URL directe)."
        );
    }

    @PostMapping("/admin/clients/delete")
    public String deleteClient(
        @RequestParam long id,
        @RequestParam(required = false) String reason,
        Principal principal
    ) {
        try {
            var client = adminCrudService.getClientDetails(id);
            return handleDeletionRedirect(
                "user",
                id,
                "Client « " + client.fullName() + " »",
                reason,
                principal,
                "/admin/clients",
                () -> adminCrudService.deleteUser(id)
            );
        } catch (org.springframework.dao.EmptyResultDataAccessException ex) {
            return redirectError("/admin/clients", "Client introuvable.");
        } catch (IllegalArgumentException ex) {
            return redirectError("/admin/clients", ex.getMessage());
        } catch (DataAccessException ex) {
            return redirectError("/admin/clients", "Suppression impossible (données encore liées).");
        } catch (RuntimeException ex) {
            String msg = ex.getMessage() != null && !ex.getMessage().isBlank()
                ? ex.getMessage()
                : "Suppression impossible.";
            return redirectError("/admin/clients", msg);
        }
    }

    @PreAuthorize("hasRole('ADMIN')")
    @GetMapping("/admin/deletion-requests")
    public String deletionRequests(Model model) {
        model.addAttribute("activePage", "deletion-requests");
        model.addAttribute("pageTitle", "Demandes de suppression");
        model.addAttribute("pageSubtitle", "Validations réservées à l'administrateur principal");
        model.addAttribute("pendingRequests", deletionRequestService.listPending());
        return "deletion-requests";
    }

    @PreAuthorize("hasRole('ADMIN')")
    @PostMapping("/admin/deletion-requests/approve")
    public String approveDeletionRequest(@RequestParam long id, Principal principal) {
        try {
            var req = deletionRequestService.findById(id)
                .orElseThrow(() -> new IllegalArgumentException("Demande introuvable."));
            executeDeletion(req.entityType(), req.entityId(), principal.getName());
            deletionRequestService.markApproved(id, principal.getName());
            adminAuditService.logEquipe(
                principal.getName(),
                "Validation définitive de la suppression demandée par "
                    + req.requestedBy()
                    + " : "
                    + req.entityLabel()
                    + "."
            );
            return "redirect:/admin/deletion-requests?success=approved";
        } catch (IllegalArgumentException ex) {
            return redirectError("/admin/deletion-requests", ex.getMessage());
        } catch (DataAccessException ex) {
            return redirectError("/admin/deletion-requests", "Suppression impossible (données liées).");
        }
    }

    @PreAuthorize("hasRole('ADMIN')")
    @PostMapping("/admin/deletion-requests/reject")
    public String rejectDeletionRequest(
        @RequestParam long id,
        @RequestParam(required = false) String reviewNote,
        Principal principal
    ) {
        try {
            var req = deletionRequestService.findById(id)
                .orElseThrow(() -> new IllegalArgumentException("Demande introuvable."));
            deletionRequestService.markRejected(id, principal.getName(), reviewNote);
            adminAuditService.logEquipe(
                principal.getName(),
                "Refus de la demande de suppression de "
                    + req.requestedBy()
                    + " concernant "
                    + req.entityLabel()
                    + "."
            );
            return "redirect:/admin/deletion-requests?success=rejected";
        } catch (IllegalArgumentException ex) {
            return redirectError("/admin/deletion-requests", ex.getMessage());
        }
    }

    @GetMapping("/admin/audit")
    public String audit(
        Model model,
        @RequestParam(defaultValue = "0") int page,
        @RequestParam(defaultValue = "80") int size,
        @RequestParam(required = false) String q,
        @RequestParam(required = false, defaultValue = "tous") String profil,
        @RequestParam(required = false) String dateFrom,
        @RequestParam(required = false) String dateTo
    ) {
        model.addAttribute("activePage", "audit");
        model.addAttribute("pageTitle", "Journal d'activité");
        model.addAttribute("pageSubtitle", "Historique lisible des actions PayFlex, agents et clients");
        model.addAttribute("auditPage", adminAuditService.page(profil, q, dateFrom, dateTo, page, size));
        model.addAttribute("q", q);
        model.addAttribute("profil", profil);
        model.addAttribute("dateFrom", dateFrom);
        model.addAttribute("dateTo", dateTo);
        putFilterQuery(model, "q", q, "profil", profil, "dateFrom", dateFrom, "dateTo", dateTo);
        return "audit";
    }

    @PreAuthorize("hasRole('ADMIN')")
    @PostMapping("/admin/audit/reset")
    public String resetAuditJournal() {
        adminAuditService.clearAll();
        return "redirect:/admin/audit?success=reset";
    }

    @GetMapping("/admin/registrations")
    public String registrations(
        Model model,
        @RequestParam(defaultValue = "0") int page,
        @RequestParam(defaultValue = "80") int size,
        @RequestParam(required = false) String q,
        @RequestParam(required = false) String status
    ) {
        model.addAttribute("activePage", "registrations");
        model.addAttribute("registrationsPage", registrationService.page(q, status, page, size));
        model.addAttribute("agentOptions", registrationService.agentOptions());
        model.addAttribute("regCountPending", registrationService.countByStatus("pending"));
        model.addAttribute("regCountApproved", registrationService.countByStatus("approved"));
        model.addAttribute("regCountRejected", registrationService.countByStatus("rejected"));
        model.addAttribute("q", q);
        model.addAttribute("status", status);
        putFilterQuery(model, "q", q, "status", status);
        return "registrations";
    }

    @PostMapping("/admin/registrations/decision")
    public String registrationDecision(
        @RequestParam long requestId,
        @RequestParam String decision,
        @RequestParam(required = false) String assignedAgentUserId,
        @RequestParam(required = false) String adminNote,
        Principal principal
    ) {
        try {
            Long agentId = parseOptionalLong(assignedAgentUserId);
            registrationService.decide(requestId, decision, agentId, principal.getName(), adminNote);
            String suffix = "approved".equals(decision) ? "approved" : ("rejected".equals(decision) ? "rejected" : "1");
            return "redirect:/admin/registrations?success=" + suffix;
        } catch (IllegalArgumentException ex) {
            return "redirect:/admin/registrations/" + requestId + "?error="
                + URLEncoder.encode(ex.getMessage(), StandardCharsets.UTF_8);
        }
    }

    @GetMapping("/admin/registrations/{id}")
    public String registrationDetail(@PathVariable long id, Model model) {
        return registrationService.findDetailById(id)
            .map(reg -> {
                model.addAttribute("activePage", "registrations");
                model.addAttribute("reg", reg);
                model.addAttribute("agentOptions", registrationService.agentOptions());
                model.addAttribute(
                    "linkedClientUserId",
                    registrationService.linkedClientUserIdForPhone(reg.phone()).orElse(null)
                );
                return "registration-detail";
            })
            .orElse("redirect:/admin/registrations?error=notfound");
    }

    @GetMapping("/admin/registrations/{id}/photo")
    public ResponseEntity<Resource> registrationPhoto(@PathVariable long id) {
        return serveRegistrationAttachment(id, true);
    }

    @GetMapping("/admin/registrations/{id}/identity")
    public ResponseEntity<Resource> registrationIdentity(@PathVariable long id) {
        return serveRegistrationAttachment(id, false);
    }

    private ResponseEntity<Resource> serveRegistrationAttachment(long registrationId, boolean profile) {
        Optional<Path> opt = registrationService.resolveStoredAttachment(registrationId, profile);
        if (opt.isEmpty()) {
            return ResponseEntity.notFound().build();
        }
        Path path = opt.get();
        Resource resource = new FileSystemResource(path.toFile());
        try {
            String ct = Files.probeContentType(path);
            MediaType mediaType = ct != null ? MediaType.parseMediaType(ct) : MediaType.APPLICATION_OCTET_STREAM;
            String filename = path.getFileName() != null ? path.getFileName().toString() : "piece";
            return ResponseEntity.ok()
                .contentType(mediaType)
                .header(HttpHeaders.CONTENT_DISPOSITION, "inline; filename=\"" + filename.replace("\"", "") + "\"")
                .body(resource);
        } catch (Exception e) {
            return ResponseEntity.notFound().build();
        }
    }

    @PostMapping("/admin/registrations/{id}/update")
    public String updateRegistrationPending(
        @PathVariable long id,
        @RequestParam String fullName,
        @RequestParam String phone,
        @RequestParam(required = false) String city,
        @RequestParam(required = false) String profession,
        @RequestParam(required = false) String gender,
        @RequestParam(required = false) String workplaceName,
        @RequestParam(required = false) String workplaceAddress,
        @RequestParam(required = false) String bossName,
        @RequestParam(required = false) String bossPhone,
        @RequestParam(required = false) String assignedAgentUserId,
        @RequestParam(required = false) String changeReason,
        Principal principal
    ) {
        Optional<String> reasonErr = moderationService.validateChangeReason(changeReason);
        if (reasonErr.isPresent()) {
            return "redirect:/admin/registrations/" + id + "?error="
                + URLEncoder.encode(reasonErr.get(), StandardCharsets.UTF_8);
        }
        try {
            Long agentId = parseOptionalLong(assignedAgentUserId);
            registrationService.updatePending(
                id,
                new RegistrationService.RegistrationPatch(
                    fullName, phone, city, profession, gender,
                    workplaceName, workplaceAddress, bossName, bossPhone,
                    agentId
                ),
                principal.getName()
            );
            moderationService.logAction(
                principal,
                AdminAuditService.ACTION_UPDATE,
                "registration",
                id,
                "Modification du dossier d'inscription « " + fullName + " ».",
                changeReason
            );
            return "redirect:/admin/registrations/" + id + "?success=updated";
        } catch (IllegalArgumentException ex) {
            return "redirect:/admin/registrations/" + id + "?error="
                + URLEncoder.encode(ex.getMessage(), StandardCharsets.UTF_8);
        }
    }

    @PostMapping("/admin/registrations/delete")
    public String deleteRegistration(
        @RequestParam long id,
        @RequestParam(required = false) String reason,
        Principal principal
    ) {
        try {
            boolean approved = registrationService.findDetailById(id)
                .map(com.payflex.backend.service.RegistrationService.RegistrationDetail::isApproved)
                .orElse(false);
            String redirectBase = approved ? "/admin/registrations?status=approved" : "/admin/registrations";
            return handleDeletionRedirect(
                "registration",
                id,
                "Inscription #" + id,
                reason,
                principal,
                redirectBase,
                () -> registrationService.deleteRegistration(id, principal.getName()),
                approved ? "archived" : "deleted"
            );
        } catch (IllegalArgumentException ex) {
            return redirectError("/admin/registrations", ex.getMessage());
        }
    }

    private String redirectError(String basePath, String message) {
        return "redirect:" + basePath + "?error=" + URLEncoder.encode(message, StandardCharsets.UTF_8);
    }

    private String handleDeletionRedirect(
        String entityType,
        long entityId,
        String entityLabel,
        String reason,
        Principal principal,
        String redirectBase,
        Runnable executeDelete
    ) {
        return handleDeletionRedirect(entityType, entityId, entityLabel, reason, principal, redirectBase, executeDelete, "1");
    }

    private String handleDeletionRedirect(
        String entityType,
        long entityId,
        String entityLabel,
        String reason,
        Principal principal,
        String redirectBase,
        Runnable executeDelete,
        String successCode
    ) {
        AdminModerationService.DeletionOutcome outcome = moderationService.handleDeletion(
            entityType,
            entityId,
            entityLabel,
            reason,
            principal,
            executeDelete
        );
        if (outcome.errorMessage() != null) {
            return redirectError(redirectBase, outcome.errorMessage());
        }
        if (outcome.deletionRequested()) {
            return "redirect:" + redirectBase + (redirectBase.contains("?") ? "&" : "?") + "success=delete_requested";
        }
        String code = successCode == null || successCode.isBlank() ? "1" : successCode;
        return "redirect:" + redirectBase + (redirectBase.contains("?") ? "&" : "?") + "success=" + code;
    }

    private void executeDeletion(String entityType, long entityId, String reviewedBy) {
        switch (entityType) {
            case "user" -> adminCrudService.deleteUser(entityId);
            case "agent" -> adminCrudService.deleteAgent(entityId);
            case "product" -> adminCrudService.deleteProduct(entityId);
            case "product_category" -> productCategoryService.delete(entityId);
            case "zone" -> adminCrudService.deleteZone(entityId);
            case "contribution" -> adminCrudService.deleteContribution(entityId);
            case "registration" -> registrationService.deleteRegistration(entityId, reviewedBy);
            default -> throw new IllegalArgumentException("Type de suppression non géré : " + entityType);
        }
    }

    private static Long parseOptionalLong(String raw) {
        if (raw == null || raw.isBlank()) {
            return null;
        }
        try {
            long v = Long.parseLong(raw.trim());
            return v > 0 ? v : null;
        } catch (NumberFormatException e) {
            return null;
        }
    }

    @GetMapping("/admin/agents/{agentId}")
    public String agentDetails(@org.springframework.web.bind.annotation.PathVariable long agentId, Model model) {
        model.addAttribute("activePage", "agents");
        var details = adminCrudService.getAgentDetails(agentId);
        model.addAttribute("agentDetails", details);
        model.addAttribute("agentClients", adminCrudService.getAgentClients(agentId));
        model.addAttribute("agentRecentContributions", adminCrudService.getRecentContributionsForAgent(agentId, 25));
        model.addAttribute("agentPendingCash", contributionWorkflowService.pendingCashSummaryForAgent(agentId));
        model.addAttribute("agentDebtEvents", contributionWorkflowService.listAgentCashDebtEvents(details.userId(), 20));
        model.addAttribute("agentDebtRepayments", contributionWorkflowService.listAgentDebtRepayments(details.userId(), 20));
        return "agent-detail";
    }

    @GetMapping("/admin/agents/{agentId}/photo")
    public ResponseEntity<Resource> agentPhoto(@PathVariable long agentId) {
        return serveAgentDossierFile(agentId, "photo");
    }

    @GetMapping("/admin/agents/{agentId}/identity")
    public ResponseEntity<Resource> agentIdentity(@PathVariable long agentId) {
        return serveAgentDossierFile(agentId, "identity");
    }

    @GetMapping("/admin/agents/{agentId}/contract")
    public ResponseEntity<Resource> agentContract(@PathVariable long agentId) {
        return serveAgentDossierFile(agentId, "contract");
    }

    private ResponseEntity<Resource> serveAgentDossierFile(long agentId, String kind) {
        Optional<Path> opt = adminCrudService.resolveAgentDossierFile(agentId, kind);
        if (opt.isEmpty()) {
            return ResponseEntity.notFound().build();
        }
        Path path = opt.get();
        Resource resource = new FileSystemResource(path.toFile());
        try {
            String ct = Files.probeContentType(path);
            MediaType mediaType = ct != null ? MediaType.parseMediaType(ct) : MediaType.APPLICATION_OCTET_STREAM;
            String filename = path.getFileName() != null ? path.getFileName().toString() : "piece";
            return ResponseEntity.ok()
                .contentType(mediaType)
                .header(HttpHeaders.CONTENT_DISPOSITION, "inline; filename=\"" + filename.replace("\"", "") + "\"")
                .body(resource);
        } catch (Exception e) {
            return ResponseEntity.notFound().build();
        }
    }

    @GetMapping("/admin/clients")
    public String clients(
        Model model,
        @RequestParam(defaultValue = "0") int page,
        @RequestParam(defaultValue = "80") int size,
        @RequestParam(required = false) String q,
        @RequestParam(required = false) String city,
        @RequestParam(required = false) String status,
        @RequestParam(required = false) String adhesion,
        @RequestParam(required = false) String assiduity
    ) {
        model.addAttribute("activePage", "clients");
        model.addAttribute("clientsPage", clientAdhesionService.clientsPage(q, city, status, adhesion, assiduity, page, size));
        model.addAttribute("q", q);
        model.addAttribute("city", city);
        model.addAttribute("status", status);
        model.addAttribute("adhesion", adhesion);
        model.addAttribute("assiduity", assiduity);
        model.addAttribute("adhesionFeeFcfa", ClientAdhesionService.ADHESION_FEE_FCFA);
        putFilterQuery(model, "q", q, "city", city, "status", status, "adhesion", adhesion, "assiduity", assiduity);
        return "clients";
    }

    @GetMapping("/admin/clients/assiduous-print")
    public String assiduousClientsPrint(
        Model model,
        @RequestParam(name = "badge", defaultValue = "or") String badge
    ) {
        model.addAttribute("activePage", "clients");
        model.addAttribute("badge", badge);
        model.addAttribute("rows", clientAdhesionService.listAssiduousClientsForPrint(badge));
        return "clients-assiduous-print";
    }

    @GetMapping("/admin/clients/{clientId}")
    public String clientDetails(@org.springframework.web.bind.annotation.PathVariable long clientId, Model model) {
        model.addAttribute("activePage", "clients");
        model.addAttribute("client", adminCrudService.getClientDetails(clientId));
        model.addAttribute("adhesion", clientAdhesionService.clientAdhesionSummary(clientId));
        model.addAttribute("adhesionFeeFcfa", ClientAdhesionService.ADHESION_FEE_FCFA);
        model.addAttribute("clientMonthly", adminCrudService.clientMonthlyCollections(clientId));
        model.addAttribute("clientContributions", adminCrudService.getRecentContributionsForClient(clientId, 40));
        model.addAttribute("agentOptions", registrationService.agentOptions());
        model.addAttribute("deliveryCases", productDeliveryService.listOpenDeliveriesForClient(clientId));
        model.addAttribute("productProgressList", productDeliveryService.listProductProgress(clientId));
        model.addAttribute("credentialSummary", adminClientCredentialService.credentialSummary(clientId));
        model.addAttribute("clientEdit", adminClientCredentialService.loadClientEditRow(clientId));
        return "client-detail";
    }

    @PostMapping(
        value = "/admin/clients/{clientId}/credentials/reveal",
        produces = MediaType.APPLICATION_JSON_VALUE
    )
    @ResponseBody
    public ResponseEntity<Map<String, Object>> revealClientCredentials(
        @PathVariable long clientId,
        @RequestParam String adminPassword,
        Principal principal
    ) {
        try {
            return ResponseEntity.ok(adminClientCredentialService.revealCredentials(
                clientId,
                principal.getName(),
                adminPassword
            ));
        } catch (IllegalArgumentException ex) {
            return ResponseEntity.status(403).body(Map.of("error", ex.getMessage()));
        }
    }

    @PostMapping("/admin/clients/{clientId}/credentials/recovery-request")
    public String adminCredentialRecoveryRequest(
        @PathVariable long clientId,
        Principal principal,
        RedirectAttributes redirectAttributes
    ) {
        try {
            adminClientCredentialService.openRecoveryRequest(
                clientId,
                "admin",
                "Signalement manuel depuis la fiche client."
            );
            redirectAttributes.addFlashAttribute("success", true);
            redirectAttributes.addFlashAttribute("successText", "Demande de rappel identifiants enregistrée.");
        } catch (IllegalArgumentException ex) {
            redirectAttributes.addFlashAttribute("error", true);
            redirectAttributes.addFlashAttribute("errorText", ex.getMessage());
        }
        return "redirect:/admin/clients/" + clientId;
    }

    @PostMapping("/admin/clients/{clientId}/credentials/recovery-resolve")
    public String resolveCredentialRecovery(
        @PathVariable long clientId,
        Principal principal,
        RedirectAttributes redirectAttributes
    ) {
        adminClientCredentialService.resolveRecoveryRequest(clientId, principal.getName());
        redirectAttributes.addFlashAttribute("success", true);
        redirectAttributes.addFlashAttribute("successText", "Demande de rappel identifiants clôturée.");
        return "redirect:/admin/clients/" + clientId;
    }

    @PostMapping("/admin/clients/{clientId}/profile/update")
    public String updateClientProfile(
        @PathVariable long clientId,
        @RequestParam String fullName,
        @RequestParam(required = false) String email,
        @RequestParam(required = false) String gender,
        @RequestParam(required = false) String city,
        @RequestParam(required = false) String profession,
        @RequestParam(required = false) String status,
        @RequestParam(required = false) String workplaceName,
        @RequestParam(required = false) String workplaceAddress,
        @RequestParam(required = false) String bossName,
        @RequestParam(required = false) String bossPhone,
        @RequestParam(required = false) String newPin,
        @RequestParam(required = false) String newAccountPassword,
        @RequestParam(required = false) String changeReason,
        Principal principal,
        RedirectAttributes redirectAttributes
    ) {
        Optional<String> reasonErr = moderationService.validateChangeReason(changeReason);
        if (reasonErr.isPresent()) {
            redirectAttributes.addFlashAttribute("error", true);
            redirectAttributes.addFlashAttribute("errorText", reasonErr.get());
            return "redirect:/admin/clients/" + clientId;
        }
        try {
            adminClientCredentialService.updateClientProfile(
                clientId,
                fullName,
                email,
                gender,
                city,
                profession,
                status,
                workplaceName,
                workplaceAddress,
                bossName,
                bossPhone,
                newPin,
                newAccountPassword
            );
            moderationService.logAction(
                principal,
                AdminAuditService.ACTION_UPDATE_STATUS,
                "client",
                clientId,
                "Mise à jour fiche client #" + clientId,
                changeReason
            );
            redirectAttributes.addFlashAttribute("success", true);
            redirectAttributes.addFlashAttribute("successText", "Fiche client mise à jour.");
        } catch (IllegalArgumentException ex) {
            redirectAttributes.addFlashAttribute("error", true);
            redirectAttributes.addFlashAttribute("errorText", ex.getMessage());
        }
        return "redirect:/admin/clients/" + clientId;
    }

    @GetMapping("/admin/deliveries")
    public String deliveries(
        Model model,
        @RequestParam(required = false) String status
    ) {
        model.addAttribute("activePage", "deliveries");
        model.addAttribute("statusFilter", status);
        model.addAttribute("deliveries", productDeliveryService.listDeliveries(status, 120));
        model.addAttribute("awaitingClosureCount", productDeliveryService.countAwaitingClosure());
        model.addAttribute("awaitingDeliveryCount", productDeliveryService.countAwaitingDelivery());
        return "deliveries";
    }

    @PostMapping("/admin/clients/{clientId}/delivery/open")
    public String openDeliveryCase(
        @PathVariable long clientId,
        @RequestParam long productId,
        Principal principal,
        RedirectAttributes redirectAttributes
    ) {
        try {
            productDeliveryService.openClosureCase(clientId, productId, principal.getName());
            redirectAttributes.addFlashAttribute("success", true);
            redirectAttributes.addFlashAttribute("successText", "Dossier clôture / livraison ouvert.");
        } catch (IllegalArgumentException ex) {
            redirectAttributes.addFlashAttribute("error", true);
            redirectAttributes.addFlashAttribute("errorText", ex.getMessage());
        }
        return "redirect:/admin/clients/" + clientId;
    }

    @PostMapping("/admin/deliveries/{deliveryId}/validate-closure")
    public String validateDeliveryClosure(
        @PathVariable long deliveryId,
        @RequestParam(required = false) String adminNote,
        @RequestParam(required = false) String changeReason,
        @RequestParam(defaultValue = "false") boolean forceDespiteCatchup,
        Principal principal,
        RedirectAttributes redirectAttributes
    ) {
        Optional<String> reasonErr = moderationService.validateChangeReason(changeReason);
        if (reasonErr.isPresent()) {
            return redirectError("/admin/deliveries", reasonErr.get());
        }
        try {
            productDeliveryService.validateClosure(deliveryId, principal.getName(), adminNote, forceDespiteCatchup);
            moderationService.logAction(
                principal,
                AdminAuditService.ACTION_UPDATE_STATUS,
                "delivery",
                deliveryId,
                "Validation de clôture carnet / solde (dossier #" + deliveryId + ").",
                changeReason
            );
            redirectAttributes.addFlashAttribute("success", true);
            redirectAttributes.addFlashAttribute("successText", "Clôture validée — le client et l’agent sont notifiés.");
        } catch (IllegalArgumentException ex) {
            redirectAttributes.addFlashAttribute("error", true);
            redirectAttributes.addFlashAttribute("errorText", ex.getMessage());
        }
        return "redirect:/admin/deliveries";
    }

    @PostMapping("/admin/deliveries/{deliveryId}/confirm-delivery")
    public String confirmProductDelivery(
        @PathVariable long deliveryId,
        @RequestParam(required = false) String deliveryNote,
        @RequestParam(required = false) String stockReference,
        @RequestParam(required = false) String changeReason,
        Principal principal,
        RedirectAttributes redirectAttributes
    ) {
        Optional<String> reasonErr = moderationService.validateChangeReason(changeReason);
        if (reasonErr.isPresent()) {
            return redirectError("/admin/deliveries", reasonErr.get());
        }
        try {
            productDeliveryService.confirmDelivery(
                deliveryId,
                principal.getName(),
                deliveryNote,
                stockReference
            );
            moderationService.logAction(
                principal,
                AdminAuditService.ACTION_UPDATE_STATUS,
                "delivery",
                deliveryId,
                "Livraison équipement enregistrée (dossier #" + deliveryId + ").",
                changeReason
            );
            redirectAttributes.addFlashAttribute("success", true);
            redirectAttributes.addFlashAttribute("successText", "Livraison enregistrée — cycle terminé.");
        } catch (IllegalArgumentException ex) {
            redirectAttributes.addFlashAttribute("error", true);
            redirectAttributes.addFlashAttribute("errorText", ex.getMessage());
        }
        return "redirect:/admin/deliveries";
    }

    @PostMapping("/admin/clients/{clientId}/assign-agent")
    public String assignClientAgent(
        @PathVariable long clientId,
        @RequestParam(required = false) String assignedAgentUserId,
        Principal principal,
        RedirectAttributes redirectAttributes
    ) {
        try {
            Long agentId = parseOptionalLong(assignedAgentUserId);
            clientAdhesionService.assignAgentToClient(clientId, agentId, principal.getName());
            redirectAttributes.addFlashAttribute("success", true);
            redirectAttributes.addFlashAttribute("successText", "Agent parrain mis à jour — visible immédiatement dans l’app client.");
            if (agentId != null && agentId > 0) {
                redirectAttributes.addFlashAttribute(
                    "clientOutreachMessage",
                    clientAdhesionService.buildClientOutreachMessage(clientId, agentId)
                );
            }
        } catch (IllegalArgumentException ex) {
            redirectAttributes.addFlashAttribute("error", true);
            redirectAttributes.addFlashAttribute("errorText", ex.getMessage());
        }
        return "redirect:/admin/clients/" + clientId;
    }

    @PostMapping("/admin/clients/{clientId}/adhesion/confirm")
    public String confirmClientAdhesion(
        @PathVariable long clientId,
        Principal principal,
        RedirectAttributes redirectAttributes
    ) {
        try {
            clientAdhesionService.markAdhesionPaidByAdmin(clientId, principal.getName());
            redirectAttributes.addFlashAttribute("success", true);
            redirectAttributes.addFlashAttribute("successText", "Adhésion confirmée — le client est maintenant adhérent.");
        } catch (IllegalArgumentException ex) {
            redirectAttributes.addFlashAttribute("error", true);
            redirectAttributes.addFlashAttribute("errorText", ex.getMessage());
        }
        return "redirect:/admin/clients/" + clientId;
    }

    @PostMapping("/admin/clients/{clientId}/adhesion/dispute/resolve")
    public String resolveAdhesionDispute(
        @PathVariable long clientId,
        Principal principal,
        @RequestParam(defaultValue = "true") boolean markPaid,
        @RequestParam(required = false) String adminNote,
        RedirectAttributes redirectAttributes
    ) {
        try {
            clientAdhesionService.resolveDispute(clientId, markPaid, principal.getName(), adminNote);
            redirectAttributes.addFlashAttribute("success", true);
            redirectAttributes.addFlashAttribute("successText", markPaid
                ? "Litige clos : adhésion enregistrée."
                : "Litige clos sans confirmation de paiement.");
        } catch (IllegalArgumentException ex) {
            redirectAttributes.addFlashAttribute("error", true);
            redirectAttributes.addFlashAttribute("errorText", ex.getMessage());
        }
        return "redirect:/admin/clients/" + clientId;
    }

    @PostMapping("/admin/clients/{clientId}/self-managed")
    public String toggleSelfManaged(
        @PathVariable long clientId,
        Principal principal,
        @RequestParam boolean value,
        RedirectAttributes redirectAttributes
    ) {
        clientAdhesionService.setSelfManaged(clientId, value, principal.getName());
        redirectAttributes.addFlashAttribute("success", true);
        redirectAttributes.addFlashAttribute("successText", value
            ? "Client marqué autonome (sans agent affiché)."
            : "Mode autonome désactivé.");
        return "redirect:/admin/clients/" + clientId;
    }

    @GetMapping("/admin/products/{productId}")
    public String productDetails(@org.springframework.web.bind.annotation.PathVariable long productId, Model model) {
        model.addAttribute("activePage", "products");
        model.addAttribute("product", adminCrudService.getProductDetails(productId));
        model.addAttribute("productContributions", adminCrudService.getProductContributions(productId));
        return "product-detail";
    }

    @GetMapping("/admin/mon-profil")
    public String monProfilGestionnaire(Principal principal) {
        return "redirect:/admin/gestionnaires/" + principal.getName();
    }

    @GetMapping("/admin/gestionnaires")
    @PreAuthorize("hasRole('ADMIN')")
    public String gestionnairesList(Model model) {
        model.addAttribute("activePage", "gestionnaires");
        model.addAttribute("gestionnaires", gestionnaireService.listGestionnaires());
        return "gestionnaires";
    }

    @GetMapping("/admin/gestionnaires/nouveau")
    @PreAuthorize("hasRole('ADMIN')")
    public String gestionnaireHireForm(Model model) {
        model.addAttribute("activePage", "gestionnaires");
        return "gestionnaire-hire";
    }

    @PostMapping(value = "/admin/gestionnaires/nouveau", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    @PreAuthorize("hasRole('ADMIN')")
    public String gestionnaireHireSubmit(
        Principal principal,
        RedirectAttributes redirectAttributes,
        @RequestParam String username,
        @RequestParam String password,
        @RequestParam String passwordConfirm,
        @RequestParam String fullName,
        @RequestParam(required = false) String email,
        @RequestParam(required = false) String phone,
        @RequestParam(required = false) String gender,
        @RequestParam(required = false) String city,
        @RequestParam(required = false) String personalAddress,
        @RequestParam(required = false) String matricule,
        @RequestParam(required = false) String hireDate,
        @RequestParam(required = false) String contractType,
        @RequestParam(required = false) String contractSignedDate,
        @RequestParam(required = false) String jobTitle,
        @RequestParam(required = false) String emergencyContactName,
        @RequestParam(required = false) String emergencyContactPhone,
        @RequestParam(required = false) String emergencyContactRelation,
        @RequestParam(required = false) String notifyContactName,
        @RequestParam(required = false) String notifyContactPhone,
        @RequestParam(required = false) String notifyContactRelation,
        @RequestParam(required = false) String guarantorName,
        @RequestParam(required = false) String guarantorPhone,
        @RequestParam(required = false) String guarantorRelation,
        @RequestParam(required = false) String secondaryContactName,
        @RequestParam(required = false) String secondaryContactPhone,
        @RequestParam(required = false) String supervisorName,
        @RequestParam(required = false) String supervisorPhone,
        @RequestParam(required = false) String referencesNotes,
        @RequestParam(required = false) String internalNotes,
        @RequestParam(required = false) MultipartFile idDocument,
        @RequestParam(required = false) MultipartFile contractDocument,
        @RequestParam(required = false) MultipartFile photo
    ) {
        if (password == null || !password.equals(passwordConfirm)) {
            redirectAttributes.addFlashAttribute("errorMessage", "Les mots de passe ne correspondent pas.");
            return "redirect:/admin/gestionnaires/nouveau";
        }
        try {
            gestionnaireService.createGestionnaire(
                username, password, fullName, email, phone, gender, city, personalAddress,
                matricule, hireDate, contractType, contractSignedDate,
                jobTitle == null || jobTitle.isBlank() ? "Gestionnaire PayFlex" : jobTitle,
                emergencyContactName, emergencyContactPhone, emergencyContactRelation,
                notifyContactName, notifyContactPhone, notifyContactRelation,
                guarantorName, guarantorPhone, guarantorRelation,
                secondaryContactName, secondaryContactPhone,
                supervisorName, supervisorPhone,
                referencesNotes, internalNotes,
                idDocument, contractDocument, photo
            );
            adminAuditService.logEquipe(
                principal.getName(),
                "Création du compte gestionnaire « " + username.trim().toLowerCase() + " » avec dossier RH."
            );
            return "redirect:/admin/gestionnaires/" + username.trim().toLowerCase() + "?created=1";
        } catch (IllegalArgumentException ex) {
            redirectAttributes.addFlashAttribute("errorMessage", ex.getMessage());
            return "redirect:/admin/gestionnaires/nouveau";
        } catch (Exception ex) {
            redirectAttributes.addFlashAttribute("errorMessage", "Enregistrement impossible : " + ex.getMessage());
            return "redirect:/admin/gestionnaires/nouveau";
        }
    }

    @GetMapping("/admin/gestionnaires/{username}")
    public String gestionnaireProfil(
        @PathVariable String username,
        Principal principal,
        Model model
    ) {
        if (!canViewGestionnaire(username, principal)) {
            return "redirect:/admin?forbidden=1";
        }
        var profile = gestionnaireService.getProfile(username);
        if (profile.isEmpty()) {
            return moderationService.isAdmin() ? "redirect:/admin/gestionnaires" : "redirect:/admin?forbidden=1";
        }
        model.addAttribute("activePage", moderationService.isAdmin() ? "gestionnaires" : "mon-profil");
        model.addAttribute("profile", profile.get());
        model.addAttribute("ownProfile", principal.getName().equals(username));
        model.addAttribute("readOnlyInternalNotes", !moderationService.isAdmin());
        return "gestionnaire-profil";
    }

    @PostMapping(value = "/admin/gestionnaires/{username}/update", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    public String gestionnaireProfilUpdate(
        @PathVariable String username,
        Principal principal,
        RedirectAttributes redirectAttributes,
        @RequestParam(required = false) String changeReason,
        @RequestParam String fullName,
        @RequestParam(required = false) String email,
        @RequestParam(required = false) String phone,
        @RequestParam(required = false) String gender,
        @RequestParam(required = false) String city,
        @RequestParam(required = false) String personalAddress,
        @RequestParam(required = false) String matricule,
        @RequestParam(required = false) String hireDate,
        @RequestParam(required = false) String contractType,
        @RequestParam(required = false) String contractSignedDate,
        @RequestParam(required = false) String jobTitle,
        @RequestParam(required = false) String emergencyContactName,
        @RequestParam(required = false) String emergencyContactPhone,
        @RequestParam(required = false) String emergencyContactRelation,
        @RequestParam(required = false) String notifyContactName,
        @RequestParam(required = false) String notifyContactPhone,
        @RequestParam(required = false) String notifyContactRelation,
        @RequestParam(required = false) String guarantorName,
        @RequestParam(required = false) String guarantorPhone,
        @RequestParam(required = false) String guarantorRelation,
        @RequestParam(required = false) String secondaryContactName,
        @RequestParam(required = false) String secondaryContactPhone,
        @RequestParam(required = false) String supervisorName,
        @RequestParam(required = false) String supervisorPhone,
        @RequestParam(required = false) String referencesNotes,
        @RequestParam(required = false) String internalNotes,
        @RequestParam(required = false) MultipartFile idDocument,
        @RequestParam(required = false) MultipartFile contractDocument,
        @RequestParam(required = false) MultipartFile photo
    ) {
        if (!canViewGestionnaire(username, principal)) {
            return "redirect:/admin?forbidden=1";
        }
        Optional<String> reasonErr = moderationService.validateChangeReason(changeReason);
        if (reasonErr.isPresent()) {
            redirectAttributes.addFlashAttribute("errorMessage", reasonErr.get());
            return "redirect:/admin/gestionnaires/" + username;
        }
        try {
            gestionnaireService.updateProfile(
                username, fullName, email, phone, gender, city, personalAddress,
                matricule, hireDate, contractType, contractSignedDate, jobTitle,
                emergencyContactName, emergencyContactPhone, emergencyContactRelation,
                notifyContactName, notifyContactPhone, notifyContactRelation,
                guarantorName, guarantorPhone, guarantorRelation,
                secondaryContactName, secondaryContactPhone,
                supervisorName, supervisorPhone,
                referencesNotes, internalNotes,
                idDocument, contractDocument, photo
            );
            moderationService.logAction(
                principal,
                "UPDATE",
                "gestionnaire",
                null,
                "Mise à jour du dossier gestionnaire « " + username + " ».",
                changeReason
            );
            return "redirect:/admin/gestionnaires/" + username + "?saved=1";
        } catch (IllegalArgumentException ex) {
            redirectAttributes.addFlashAttribute("errorMessage", ex.getMessage());
            return "redirect:/admin/gestionnaires/" + username;
        } catch (Exception ex) {
            redirectAttributes.addFlashAttribute("errorMessage", "Mise à jour impossible.");
            return "redirect:/admin/gestionnaires/" + username;
        }
    }

    @GetMapping("/admin/gestionnaires/{username}/photo")
    public ResponseEntity<Resource> gestionnairePhoto(@PathVariable String username, Principal principal) {
        if (!canViewGestionnaire(username, principal)) {
            return ResponseEntity.status(403).build();
        }
        return serveGestionnaireFile(username, "photo");
    }

    @GetMapping("/admin/gestionnaires/{username}/identity")
    public ResponseEntity<Resource> gestionnaireIdentity(@PathVariable String username, Principal principal) {
        if (!canViewGestionnaire(username, principal)) {
            return ResponseEntity.status(403).build();
        }
        return serveGestionnaireFile(username, "identity");
    }

    @GetMapping("/admin/gestionnaires/{username}/contract")
    public ResponseEntity<Resource> gestionnaireContract(@PathVariable String username, Principal principal) {
        if (!canViewGestionnaire(username, principal)) {
            return ResponseEntity.status(403).build();
        }
        return serveGestionnaireFile(username, "contract");
    }

    private boolean canViewGestionnaire(String username, Principal principal) {
        if (moderationService.isAdmin()) {
            return gestionnaireService.isGestionnaireAccount(username);
        }
        return principal != null && principal.getName().equals(username)
            && gestionnaireService.isGestionnaireAccount(username);
    }

    private ResponseEntity<Resource> serveGestionnaireFile(String username, String kind) {
        Optional<Path> opt = gestionnaireService.resolveDossierFile(username, kind);
        if (opt.isEmpty()) {
            return ResponseEntity.notFound().build();
        }
        Path path = opt.get();
        Resource resource = new FileSystemResource(path.toFile());
        try {
            String ct = Files.probeContentType(path);
            MediaType mediaType = ct != null ? MediaType.parseMediaType(ct) : MediaType.APPLICATION_OCTET_STREAM;
            String filename = path.getFileName() != null ? path.getFileName().toString() : "piece";
            return ResponseEntity.ok()
                .contentType(mediaType)
                .header(HttpHeaders.CONTENT_DISPOSITION, "inline; filename=\"" + filename.replace("\"", "") + "\"")
                .body(resource);
        } catch (IOException ex) {
            return ResponseEntity.internalServerError().build();
        }
    }

    @GetMapping("/admin/support-chat")
    public String supportChatIndex(@RequestParam(required = false) Long open, Model model) {
        model.addAttribute("activePage", "support-chat");
        model.addAttribute("threads", supportChatService.listThreads());
        model.addAttribute("broadcastZones", supportChatService.listZonesForBroadcast());
        model.addAttribute("broadcastClients", supportChatService.listClientTargetsForBroadcast());
        if (open != null && open > 0) {
            model.addAttribute("openUserId", open);
            adminCrudService.findUserById(open).ifPresent(u -> model.addAttribute("openThreadUser", u));
            model.addAttribute("openMessages", supportChatService.messagesForUser(open, 500));
        }
        return "support-chat";
    }

    @PostMapping("/admin/support-chat/broadcast")
    public String supportChatBroadcast(
        @RequestParam String targetType,
        @RequestParam(required = false) Long zoneId,
        @RequestParam(required = false) List<Long> userIds,
        @RequestParam(required = false) String title,
        @RequestParam String body,
        Principal principal
    ) {
        try {
            int count = supportChatService.sendBroadcast(
                targetType,
                zoneId,
                userIds,
                title,
                body,
                principal.getName()
            );
            adminAuditService.logEquipe(
                principal.getName(),
                "Envoi groupé chat (" + targetType + ", " + count + " client(s))."
            );
            return "redirect:/admin/support-chat?broadcastOk=" + count;
        } catch (IllegalArgumentException ex) {
            return "redirect:/admin/support-chat?broadcastError=" + java.net.URLEncoder.encode(
                ex.getMessage(),
                java.nio.charset.StandardCharsets.UTF_8
            );
        }
    }

    @GetMapping("/admin/support-chat/{userId}")
    public String supportChatThreadLegacy(@PathVariable long userId) {
        return "redirect:/admin/support-chat?open=" + userId;
    }

    @PostMapping("/admin/support-chat/send")
    public String supportChatReply(
        @RequestParam long userId,
        @RequestParam String body,
        Principal principal
    ) {
        try {
            supportChatService.addMessage(userId, "admin", body);
            adminAuditService.logEquipe(
                principal.getName(),
                "Réponse au chat support (utilisateur #" + userId + ")."
            );
        } catch (IllegalArgumentException ex) {
            return "redirect:/admin/support-chat?open=" + userId + "&error=1";
        }
        return "redirect:/admin/support-chat?open=" + userId + "&sent=1";
    }

    @PostMapping("/admin/support-chat/delete-message")
    public String supportChatDeleteMessage(
        @RequestParam long messageId,
        @RequestParam long userId,
        Principal principal
    ) {
        int n = supportChatService.deleteMessage(messageId, null);
        if (n > 0) {
            adminAuditService.logEquipe(
                principal.getName(),
                "Suppression message chat #" + messageId + " (utilisateur #" + userId + ")."
            );
        }
        return "redirect:/admin/support-chat?open=" + userId + (n > 0 ? "&msgDeleted=1" : "&msgDeleteError=1");
    }

    @PostMapping("/admin/support-chat/delete-thread")
    public String supportChatDeleteThread(
        @RequestParam long userId,
        Principal principal
    ) {
        int n = supportChatService.deleteThread(userId);
        if (n > 0) {
            adminAuditService.logEquipe(
                principal.getName(),
                "Suppression conversation chat support (utilisateur #" + userId + ", " + n + " message(s))."
            );
        }
        return "redirect:/admin/support-chat" + (n > 0 ? "?threadDeleted=1" : "?threadDeleteError=1");
    }

    @GetMapping("/admin/support-chat/api/messages")
    @ResponseBody
    public List<Map<String, Object>> supportChatMessagesApi(@RequestParam long userId) {
        if (userId <= 0) {
            return List.of();
        }
        List<Map<String, Object>> rows = supportChatService.messagesForUser(userId, 500);
        List<Map<String, Object>> out = new ArrayList<>(rows.size());
        for (Map<String, Object> r : rows) {
            out.add(mapAdminChatMessageRow(r));
        }
        return out;
    }

    @GetMapping("/admin/support-chat/api/threads")
    @ResponseBody
    public List<Map<String, Object>> supportChatThreadsApi() {
        return supportChatService.listThreads();
    }

    @PostMapping("/admin/support-chat/api/send")
    @ResponseBody
    public ResponseEntity<?> supportChatSendApi(
        @RequestParam long userId,
        @RequestParam String body,
        Principal principal
    ) {
        if (userId <= 0) {
            return ResponseEntity.badRequest().body(Map.of("message", "Client invalide."));
        }
        try {
            long messageId = supportChatService.addAdminMessage(userId, body);
            adminAuditService.logEquipe(
                principal.getName(),
                "Réponse au chat support (utilisateur #" + userId + ")."
            );
            return ResponseEntity.ok(Map.of("ok", true, "id", messageId));
        } catch (IllegalArgumentException ex) {
            return ResponseEntity.badRequest().body(Map.of("message", ex.getMessage()));
        }
    }

    private static Map<String, Object> mapAdminChatMessageRow(Map<String, Object> r) {
        Map<String, Object> m = new LinkedHashMap<>();
        m.put("id", r.get("id"));
        m.put("body", r.get("body"));
        m.put("sender", r.get("sender"));
        m.put("created_at", r.get("created_at"));
        Object url = r.get("attachment_url");
        if (url != null && !String.valueOf(url).isBlank()) {
            m.put("attachment_url", url);
            m.put("attachment_kind", r.get("attachment_kind"));
            m.put("attachment_name", r.get("attachment_name"));
            m.put("attachment_mime", r.get("attachment_mime"));
        }
        return m;
    }

    /** Chaîne de requête pour conserver les filtres dans la pagination (Thymeleaf). */
    private static void validateAccountPasswordPair(String password, String confirm) {
        String p = password == null ? "" : password.trim();
        String c = confirm == null ? "" : confirm.trim();
        if (p.length() < 8) {
            throw new IllegalArgumentException("Le mot de passe doit contenir au moins 8 caractères.");
        }
        if (!p.equals(c)) {
            throw new IllegalArgumentException("Les mots de passe ne correspondent pas.");
        }
    }

    private static void putFilterQuery(Model model, String... keyValuePairs) {
        if (keyValuePairs.length % 2 != 0) {
            throw new IllegalArgumentException("Nombre pair de paramètres requis (clé, valeur).");
        }
        StringBuilder sb = new StringBuilder();
        for (int i = 0; i < keyValuePairs.length; i += 2) {
            String key = keyValuePairs[i];
            String value = keyValuePairs[i + 1];
            if (value == null || value.isBlank()) {
                continue;
            }
            if (!sb.isEmpty()) {
                sb.append('&');
            }
            sb.append(key).append('=').append(URLEncoder.encode(value.trim(), StandardCharsets.UTF_8));
        }
        model.addAttribute("filterQuery", sb.isEmpty() ? "" : sb.toString());
    }
}
