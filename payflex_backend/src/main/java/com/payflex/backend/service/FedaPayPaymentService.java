package com.payflex.backend.service;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.payflex.backend.config.PayflexProperties;
import org.springframework.dao.EmptyResultDataAccessException;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.LinkedHashMap;
import java.util.Map;
import java.util.Objects;
import java.util.Optional;

@Service
public class FedaPayPaymentService {

    private final JdbcTemplate jdbcTemplate;
    private final FedaPayService fedaPayService;
    private final ContributionWorkflowService contributionWorkflowService;
    private final ContributionValidationAlertService alertService;
    private final AdminAuditService auditService;
    private final ClientAdhesionService clientAdhesionService;
    private final PayflexProperties.Fedapay fedapayConfig;

    public FedaPayPaymentService(
        JdbcTemplate jdbcTemplate,
        FedaPayService fedaPayService,
        ContributionWorkflowService contributionWorkflowService,
        ContributionValidationAlertService alertService,
        AdminAuditService auditService,
        ClientAdhesionService clientAdhesionService,
        PayflexProperties payflexProperties
    ) {
        this.jdbcTemplate = jdbcTemplate;
        this.fedaPayService = fedaPayService;
        this.contributionWorkflowService = contributionWorkflowService;
        this.alertService = alertService;
        this.auditService = auditService;
        this.clientAdhesionService = clientAdhesionService;
        this.fedapayConfig = payflexProperties.getFedapay();
    }

    public boolean isAvailable() {
        return fedaPayService.isConfigured();
    }

    @Transactional
    public Map<String, Object> initMobileMoneyPayment(
        long userId,
        Long productId,
        Long agentRowId,
        double amount
    ) {
        if (!isAvailable()) {
            return Map.of("fedapayEnabled", false);
        }
        int amountFcfa = (int) Math.round(amount);
        if (amountFcfa <= 0) {
            throw new IllegalArgumentException("Montant invalide.");
        }
        String ref = "PF-FEDAPAY-" + System.currentTimeMillis();
        jdbcTemplate.update(
            """
            INSERT INTO contributions (user_id, product_id, agent_id, amount, payment_mode, status, reference_code, paid_at, payment_provider)
            VALUES (?, ?, ?, ?, 'mobile_money', 'pending', ?, NULL, 'fedapay')
            """,
            userId,
            productId,
            agentRowId,
            amount,
            ref
        );
        long contributionId = jdbcTemplate.queryForObject("SELECT LAST_INSERT_ID()", Long.class);

        Map<String, Object> customer = buildCustomerPayload(userId);
        String callbackUrl = fedapayConfig.getPublicBaseUrl().replaceAll("/$", "")
            + "/api/mobile/contributions/fedapay/callback?contributionId=" + contributionId;
        String description = "PayFlex cotisation #" + contributionId + " — " + ref;

        FedaPayService.CheckoutResult checkout = fedaPayService.createCheckout(
            amountFcfa,
            description,
            callbackUrl,
            customer
        );

        jdbcTemplate.update(
            "UPDATE contributions SET fedapay_transaction_id = ? WHERE id = ?",
            checkout.transactionId(),
            contributionId
        );

        auditService.logClient(
            userId,
            "Paiement mobile money initié via FedaPay (" + amountFcfa + " FCFA, réf. " + ref + ")."
        );

        Map<String, Object> out = new LinkedHashMap<>();
        out.put("fedapayEnabled", true);
        out.put("contributionId", contributionId);
        out.put("referenceCode", ref);
        out.put("paymentUrl", checkout.paymentUrl());
        out.put("fedapayTransactionId", checkout.transactionId());
        out.put("callbackUrl", callbackUrl);
        out.put("publicBaseUrl", fedapayConfig.getPublicBaseUrl());
        out.put("status", "pending");
        out.put("message", "Ouvrez la page FedaPay pour finaliser le paiement.");
        return out;
    }

