package com.payflex.backend.service;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ObjectNode;
import com.payflex.backend.config.PayflexProperties;
import org.springframework.http.MediaType;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestClient;
import org.springframework.web.client.RestClientResponseException;

import javax.crypto.Mac;
import javax.crypto.spec.SecretKeySpec;
import java.nio.charset.StandardCharsets;
import java.util.HexFormat;
import java.util.Map;
import java.util.Optional;

@Service
public class FedaPayService {

    private final PayflexProperties.Fedapay config;
    private final RestClient restClient;
    private final ObjectMapper objectMapper;

    public FedaPayService(PayflexProperties payflexProperties, ObjectMapper objectMapper) {
        this.config = payflexProperties.getFedapay();
        this.objectMapper = objectMapper;
        this.restClient = RestClient.builder().build();
    }

    public boolean isConfigured() {
        return config.isConfigured();
    }

    public record CheckoutResult(String transactionId, String paymentUrl, String status) {}

    public CheckoutResult createCheckout(
        int amountFcfa,
        String description,
        String callbackUrl,
        Map<String, Object> customer
    ) {
        if (!isConfigured()) {
            throw new IllegalStateException("FedaPay n'est pas configuré (clé API manquante).");
        }
        ObjectNode body = objectMapper.createObjectNode();
        body.put("description", description);
        body.put("amount", amountFcfa);
        body.set("currency", objectMapper.createObjectNode().put("iso", "XOF"));
        if (callbackUrl != null && !callbackUrl.isBlank()) {
            body.put("callback_url", callbackUrl);
        }
        if (customer != null && !customer.isEmpty()) {
            body.set("customer", objectMapper.valueToTree(customer));
        }

        JsonNode tx = post("/transactions", body);
        JsonNode entity = unwrapEntity(tx);
        String transactionId = textAt(entity, "id");
        if (transactionId == null || transactionId.isBlank()) {
            throw new IllegalStateException("Réponse FedaPay invalide : identifiant transaction absent.");
        }
        String url = textAt(entity, "payment_url");
        if (url == null || url.isBlank()) {
            JsonNode tokenRes = post("/transactions/" + transactionId + "/token", objectMapper.createObjectNode());
            url = textAt(unwrapEntity(tokenRes), "url");
            if (url == null) {
                url = textAt(tokenRes, "url");
            }
        }
        if (url == null || url.isBlank()) {
            throw new IllegalStateException("Lien de paiement FedaPay indisponible.");
        }
        String status = textAt(entity, "status");
        return new CheckoutResult(transactionId, url, status == null ? "pending" : status);
    }

    public Optional<String> fetchTransactionStatus(String transactionId) {
        if (!isConfigured() || transactionId == null || transactionId.isBlank()) {
            return Optional.empty();
        }
        try {
            JsonNode tx = get("/transactions/" + transactionId);
            String status = textAt(unwrapEntity(tx), "status");
            return Optional.ofNullable(status);
        } catch (RestClientResponseException ex) {
            return Optional.empty();
        }
    }

    public boolean verifyWebhookSignature(String rawBody, String signatureHeader) {
        if (signatureHeader == null || signatureHeader.isBlank()) {
            return false;
        }
        String secret = config.getWebhookSecret();
        if (secret == null || secret.isBlank()) {
            // Mode test sans secret : accepter uniquement en sandbox
            return config.isSandbox();
        }
        try {
            Mac mac = Mac.getInstance("HmacSHA256");
            mac.init(new SecretKeySpec(secret.getBytes(StandardCharsets.UTF_8), "HmacSHA256"));
            byte[] hash = mac.doFinal(rawBody.getBytes(StandardCharsets.UTF_8));
            String computed = HexFormat.of().formatHex(hash);
            String sig = signatureHeader.trim().toLowerCase();
            if (sig.startsWith("sha256=")) {
                sig = sig.substring(7);
            }
            return computed.equalsIgnoreCase(sig) || signatureHeader.equalsIgnoreCase(computed);
        } catch (Exception ex) {
            return false;
        }
    }

    private JsonNode post(String path, JsonNode body) {
        try {
            String response = restClient.post()
                .uri(config.apiBaseUrl() + path)
                .header("Authorization", "Bearer " + config.getApiKey())
                .contentType(MediaType.APPLICATION_JSON)
                .body(body.toString())
                .retrieve()
                .body(String.class);
            return objectMapper.readTree(response == null ? "{}" : response);
        } catch (RestClientResponseException ex) {
            throw new IllegalStateException("FedaPay API : " + ex.getStatusCode() + " — " + ex.getResponseBodyAsString());
        } catch (Exception ex) {
            throw new IllegalStateException("FedaPay API indisponible : " + ex.getMessage());
        }
    }

    private JsonNode get(String path) {
        try {
            String response = restClient.get()
                .uri(config.apiBaseUrl() + path)
                .header("Authorization", "Bearer " + config.getApiKey())
                .retrieve()
                .body(String.class);
            return objectMapper.readTree(response == null ? "{}" : response);
        } catch (RestClientResponseException ex) {
            throw new IllegalStateException("FedaPay API : " + ex.getStatusCode());
        } catch (Exception ex) {
            throw new IllegalStateException("FedaPay API : " + ex.getMessage());
        }
    }

    /** FedaPay renvoie souvent `{ "v1/transaction": { ... } }` ou `{ "data": { ... } }`. */
    private static JsonNode unwrapEntity(JsonNode root) {
        if (root == null || root.isMissingNode()) {
            return root;
        }
        JsonNode data = root.path("data");
        if (data.isObject() && data.has("id")) {
            return data;
        }
        var fields = root.fields();
        while (fields.hasNext()) {
            var entry = fields.next();
            if (entry.getValue().isObject() && entry.getValue().has("id")) {
                return entry.getValue();
            }
        }
        return root;
    }

    private static String textAt(JsonNode node, String field) {
        if (node == null || node.isMissingNode() || !node.has(field) || node.get(field).isNull()) {
            return null;
        }
        return node.get(field).asText();
    }
}
