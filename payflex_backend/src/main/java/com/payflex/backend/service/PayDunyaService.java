package com.payflex.backend.service;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ObjectNode;
import com.payflex.backend.config.PayflexProperties;
import org.springframework.http.MediaType;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestClient;
import org.springframework.web.client.RestClientResponseException;

import java.util.Map;
import java.util.Optional;

/**
 * Client HTTP PayDunya (API « Checkout Invoice » — Paiement Avec Redirection).
 * Le montant est verrouillé côté serveur via {@code total_amount}.
 */
@Service
public class PayDunyaService {

    private final PayflexProperties.Paydunya config;
    private final RestClient restClient;
    private final ObjectMapper objectMapper;

    public PayDunyaService(PayflexProperties payflexProperties, ObjectMapper objectMapper) {
        this.config = payflexProperties.getPaydunya();
        this.objectMapper = objectMapper;
        this.restClient = RestClient.builder().build();
    }

    public boolean isConfigured() {
        return config.isConfigured();
    }

    /** @param token jeton de facture PayDunya, {@code paymentUrl} = page de paiement à ouvrir. */
    public record CheckoutResult(String token, String paymentUrl, String status) {}

    /**
     * Crée une facture Checkout Invoice. {@code total_amount} est le montant facturé (les items
     * sont décoratifs). {@code customData} rattache le paiement à la cotisation/client PayFlex.
     */
    public CheckoutResult createCheckout(
        int amountFcfa,
        String description,
        String callbackUrl,
        String returnUrl,
        String cancelUrl,
        Map<String, Object> customer,
        Map<String, Object> customData
    ) {
        if (!isConfigured()) {
            throw new IllegalStateException("PayDunya n'est pas configuré (clés d'API manquantes).");
        }

        ObjectNode invoice = objectMapper.createObjectNode();
        invoice.put("total_amount", amountFcfa);
        invoice.put("description", description);
        if (customer != null && !customer.isEmpty()) {
            invoice.set("customer", objectMapper.valueToTree(customer));
        }

        ObjectNode store = objectMapper.createObjectNode();
        store.put("name", "PayFlex");

        ObjectNode actions = objectMapper.createObjectNode();
        if (callbackUrl != null && !callbackUrl.isBlank()) {
            actions.put("callback_url", callbackUrl);
        }
        if (returnUrl != null && !returnUrl.isBlank()) {
            actions.put("return_url", returnUrl);
        }
        if (cancelUrl != null && !cancelUrl.isBlank()) {
            actions.put("cancel_url", cancelUrl);
        }

        ObjectNode body = objectMapper.createObjectNode();
        body.set("invoice", invoice);
        body.set("store", store);
        body.set("actions", actions);
        if (customData != null && !customData.isEmpty()) {
            body.set("custom_data", objectMapper.valueToTree(customData));
        }

        JsonNode res = post("/checkout-invoice/create", body);
        String responseCode = textAt(res, "response_code");
        if (!"00".equals(responseCode)) {
            throw new IllegalStateException(
                "PayDunya : création de facture refusée (" + textAt(res, "response_text") + ")."
            );
        }
        String token = textAt(res, "token");
        if (token == null || token.isBlank()) {
            throw new IllegalStateException("Réponse PayDunya invalide : jeton de facture absent.");
        }
        // response_text contient l'URL de paiement (https://paydunya.com/checkout/invoice/{token}).
        String url = textAt(res, "response_text");
        if (url == null || !url.startsWith("http")) {
            url = textAt(res, "invoice_url");
        }
        if (url == null || url.isBlank()) {
            throw new IllegalStateException("Lien de paiement PayDunya indisponible.");
        }
        return new CheckoutResult(token, url, "pending");
    }

    /**
     * Vérifie l'état d'un paiement via {@code confirm/{token}}. Statuts PayDunya :
     * {@code pending}, {@code completed}, {@code cancelled}, {@code failed}.
     */
    public Optional<String> fetchInvoiceStatus(String token) {
        if (!isConfigured() || token == null || token.isBlank()) {
            return Optional.empty();
        }
        try {
            JsonNode res = get("/checkout-invoice/confirm/" + token);
            String status = textAt(res, "status");
            return Optional.ofNullable(status);
        } catch (RestClientResponseException ex) {
            return Optional.empty();
        } catch (Exception ex) {
            return Optional.empty();
        }
    }

    private JsonNode post(String path, JsonNode body) {
        try {
            String response = restClient.post()
                .uri(config.apiBaseUrl() + path)
                .header("PAYDUNYA-MASTER-KEY", config.getMasterKey())
                .header("PAYDUNYA-PRIVATE-KEY", config.getPrivateKey())
                .header("PAYDUNYA-TOKEN", config.getToken())
                .contentType(MediaType.APPLICATION_JSON)
                .body(body.toString())
                .retrieve()
                .body(String.class);
            return objectMapper.readTree(response == null ? "{}" : response);
        } catch (RestClientResponseException ex) {
            throw new IllegalStateException("PayDunya API : " + ex.getStatusCode() + " — " + ex.getResponseBodyAsString());
        } catch (Exception ex) {
            throw new IllegalStateException("PayDunya API indisponible : " + ex.getMessage());
        }
    }

    private JsonNode get(String path) {
        try {
            String response = restClient.get()
                .uri(config.apiBaseUrl() + path)
                .header("PAYDUNYA-MASTER-KEY", config.getMasterKey())
                .header("PAYDUNYA-PRIVATE-KEY", config.getPrivateKey())
                .header("PAYDUNYA-TOKEN", config.getToken())
                .header("Content-Type", "application/json")
                .retrieve()
                .body(String.class);
            return objectMapper.readTree(response == null ? "{}" : response);
        } catch (RestClientResponseException ex) {
            throw new IllegalStateException("PayDunya API : " + ex.getStatusCode());
        } catch (Exception ex) {
            throw new IllegalStateException("PayDunya API : " + ex.getMessage());
        }
    }

    private static String textAt(JsonNode node, String field) {
        if (node == null || node.isMissingNode() || !node.has(field) || node.get(field).isNull()) {
            return null;
        }
        return node.get(field).asText();
    }
}
