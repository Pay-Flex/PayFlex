package com.payflex.backend.service;

import org.springframework.dao.EmptyResultDataAccessException;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.LinkedHashMap;
import java.util.Map;
import java.util.Objects;

@Service
public class AdminClientCredentialService {

    private final JdbcTemplate jdbcTemplate;
    private final CredentialHashService credentialHashService;
    private final CredentialVaultService credentialVaultService;
    private final UserInboxNotificationService inboxNotificationService;
    private final PasswordEncoder passwordEncoder;

    public AdminClientCredentialService(
        JdbcTemplate jdbcTemplate,
        CredentialHashService credentialHashService,
        CredentialVaultService credentialVaultService,
        UserInboxNotificationService inboxNotificationService,
        PasswordEncoder passwordEncoder
    ) {
        this.jdbcTemplate = jdbcTemplate;
        this.credentialHashService = credentialHashService;
        this.credentialVaultService = credentialVaultService;
        this.inboxNotificationService = inboxNotificationService;
        this.passwordEncoder = passwordEncoder;
    }

    public boolean verifyAdminPassword(String adminUsername, String adminPassword) {
        if (adminUsername == null || adminUsername.isBlank() || adminPassword == null || adminPassword.isBlank()) {
            return false;
        }
        try {
            String stored = jdbcTemplate.queryForObject(
                "SELECT password FROM admin_users WHERE username = ? AND enabled = TRUE LIMIT 1",
                String.class,
                adminUsername.trim()
            );
            if (credentialHashService.matchesAdminPassword(adminPassword, stored)) {
                return true;
            }
            try {
                return passwordEncoder.matches(adminPassword.trim(), stored);
            } catch (IllegalArgumentException ex) {
                return false;
            }
        } catch (EmptyResultDataAccessException ex) {
            return false;
        }
    }

    public Map<String, Object> credentialSummary(long clientUserId) {
        ensureClient(clientUserId);
        Map<String, Object> out = new LinkedHashMap<>();
        out.put("hasPin", credentialVaultService.hasPinDefined(clientUserId));
        out.put("hasAccountPassword", credentialVaultService.hasAccountPasswordDefined(clientUserId));
        out.put("pinVaultAvailable", credentialVaultService.hasPinVault(clientUserId));
        out.put("passwordVaultAvailable", credentialVaultService.hasPasswordVault(clientUserId));
        out.put("recoveryOpen", hasOpenRecoveryRequest(clientUserId));
        return out;
    }

    public Map<String, Object> revealCredentials(long clientUserId, String adminUsername, String adminPassword) {
        if (!verifyAdminPassword(adminUsername, adminPassword)) {
            throw new IllegalArgumentException("Mot de passe administrateur incorrect.");
        }
        ensureClient(clientUserId);
        Map<String, Object> out = new LinkedHashMap<>();
        String pin = credentialVaultService.revealPin(clientUserId);
        String pass = credentialVaultService.revealAccountPassword(clientUserId);
        out.put("pin", pin != null ? pin : (credentialVaultService.hasPinDefined(clientUserId)
            ? "—"
            : "—"));
        out.put("accountPassword", pass != null ? pass : (credentialVaultService.hasAccountPasswordDefined(clientUserId)
            ? "—"
            : "—"));
        if (pin == null && credentialVaultService.hasPinDefined(clientUserId)) {
            out.put("pinHint", "Identifiant défini mais non récupérable. Utilisez « Modifier le compte » pour en saisir un nouveau (il sera affichable ensuite).");
        }
        if (pass == null && credentialVaultService.hasAccountPasswordDefined(clientUserId)) {
            out.put("passwordHint", "Mot de passe défini mais non récupérable. Utilisez « Modifier le compte » pour en définir un nouveau.");
        }
        return out;
    }

    @Transactional
    public void updateClientProfile(
        long clientUserId,
        String fullName,
        String email,
        String gender,
        String city,
        String profession,
        String status,
        String workplaceName,
        String workplaceAddress,
        String bossName,
        String bossPhone,
        String newPin,
        String newAccountPassword
    ) {
        ensureClient(clientUserId);
        if (fullName == null || fullName.isBlank()) {
            throw new IllegalArgumentException("Nom complet requis.");
        }
        String st = normalizeClientStatus(status);
        jdbcTemplate.update(
            """
            UPDATE users SET full_name = ?, email = ?, gender = ?, city = ?, profession = ?, status = ?,
                workplace_name = ?, workplace_address = ?, boss_name = ?, boss_phone = ?
            WHERE id = ?
            """,
            fullName.trim(),
            UserContactUniquenessService.normalizeEmail(email),
            emptyToNull(gender),
            emptyToNull(city),
            emptyToNull(profession),
            st,
            emptyToNull(workplaceName),
            emptyToNull(workplaceAddress),
            emptyToNull(bossName),
            emptyToNull(bossPhone),
            clientUserId
        );
        if (newPin != null && !newPin.isBlank()) {
            credentialHashService.validateMobilePin(newPin);
            String hashed = credentialHashService.hashMobilePin(newPin);
            jdbcTemplate.update(
                "UPDATE users SET pin = ?, secret_code = ? WHERE id = ?",
                hashed,
                hashed,
                clientUserId
            );
            credentialVaultService.storeForUser(clientUserId, newPin, null);
        }
        if (newAccountPassword != null && !newAccountPassword.isBlank()) {
            String hashed = credentialHashService.hashMobileCredential(newAccountPassword);
            jdbcTemplate.update("UPDATE users SET account_password = ? WHERE id = ?", hashed, clientUserId);
            credentialVaultService.storeForUser(clientUserId, null, newAccountPassword);
        }
    }

