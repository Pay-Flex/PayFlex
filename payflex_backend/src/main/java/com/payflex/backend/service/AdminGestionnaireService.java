package com.payflex.backend.service;

import org.springframework.dao.DuplicateKeyException;
import org.springframework.dao.EmptyResultDataAccessException;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.multipart.MultipartFile;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.StandardCopyOption;
import java.time.LocalDate;
import java.time.format.DateTimeFormatter;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Service
public class AdminGestionnaireService {

    private final JdbcTemplate jdbcTemplate;
    private final CredentialHashService credentialHashService;

    public AdminGestionnaireService(JdbcTemplate jdbcTemplate, CredentialHashService credentialHashService) {
        this.jdbcTemplate = jdbcTemplate;
        this.credentialHashService = credentialHashService;
    }

    public record GestionnaireListRow(
        String username,
        String fullName,
        String email,
        String phone,
        boolean enabled,
        String matricule,
        String jobTitle,
        boolean profileComplete
    ) {}

    public record GestionnaireProfile(
        String username,
        boolean enabled,
        String fullName,
        String email,
        String phone,
        String gender,
        String city,
        String personalAddress,
        String matricule,
        String hireDate,
        String contractType,
        String contractSignedDate,
        String jobTitle,
        String emergencyContactName,
        String emergencyContactPhone,
        String emergencyContactRelation,
        String notifyContactName,
        String notifyContactPhone,
        String notifyContactRelation,
        String guarantorName,
        String guarantorPhone,
        String guarantorRelation,
        String secondaryContactName,
        String secondaryContactPhone,
        String supervisorName,
        String supervisorPhone,
        String referencesNotes,
        String internalNotes,
        String idDocumentPath,
        String contractDocumentPath,
        String photoPath
    ) {
        public int completenessPercent() {
            int total = 18;
            int ok = 0;
            if (nz(fullName)) ok++;
            if (nz(phone)) ok++;
            if (nz(email)) ok++;
            if (nz(gender)) ok++;
            if (nz(city) || nz(personalAddress)) ok++;
            if (nz(matricule)) ok++;
            if (nz(hireDate)) ok++;
            if (nz(contractType)) ok++;
            if (nz(contractSignedDate)) ok++;
            if (nz(emergencyContactName) && nz(emergencyContactPhone)) ok++;
            if (nz(notifyContactName) && nz(notifyContactPhone)) ok++;
            if (nz(guarantorName) && nz(guarantorPhone)) ok++;
            if (nz(secondaryContactName)) ok++;
            if (nz(supervisorName)) ok++;
            if (nz(idDocumentPath)) ok++;
            if (nz(contractDocumentPath)) ok++;
            if (nz(photoPath)) ok++;
            if (nz(referencesNotes)) ok++;
            if (nz(jobTitle)) ok++;
            return Math.min(100, (ok * 100) / total);
        }

        private static boolean nz(String s) {
            return s != null && !s.isBlank();
        }
    }

    public boolean isGestionnaireAccount(String username) {
        if (username == null || username.isBlank()) {
            return false;
        }
        Long n = jdbcTemplate.queryForObject(
            """
            SELECT COUNT(*) FROM admin_authorities
            WHERE username = ? AND authority = 'ROLE_GESTIONNAIRE'
            """,
            Long.class,
            username.trim()
        );
        return n != null && n > 0;
    }

    public List<GestionnaireListRow> listGestionnaires() {
        return jdbcTemplate.query(
            """
            SELECT u.username, u.full_name, u.email, u.phone, u.enabled, u.matricule, u.job_title,
                   u.photo_path, u.id_document_path, u.contract_document_path,
                   u.emergency_contact_name, u.emergency_contact_phone,
                   u.notify_contact_name, u.guarantor_name, u.hire_date, u.contract_signed_date
            FROM admin_users u
            INNER JOIN admin_authorities a ON a.username = u.username AND a.authority = 'ROLE_GESTIONNAIRE'
            ORDER BY u.full_name ASC, u.username ASC
            """,
            (rs, i) -> new GestionnaireListRow(
                rs.getString("username"),
                rs.getString("full_name"),
                rs.getString("email"),
                rs.getString("phone"),
                rs.getBoolean("enabled"),
                rs.getString("matricule"),
                rs.getString("job_title"),
                hasText(rs.getString("photo_path"))
                    && hasText(rs.getString("id_document_path"))
                    && hasText(rs.getString("contract_document_path"))
                    && hasText(rs.getString("emergency_contact_name"))
                    && hasText(rs.getString("guarantor_name"))
                    && hasText(rs.getString("notify_contact_name"))
            )
        );
    }