    @Transactional
    public Map<String, Object> initAdhesionPayment(long userId) {
        if (!isAvailable()) {
            return Map.of("fedapayEnabled", false);
        }
        ensureClientMayPayAdhesion(userId);
        Map<String, Object> customer = buildCustomerPayload(userId);
        String callbackUrl = fedapayConfig.getPublicBaseUrl().replaceAll("/$", "")
            + "/api/mobile/adhesion/fedapay/callback?userId=" + userId;
        String description = "PayFlex adhésion — " + ClientAdhesionService.ADHESION_FEE_FCFA + " FCFA";

        FedaPayService.CheckoutResult checkout = fedaPayService.createCheckout(
            ClientAdhesionService.ADHESION_FEE_FCFA,
            description,
            callbackUrl,
            customer
        );

        jdbcTemplate.update(
            "UPDATE users SET adhesion_fedapay_transaction_id = ? WHERE id = ?",
            checkout.transactionId(),
            userId
        );

        auditService.logClient(
            userId,
            "Paiement adhésion initié via FedaPay (" + ClientAdhesionService.ADHESION_FEE_FCFA + " FCFA)."
        );

        Map<String, Object> out = new LinkedHashMap<>();
        out.put("fedapayEnabled", true);
        out.put("paymentUrl", checkout.paymentUrl());
        out.put("fedapayTransactionId", checkout.transactionId());
        out.put("callbackUrl", callbackUrl);
        out.put("publicBaseUrl", fedapayConfig.getPublicBaseUrl());
        out.put("amountFcfa", ClientAdhesionService.ADHESION_FEE_FCFA);
        out.put("status", "pending");
        out.put("message", "Ouvrez FedaPay pour payer votre adhésion PayFlex.");
        return out;
    }

    public Map<String, Object> adhesionPaymentStatus(long userId) {
        ensureClient(userId);
        Map<String, Object> row = jdbcTemplate.queryForMap(
            """
            SELECT adhesion_fee_paid, status, adhesion_fedapay_transaction_id
            FROM users WHERE id = ?
            """,
            userId
        );
        boolean paid = Boolean.TRUE.equals(row.get("adhesion_fee_paid"));
        if (paid || ClientAdhesionService.STATUS_ADHERED.equals(String.valueOf(row.get("status")))) {
            return Map.of("status", "adhered", "adhesionFeePaid", true);
        }
        String fedapayTx = Objects.toString(row.get("adhesion_fedapay_transaction_id"), "");
        if (!fedapayTx.isBlank()) {
            fedaPayService.fetchTransactionStatus(fedapayTx).ifPresent(fpStatus -> {
                if (isApproved(fpStatus)) {
                    try {
                        clientAdhesionService.markAdhesionPaidByFedaPay(userId, fedapayTx);
                    } catch (IllegalArgumentException ignored) {
                        // déjà réglée
                    }
                }
            });
            row = jdbcTemplate.queryForMap(
                "SELECT adhesion_fee_paid, status FROM users WHERE id = ?",
                userId
            );
            paid = Boolean.TRUE.equals(row.get("adhesion_fee_paid"));
        }
        Map<String, Object> out = new LinkedHashMap<>();
        out.put("status", paid ? "adhered" : "pending");
        out.put("adhesionFeePaid", paid);
        out.put("fedapayTransactionId", fedapayTx);
        return out;
    }

    public Map<String, Object> paymentStatus(long contributionId, long userId) {
        Map<String, Object> row = loadContribution(contributionId);
        if (row == null) {
            throw new IllegalArgumentException("Cotisation introuvable.");
        }
        long owner = ((Number) row.get("user_id")).longValue();
        if (owner != userId) {
            throw new IllegalArgumentException("Accès refusé.");
        }
        String status = Objects.toString(row.get("status"), "pending");
        String fedapayTx = Objects.toString(row.get("fedapay_transaction_id"), "");
        if ("pending".equals(status) && !fedapayTx.isBlank()) {
            fedaPayService.fetchTransactionStatus(fedapayTx).ifPresent(fpStatus -> {
                if (isApproved(fpStatus)) {
                    try {
                        contributionWorkflowService.validateByFedaPay(contributionId, fedapayTx);
                    } catch (IllegalArgumentException ignored) {
                        // déjà validée entre-temps
                    }
                }
            });
            row = loadContribution(contributionId);
            if (row != null) {
                status = Objects.toString(row.get("status"), status);
            }
        }
        Map<String, Object> out = new LinkedHashMap<>();
        out.put("contributionId", contributionId);
        out.put("status", status);
        out.put("referenceCode", row == null ? "" : Objects.toString(row.get("reference_code"), ""));
        out.put("fedapayTransactionId", fedapayTx);
        return out;
    }