    public Map<String, Object> loadClientEditRow(long clientUserId) {
        ensureClient(clientUserId);
        return jdbcTemplate.queryForMap(
            """
            SELECT id, full_name, phone, email, gender, city, profession, status,
                   workplace_name, workplace_address, boss_name, boss_phone, unique_code
            FROM users WHERE id = ?
            """,
            clientUserId
        );
    }

    @Transactional
    public long openRecoveryRequest(long clientUserId, String source, String note) {
        ensureClient(clientUserId);
        if (hasOpenRecoveryRequest(clientUserId)) {
            return jdbcTemplate.queryForObject(
                "SELECT id FROM client_credential_recovery_requests WHERE user_id = ? AND status = 'open' ORDER BY id DESC LIMIT 1",
                Long.class,
                clientUserId
            );
        }
        jdbcTemplate.update(
            """
            INSERT INTO client_credential_recovery_requests (user_id, status, source, note)
            VALUES (?, 'open', ?, ?)
            """,
            clientUserId,
            source == null || source.isBlank() ? "admin" : source.trim(),
            note
        );
        long id = jdbcTemplate.queryForObject("SELECT LAST_INSERT_ID()", Long.class);
        inboxNotificationService.notifyClientAndAssignedAgent(
            clientUserId,
            "credential_recovery",
            "Demande enregistrée",
            "PayFlex vous rappellera pour vous aider à retrouver vos accès.",
            "Rappel identifiants demandé",
            "Le client {client} a signalé un oubli de PIN ou mot de passe.",
            null
        );
        return id;
    }

    @Transactional
    public void resolveRecoveryRequest(long clientUserId, String adminUsername) {
        jdbcTemplate.update(
            """
            UPDATE client_credential_recovery_requests
            SET status = 'resolved', resolved_at = NOW(), resolved_by = ?
            WHERE user_id = ? AND status = 'open'
            """,
            adminUsername,
            clientUserId
        );
    }

    @Transactional
    public Map<String, Object> requestMobileCallback(String phone, String fullName) {
        String ph = phone == null ? "" : phone.trim();
        String fn = fullName == null ? "" : fullName.trim();
        if (ph.isEmpty()) {
            throw new IllegalArgumentException("Numéro de téléphone requis.");
        }
        Long userId;
        try {
            if (fn.isEmpty()) {
                userId = jdbcTemplate.queryForObject(
                    """
                    SELECT u.id FROM users u
                    JOIN roles r ON r.id = u.role_id AND r.code = 'client'
                    WHERE TRIM(u.phone) = ? AND u.status IN ('valide', 'adhere', 'pending')
                    LIMIT 1
                    """,
                    Long.class,
                    ph
                );
            } else {
                userId = jdbcTemplate.queryForObject(
                    """
                    SELECT u.id FROM users u
                    JOIN roles r ON r.id = u.role_id AND r.code = 'client'
                    WHERE TRIM(u.phone) = ? AND LOWER(TRIM(u.full_name)) = LOWER(?)
                    LIMIT 1
                    """,
                    Long.class,
                    ph,
                    fn
                );
            }
        } catch (EmptyResultDataAccessException ex) {
            throw new IllegalArgumentException("Compte introuvable. Vérifiez le numéro ou contactez le centre PayFlex.");
        }
        long requestId = openRecoveryRequest(
            userId,
            "mobile",
            "Oubli complet signalé depuis l'application mobile."
        );
        return Map.of(
            "status", "queued",
            "message", "Votre demande est enregistrée. Un conseiller PayFlex vous rappellera sous peu.",
            "requestId", requestId
        );
    }

    public boolean hasOpenRecoveryRequest(long clientUserId) {
        Long n = jdbcTemplate.queryForObject(
            "SELECT COUNT(*) FROM client_credential_recovery_requests WHERE user_id = ? AND status = 'open'",
            Long.class,
            clientUserId
        );
        return n != null && n > 0;
    }

    private void ensureClient(long clientUserId) {
        Long n = jdbcTemplate.queryForObject(
            """
            SELECT COUNT(*) FROM users u
            JOIN roles r ON r.id = u.role_id AND r.code = 'client'
            WHERE u.id = ?
            """,
            Long.class,
            clientUserId
        );
        if (n == null || n == 0) {
            throw new IllegalArgumentException("Client introuvable.");
        }
    }

    private static String normalizeClientStatus(String status) {
        if (status == null || status.isBlank()) {
            return "pending";
        }
        String s = status.trim().toLowerCase();
        return switch (s) {
            case "valide", "pending", "bloque", "adhere" -> s;
            default -> "pending";
        };
    }

    private static String emptyToNull(String v) {
        if (v == null || v.isBlank()) {
            return null;
        }
        return v.trim();
    }
}
