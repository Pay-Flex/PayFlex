package com.payflex.backend.service;

import com.payflex.backend.config.PayflexProperties;
import org.springframework.core.env.Environment;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;

import javax.crypto.Cipher;
import javax.crypto.spec.GCMParameterSpec;
import javax.crypto.spec.SecretKeySpec;
import java.nio.ByteBuffer;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.SecureRandom;
import java.util.Arrays;
import java.util.Base64;
import java.util.Objects;

/**
 * Archive chiffrée des identifiants mobiles pour révélation admin (en complément du hash BCrypt).
 */
@Service
public class CredentialVaultService {

    private static final String PREFIX = "v1:";
    private static final int GCM_TAG_BITS = 128;
    private static final int IV_BYTES = 12;

    private final JdbcTemplate jdbcTemplate;
    private final SecretKeySpec secretKey;
    private final SecureRandom secureRandom = new SecureRandom();

    public CredentialVaultService(JdbcTemplate jdbcTemplate, PayflexProperties payflexProperties, Environment environment) {
        this.jdbcTemplate = jdbcTemplate;
        failFastIfUnsafeInProd(payflexProperties, environment);
        this.secretKey = deriveKey(payflexProperties.getVaultKey());
    }

    /**
     * Refuse de démarrer sous le profil {@code prod} si PAYFLEX_VAULT_KEY (payflex.vault-key)
     * n'a pas été explicitement défini : la valeur de repli est publique (présente dans le code
     * source) et rendrait le chiffrement du coffre identifiants totalement inefficace en
     * production. Le profil {@code dev} / défaut conserve la valeur de repli pour rester simple
     * en local.
     */
    private static void failFastIfUnsafeInProd(PayflexProperties payflexProperties, Environment environment) {
        boolean isProd = Arrays.asList(environment.getActiveProfiles()).contains("prod");
        if (!isProd) {
            return;
        }
        String vaultKey = payflexProperties.getVaultKey();
        if (vaultKey == null || vaultKey.isBlank() || PayflexProperties.DEFAULT_VAULT_KEY.equals(vaultKey)) {
            throw new IllegalStateException(
                "PAYFLEX_VAULT_KEY doit être défini explicitement (variable d'environnement) en profil 'prod' : "
                    + "la valeur par défaut n'est pas sûre en production. Démarrage refusé."
            );
        }
    }

    public void storeForUser(long userId, String plainPin, String plainAccountPassword) {
        if (userId <= 0) {
            return;
        }
        String pinCipher = encryptNullable(plainPin);
        String passCipher = encryptNullable(plainAccountPassword);
        if (pinCipher == null && passCipher == null) {
            return;
        }
        jdbcTemplate.update(
            """
            UPDATE users
            SET pin_vault_cipher = COALESCE(?, pin_vault_cipher),
                account_password_vault_cipher = COALESCE(?, account_password_vault_cipher)
            WHERE id = ?
            """,
            pinCipher,
            passCipher,
            userId
        );
    }

    public void storeForRegistrationRequest(long registrationId, String plainPin, String plainAccountPassword) {
        if (registrationId <= 0) {
            return;
        }
        String pinCipher = encryptNullable(plainPin);
        String passCipher = encryptNullable(plainAccountPassword);
        if (pinCipher == null && passCipher == null) {
            return;
        }
        jdbcTemplate.update(
            """
            UPDATE registration_requests
            SET pin_vault_cipher = COALESCE(?, pin_vault_cipher),
                account_password_vault_cipher = COALESCE(?, account_password_vault_cipher)
            WHERE id = ?
            """,
            pinCipher,
            passCipher,
            registrationId
        );
    }

    public void copyRegistrationVaultToUser(long registrationId, long userId) {
        if (registrationId <= 0 || userId <= 0) {
            return;
        }
        jdbcTemplate.update(
            """
            UPDATE users u
            INNER JOIN registration_requests r ON r.id = ?
            SET u.pin_vault_cipher = COALESCE(u.pin_vault_cipher, r.pin_vault_cipher),
                u.account_password_vault_cipher = COALESCE(u.account_password_vault_cipher, r.account_password_vault_cipher)
            WHERE u.id = ?
            """,
            registrationId,
            userId
        );
    }

    public int backfillUserVaultFromRegistrations() {
        return jdbcTemplate.update(
            """
            UPDATE users u
            INNER JOIN roles r ON r.id = u.role_id AND r.code = 'client'
            INNER JOIN registration_requests reg ON reg.status IN ('approved', 'pending')
              AND (
                (u.phone IS NOT NULL AND TRIM(u.phone) <> '' AND TRIM(reg.phone) = TRIM(u.phone))
                OR (u.unique_code IS NOT NULL AND TRIM(u.unique_code) <> '' AND TRIM(reg.unique_code) = TRIM(u.unique_code))
              )
            SET u.pin_vault_cipher = COALESCE(u.pin_vault_cipher, reg.pin_vault_cipher),
                u.account_password_vault_cipher = COALESCE(u.account_password_vault_cipher, reg.account_password_vault_cipher)
            WHERE (u.pin_vault_cipher IS NULL OR TRIM(u.pin_vault_cipher) = '')
               OR (u.account_password_vault_cipher IS NULL OR TRIM(u.account_password_vault_cipher) = '')
            """
        );
    }