    public Optional<GestionnaireProfile> getProfile(String username) {
        if (!isGestionnaireAccount(username)) {
            return Optional.empty();
        }
        try {
            return Optional.of(
                jdbcTemplate.queryForObject(
                    profileSelectSql() + " WHERE u.username = ?",
                    (rs, i) -> mapProfile(rs),
                    username.trim()
                )
            );
        } catch (EmptyResultDataAccessException ex) {
            return Optional.empty();
        }
    }

    @Transactional(rollbackFor = Exception.class)
    public void createGestionnaire(
        String username,
        String rawPassword,
        String fullName,
        String email,
        String phone,
        String gender,
        String city,
        String personalAddress,
        String matricule,
        String hireDateStr,
        String contractType,
        String contractSignedDateStr,
        String jobTitle,
        String emergencyContactName,
        String emergencyContactPhone,
        String emergencyContactRelation,
        String notifyContactName,
        String notifyContactPhone,
        String notifyContactRelation,
        String guarantorName,
        String guarantorPhone,
        String guarantorRelation,
        String secondaryContactName,
        String secondaryContactPhone,
        String supervisorName,
        String supervisorPhone,
        String referencesNotes,
        String internalNotes,
        MultipartFile idDocument,
        MultipartFile contractDocument,
        MultipartFile photo
    ) throws IOException {
        createTeamMember(
            "ROLE_GESTIONNAIRE",
            username,
            rawPassword,
            fullName,
            email,
            phone,
            gender,
            city,
            personalAddress,
            matricule,
            hireDateStr,
            contractType,
            contractSignedDateStr,
            jobTitle,
            emergencyContactName,
            emergencyContactPhone,
            emergencyContactRelation,
            notifyContactName,
            notifyContactPhone,
            notifyContactRelation,
            guarantorName,
            guarantorPhone,
            guarantorRelation,
            secondaryContactName,
            secondaryContactPhone,
            supervisorName,
            supervisorPhone,
            referencesNotes,
            internalNotes,
            idDocument,
            contractDocument,
            photo
        );
    }

    @Transactional(rollbackFor = Exception.class)
    public void createAdministrateur(
        String username,
        String rawPassword,
        String fullName,
        String email,
        String phone,
        String gender,
        String city,
        String personalAddress,
        String matricule,
        String hireDateStr,
        String contractType,
        String contractSignedDateStr,
        String jobTitle,
        String emergencyContactName,
        String emergencyContactPhone,
        String emergencyContactRelation,
        String notifyContactName,
        String notifyContactPhone,
        String notifyContactRelation,
        String guarantorName,
        String guarantorPhone,
        String guarantorRelation,
        String secondaryContactName,
        String secondaryContactPhone,
        String supervisorName,
        String supervisorPhone,
        String referencesNotes,
        String internalNotes,
        MultipartFile idDocument,
        MultipartFile contractDocument,
        MultipartFile photo
    ) throws IOException {
        String title = jobTitle == null || jobTitle.isBlank() ? "Administrateur PayFlex" : jobTitle;
        createTeamMember(
            "ROLE_ADMIN",
            username,
            rawPassword,
            fullName,
            email,
            phone,
            gender,
            city,
            personalAddress,
            matricule,
            hireDateStr,
            contractType,
            contractSignedDateStr,
            title,
            emergencyContactName,
            emergencyContactPhone,
            emergencyContactRelation,
            notifyContactName,
            notifyContactPhone,
            notifyContactRelation,
            guarantorName,
            guarantorPhone,
            guarantorRelation,
            secondaryContactName,
            secondaryContactPhone,
            supervisorName,
            supervisorPhone,
            referencesNotes,
            internalNotes,
            idDocument,
            contractDocument,
            photo
        );
    }

