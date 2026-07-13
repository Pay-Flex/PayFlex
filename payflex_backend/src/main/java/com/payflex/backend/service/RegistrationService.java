package com.payflex.backend.service;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.web.multipart.MultipartFile;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.StandardCopyOption;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;

@Service
public class RegistrationService {

    private static final Logger log = LoggerFactory.getLogger(RegistrationService.class);

    private final JdbcTemplate jdbcTemplate;
    private final AdminAuditService auditService;
    private final CredentialHashService credentialHashService;
    private final UserContactUniquenessService contactUniqueness;
    private final ClientAdhesionService clientAdhesionService;
    private final UserInboxNotificationService inboxNotifications;
    private final CredentialVaultService credentialVaultService;
    private final AdminWebPushService adminWebPushService;
    private final Path uploadRoot;

    public RegistrationService(
        JdbcTemplate jdbcTemplate,
        AdminAuditService auditService,
        CredentialHashService credentialHashService,
        UserContactUniquenessService contactUniqueness,
        ClientAdhesionService clientAdhesionService,
        UserInboxNotificationService inboxNotifications,
        CredentialVaultService credentialVaultService,
        AdminWebPushService adminWebPushService
    ) throws IOException {
        this.jdbcTemplate = jdbcTemplate;
        this.auditService = auditService;
        this.credentialHashService = credentialHashService;
        this.contactUniqueness = contactUniqueness;
        this.clientAdhesionService = clientAdhesionService;
        this.inboxNotifications = inboxNotifications;
        this.credentialVaultService = credentialVaultService;
        this.adminWebPushService = adminWebPushService;
        this.uploadRoot = Path.of("uploads", "registrations");
        Files.createDirectories(uploadRoot);
    }