    @Transactional
    public void handleWebhookEvent(String eventName, JsonNode entity) {
        String transactionId = extractTransactionId(entity);
        if (transactionId == null || transactionId.isBlank()) {
            return;
        }
        Long adhesionUserId = findUserIdByAdhesionFedaPayTx(transactionId);
        if (adhesionUserId != null) {
            if (isPaymentSuccessEvent(eventName, entity)) {
                try {
                    clientAdhesionService.markAdhesionPaidByFedaPay(adhesionUserId, transactionId);
                } catch (IllegalArgumentException ignored) {
                    // déjà réglée
                }
            }
            return;
        }

        Long contributionId = findContributionIdByFedaPayTx(transactionId);
        if (contributionId == null) {
            return;
        }
        if (isPaymentSuccessEvent(eventName, entity)) {
            contributionWorkflowService.validateByFedaPay(contributionId, transactionId);
            alertService.create(
                contributionId,
                ContributionValidationAlertService.TYPE_FEDAPAY_APPROVED,
                "Paiement FedaPay confirmé (transaction " + transactionId + ")."
            );
        } else if (isPaymentCanceledEvent(eventName, entity)) {
            jdbcTemplate.update(
                """
                UPDATE contributions
                SET status = 'rejected', rejection_reason = ?, paid_at = NULL
                WHERE id = ? AND status = 'pending'
                """,
                "Paiement FedaPay annulé ou expiré.",
                contributionId
            );
            alertService.create(
                contributionId,
                ContributionValidationAlertService.TYPE_FEDAPAY_CANCELED,
                "Paiement FedaPay annulé (transaction " + transactionId + ")."
            );
        }
    }

    /** Code pays FedaPay (ISO) à partir du préfixe international. */
    private static String phoneCountryIso(String e164) {
        if (e164.startsWith("+228")) {
            return "tg";
        }
        if (e164.startsWith("+229")) {
            return "bj";
        }
        if (e164.startsWith("+225")) {
            return "ci";
        }
        if (e164.startsWith("+221")) {
            return "sn";
        }
        return "tg";
    }

    private Map<String, Object> buildCustomerPayload(long userId) {
        try {
            Map<String, Object> u = jdbcTemplate.queryForMap(
                "SELECT full_name, phone, email FROM users WHERE id = ?",
                userId
            );
            String fullName = Objects.toString(u.get("full_name"), "Client PayFlex");
            String[] parts = fullName.trim().split("\\s+", 2);
            Map<String, Object> customer = new LinkedHashMap<>();
            customer.put("firstname", parts[0]);
            customer.put("lastname", parts.length > 1 ? parts[1] : "PayFlex");
            String email = Objects.toString(u.get("email"), "");
            if (!email.isBlank()) {
                customer.put("email", email);
            }
            String phone = Objects.toString(u.get("phone"), "");
            if (!phone.isBlank()) {
                String normalized = phone.startsWith("+") ? phone : "+" + phone.replaceAll("\\D", "");
                Map<String, Object> phoneNode = new LinkedHashMap<>();
                phoneNode.put("number", normalized);
                phoneNode.put("country", phoneCountryIso(normalized));
                customer.put("phone_number", phoneNode);
            }
            return customer;
        } catch (EmptyResultDataAccessException ex) {
            return Map.of("firstname", "Client", "lastname", "PayFlex");
        }
    }

