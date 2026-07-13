package com.payflex.backend.controller;

import com.payflex.backend.service.AdminWebPushService;
import jakarta.servlet.http.HttpServletRequest;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.security.Principal;
import java.util.Map;

/**
 * Abonnements Web Push des postes admin/support. Sous {@code /admin/**} :
 * protégé par la session Spring Security (rôles ADMIN / GESTIONNAIRE).
 */
@RestController
@RequestMapping("/admin/web-push")
public class AdminWebPushController {

    private final AdminWebPushService adminWebPushService;

    public AdminWebPushController(AdminWebPushService adminWebPushService) {
        this.adminWebPushService = adminWebPushService;
    }

    /** Clé publique VAPID + état d'activation, consommés par le JS admin. */
    @GetMapping("/config")
    public ResponseEntity<?> config() {
        return ResponseEntity.ok(Map.of(
            "enabled", adminWebPushService.isEnabled(),
            "publicKey", adminWebPushService.publicKey() == null ? "" : adminWebPushService.publicKey()
        ));
    }

    @PostMapping("/subscribe")
    public ResponseEntity<?> subscribe(@RequestBody Map<String, Object> payload, Principal principal, HttpServletRequest request) {
        if (principal == null) {
            return ResponseEntity.status(401).body(Map.of("message", "Session admin requise."));
        }
        String endpoint = String.valueOf(payload.getOrDefault("endpoint", "")).trim();
        Map<String, Object> keys = asMap(payload.get("keys"));
        String p256dh = keys == null ? "" : String.valueOf(keys.getOrDefault("p256dh", "")).trim();
        String auth = keys == null ? "" : String.valueOf(keys.getOrDefault("auth", "")).trim();
        if (endpoint.isEmpty() || p256dh.isEmpty() || auth.isEmpty()) {
            return ResponseEntity.badRequest().body(Map.of("message", "Abonnement invalide."));
        }
        adminWebPushService.saveSubscription(principal.getName(), endpoint, p256dh, auth, request.getHeader("User-Agent"));
        return ResponseEntity.ok(Map.of("ok", true));
    }

    @PostMapping("/unsubscribe")
    public ResponseEntity<?> unsubscribe(@RequestBody Map<String, Object> payload) {
        String endpoint = String.valueOf(payload.getOrDefault("endpoint", "")).trim();
        if (!endpoint.isEmpty()) {
            adminWebPushService.removeSubscription(endpoint);
        }
        return ResponseEntity.ok(Map.of("ok", true));
    }

    @SuppressWarnings("unchecked")
    private static Map<String, Object> asMap(Object value) {
        return value instanceof Map ? (Map<String, Object>) value : null;
    }
}
