package com.payflex.backend.controller;

import com.payflex.backend.service.PayDunyaPaymentService;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.ResponseEntity;
import org.springframework.util.MultiValueMap;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.Map;

/**
 * IPN PayDunya : PayDunya POST en {@code application/x-www-form-urlencoded} un tableau sous
 * la clé {@code data} (ex. {@code data[invoice][token]}, {@code data[status]}). On NE fait PAS
 * confiance aveuglément : {@link PayDunyaPaymentService#handleIpn(String)} revalide via
 * {@code confirm/{token}} avant de marquer la cotisation payée (idempotent).
 */
@RestController
@RequestMapping("/api/paydunya")
public class PayDunyaWebhookController {

    private static final Logger log = LoggerFactory.getLogger(PayDunyaWebhookController.class);

    private final PayDunyaPaymentService payDunyaPaymentService;

    public PayDunyaWebhookController(PayDunyaPaymentService payDunyaPaymentService) {
        this.payDunyaPaymentService = payDunyaPaymentService;
    }

    @PostMapping(value = "/webhook", consumes = "application/x-www-form-urlencoded")
    public ResponseEntity<Map<String, Object>> webhook(@RequestBody MultiValueMap<String, String> form) {
        try {
            String token = extractToken(form);
            if (token == null || token.isBlank()) {
                log.warn("IPN PayDunya : jeton de facture introuvable dans le corps.");
                return ResponseEntity.badRequest().body(Map.of("received", false, "error", "missing_token"));
            }
            payDunyaPaymentService.handleIpn(token);
            return ResponseEntity.ok(Map.of("received", true));
        } catch (Exception ex) {
            log.error("IPN PayDunya : {}", ex.getMessage());
            return ResponseEntity.internalServerError().body(Map.of("received", false));
        }
    }

    /**
     * Récupère le jeton de facture quelle que soit la forme des clés form-urlencoded envoyées
     * par PayDunya ({@code data[invoice][token]}, {@code data[token]}, {@code token}…).
     */
    private static String extractToken(MultiValueMap<String, String> form) {
        if (form == null || form.isEmpty()) {
            return null;
        }
        String invoiceToken = null;
        String anyToken = null;
        for (Map.Entry<String, java.util.List<String>> entry : form.entrySet()) {
            String key = entry.getKey() == null ? "" : entry.getKey().toLowerCase();
            String value = entry.getValue() == null || entry.getValue().isEmpty() ? null : entry.getValue().get(0);
            if (value == null || value.isBlank() || !key.contains("token")) {
                continue;
            }
            if (key.contains("invoice")) {
                invoiceToken = value;
            }
            anyToken = value;
        }
        return invoiceToken != null ? invoiceToken : anyToken;
    }
}