    public String revealPin(long userId) {
        String fromUser = revealUserColumn(userId, "pin_vault_cipher");
        if (fromUser != null) {
            return fromUser;
        }
        return revealRegistrationColumnForClient(userId, "pin_vault_cipher");
    }

    public String revealAccountPassword(long userId) {
        String fromUser = revealUserColumn(userId, "account_password_vault_cipher");
        if (fromUser != null) {
            return fromUser;
        }
        return revealRegistrationColumnForClient(userId, "account_password_vault_cipher");
    }

    public boolean hasPinDefined(long userId) {
        return hasCredential(userId, "pin");
    }

    public boolean hasAccountPasswordDefined(long userId) {
        String pass = jdbcTemplate.query(
            "SELECT account_password FROM users WHERE id = ?",
            rs -> rs.next() ? rs.getString(1) : null,
            userId
        );
        return pass != null && !pass.isBlank();
    }

    public boolean hasPinVault(long userId) {
        return hasVaultCipher(userId, "pin_vault_cipher");
    }

    public boolean hasPasswordVault(long userId) {
        return hasVaultCipher(userId, "account_password_vault_cipher");
    }

    private boolean hasCredential(long userId, String column) {
        String v = jdbcTemplate.query(
            "SELECT " + column + " FROM users WHERE id = ?",
            rs -> rs.next() ? rs.getString(1) : null,
            userId
        );
        return v != null && !v.isBlank();
    }

    private boolean hasVaultCipher(long userId, String column) {
        String v = jdbcTemplate.query(
            "SELECT " + column + " FROM users WHERE id = ?",
            rs -> rs.next() ? rs.getString(1) : null,
            userId
        );
        return v != null && !v.isBlank();
    }

    private String revealUserColumn(long userId, String column) {
        String cipher = jdbcTemplate.query(
            "SELECT " + column + " FROM users WHERE id = ?",
            rs -> rs.next() ? rs.getString(1) : null,
            userId
        );
        if (cipher == null || cipher.isBlank()) {
            return null;
        }
        return decrypt(cipher);
    }

    private String revealRegistrationColumnForClient(long userId, String column) {
        String cipher = jdbcTemplate.query(
            """
            SELECT reg.%s
            FROM users u
            INNER JOIN roles r ON r.id = u.role_id AND r.code = 'client'
            INNER JOIN registration_requests reg ON reg.status IN ('approved', 'pending')
              AND (
                (u.phone IS NOT NULL AND TRIM(u.phone) <> '' AND TRIM(reg.phone) = TRIM(u.phone))
                OR (u.unique_code IS NOT NULL AND TRIM(u.unique_code) <> '' AND TRIM(reg.unique_code) = TRIM(u.unique_code))
              )
            WHERE u.id = ?
            ORDER BY reg.id DESC
            LIMIT 1
            """.formatted(column),
            rs -> rs.next() ? rs.getString(1) : null,
            userId
        );
        if (cipher == null || cipher.isBlank()) {
            return null;
        }
        return decrypt(cipher);
    }

    private String encryptNullable(String raw) {
        if (raw == null || raw.isBlank()) {
            return null;
        }
        return encrypt(raw.trim());
    }

    private String encrypt(String plaintext) {
        try {
            byte[] iv = new byte[IV_BYTES];
            secureRandom.nextBytes(iv);
            Cipher cipher = Cipher.getInstance("AES/GCM/NoPadding");
            cipher.init(Cipher.ENCRYPT_MODE, secretKey, new GCMParameterSpec(GCM_TAG_BITS, iv));
            byte[] encrypted = cipher.doFinal(plaintext.getBytes(StandardCharsets.UTF_8));
            ByteBuffer buf = ByteBuffer.allocate(iv.length + encrypted.length);
            buf.put(iv);
            buf.put(encrypted);
            return PREFIX + Base64.getEncoder().encodeToString(buf.array());
        } catch (Exception ex) {
            throw new IllegalStateException("Chiffrement vault indisponible.", ex);
        }
    }

    private String decrypt(String stored) {
        if (stored == null || !stored.startsWith(PREFIX)) {
            return null;
        }
        try {
            byte[] payload = Base64.getDecoder().decode(stored.substring(PREFIX.length()));
            ByteBuffer buf = ByteBuffer.wrap(payload);
            byte[] iv = new byte[IV_BYTES];
            buf.get(iv);
            byte[] encrypted = new byte[buf.remaining()];
            buf.get(encrypted);
            Cipher cipher = Cipher.getInstance("AES/GCM/NoPadding");
            cipher.init(Cipher.DECRYPT_MODE, secretKey, new GCMParameterSpec(GCM_TAG_BITS, iv));
            byte[] plain = cipher.doFinal(encrypted);
            return new String(plain, StandardCharsets.UTF_8);
        } catch (Exception ex) {
            return null;
        }
    }

    private static SecretKeySpec deriveKey(String rawKey) {
        String seed = Objects.toString(rawKey, "payflex-dev-vault-key-change-me");
        try {
            byte[] hash = MessageDigest.getInstance("SHA-256").digest(seed.getBytes(StandardCharsets.UTF_8));
            return new SecretKeySpec(hash, "AES");
        } catch (Exception ex) {
            throw new IllegalStateException("Clé vault invalide.", ex);
        }
    }
}
