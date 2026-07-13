package com.payflex.backend.service;

import com.payflex.backend.config.PayflexProperties;
import nl.martijndwars.webpush.Notification;
import nl.martijndwars.webpush.PushService;
import org.bouncycastle.jce.provider.BouncyCastleProvider;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.scheduling.annotation.Async;
import org.springframework.stereotype.Service;

import jakarta.annotation.PostConstruct;
import java.nio.charset.StandardCharsets;
import java.security.Security;
import java.util.List;
import java.util.Map;

/**
 * Web Push (VAPID) pour les postes admin / support (navigateur).
 * <p>
 * Gère le stockage des abonnements ({@code admin_push_subscriptions}) et l'envoi
 * réel. Entièrement gardé : si les clés VAPID ne sont pas configurées, l'envoi est
 * ignoré (l'admin conserve le polling / badges existants).
 */
@Service
public class AdminWebPushService {

    private static final Logger log = LoggerFactory.getLogger(AdminWebPushService.class);

    private final JdbcTemplate jdbcTemplate;
    private final PayflexProperties properties;
    private PushService pushService;

    public AdminWebPushService(JdbcTemplate jdbcTemplate, PayflexProperties properties) {
        this.jdbcTemplate = jdbcTemplate;
        this.properties = properties;
    }

    @PostConstruct
    void init() {
        PayflexProperties.Push.WebPush cfg = properties.getPush().getWebPush();
        if (cfg == null || !cfg.isConfigured()) {
            log.info("Web Push admin désactivé (clés VAPID non configurées) — repli sur le polling admin.");
            return;
        }
        try {
            if (Security.getProvider(BouncyCastleProvider.PROVIDER_NAME) == null) {
                Security.addProvider(new BouncyCastleProvider());
            }
            this.pushService = new PushService(cfg.getPublicKey().trim(), cfg.getPrivateKey().trim(), cfg.getSubject());
            log.info("Web Push admin actif (VAPID configuré).");
        } catch (Exception ex) {
            this.pushService = null;
            log.warn("Web Push admin désactivé : clés VAPID invalides ({}).", ex.getMessage());
        }
    }

    public boolean isEnabled() {
        return pushService != null;
    }

    public String publicKey() {
        return properties.getPush().getWebPush().getPublicKey();
    }

    // ---------------------------------------------------------------- stockage

    public void saveSubscription(String username, String endpoint, String p256dh, String auth, String userAgent) {
        if (username == null || username.isBlank() || endpoint == null || endpoint.isBlank()
            || p256dh == null || p256dh.isBlank() || auth == null || auth.isBlank()) {
            return;
        }
        String ua = userAgent == null ? null : (userAgent.length() > 250 ? userAgent.substring(0, 250) : userAgent);
        jdbcTemplate.update(
            """
            INSERT INTO admin_push_subscriptions (admin_username, endpoint, p256dh, auth, user_agent)
            VALUES (?, ?, ?, ?, ?)
            ON DUPLICATE KEY UPDATE admin_username = VALUES(admin_username), p256dh = VALUES(p256dh),
                                    auth = VALUES(auth), user_agent = VALUES(user_agent),
                                    updated_at = CURRENT_TIMESTAMP
            """,
            username.trim(), endpoint.trim(), p256dh.trim(), auth.trim(), ua
        );
    }

    public void removeSubscription(String endpoint) {
        if (endpoint == null || endpoint.isBlank()) {
            return;
        }
        jdbcTemplate.update("DELETE FROM admin_push_subscriptions WHERE endpoint = ?", endpoint.trim());
    }

    // ------------------------------------------------------------------ envoi

    /** Diffuse une notification Web Push à tous les postes admin/support abonnés. */
    @Async
    public void notifyAllAdmins(String title, String body, String url) {
        if (pushService == null || title == null || title.isBlank()) {
            return;
        }
        List<Map<String, Object>> subs = jdbcTemplate.queryForList(
            "SELECT endpoint, p256dh, auth FROM admin_push_subscriptions"
        );
        if (subs.isEmpty()) {
            return;
        }
        String payload = buildPayload(title, body, url);
        for (Map<String, Object> sub : subs) {
            sendOne(
                String.valueOf(sub.get("endpoint")),
                String.valueOf(sub.get("p256dh")),
                String.valueOf(sub.get("auth")),
                payload
            );
        }
    }

    private void sendOne(String endpoint, String p256dh, String auth, String payload) {
        try {
            Notification notification = new Notification(endpoint, p256dh, auth, payload.getBytes(StandardCharsets.UTF_8));
            var response = pushService.send(notification);
            int status = response.getStatusLine().getStatusCode();
            if (status == 404 || status == 410) {
                // Abonnement expiré/révoqué côté navigateur : purge.
                removeSubscription(endpoint);
            } else if (status >= 400) {
                log.warn("Web Push admin : réponse HTTP {} pour un abonnement.", status);
            }
        } catch (Exception ex) {
            log.warn("Échec envoi Web Push admin : {}", ex.getMessage());
        }
    }

    private static String buildPayload(String title, String body, String url) {
        return "{\"title\":\"" + escape(title) + "\","
            + "\"body\":\"" + escape(body == null ? "" : body) + "\","
            + "\"url\":\"" + escape(url == null || url.isBlank() ? "/admin" : url) + "\"}";
    }

    private static String escape(String s) {
        StringBuilder sb = new StringBuilder(s.length() + 8);
        for (int i = 0; i < s.length(); i++) {
            char c = s.charAt(i);
            switch (c) {
                case '"' -> sb.append("\\\"");
                case '\\' -> sb.append("\\\\");
                case '\n' -> sb.append("\\n");
                case '\r' -> sb.append("\\r");
                case '\t' -> sb.append("\\t");
                default -> {
                    if (c < 0x20) {
                        sb.append(String.format("\\u%04x", (int) c));
                    } else {
                        sb.append(c);
                    }
                }
            }
        }
        return sb.toString();
    }
}
