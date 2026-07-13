package com.payflex.backend.controller;

import com.payflex.backend.service.DeviceTokenService;
import com.payflex.backend.service.MobileApiService;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.Map;

/**
 * Enregistrement des jetons push FCM des apps mobiles (client + agent).
 * <p>
 * Séparé de {@code MobileApiController} pour limiter les conflits. Route sous
 * {@code /api/mobile/**} (hors filtre Spring Security) ; l'authentification se fait
 * par les identifiants de session mobile ({@code userId} + {@code phone} + {@code pin}),
 * comme le reste de l'API mobile.
 */
@RestController
@RequestMapping("/api/mobile/devices")
public class MobilePushController {

    private final MobileApiService mobileApiService;
    private final DeviceTokenService deviceTokenService;

    public MobilePushController(MobileApiService mobileApiService, DeviceTokenService deviceTokenService) {
        this.mobileApiService = mobileApiService;
        this.deviceTokenService = deviceTokenService;
    }

    @PostMapping("/register-token")
    public ResponseEntity<?> registerToken(@RequestBody Map<String, Object> payload) {
        long userId = parseLong(payload.get("userId"));
        if (userId <= 0 || !credentialsMatch(payload, userId)) {
            return ResponseEntity.status(401).body(Map.of("message", "Session invalide."));
        }
        String token = String.valueOf(payload.getOrDefault("token", "")).trim();
        if (token.isEmpty()) {
            token = String.valueOf(payload.getOrDefault("fcmToken", "")).trim();
        }
        if (token.isEmpty()) {
            return ResponseEntity.badRequest().body(Map.of("message", "Jeton manquant."));
        }
        String platform = String.valueOf(payload.getOrDefault("platform", "android")).trim();
        String role = String.valueOf(payload.getOrDefault("role", "")).trim();
        deviceTokenService.registerToken(userId, token, platform, role);
        return ResponseEntity.ok(Map.of("ok", true));
    }

    @PostMapping("/unregister-token")
    public ResponseEntity<?> unregisterToken(@RequestBody Map<String, Object> payload) {
        String token = String.valueOf(payload.getOrDefault("token", "")).trim();
        if (token.isEmpty()) {
            token = String.valueOf(payload.getOrDefault("fcmToken", "")).trim();
        }
        // La déconnexion invalide souvent les identifiants : on purge le jeton
        // dès qu'il est fourni (le jeton étant lui-même le secret de l'appareil).
        if (!token.isEmpty()) {
            deviceTokenService.removeToken(token);
        }
        return ResponseEntity.ok(Map.of("ok", true));
    }

    private boolean credentialsMatch(Map<String, Object> payload, long userId) {
        String phone = String.valueOf(payload.getOrDefault("phone", "")).trim();
        String pin = String.valueOf(payload.getOrDefault("pin", "")).trim();
        if (phone.isEmpty() || pin.isEmpty()) {
            return false;
        }
        return mobileApiService.profileByCredentials(phone, pin, userId) != null;
    }

    private static long parseLong(Object value) {
        if (value == null) {
            return 0L;
        }
        try {
            return Long.parseLong(value.toString().trim());
        } catch (NumberFormatException ex) {
            return 0L;
        }
    }
}
