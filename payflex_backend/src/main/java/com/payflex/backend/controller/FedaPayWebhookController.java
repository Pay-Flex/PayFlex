package com.payflex.backend.controller;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.payflex.backend.service.FedaPayPaymentService;
import com.payflex.backend.service.FedaPayService;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.Map;

@RestController
@RequestMapping("/api/fedapay")
public class FedaPayWebhookController {

    private static final Logger log = LoggerFactory.getLogger(FedaPayWebhookController.class);

    private final FedaPayService fedaPayService;
    private final FedaPayPaymentService fedaPayPaymentService;
    private final ObjectMapper objectMapper;

    public FedaPayWebhookController(
        FedaPayService fedaPayService,
        FedaPayPaymentService fedaPayPaymentService,
        ObjectMapper objectMapper
    ) {
        this.fedaPayService = fedaPayService;
        this.fedaPayPaymentService = fedaPayPaymentService;
        this.objectMapper = objectMapper;
    }

    @PostMapping("/webhook")
    public ResponseEntity<Map<String, Object>> webhook(
        @RequestBody String rawBody,
        @RequestHeader(value = "X-FEDAPAY-SIGNATURE", required = false) String signature
    ) {
        if (!fedaPayService.verifyWebhookSignature(rawBody, signature)) {
            log.warn("Webhook FedaPay : signature invalide ou absente.");
            return ResponseEntity.badRequest().body(Map.of("received", false, "error", "invalid_signature"));
        }
        try {
            JsonNode root = objectMapper.readTree(rawBody);
            String eventName = text(root, "name");
            if (eventName == null) {
                eventName = text(root, "event");
            }
            if (eventName == null) {
                eventName = text(root.path("data"), "name");
            }
            JsonNode entity = root.path("entity");
            if (entity.isMissingNode()) {
                entity = root.path("data").path("entity");
            }
            if (entity.isMissingNode()) {
                entity = root.path("data");
            }
            fedaPayPaymentService.handleWebhookEvent(eventName, entity);
            return ResponseEntity.ok(Map.of("received", true));
        } catch (Exception ex) {
            log.error("Webhook FedaPay : {}", ex.getMessage());
            return ResponseEntity.internalServerError().body(Map.of("received", false));
        }
    }

    private static String text(JsonNode node, String field) {
        if (node == null || !node.has(field) || node.get(field).isNull()) {
            return null;
        }
        return node.get(field).asText();
    }
}
