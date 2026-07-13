package com.payflex.backend.service;

import org.springframework.dao.DataAccessException;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.security.SecureRandom;
import java.util.HexFormat;
import java.util.List;
import java.util.Map;

/**
 * Récupération de compte mobile : vérification d’identité puis nouveau PIN + code secret cotisation.
 */
@Service
public class MobileRecoveryService {

    private static final int TOKEN_BYTES = 24;
    private static final int EXPIRY_MINUTES = 25;

    private final JdbcTemplate jdbcTemplate;
    private final CredentialHashService credentialHashService;
    private final CredentialVaultService credentialVaultService;
    private final AdminClientCredentialService adminClientCredentialService;
    private final SecureRandom secureRandom = new SecureRandom();

    public MobileRecoveryService(
        JdbcTemplate jdbcTemplate,
        CredentialHashService credentialHashService,
        CredentialVaultService credentialVaultService,
        AdminClientCredentialService adminClientCredentialService
    ) {
        this.jdbcTemplate = jdbcTemplate;
        this.credentialHashService = credentialHashService;
        this.credentialVaultService = credentialVaultService;
        this.adminClientCredentialService = adminClientCredentialService;
    }

    /**
     * @return map avec {@code resetToken} si les données correspondent à un compte mobile actif.
     */
    @Transactional
    public Map<String, Object> requestRecovery(String phone, String fullName, String uniqueCode) {
        String ph = normalizeInput(phone);
        String fn = normalizeInput(fullName);
        String uc = normalizeInput(uniqueCode);
        if (ph.isEmpty() || fn.isEmpty() || uc.isEmpty()) {
            throw new IllegalArgumentException("Téléphone, nom complet et code unique sont requis.");
        }
        List<Long> ids;
        try {
            ids = jdbcTemplate.query(
                """
                SELECT u.id
                FROM users u
                JOIN roles r ON r.id = u.role_id
                WHERE TRIM(u.phone) = ?
                  AND LOWER(TRIM(u.full_name)) = LOWER(?)
                  AND TRIM(u.unique_code) = ?
                  AND r.code IN ('client', 'agent')
                  AND u.status = 'valide'
                LIMIT 2
                """,
                (rs, i) -> rs.getLong("id"),
                ph,
                fn,
                uc
            );
        } catch (DataAccessException ex) {
            throw new IllegalStateException("Erreur lors de la vérification.", ex);
        }
        if (ids.isEmpty()) {
            throw new IllegalArgumentException("Les informations ne correspondent à aucun compte actif. Vérifiez vos saisies.");
        }
        if (ids.size() > 1) {
            throw new IllegalStateException("Conflit de compte : contactez le support.");
        }
        long userId = ids.get(0);

        jdbcTemplate.update("DELETE FROM mobile_password_reset_tokens WHERE user_id = ? AND used_at IS NULL", userId);

        String token = generateToken();
        jdbcTemplate.update(
            """
            INSERT INTO mobile_password_reset_tokens (user_id, token, expires_at)
            VALUES (?, ?, DATE_ADD(NOW(), INTERVAL ? MINUTE))
            """,
            userId,
            token,
            EXPIRY_MINUTES
        );

        return Map.of(
            "resetToken", token,
            "expiresInMinutes", EXPIRY_MINUTES
        );
    }

    @Transactional
    public void resetCredentials(String token, String newPin) {
        String t = normalizeInput(token);
        String pin = normalizeInput(newPin);
        if (t.isEmpty()) {
            throw new IllegalArgumentException("Jeton de réinitialisation manquant.");
        }
        credentialHashService.validateMobileCredential(pin);

        List<Map<String, Object>> rows;
        try {
            rows = jdbcTemplate.queryForList(
                """
                SELECT id, user_id FROM mobile_password_reset_tokens
                WHERE token = ? AND used_at IS NULL AND expires_at > NOW()
                LIMIT 1
                """,
                t
            );
        } catch (DataAccessException ex) {
            throw new IllegalStateException("Erreur lors de la lecture du jeton.", ex);
        }
        if (rows.isEmpty()) {
            throw new IllegalArgumentException("Lien de réinitialisation invalide ou expiré. Reprenez la procédure depuis l’écran « Mot de passe oublié ».");
        }
        long tokenId = ((Number) rows.get(0).get("id")).longValue();
        long userId = ((Number) rows.get(0).get("user_id")).longValue();

        String hashed = credentialHashService.hashMobileCredential(pin);
        jdbcTemplate.update(
            "UPDATE users SET pin = ?, secret_code = ?, account_password = ? WHERE id = ?",
            hashed,
            hashed,
            hashed,
            userId
        );
        credentialVaultService.storeForUser(userId, pin, pin);
        jdbcTemplate.update(
            "UPDATE mobile_password_reset_tokens SET used_at = NOW() WHERE id = ?",
            tokenId
        );
    }

    public Map<String, Object> requestCallbackAssistance(String phone, String fullName) {
        return adminClientCredentialService.requestMobileCallback(phone, fullName);
    }

    private static String normalizeInput(String s) {
        if (s == null) {
            return "";
        }
        return s.trim();
    }

    private String generateToken() {
        byte[] buf = new byte[TOKEN_BYTES];
        secureRandom.nextBytes(buf);
        return HexFormat.of().formatHex(buf);
    }

}