    private void createTeamMember(
        String authority,
        String username,
        String rawPassword,
        String fullName,
        String email,
        String phone,
        String gender,
        String city,
        String personalAddress,
        String matricule,
        String hireDateStr,
        String contractType,
        String contractSignedDateStr,
        String jobTitle,
        String emergencyContactName,
        String emergencyContactPhone,
        String emergencyContactRelation,
        String notifyContactName,
        String notifyContactPhone,
        String notifyContactRelation,
        String guarantorName,
        String guarantorPhone,
        String guarantorRelation,
        String secondaryContactName,
        String secondaryContactPhone,
        String supervisorName,
        String supervisorPhone,
        String referencesNotes,
        String internalNotes,
        MultipartFile idDocument,
        MultipartFile contractDocument,
        MultipartFile photo
    ) throws IOException {
        String user = requireText(username, "Identifiant de connexion requis").toLowerCase();
        if (!user.matches("[a-z0-9._-]{3,50}")) {
            throw new IllegalArgumentException("Identifiant invalide (3–50 caractères : lettres, chiffres, . _ -).");
        }
        requireText(rawPassword, "Mot de passe requis");
        if (rawPassword.trim().length() < 8) {
            throw new IllegalArgumentException("Le mot de passe doit contenir au moins 8 caractères.");
        }
        requireText(fullName, "Nom complet requis");
        Long exists = jdbcTemplate.queryForObject(
            "SELECT COUNT(*) FROM admin_users WHERE username = ?",
            Long.class,
            user
        );
        if (exists != null && exists > 0) {
            throw new IllegalArgumentException("Cet identifiant existe déjà.");
        }
        validateMatricule(matricule, null);

        String idPath = storeFile(idDocument, "id");
        String contractPath = storeFile(contractDocument, "contract");
        String photoPath = storeFile(photo, "photo");

        String encoded = credentialHashService.hashAdminPassword(rawPassword);
        try {
            jdbcTemplate.update(
                """
                INSERT INTO admin_users (
                  username, password, enabled, full_name, email,
                  phone, gender, city, personal_address, matricule,
                  hire_date, contract_type, contract_signed_date, job_title,
                  emergency_contact_name, emergency_contact_phone, emergency_contact_relation,
                  notify_contact_name, notify_contact_phone, notify_contact_relation,
                  guarantor_name, guarantor_phone, guarantor_relation,
                  secondary_contact_name, secondary_contact_phone,
                  supervisor_name, supervisor_phone,
                  references_notes, internal_notes,
                  id_document_path, contract_document_path, photo_path
                ) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)
                """,
                user,
                encoded,
                true,
                fullName.trim(),
                emptyToNull(email),
                emptyToNull(phone),
                emptyToNull(gender),
                emptyToNull(city),
                emptyToNull(personalAddress),
                emptyToNull(matricule),
                parseDate(hireDateStr),
                emptyToNull(contractType),
                parseDate(contractSignedDateStr),
                emptyToNull(jobTitle),
                emptyToNull(emergencyContactName),
                emptyToNull(emergencyContactPhone),
                emptyToNull(emergencyContactRelation),
                emptyToNull(notifyContactName),
                emptyToNull(notifyContactPhone),
                emptyToNull(notifyContactRelation),
                emptyToNull(guarantorName),
                emptyToNull(guarantorPhone),
                emptyToNull(guarantorRelation),
                emptyToNull(secondaryContactName),
                emptyToNull(secondaryContactPhone),
                emptyToNull(supervisorName),
                emptyToNull(supervisorPhone),
                emptyToNull(referencesNotes),
                emptyToNull(internalNotes),
                idPath,
                contractPath,
                photoPath
            );
        } catch (DuplicateKeyException ex) {
            throw new IllegalArgumentException("Matricule ou identifiant déjà utilisé.");
        }
        grantTeamAuthority(user, authority);
    }

    private void grantTeamAuthority(String username, String authority) {
        jdbcTemplate.update(
            "INSERT INTO admin_authorities (username, authority) VALUES (?, ?)",
            username,
            authority
        );
    }

