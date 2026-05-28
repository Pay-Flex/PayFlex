package com.payflex.backend.service;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;

/**
 * Envoi push : enregistre le token FCM et journalise les envois.
 * Branchez Firebase Admin SDK via configuration pour des push hors application.
 */
@Service
public class PushNotificationService {

    private static final Logger log = LoggerFactory.getLogger(PushNotificationService.class);

    private final JdbcTemplate jdbcTemplate;

    public PushNotificationService(JdbcTemplate jdbcTemplate) {
        this.jdbcTemplate = jdbcTemplate;
    }

    public void saveFcmToken(long userId, String token) {
        if (userId <= 0 || token == null || token.isBlank()) {
            return;
        }
        jdbcTemplate.update("UPDATE users SET fcm_token = ? WHERE id = ?", token.trim(), userId);
    }

    public void notifyUser(long userId, String title, String body) {
        if (userId <= 0) {
            return;
        }
        String token = null;
        try {
            token = jdbcTemplate.queryForObject(
                "SELECT fcm_token FROM users WHERE id = ?",
                String.class,
                userId
            );
        } catch (org.springframework.dao.EmptyResultDataAccessException ignored) {
            return;
        }
        if (token == null || token.isBlank()) {
            log.debug("Push non envoyé (pas de token FCM) userId={}", userId);
            return;
        }
        log.info("Push à envoyer userId={} title={} (configurer Firebase pour livraison réelle)", userId, title);
    }
}