    public long submit(RegistrationInput input, MultipartFile profilePhoto, MultipartFile idDocument) throws IOException {
        RegistrationInput normalized = withNormalizedGender(input);
        validate(normalized);
        log.info("submit phone={} role={}", maskPhone(normalized.phone()), normalized.requestedRole());
        Optional<Long> existingPending = Optional.empty();
        if (normalized.phone() != null && !normalized.phone().isBlank()) {
            existingPending = findPendingIdByPhone(normalized.phone());
        }
        if (existingPending.isPresent()) {
            log.info("Demande pending existante id={} → resubmit", existingPending.get());
            return resubmitPendingRegistration(existingPending.get(), normalized, profilePhoto, idDocument);
        }
        Long existingClientId = null;
        if (normalized.phone() != null && !normalized.phone().isBlank()) {
            existingClientId = findClientUserIdByPhone(normalized.phone());
            if (existingClientId != null && existingClientId > 0) {
                String clientStatus = jdbcTemplate.queryForObject(
                    "SELECT status FROM users WHERE id = ? LIMIT 1",
                    String.class,
                    existingClientId
                );
                if (clientStatus != null && clientStatus.equalsIgnoreCase("pending")) {
                    contactUniqueness.assertPhoneAvailable(normalized.phone(), existingClientId);
                } else {
                    contactUniqueness.assertPhoneAvailable(normalized.phone(), null);
                }
            } else {
                contactUniqueness.assertPhoneAvailable(normalized.phone(), null);
            }
        }
        contactUniqueness.assertEmailAvailable(normalized.email(), existingClientId);
        if (!"agent".equalsIgnoreCase(normalized.submittedBy())) {
            if (profilePhoto == null || profilePhoto.isEmpty()) {
                throw new IllegalArgumentException("Photo de profil requise.");
            }
            if (!normalized.idDocumentWaived() && (idDocument == null || idDocument.isEmpty())) {
                throw new IllegalArgumentException(
                    "Pièce d'identité requise, ou cochez l'option « je n'ai pas de carte d'identité ni passeport »."
                );
            }
        }
        String photoPath = storeFile(profilePhoto, "profile");
        String docPath = normalized.idDocumentWaived() ? null : storeFile(idDocument, "identity");
        StoredCredentials creds = hashCredentialsForStorage(normalized.pin(), normalized.accountPassword());

        jdbcTemplate.update(
            """
            INSERT INTO registration_requests (
              full_name, phone, city, profession, gender, submitted_by, requested_role,
              submitted_by_agent_user_id, assigned_agent_user_id, pin, secret_code, account_password, unique_code,
              workplace_name, workplace_address, boss_name, boss_phone, profile_photo_path, id_document_path,
              id_document_waived
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            normalized.fullName(), normalized.phone(), normalized.city(), normalized.profession(), normalized.gender(),
            normalized.submittedBy(), normalized.requestedRole(), normalized.submittedByAgentUserId(), normalized.assignedAgentUserId(),
            creds.pin(), creds.secretCode(), creds.accountPassword(), normalized.uniqueCode(), normalized.workplaceName(), normalized.workplaceAddress(),
            normalized.bossName(), normalized.bossPhone(), photoPath, docPath, normalized.idDocumentWaived()
        );
        Long id = jdbcTemplate.queryForObject("SELECT LAST_INSERT_ID()", Long.class);
        long savedId = id == null ? 0L : id;
        credentialVaultService.storeForRegistrationRequest(
            savedId,
            normalized.pin(),
            normalized.accountPassword()
        );
        log.info("Inscription sauvegardée id={} phone={}", savedId, maskPhone(normalized.phone()));
        if ("self".equalsIgnoreCase(normalized.submittedBy())) {
            RegistrationInput activationInput = asClientAccountInput(normalized);
            finalizeClientSelfRegistration(savedId, activationInput, photoPath, docPath);
            persistClientProfileSegment(savedId, normalized);
            log.info("Client activé (valide) phone={} segment={}", maskPhone(normalized.phone()), normalized.requestedRole());
        } else if ("client".equalsIgnoreCase(normalized.requestedRole())
            || "agent".equalsIgnoreCase(normalized.submittedBy())) {
            RegistrationInput activationInput = "agent".equalsIgnoreCase(normalized.submittedBy())
                ? asClientAccountInput(normalized)
                : normalized;
            finalizeClientSelfRegistration(savedId, activationInput, photoPath, docPath);
            log.info("Client activé (valide) phone={}", maskPhone(normalized.phone()));
        }
        if ("agent".equalsIgnoreCase(normalized.submittedBy())
            && normalized.submittedByAgentUserId() != null
            && normalized.submittedByAgentUserId() > 0) {
            auditService.logAgent(
                normalized.submittedByAgentUserId(),
                "A déposé une demande d'inscription au nom de « " + normalized.fullName() + " »."
            );
        } else {
            auditService.logVisiteur(
                normalized.fullName(),
                "Souhaite rejoindre PayFlex : demande envoyée depuis l'application (téléphone " + normalized.phone() + ")."
            );
        }
        // Web Push temps réel vers les postes admin/support (ignoré si VAPID non configuré).
        adminWebPushService.notifyAllAdmins(
            "Nouvelle inscription PayFlex",
            normalized.fullName() + " a envoyé une demande d'inscription.",
            "/admin/registrations"
        );
        return savedId;
    }

    public AdminCrudService.PageResult<RegistrationRow> page(String q, String status, int page, int size) {
        size = AdminCrudService.normalizePageSize(size);
        String where = " WHERE 1=1 ";
        var args = new java.util.ArrayList<Object>();
        if (q != null && !q.isBlank()) {
            where += " AND (reg.full_name LIKE ? OR reg.phone LIKE ? OR reg.profession LIKE ?) ";
            String like = "%" + q.trim() + "%";
            args.add(like); args.add(like); args.add(like);
        }
        if (status != null && !status.isBlank()) {
            where += " AND reg.status = ? ";
            args.add(status);
        }
        long total = jdbcTemplate.queryForObject(
            "SELECT COUNT(*) FROM registration_requests reg " + where,
            args.toArray(),
            Long.class
        );
        args.add(size);
        args.add(page * size);
        List<RegistrationRow> rows = jdbcTemplate.query(
            """
            SELECT reg.id, reg.full_name, reg.phone, reg.city, reg.profession, reg.gender, reg.requested_role,
                   reg.submitted_by, reg.assigned_agent_user_id, reg.unique_code, reg.status, reg.created_at,
                   reg.workplace_name, reg.workplace_address, reg.boss_name, reg.boss_phone,
                   (
                     SELECT u.id FROM users u
                     INNER JOIN roles r ON r.id = u.role_id AND r.code = 'client'
                     WHERE TRIM(u.phone) = TRIM(reg.phone)
                        OR REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(TRIM(u.phone), ' ', ''), '-', ''), '(', ''), ')', ''), '+', '')
                           = REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(TRIM(reg.phone), ' ', ''), '-', ''), '(', ''), ')', ''), '+', '')
                     ORDER BY u.id DESC
                     LIMIT 1
                   ) AS linked_client_user_id
            FROM registration_requests reg
            """ + where + " ORDER BY reg.created_at DESC LIMIT ? OFFSET ?",
            args.toArray(),
            (rs, i) -> new RegistrationRow(
                rs.getLong("id"),
                rs.getString("full_name"),
                rs.getString("phone"),
                rs.getString("city"),
                rs.getString("profession"),
                rs.getString("gender"),
                rs.getString("requested_role"),
                rs.getString("submitted_by"),
                rs.getObject("assigned_agent_user_id") == null ? null : rs.getLong("assigned_agent_user_id"),
                rs.getString("unique_code"),
                rs.getString("status"),
                rs.getString("created_at"),
                rs.getString("workplace_name"),
                rs.getString("workplace_address"),
                rs.getString("boss_name"),
                rs.getString("boss_phone"),
                rs.getObject("linked_client_user_id") == null ? null : rs.getLong("linked_client_user_id")
            )
        );
        return AdminCrudService.PageResult.of(rows, page, size, total);
    }

    public long countByStatus(String status) {
        if (status == null || status.isBlank()) {
            return jdbcTemplate.queryForObject("SELECT COUNT(*) FROM registration_requests", Long.class);
        }
        Long n = jdbcTemplate.queryForObject(
            "SELECT COUNT(*) FROM registration_requests WHERE status = ?",
            Long.class,
            status
        );
        return n == null ? 0L : n;
    }

    public void decide(long requestId, String decision, Long assignedAgentUserId, String adminUsername, String adminNote) {
        if (!"approved".equals(decision) && !"rejected".equals(decision)) {
            throw new IllegalArgumentException("Décision invalide");
        }
        if ("rejected".equals(decision) && (adminNote == null || adminNote.isBlank())) {
            throw new IllegalArgumentException("Indiquez un motif de refus dans le commentaire interne.");
        }
        var req = jdbcTemplate.queryForList("SELECT * FROM registration_requests WHERE id = ? LIMIT 1", requestId);
        if (req.isEmpty()) throw new IllegalArgumentException("Demande introuvable");
        var row = req.get(0);
        Long agentFromClient = toLong(row.get("assigned_agent_user_id"));
        Long finalAgentId = assignedAgentUserId != null && assignedAgentUserId > 0
            ? assignedAgentUserId
            : agentFromClient;

        jdbcTemplate.update(
            """
            UPDATE registration_requests
            SET status = ?, assigned_agent_user_id = ?, admin_note = ?, reviewed_at = NOW(), reviewed_by_admin = ?
            WHERE id = ?
            """,
            decision, finalAgentId, adminNote, adminUsername, requestId
        );

        if ("approved".equals(decision)) {
            Long clientRoleId = jdbcTemplate.queryForObject(
                "SELECT id FROM roles WHERE code = 'client' LIMIT 1",
                Long.class
            );
            Long existingUserId = findClientUserIdByPhone(String.valueOf(row.get("phone")));
            long linkedUserId;
            if (existingUserId != null && existingUserId > 0) {
                jdbcTemplate.update(
                    """
                    UPDATE users SET
                      full_name = ?, role_id = ?, city = ?, profession = ?, gender = ?, status = 'valide',
                      pin = ?, secret_code = ?, account_password = COALESCE(account_password, ?), unique_code = ?,
                      assigned_agent_user_id = ?,
                      profile_photo_path = ?, id_document_path = ?,
                      workplace_name = ?, workplace_address = ?, boss_name = ?, boss_phone = ?
                    WHERE id = ?
                    """,
                    row.get("full_name"), clientRoleId, row.get("city"), row.get("profession"), row.get("gender"),
                    row.get("pin"), row.get("secret_code"), row.get("account_password"), row.get("unique_code"), finalAgentId,
                    row.get("profile_photo_path"), row.get("id_document_path"),
                    row.get("workplace_name"), row.get("workplace_address"), row.get("boss_name"), row.get("boss_phone"),
                    existingUserId
                );
                linkedUserId = existingUserId;
            } else {
                jdbcTemplate.update(
                    """
                    INSERT INTO users (
                      full_name, phone, role_id, city, profession, gender, status, pin, secret_code, account_password, unique_code,
                      assigned_agent_user_id, profile_photo_path, id_document_path, workplace_name, workplace_address, boss_name, boss_phone
                    ) VALUES (?, ?, ?, ?, ?, ?, 'valide', ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                    """,
                    row.get("full_name"), row.get("phone"), clientRoleId, row.get("city"), row.get("profession"),
                    row.get("gender"),
                    row.get("pin"), row.get("secret_code"), row.get("account_password"), row.get("unique_code"),
                    finalAgentId, row.get("profile_photo_path"), row.get("id_document_path"),
                    row.get("workplace_name"), row.get("workplace_address"), row.get("boss_name"), row.get("boss_phone")
                );
                Long newId = jdbcTemplate.queryForObject("SELECT LAST_INSERT_ID()", Long.class);
                linkedUserId = newId == null ? 0L : newId;
            }
            if (linkedUserId > 0) {
                credentialVaultService.copyRegistrationVaultToUser(requestId, linkedUserId);
            }
        } else if ("rejected".equals(decision)) {
            Long existingUserId = findClientUserIdByPhone(String.valueOf(row.get("phone")));
            if (existingUserId != null && existingUserId > 0) {
                jdbcTemplate.update("UPDATE users SET status = 'bloque' WHERE id = ? AND status = 'pending'", existingUserId);
            }
        }
        String nom = row.get("full_name") != null ? row.get("full_name").toString() : "Personne concernée";
        String tel = row.get("phone") != null ? row.get("phone").toString() : "";
        Long clientUserId = findClientUserIdByPhone(tel);
        if ("approved".equals(decision)) {
            auditService.logEquipe(
                adminUsername,
                "Validation : « " + nom + " » (" + tel + ") peut désormais utiliser PayFlex en tant que client."
            );
            if (clientUserId != null && clientUserId > 0) {
                inboxNotifications.notifyClientAndAssignedAgent(
                    clientUserId,
                    "account_approved",
                    "Compte validé",
                    "Votre inscription PayFlex est approuvée. Finalisez l’adhésion (250 FCFA) pour activer les cotisations.",
                    "Inscription validée — {client}",
                    "Le compte de {client} est validé. Accompagnez-le pour l’adhésion et la première cotisation.",
                    null
                );
            }
        } else {
            auditService.logEquipe(
                adminUsername,
                "Refus : la demande de « " + nom + " » (" + tel + ") n'a pas été retenue."
            );
            if (clientUserId != null && clientUserId > 0) {
                String motif = adminNote != null && !adminNote.isBlank()
                    ? adminNote.trim()
                    : "Demande non retenue par le centre PayFlex.";
                inboxNotifications.notifyClientAndAssignedAgent(
                    clientUserId,
                    "account_rejected",
                    "Inscription refusée",
                    motif,
                    "Inscription refusée — {client}",
                    "L’inscription de {client} a été refusée : " + motif,
                    null
                );
            }
        }
    }

    public List<AgentOption> agentOptions() {
        return jdbcTemplate.query(
            """
            SELECT u.id, u.full_name FROM users u
            JOIN roles r ON r.id = u.role_id
            WHERE r.code = 'agent' AND u.status = 'valide'
            ORDER BY u.full_name
            """,
            (rs, i) -> new AgentOption(rs.getLong("id"), rs.getString("full_name"))
        );
    }

    private RegistrationInput withNormalizedGender(RegistrationInput input) {
        String pin = unifiedPlainPin(input);
        String password = unifiedPlainAccountPassword(input);
        return new RegistrationInput(
            input.fullName(),
            input.phone(),
            input.email(),
            input.city(),
            input.profession(),
            normalizeGender(input.gender()),
            input.submittedBy(),
            input.requestedRole(),
            input.submittedByAgentUserId(),
            input.assignedAgentUserId(),
            pin,
            pin,
            password,
            input.uniqueCode(),
            input.workplaceName(),
            input.workplaceAddress(),
            input.bossName(),
            input.bossPhone(),
            input.idDocumentWaived()
        );
    }

    private String unifiedPlainPin(RegistrationInput input) {
        String pin = input.pin() == null ? "" : input.pin().trim();
        if (pin.isEmpty()) {
            throw new IllegalArgumentException("Code PIN requis (4 chiffres).");
        }
        if (!credentialHashService.isMobilePinFormat(pin)) {
            throw new IllegalArgumentException("Le code PIN doit contenir exactement 4 à 12 chiffres.");
        }
        return pin;
    }

    private String unifiedPlainAccountPassword(RegistrationInput input) {
        String password = input.accountPassword();
        if (password == null || password.isBlank()) {
            password = input.secretCode();
        }
        if (password == null || password.isBlank()) {
            throw new IllegalArgumentException("Mot de passe requis (minimum 6 caractères).");
        }
        password = password.trim();
        if (password.length() < 6) {
            throw new IllegalArgumentException("Mot de passe requis (minimum 6 caractères).");
        }
        credentialHashService.validateMobileCredential(password);
        return password;
    }

    private record StoredCredentials(String pin, String secretCode, String accountPassword) {}

    private StoredCredentials hashCredentialsForStorage(String plainPin, String plainPassword) {
        String pin = plainPin == null ? "" : plainPin.trim();
        String password = plainPassword == null ? "" : plainPassword.trim();
        if (!credentialHashService.isMobilePinFormat(pin)) {
            throw new IllegalArgumentException("Le code PIN doit contenir 4 à 12 chiffres.");
        }
        credentialHashService.validateMobileCredential(password);
        String hashedPin = credentialHashService.hashMobilePin(pin);
        String hashedPassword = credentialHashService.hashMobileCredential(password);
        return new StoredCredentials(hashedPin, hashedPin, hashedPassword);
    }

    /** @deprecated utiliser {@link #hashCredentialsForStorage} */
    private String[] hashPinForStorage(String plainPin) {
        StoredCredentials c = hashCredentialsForStorage(plainPin, plainPin);
        return new String[] { c.pin(), c.secretCode() };
    }

    static String normalizeGender(String gender) {
        if (gender == null || gender.isBlank()) {
            return "";
        }
        String g = gender.trim();
        if (g.equalsIgnoreCase("homme") || g.equalsIgnoreCase("male") || g.equals("M")) {
            return "M";
        }
        if (g.equalsIgnoreCase("femme") || g.equalsIgnoreCase("female") || g.equals("F")) {
            return "F";
        }
        if (g.equalsIgnoreCase("autre")) {
            return "Autre";
        }
        return g.length() > 20 ? g.substring(0, 20) : g;
    }

    private void validate(RegistrationInput input) {
        String requestedRole = input.requestedRole() == null || input.requestedRole().isBlank()
            ? "client"
            : input.requestedRole().trim().toLowerCase(Locale.ROOT);
        if ("agent".equals(requestedRole) || "admin".equals(requestedRole) || "gestionnaire".equals(requestedRole)) {
            throw new IllegalArgumentException(
                "Les comptes agent et équipe sont créés par un administrateur ou gestionnaire PayFlex, pas depuis l'application mobile."
            );
        }
        if (input.fullName() == null || input.fullName().isBlank()) throw new IllegalArgumentException("Nom requis");
        boolean agentEnrollment = "agent".equalsIgnoreCase(input.submittedBy());
        if (!agentEnrollment && (input.phone() == null || input.phone().isBlank())) {
            throw new IllegalArgumentException("Téléphone requis");
        }
        if (agentEnrollment && (input.uniqueCode() == null || input.uniqueCode().isBlank())) {
            throw new IllegalArgumentException("Code client interne requis pour l'inscription agent.");
        }
        String emailNorm = UserContactUniquenessService.normalizeEmail(input.email());
        if (input.email() != null && !input.email().isBlank() && (emailNorm == null || !input.email().trim().contains("@"))) {
            throw new IllegalArgumentException("Adresse e-mail invalide.");
        }
        if (input.pin() == null || input.pin().isBlank()) {
            throw new IllegalArgumentException("Code PIN requis (4 chiffres).");
        }
        if (input.accountPassword() == null || input.accountPassword().isBlank()) {
            throw new IllegalArgumentException("Mot de passe requis (minimum 6 caractères).");
        }
        if ("self".equalsIgnoreCase(input.submittedBy())
            && input.assignedAgentUserId() != null
            && input.assignedAgentUserId() > 0
            && !isValidAgentUserId(input.assignedAgentUserId())) {
            throw new IllegalArgumentException("Agent PayFlex invalide ou indisponible.");
        }
    }

    private boolean isMobileClientSelfRegistration(RegistrationInput input) {
        return "self".equalsIgnoreCase(input.submittedBy());
    }

    /** Compte toujours « client » ; le segment métier reste dans registration_requests.requested_role. */
    private RegistrationInput asClientAccountInput(RegistrationInput normalized) {
        return new RegistrationInput(
            normalized.fullName(),
            normalized.phone(),
            normalized.email(),
            normalized.city(),
            normalized.profession(),
            normalized.gender(),
            normalized.submittedBy(),
            "client",
            normalized.submittedByAgentUserId(),
            normalized.assignedAgentUserId(),
            normalized.pin(),
            normalized.secretCode(),
            normalized.accountPassword(),
            normalized.uniqueCode(),
            normalized.workplaceName(),
            normalized.workplaceAddress(),
            normalized.bossName(),
            normalized.bossPhone(),
            normalized.idDocumentWaived()
        );
    }

    private void persistClientProfileSegment(long requestId, RegistrationInput normalized) {
        String segment = normalized.requestedRole() == null ? "" : normalized.requestedRole().trim();
        if (segment.isEmpty() || "client".equalsIgnoreCase(segment)) {
            return;
        }
        jdbcTemplate.update(
            "UPDATE registration_requests SET requested_role = ? WHERE id = ?",
            segment.length() > 40 ? segment.substring(0, 40) : segment,
            requestId
        );
    }

    /**
     * Inscription client mobile : compte actif immédiatement, adhésion 250 FCFA ensuite (agent ou PayDunya).
     */
    private void finalizeClientSelfRegistration(
        long requestId,
        RegistrationInput input,
        String photoPath,
        String docPath
    ) {
        syncClientUserFromRegistration(input, photoPath, docPath);
        Long userId = resolveClientUserId(input);
        if (userId != null && userId > 0) {
            credentialVaultService.copyRegistrationVaultToUser(requestId, userId);
        }
        jdbcTemplate.update(
            """
            UPDATE registration_requests
            SET status = 'approved', assigned_agent_user_id = ?, admin_note = ?,
                reviewed_at = NOW(), reviewed_by_admin = 'auto-mobile'
            WHERE id = ?
            """,
            input.assignedAgentUserId(),
            "Inscription automatique — adhésion " + ClientAdhesionService.ADHESION_FEE_FCFA + " FCFA requise.",
            requestId
        );
        if (userId != null && userId > 0) {
            clientAdhesionService.onClientAccountOpened(userId, input.assignedAgentUserId());
        }
        String contactLabel = input.phone() != null && !input.phone().isBlank()
            ? "téléphone " + input.phone()
            : "code " + input.uniqueCode();
        auditService.logVisiteur(
            input.fullName(),
            "Compte PayFlex ouvert depuis l'application (" + contactLabel + "). Adhésion à finaliser."
        );
    }

    private boolean isValidAgentUserId(long agentUserId) {
        Long n = jdbcTemplate.queryForObject(
            """
            SELECT COUNT(*) FROM users u
            INNER JOIN roles r ON r.id = u.role_id
            WHERE u.id = ? AND r.code = 'agent' AND u.status = 'valide'
            """,
            Long.class,
            agentUserId
        );
        return n != null && n > 0;
    }

    private String storeFile(MultipartFile file, String prefix) throws IOException {
        if (file == null || file.isEmpty()) return null;
        String ext = "";
        String original = file.getOriginalFilename();
        if (original != null && original.contains(".")) {
            ext = original.substring(original.lastIndexOf('.'));
        }
        String name = prefix + "_" + LocalDateTime.now().format(DateTimeFormatter.ofPattern("yyyyMMddHHmmss")) + "_" + UUID.randomUUID() + ext;
        Path target = uploadRoot.resolve(name);
        Files.copy(file.getInputStream(), target, StandardCopyOption.REPLACE_EXISTING);
        return target.toString().replace("\\", "/");
    }

    public record RegistrationInput(
        String fullName,
        String phone,
        String email,
        String city,
        String profession,
        String gender,
        String submittedBy,
        String requestedRole,
        Long submittedByAgentUserId,
        Long assignedAgentUserId,
        String pin,
        String secretCode,
        String accountPassword,
        String uniqueCode,
        String workplaceName,
        String workplaceAddress,
        String bossName,
        String bossPhone,
        boolean idDocumentWaived
    ) {}

    public record RegistrationRow(
        long id,
        String fullName,
        String phone,
        String city,
        String profession,
        String gender,
        String requestedRole,
        String submittedBy,
        Long assignedAgentUserId,
        String uniqueCode,
        String status,
        String createdAt,
        String workplaceName,
        String workplaceAddress,
        String bossName,
        String bossPhone,
        Long linkedClientUserId
    ) {}

    /**
     * Fiche admin complète (documents, statut, agents liés).
     */
    public record RegistrationDetail(
        long id,
        String fullName,
        String phone,
        String city,
        String profession,
        String gender,
        String requestedRole,
        String submittedBy,
        Long submittedByAgentUserId,
        String submittedByAgentName,
        Long assignedAgentUserId,
        String assignedAgentName,
        String uniqueCode,
        String status,
        String createdAt,
        String reviewedAt,
        String reviewedByAdmin,
        String adminNote,
        String workplaceName,
        String workplaceAddress,
        String bossName,
        String bossPhone,
        String profilePhotoPath,
        String idDocumentPath,
        boolean idDocumentWaived,
        boolean pinDefined,
        boolean secretDefined
    ) {
        public boolean isPending() {
            return "pending".equals(status);
        }

        public boolean isDeletable() {
            return true;
        }

        public boolean isApproved() {
            return "approved".equals(status);
        }
    }

    public record RegistrationPatch(
        String fullName,
        String phone,
        String city,
        String profession,
        String gender,
        String workplaceName,
        String workplaceAddress,
        String bossName,
        String bossPhone,
        Long assignedAgentUserId
    ) {}

    public record AgentOption(long id, String fullName) {}

    public Optional<RegistrationDetail> findDetailById(long id) {
        List<RegistrationDetail> list = jdbcTemplate.query(
            """
            SELECT r.id, r.full_name, r.phone, r.city, r.profession, r.gender, r.requested_role, r.submitted_by,
                   r.submitted_by_agent_user_id, sb.full_name AS submitted_by_agent_name,
                   r.assigned_agent_user_id, ag.full_name AS assigned_agent_name,
                   r.unique_code, r.status, r.created_at, r.reviewed_at, r.reviewed_by_admin, r.admin_note,
                   r.workplace_name, r.workplace_address, r.boss_name, r.boss_phone,
                   r.profile_photo_path, r.id_document_path, r.id_document_waived, r.pin, r.secret_code
            FROM registration_requests r
            LEFT JOIN users ag ON ag.id = r.assigned_agent_user_id
            LEFT JOIN users sb ON sb.id = r.submitted_by_agent_user_id
            WHERE r.id = ?
            LIMIT 1
            """,
            (rs, i) -> {
                String pin = rs.getString("pin");
                String sec = rs.getString("secret_code");
                return new RegistrationDetail(
                    rs.getLong("id"),
                    rs.getString("full_name"),
                    rs.getString("phone"),
                    rs.getString("city"),
                    rs.getString("profession"),
                    rs.getString("gender"),
                    rs.getString("requested_role"),
                    rs.getString("submitted_by"),
                    rs.getObject("submitted_by_agent_user_id") == null ? null : rs.getLong("submitted_by_agent_user_id"),
                    rs.getString("submitted_by_agent_name"),
                    rs.getObject("assigned_agent_user_id") == null ? null : rs.getLong("assigned_agent_user_id"),
                    rs.getString("assigned_agent_name"),
                    rs.getString("unique_code"),
                    rs.getString("status"),
                    rs.getString("created_at"),
                    rs.getString("reviewed_at"),
                    rs.getString("reviewed_by_admin"),
                    rs.getString("admin_note"),
                    rs.getString("workplace_name"),
                    rs.getString("workplace_address"),
                    rs.getString("boss_name"),
                    rs.getString("boss_phone"),
                    rs.getString("profile_photo_path"),
                    rs.getString("id_document_path"),
                    rs.getBoolean("id_document_waived"),
                    pin != null && !pin.isBlank(),
                    sec != null && !sec.isBlank()
                );
            },
            id
        );
        if (list.isEmpty()) {
            return Optional.empty();
        }
        return Optional.of(list.get(0));
    }

    /**
     * Met à jour une demande encore en attente (pas le PIN ni le code secret — définis côté mobile).
     */
    public void updatePending(long id, RegistrationPatch patch, String adminUsername) {
        if (patch.fullName() == null || patch.fullName().isBlank()) {
            throw new IllegalArgumentException("Le nom est obligatoire.");
        }
        if (patch.phone() == null || patch.phone().isBlank()) {
            throw new IllegalArgumentException("Le téléphone est obligatoire.");
        }
        int n = jdbcTemplate.update(
            """
            UPDATE registration_requests SET
              full_name = ?, phone = ?, city = ?, profession = ?, gender = ?,
              workplace_name = ?, workplace_address = ?, boss_name = ?, boss_phone = ?,
              assigned_agent_user_id = ?
            WHERE id = ? AND status = 'pending'
            """,
            patch.fullName().trim(),
            patch.phone().trim(),
            nullToBlank(patch.city()),
            nullToBlank(patch.profession()),
            normalizeGender(patch.gender()),
            nullToBlank(patch.workplaceName()),
            nullToBlank(patch.workplaceAddress()),
            nullToBlank(patch.bossName()),
            nullToBlank(patch.bossPhone()),
            patch.assignedAgentUserId(),
            id
        );
        if (n == 0) {
            throw new IllegalArgumentException("Dossier introuvable ou déjà traité — impossible de modifier.");
        }
        auditService.logEquipe(adminUsername, "Mise à jour de la demande d'inscription (réf. #" + id + ").");
    }

    /**
     * Supprime une demande d'inscription (fichiers joints retirés du disque si possible).
     * Si le dossier est déjà approuvé, seul l'historique est retiré — le compte client reste actif.
     */
    public void deleteRegistration(long id, String adminUsername) {
        List<Map<String, Object>> rows = jdbcTemplate.queryForList(
            "SELECT status, profile_photo_path, id_document_path, full_name, phone FROM registration_requests WHERE id = ?",
            id
        );
        if (rows.isEmpty()) {
            throw new IllegalArgumentException("Demande introuvable.");
        }
        var row = rows.get(0);
        String st = row.get("status") != null ? row.get("status").toString() : "";
        deleteStoredFile(objectToString(row.get("profile_photo_path")));
        deleteStoredFile(objectToString(row.get("id_document_path")));
        jdbcTemplate.update("DELETE FROM registration_requests WHERE id = ?", id);
        String nom = objectToString(row.get("full_name"));
        if ("approved".equals(st)) {
            auditService.logEquipe(
                adminUsername,
                "Retrait de l'historique — inscription approuvée « " + nom + " » (réf. #" + id + "). Le compte client reste actif."
            );
            return;
        }
        auditService.logEquipe(adminUsername, "Suppression de la demande d'inscription « " + nom + " » (réf. #" + id + ").");
    }

    private static String objectToString(Object o) {
        return o == null ? null : o.toString();
    }

    private static String nullToBlank(String s) {
        return s == null ? "" : s.trim();
    }

    private static Long toLong(Object o) {
        if (o == null) {
            return null;
        }
        if (o instanceof Number n) {
            return n.longValue();
        }
        try {
            return Long.parseLong(o.toString());
        } catch (NumberFormatException ex) {
            return null;
        }
    }

    private void deleteStoredFile(String pathStr) {
        if (pathStr == null || pathStr.isBlank()) return;
        try {
            Path p = Path.of(pathStr);
            if (!p.isAbsolute()) {
                p = Path.of("").toAbsolutePath().resolve(p).normalize();
            }
            Files.deleteIfExists(p);
        } catch (IOException ignored) {
            // fichier déjà absent ou verrou — la ligne DB est quand même supprimée
        }
    }

    public Optional<Path> resolveStoredAttachment(long registrationId, boolean profile) {
        Optional<RegistrationDetail> d = findDetailById(registrationId);
        if (d.isEmpty()) {
            return Optional.empty();
        }
        String rel = profile ? d.get().profilePhotoPath() : d.get().idDocumentPath();
        if (rel == null || rel.isBlank()) {
            return Optional.empty();
        }
        Path root = Path.of("").toAbsolutePath().normalize();
        Path filePath = Path.of(rel);
        if (!filePath.isAbsolute()) {
            filePath = root.resolve(filePath).normalize();
        }
        Path allowed = root.resolve("uploads").resolve("registrations").normalize();
        if (!filePath.startsWith(allowed) || !Files.isRegularFile(filePath)) {
            return Optional.empty();
        }
        return Optional.of(filePath);
    }

    /**
     * Évite les doublons : une seule demande « pending » par numéro de téléphone.
     */
    public Optional<Long> findPendingIdByPhone(String phoneRaw) {
        if (phoneRaw == null || phoneRaw.isBlank()) {
            return Optional.empty();
        }
        String trimmed = phoneRaw.trim();
        String digits = normalizePhoneDigits(trimmed);
        String digitsCompare = digits.isEmpty() ? trimmed : digits;
        List<Long> ids = jdbcTemplate.query(
            """
            SELECT id FROM registration_requests
            WHERE status IN ('pending', 'approved')
              AND (
                TRIM(phone) = ?
                OR REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(phone, ' ', ''), '-', ''), '(', ''), ')', ''), '+', '') = ?
              )
            ORDER BY id DESC
            LIMIT 1
            """,
            (rs, i) -> rs.getLong("id"),
            trimmed,
            digitsCompare
        );
        return ids.isEmpty() ? Optional.empty() : Optional.of(ids.get(0));
    }

    /**
     * Crée ou met à jour le compte client actif ({@code valide}) — adhésion 250 FCFA pour devenir adhérent.
     */
    private void syncClientUserFromRegistration(RegistrationInput input, String photoPath, String docPath) {
        Long clientRoleId = jdbcTemplate.queryForObject(
            "SELECT id FROM roles WHERE code = 'client' LIMIT 1",
            Long.class
        );
        StoredCredentials creds = hashCredentialsForStorage(input.pin(), input.accountPassword());
        Long existingUserId = resolveClientUserId(input);
        if (existingUserId != null && existingUserId > 0) {
            jdbcTemplate.update(
                """
                UPDATE users SET
                  full_name = ?, email = ?, role_id = ?, city = ?, profession = ?, gender = ?, status = 'valide',
                  pin = ?, secret_code = ?, account_password = ?, unique_code = ?, assigned_agent_user_id = ?,
                  profile_photo_path = ?, id_document_path = ?,
                  workplace_name = ?, workplace_address = ?, boss_name = ?, boss_phone = ?
                WHERE id = ?
                """,
                input.fullName(), UserContactUniquenessService.normalizeEmail(input.email()), clientRoleId,
                input.city(), input.profession(), input.gender(),
                creds.pin(), creds.secretCode(), creds.accountPassword(), input.uniqueCode(), input.assignedAgentUserId(),
                photoPath, docPath, input.workplaceName(), input.workplaceAddress(), input.bossName(), input.bossPhone(),
                existingUserId
            );
            credentialVaultService.storeForUser(existingUserId, input.pin(), input.accountPassword());
            return;
        }
        jdbcTemplate.update(
            """
            INSERT INTO users (
              full_name, phone, email, role_id, city, profession, gender, status, pin, secret_code, account_password, unique_code,
              assigned_agent_user_id, profile_photo_path, id_document_path, workplace_name, workplace_address, boss_name, boss_phone
            ) VALUES (?, ?, ?, ?, ?, ?, ?, 'valide', ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            input.fullName(), input.phone(), UserContactUniquenessService.normalizeEmail(input.email()), clientRoleId,
            input.city(), input.profession(), input.gender(),
            creds.pin(), creds.secretCode(), creds.accountPassword(), input.uniqueCode(), input.assignedAgentUserId(),
            photoPath, docPath, input.workplaceName(), input.workplaceAddress(), input.bossName(), input.bossPhone()
        );
        Long newUserId = jdbcTemplate.queryForObject("SELECT LAST_INSERT_ID()", Long.class);
        if (newUserId != null && newUserId > 0) {
            credentialVaultService.storeForUser(newUserId, input.pin(), input.accountPassword());
        }
    }

    /** @deprecated compat interne — utiliser {@link #syncClientUserFromRegistration}. */
    private void syncPendingClientUser(RegistrationInput input, String photoPath, String docPath) {
        syncClientUserFromRegistration(input, photoPath, docPath);
    }

    /** Masque les derniers chiffres pour les logs — jamais le numéro complet. */
    private static String maskPhone(String phone) {
        if (phone == null || phone.isBlank()) return "(vide)";
        String digits = phone.replaceAll("\\D", "");
        if (digits.length() <= 4) return "****";
        return "***" + digits.substring(digits.length() - 4);
    }

    /**
     * Reprise après timeout ou double envoi : met à jour la demande et le compte client « pending »
     * avec le PIN saisi (en clair), sans re-hacher un hash déjà stocké.
     */
    private long resubmitPendingRegistration(
        long id,
        RegistrationInput input,
        MultipartFile profilePhoto,
        MultipartFile idDocument
    ) throws IOException {
        var rows = jdbcTemplate.queryForList(
            "SELECT * FROM registration_requests WHERE id = ? AND status IN ('pending', 'approved') LIMIT 1",
            id
        );
        if (rows.isEmpty()) {
            throw new IllegalArgumentException("Demande introuvable ou déjà traitée.");
        }
        var row = rows.get(0);
        String photoPath = row.get("profile_photo_path") != null ? row.get("profile_photo_path").toString() : null;
        String docPath = row.get("id_document_path") != null ? row.get("id_document_path").toString() : null;
        if (profilePhoto != null && !profilePhoto.isEmpty()) {
            photoPath = storeFile(profilePhoto, "profile");
        } else if (photoPath == null || photoPath.isBlank()) {
            throw new IllegalArgumentException("Photo de profil requise.");
        }
        if (!input.idDocumentWaived()) {
            if (idDocument != null && !idDocument.isEmpty()) {
                docPath = storeFile(idDocument, "identity");
            } else if (docPath == null || docPath.isBlank()) {
                throw new IllegalArgumentException(
                    "Pièce d'identité requise, ou cochez l'option « je n'ai pas de carte d'identité ni passeport »."
                );
            }
        } else {
            docPath = null;
        }
        StoredCredentials creds = hashCredentialsForStorage(input.pin(), input.accountPassword());
        credentialVaultService.storeForRegistrationRequest(id, input.pin(), input.accountPassword());
        jdbcTemplate.update(
            """
            UPDATE registration_requests SET
              full_name = ?, city = ?, profession = ?, gender = ?,
              assigned_agent_user_id = ?, pin = ?, secret_code = ?, account_password = ?, unique_code = ?,
              workplace_name = ?, workplace_address = ?, boss_name = ?, boss_phone = ?,
              profile_photo_path = ?, id_document_path = ?, id_document_waived = ?
            WHERE id = ? AND status = 'pending'
            """,
            input.fullName(), input.city(), input.profession(), input.gender(),
            input.assignedAgentUserId(), creds.pin(), creds.secretCode(), creds.accountPassword(), input.uniqueCode(),
            input.workplaceName(), input.workplaceAddress(), input.bossName(), input.bossPhone(),
            photoPath, docPath, input.idDocumentWaived(), id
        );
        if (isMobileClientSelfRegistration(input) || "client".equalsIgnoreCase(input.requestedRole())) {
            RegistrationInput activationInput = isMobileClientSelfRegistration(input)
                ? asClientAccountInput(input)
                : input;
            finalizeClientSelfRegistration(id, activationInput, photoPath, docPath);
            persistClientProfileSegment(id, input);
            log.info("resubmit: client activé id={} phone={}", id, maskPhone(input.phone()));
        }
        return id;
    }

    private void syncPendingClientUserFromRequest(long registrationRequestId) {
        var rows = jdbcTemplate.queryForList("SELECT * FROM registration_requests WHERE id = ? LIMIT 1", registrationRequestId);
        if (rows.isEmpty()) {
            return;
        }
        var row = rows.get(0);
        RegistrationInput input = new RegistrationInput(
            String.valueOf(row.get("full_name")),
            String.valueOf(row.get("phone")),
            null,
            row.get("city") != null ? row.get("city").toString() : null,
            row.get("profession") != null ? row.get("profession").toString() : null,
            row.get("gender") != null ? row.get("gender").toString() : null,
            String.valueOf(row.get("submitted_by")),
            String.valueOf(row.get("requested_role")),
            toLong(row.get("submitted_by_agent_user_id")),
            toLong(row.get("assigned_agent_user_id")),
            String.valueOf(row.get("pin")),
            String.valueOf(row.get("secret_code")),
            row.get("account_password") != null ? row.get("account_password").toString() : null,
            String.valueOf(row.get("unique_code")),
            row.get("workplace_name") != null ? row.get("workplace_name").toString() : null,
            row.get("workplace_address") != null ? row.get("workplace_address").toString() : null,
            row.get("boss_name") != null ? row.get("boss_name").toString() : null,
            row.get("boss_phone") != null ? row.get("boss_phone").toString() : null,
            Boolean.TRUE.equals(row.get("id_document_waived"))
        );
        String photo = row.get("profile_photo_path") != null ? row.get("profile_photo_path").toString() : null;
        String doc = row.get("id_document_path") != null ? row.get("id_document_path").toString() : null;
        if ("client".equalsIgnoreCase(input.requestedRole())) {
            syncPendingClientUser(input, photo, doc);
        }
    }

    public Optional<Long> linkedClientUserIdForPhone(String phoneRaw) {
        return Optional.ofNullable(findClientUserIdByPhone(phoneRaw));
    }

    public Optional<Long> linkedClientUserIdForUniqueCode(String uniqueCode) {
        return Optional.ofNullable(findClientUserIdByUniqueCode(uniqueCode));
    }

    private Long resolveClientUserId(RegistrationInput input) {
        Long byPhone = null;
        if (input.phone() != null && !input.phone().isBlank()) {
            byPhone = findClientUserIdByPhone(input.phone());
        }
        if (byPhone != null && byPhone > 0) {
            return byPhone;
        }
        return findClientUserIdByUniqueCode(input.uniqueCode());
    }

    private Long findClientUserIdByUniqueCode(String uniqueCode) {
        if (uniqueCode == null || uniqueCode.isBlank()) {
            return null;
        }
        List<Long> ids = jdbcTemplate.query(
            """
            SELECT u.id FROM users u
            INNER JOIN roles r ON r.id = u.role_id AND r.code = 'client'
            WHERE TRIM(u.unique_code) = ?
            ORDER BY u.id DESC
            LIMIT 1
            """,
            (rs, i) -> rs.getLong(1),
            uniqueCode.trim()
        );
        return ids.isEmpty() ? null : ids.get(0);
    }

    private Long findClientUserIdByPhone(String phoneRaw) {
        if (phoneRaw == null || phoneRaw.isBlank()) {
            return null;
        }
        String trimmed = phoneRaw.trim();
        String digits = normalizePhoneDigits(trimmed);
        String digitsCompare = digits.isEmpty() ? trimmed : digits;
        List<Long> ids = jdbcTemplate.query(
            """
            SELECT u.id FROM users u
            INNER JOIN roles r ON r.id = u.role_id AND r.code = 'client'
            WHERE TRIM(u.phone) = ?
               OR REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(TRIM(u.phone), ' ', ''), '-', ''), '(', ''), ')', ''), '+', '') = ?
            ORDER BY u.id DESC
            LIMIT 1
            """,
            (rs, i) -> rs.getLong(1),
            trimmed,
            digitsCompare
        );
        return ids.isEmpty() ? null : ids.get(0);
    }

    private static String normalizePhoneDigits(String phone) {
        if (phone == null) {
            return "";
        }
        StringBuilder sb = new StringBuilder();
        for (int i = 0; i < phone.length(); i++) {
            char c = phone.charAt(i);
            if (c >= '0' && c <= '9') {
                sb.append(c);
            }
        }
        return sb.toString();
    }
}
