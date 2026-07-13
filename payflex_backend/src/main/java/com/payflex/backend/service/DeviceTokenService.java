package com.payflex.backend.service;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;

import java.util.List;

/**
 * Stockage des jetons d'appareil FCM (table {@code user_device_tokens}).
 * Un utilisateur peut avoir plusieurs appareils ; un jeton est unique.
 */
@Service
public class DeviceTokenService {

    private static final Logger log = LoggerFactory.getLogger(DeviceTokenService.class);

    private final JdbcTemplate jdbcTemplate;

    public DeviceTokenService(JdbcTemplate jdbcTemplate) {
        this.jdbcTemplate = jdbcTemplate;
    }

    /** Enregistre (ou rattache) un jeton FCM à un utilisateur. Idempotent. */
    public void registerToken(long userId, String token, String platform, String role) {
        if (userId <= 0 || token == null || token.isBlank()) {
            return;
        }
        String t = token.trim();
        String p = platform == null || platform.isBlank() ? "android" : platform.trim();
        String r = role == null || role.isBlank() ? null : role.trim();
        // Le jeton étant unique, on réaffecte l'appareil au bon utilisateur.
        jdbcTemplate.update(
            """
            INSERT INTO user_device_tokens (user_id, role, token, platform)
            VALUES (?, ?, ?, ?)
            ON DUPLICATE KEY UPDATE user_id = VALUES(user_id), role = VALUES(role),
                                    platform = VALUES(platform), updated_at = CURRENT_TIMESTAMP
            """,
            userId, r, t, p
        );
    }

    /** Supprime un jeton précis (déconnexion sur cet appareil). */
    public void removeToken(String token) {
        if (token == null || token.isBlank()) {
            return;
        }
        jdbcTemplate.update("DELETE FROM user_device_tokens WHERE token = ?", token.trim());
    }

    /** Supprime un jeton devenu invalide côté FCM (nettoyage automatique). */
    public void removeInvalidToken(String token) {
        removeToken(token);
        log.debug("Jeton FCM invalide purgé.");
    }

    public List<String> tokensForUser(long userId) {
        if (userId <= 0) {
            return List.of();
        }
        return jdbcTemplate.query(
            "SELECT token FROM user_device_tokens WHERE user_id = ?",
            (rs, i) -> rs.getString(1),
            userId
        );
    }
}