    private Map<String, Object> loadContribution(long id) {
        try {
            return jdbcTemplate.queryForMap(
                """
                SELECT id, user_id, status, reference_code, fedapay_transaction_id
                FROM contributions WHERE id = ?
                """,
                id
            );
        } catch (EmptyResultDataAccessException ex) {
            return null;
        }
    }

    private void ensureClientMayPayAdhesion(long userId) {
        ensureClient(userId);
        Map<String, Object> row = jdbcTemplate.queryForMap(
            "SELECT adhesion_fee_paid, status FROM users WHERE id = ?",
            userId
        );
        if (Boolean.TRUE.equals(row.get("adhesion_fee_paid"))
            || ClientAdhesionService.STATUS_ADHERED.equals(String.valueOf(row.get("status")))) {
            throw new IllegalArgumentException("Adhésion déjà réglée.");
        }
        String status = String.valueOf(row.get("status"));
        if ("bloque".equals(status) || "pending".equals(status)) {
            throw new IllegalArgumentException("Compte non éligible au paiement d'adhésion.");
        }
    }

    private void ensureClient(long userId) {
        Long n = jdbcTemplate.queryForObject(
            """
            SELECT COUNT(*) FROM users u
            INNER JOIN roles r ON r.id = u.role_id AND r.code = 'client'
            WHERE u.id = ?
            """,
            Long.class,
            userId
        );
        if (n == null || n == 0) {
            throw new IllegalArgumentException("Client introuvable.");
        }
    }

    private Long findUserIdByAdhesionFedaPayTx(String transactionId) {
        try {
            return jdbcTemplate.queryForObject(
                "SELECT id FROM users WHERE adhesion_fedapay_transaction_id = ? LIMIT 1",
                Long.class,
                transactionId
            );
        } catch (EmptyResultDataAccessException ex) {
            return null;
        }
    }

    private Long findContributionIdByFedaPayTx(String transactionId) {
        try {
            return jdbcTemplate.queryForObject(
                "SELECT id FROM contributions WHERE fedapay_transaction_id = ? LIMIT 1",
                Long.class,
                transactionId
            );
        } catch (EmptyResultDataAccessException ex) {
            return null;
        }
    }

    private static boolean isApproved(String fpStatus) {
        if (fpStatus == null) {
            return false;
        }
        String s = fpStatus.toLowerCase();
        return s.contains("approved") || s.contains("completed") || s.equals("success");
    }

    /** Succès FedaPay : nom d'événement webhook ou statut dans l'entité transaction. */
    private static boolean isPaymentSuccessEvent(String eventName, JsonNode entity) {
        if (eventName != null) {
            String e = eventName.toLowerCase();
            if (e.contains("approved") || e.contains("completed") || e.contains("success")) {
                return true;
            }
        }
        String txStatus = textAt(entity, "status");
        if (txStatus == null && entity != null) {
            txStatus = textAt(entity.path("data"), "status");
        }
        return isApproved(txStatus);
    }

    private static boolean isPaymentCanceledEvent(String eventName, JsonNode entity) {
        if (eventName != null) {
            String e = eventName.toLowerCase();
            if (e.contains("canceled") || e.contains("cancelled") || e.contains("failed")) {
                return true;
            }
        }
        String txStatus = textAt(entity, "status");
        if (txStatus == null && entity != null) {
            txStatus = textAt(entity.path("data"), "status");
        }
        if (txStatus != null) {
            String s = txStatus.toLowerCase();
            return s.contains("canceled") || s.contains("cancelled") || s.contains("failed");
        }
        return false;
    }

    private static String textAt(JsonNode node, String field) {
        if (node == null || !node.has(field) || node.get(field).isNull()) {
            return null;
        }
        return node.get(field).asText();
    }

    private static String extractTransactionId(JsonNode entity) {
        if (entity == null || entity.isMissingNode()) {
            return null;
        }
        if (entity.has("id") && !entity.get("id").isNull()) {
            return entity.get("id").asText();
        }
        JsonNode data = entity.path("data");
        if (data.has("id")) {
            return data.get("id").asText();
        }
        if (data.has("transaction_id")) {
            return data.get("transaction_id").asText();
        }
        return null;
    }
}