    @Transactional(rollbackFor = Exception.class)
    public void updateProfile(
        String username,
        String fullName,
        String email,
        String phone,
        String gender,
        String city,
        String personalAddress,
        String matricule,
        String hireDateStr,
        String contractType,
        String contractSignedDateStr,
        String jobTitle,
        String emergencyContactName,
        String emergencyContactPhone,
        String emergencyContactRelation,
        String notifyContactName,
        String notifyContactPhone,
        String notifyContactRelation,
        String guarantorName,
        String guarantorPhone,
        String guarantorRelation,
        String secondaryContactName,
        String secondaryContactPhone,
        String supervisorName,
        String supervisorPhone,
        String referencesNotes,
        String internalNotes,
        MultipartFile idDocument,
        MultipartFile contractDocument,
        MultipartFile photo
    ) throws IOException {
        if (!isGestionnaireAccount(username)) {
            throw new IllegalArgumentException("Compte gestionnaire introuvable.");
        }
        requireText(fullName, "Nom complet requis");
        validateMatricule(matricule, username);

        GestionnaireProfile current = getProfile(username).orElseThrow();
        String idPath = storeFile(idDocument, "id");
        if (idPath == null) idPath = current.idDocumentPath();
        String contractPath = storeFile(contractDocument, "contract");
        if (contractPath == null) contractPath = current.contractDocumentPath();
        String photoPath = storeFile(photo, "photo");
        if (photoPath == null) photoPath = current.photoPath();

        jdbcTemplate.update(
            """
            UPDATE admin_users SET
              full_name = ?, email = ?, phone = ?, gender = ?, city = ?, personal_address = ?,
              matricule = ?, hire_date = ?, contract_type = ?, contract_signed_date = ?, job_title = ?,
              emergency_contact_name = ?, emergency_contact_phone = ?, emergency_contact_relation = ?,
              notify_contact_name = ?, notify_contact_phone = ?, notify_contact_relation = ?,
              guarantor_name = ?, guarantor_phone = ?, guarantor_relation = ?,
              secondary_contact_name = ?, secondary_contact_phone = ?,
              supervisor_name = ?, supervisor_phone = ?,
              references_notes = ?, internal_notes = ?,
              id_document_path = ?, contract_document_path = ?, photo_path = ?
            WHERE username = ?
            """,
            fullName.trim(),
            emptyToNull(email),
            emptyToNull(phone),
            emptyToNull(gender),
            emptyToNull(city),
            emptyToNull(personalAddress),
            emptyToNull(matricule),
            parseDate(hireDateStr),
            emptyToNull(contractType),
            parseDate(contractSignedDateStr),
            emptyToNull(jobTitle),
            emptyToNull(emergencyContactName),
            emptyToNull(emergencyContactPhone),
            emptyToNull(emergencyContactRelation),
            emptyToNull(notifyContactName),
            emptyToNull(notifyContactPhone),
            emptyToNull(notifyContactRelation),
            emptyToNull(guarantorName),
            emptyToNull(guarantorPhone),
            emptyToNull(guarantorRelation),
            emptyToNull(secondaryContactName),
            emptyToNull(secondaryContactPhone),
            emptyToNull(supervisorName),
            emptyToNull(supervisorPhone),
            emptyToNull(referencesNotes),
            emptyToNull(internalNotes),
            idPath,
            contractPath,
            photoPath,
            username.trim()
        );
    }

    public Optional<Path> resolveDossierFile(String username, String kind) {
        try {
            var row = jdbcTemplate.queryForMap(
                "SELECT photo_path, id_document_path, contract_document_path FROM admin_users WHERE username = ?",
                username.trim()
            );
            String rel = switch (kind) {
                case "photo" -> (String) row.get("photo_path");
                case "identity" -> (String) row.get("id_document_path");
                case "contract" -> (String) row.get("contract_document_path");
                default -> null;
            };
            if (rel == null || rel.isBlank()) {
                return Optional.empty();
            }
            Path file = Path.of(rel.replace('\\', '/')).normalize();
            if (!file.isAbsolute()) {
                file = Path.of(".").resolve(file).normalize();
            }
            if (Files.isRegularFile(file)) {
                return Optional.of(file);
            }
            Path byName = Path.of("uploads", "gestionnaire-dossiers").resolve(file.getFileName()).normalize();
            if (Files.isRegularFile(byName)) {
                return Optional.of(byName);
            }
            return Optional.empty();
        } catch (EmptyResultDataAccessException ex) {
            return Optional.empty();
        }
    }

    private String profileSelectSql() {
        return """
            SELECT u.username, u.enabled, u.full_name, u.email, u.phone, u.gender, u.city, u.personal_address,
                   u.matricule, u.hire_date, u.contract_type, u.contract_signed_date, u.job_title,
                   u.emergency_contact_name, u.emergency_contact_phone, u.emergency_contact_relation,
                   u.notify_contact_name, u.notify_contact_phone, u.notify_contact_relation,
                   u.guarantor_name, u.guarantor_phone, u.guarantor_relation,
                   u.secondary_contact_name, u.secondary_contact_phone,
                   u.supervisor_name, u.supervisor_phone,
                   u.references_notes, u.internal_notes,
                   u.id_document_path, u.contract_document_path, u.photo_path
            FROM admin_users u
            """;
    }

    private static GestionnaireProfile mapProfile(java.sql.ResultSet rs) throws java.sql.SQLException {
        return new GestionnaireProfile(
            rs.getString("username"),
            rs.getBoolean("enabled"),
            rs.getString("full_name"),
            rs.getString("email"),
            rs.getString("phone"),
            rs.getString("gender"),
            rs.getString("city"),
            rs.getString("personal_address"),
            rs.getString("matricule"),
            formatDate(rs.getDate("hire_date")),
            rs.getString("contract_type"),
            formatDate(rs.getDate("contract_signed_date")),
            rs.getString("job_title"),
            rs.getString("emergency_contact_name"),
            rs.getString("emergency_contact_phone"),
            rs.getString("emergency_contact_relation"),
            rs.getString("notify_contact_name"),
            rs.getString("notify_contact_phone"),
            rs.getString("notify_contact_relation"),
            rs.getString("guarantor_name"),
            rs.getString("guarantor_phone"),
            rs.getString("guarantor_relation"),
            rs.getString("secondary_contact_name"),
            rs.getString("secondary_contact_phone"),
            rs.getString("supervisor_name"),
            rs.getString("supervisor_phone"),
            rs.getString("references_notes"),
            rs.getString("internal_notes"),
            rs.getString("id_document_path"),
            rs.getString("contract_document_path"),
            rs.getString("photo_path")
        );
    }

    private static String formatDate(java.sql.Date d) {
        return d == null ? null : d.toLocalDate().toString();
    }

    private static java.sql.Date parseDate(String raw) {
        if (raw == null || raw.isBlank()) {
            return null;
        }
        return java.sql.Date.valueOf(LocalDate.parse(raw.trim()));
    }

    private void validateMatricule(String matricule, String excludeUsername) {
        String mat = matricule == null ? null : matricule.trim();
        if (mat == null || mat.isEmpty()) {
            return;
        }
        Long n = jdbcTemplate.queryForObject(
            "SELECT COUNT(*) FROM admin_users WHERE matricule = ? AND (? IS NULL OR username <> ?)",
            Long.class,
            mat,
            excludeUsername,
            excludeUsername
        );
        if (n != null && n > 0) {
            throw new IllegalArgumentException("Ce matricule est déjà attribué.");
        }
    }

    private Path ensureUploadRoot() throws IOException {
        Path root = Path.of("uploads", "gestionnaire-dossiers");
        Files.createDirectories(root);
        return root;
    }

    private String storeFile(MultipartFile file, String prefix) throws IOException {
        if (file == null || file.isEmpty()) {
            return null;
        }
        String ext = "";
        String original = file.getOriginalFilename();
        if (original != null && original.contains(".")) {
            ext = original.substring(original.lastIndexOf('.'));
        }
        String name = prefix + "_" + LocalDate.now().format(DateTimeFormatter.BASIC_ISO_DATE) + "_" + UUID.randomUUID() + ext;
        Path target = ensureUploadRoot().resolve(name);
        Files.copy(file.getInputStream(), target, StandardCopyOption.REPLACE_EXISTING);
        return target.toString().replace("\\", "/");
    }

    private static String requireText(String s, String msg) {
        if (s == null || s.isBlank()) {
            throw new IllegalArgumentException(msg);
        }
        return s.trim();
    }

    private static boolean hasText(String s) {
        return s != null && !s.isBlank();
    }

    private static String emptyToNull(String s) {
        if (s == null || s.isBlank()) {
            return null;
        }
        return s.trim();
    }
}
