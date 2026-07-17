package com.payflex.backend.service;

import com.payflex.backend.config.PayflexProperties;
import org.springframework.dao.EmptyResultDataAccessException;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.LinkedHashMap;
import java.util.Map;
import java.util.Objects;
import java.util.Optional;

/**
 * Paiement mobile money via PayDunya (Checkout Invoice) — passerelle unique de PayFlex.
 * Le montant est fixé et verrouillé côté serveur ({@code total_amount}) : jamais saisi par le client.
 */
@Service
public class PayDunyaPaymentService {

    private final JdbcTemplate jdbcTemplate;
    private final PayDunyaService payDunyaService;
    private final ContributionWorkflowService contributionWorkflowService;
    private final ContributionValidationAlertService alertService;
    private final AdminAuditService auditService;
    private final ClientAdhesionService clientAdhesionService;
    private final ContributionAllocationService contributionAllocationService;
    private final PayflexProperties.Paydunya paydunyaConfig;

    public PayDunyaPaymentService(
        JdbcTemplate jdbcTemplate,
        PayDunyaService payDunyaService,
        ContributionWorkflowService contributionWorkflowService,
        ContributionValidationAlertService alertService,
        AdminAuditService auditService,
        ClientAdhesionService clientAdhesionService,
        ContributionAllocationService contributionAllocationService,
        PayflexProperties payflexProperties
    ) {
        this.jdbcTemplate = jdbcTemplate;
        this.payDunyaService = payDunyaService;
        this.contributionWorkflowService = contributionWorkflowService;
        this.alertService = alertService;
        this.auditService = auditService;
        this.clientAdhesionService = clientAdhesionService;
        this.contributionAllocationService = contributionAllocationService;
        this.paydunyaConfig = payflexProperties.getPaydunya();
    }

    public boolean isAvailable() {
        return payDunyaService.isConfigured();
    }

    @Transactional
    public Map<String, Object> initMobileMoneyPayment(
        long userId,
        Long productId,
        Long agentRowId,
        double amount
    ) {
        return initMobileMoneyPayment(userId, productId, agentRowId, amount, null);
    }

    /**
     * Variante avec numéro de payeur optionnel (Flooz / Mixx by Yas d'un tiers). {@code payerPhone}
     * nul ou vide → on retombe sur le numéro du compte.
     */
    @Transactional
    public Map<String, Object> initMobileMoneyPayment(
        long userId,
        Long productId,
        Long agentRowId,
        double amount,
        String payerPhone
    ) {
        if (!isAvailable()) {
            return Map.of("paydunyaEnabled", false);
        }
        int amountFcfa = (int) Math.round(amount);
        if (amountFcfa <= 0) {
            throw new IllegalArgumentException("Montant invalide.");
        }
        // Pas de blocage ici : un montant supérieur au reste à payer sera automatiquement réparti
        // sur les autres produits actifs du client au moment de la VALIDATION du paiement
        // (webhook/IPN PayDunya confirmé) — voir ContributionWorkflowService#applyValidation.
        String ref = "PF-PAYDUNYA-" + System.currentTimeMillis();
        jdbcTemplate.update(
            """
            INSERT INTO contributions (user_id, product_id, agent_id, amount, payment_mode, status, reference_code, paid_at, payment_provider)
            VALUES (?, ?, ?, ?, 'mobile_money', 'pending', ?, NULL, 'paydunya')
            """,
            userId,
            productId,
            agentRowId,
            amount,
            ref
        );
        long contributionId = jdbcTemplate.queryForObject("SELECT LAST_INSERT_ID()", Long.class);

        Map<String, Object> customer = buildCustomerPayload(userId, payerPhone);
        String base = paydunyaConfig.getPublicBaseUrl().replaceAll("/$", "");
        String callbackUrl = base + "/api/paydunya/webhook";
        String returnUrl = base + "/api/mobile/contributions/paydunya/callback?contributionId=" + contributionId;
        String cancelUrl = returnUrl + "&status=cancelled";
        String description = "PayFlex cotisation #" + contributionId + " — " + ref;

        Map<String, Object> customData = new LinkedHashMap<>();
        customData.put("contributionId", contributionId);
        customData.put("clientId", userId);
        customData.put("referenceCode", ref);

        PayDunyaService.CheckoutResult checkout = payDunyaService.createCheckout(
            amountFcfa, description, callbackUrl, returnUrl, cancelUrl, customer, customData
        );

        jdbcTemplate.update(
            "UPDATE contributions SET paydunya_token = ? WHERE id = ?",
            checkout.token(),
            contributionId
        );

        auditService.logClient(
            userId,
            "Paiement mobile money initié via PayDunya (" + amountFcfa + " FCFA, réf. " + ref + ")."
        );

        Map<String, Object> out = new LinkedHashMap<>();
        out.put("paydunyaEnabled", true);
        out.put("contributionId", contributionId);
        out.put("referenceCode", ref);
        out.put("paymentUrl", checkout.paymentUrl());
        out.put("paydunyaToken", checkout.token());
        out.put("callbackUrl", returnUrl);
        out.put("publicBaseUrl", paydunyaConfig.getPublicBaseUrl());
        out.put("status", "pending");
        out.put("message", "Ouvrez la page PayDunya pour finaliser le paiement.");
        return out;
    }

    /**
     * Paiement de l'adhésion PayFlex (250 FCFA) via PayDunya.
     * {@code custom_data.kind = "adhesion"} rattache le paiement au client pour l'IPN.
     */
    @Transactional
    public Map<String, Object> initAdhesionPayment(long userId) {
        if (!isAvailable()) {
            return Map.of("paydunyaEnabled", false);
        }
        ensureClientMayPayAdhesion(userId);

        Map<String, Object> customer = buildCustomerPayload(userId, null);
        String base = paydunyaConfig.getPublicBaseUrl().replaceAll("/$", "");
        String callbackUrl = base + "/api/paydunya/webhook";
        String returnUrl = base + "/api/mobile/adhesion/paydunya/callback?userId=" + userId;
        String cancelUrl = returnUrl + "&status=cancelled";
        String description = "PayFlex adhésion — " + ClientAdhesionService.ADHESION_FEE_FCFA + " FCFA";

        Map<String, Object> customData = new LinkedHashMap<>();
        customData.put("kind", "adhesion");
        customData.put("clientId", userId);

        PayDunyaService.CheckoutResult checkout = payDunyaService.createCheckout(
            ClientAdhesionService.ADHESION_FEE_FCFA, description, callbackUrl, returnUrl, cancelUrl, customer, customData
        );

        jdbcTemplate.update(
            "UPDATE users SET adhesion_paydunya_token = ? WHERE id = ?",
            checkout.token(),
            userId
        );

        auditService.logClient(
            userId,
            "Paiement adhésion initié via PayDunya (" + ClientAdhesionService.ADHESION_FEE_FCFA + " FCFA)."
        );

        Map<String, Object> out = new LinkedHashMap<>();
        out.put("paydunyaEnabled", true);
        out.put("paymentUrl", checkout.paymentUrl());
        out.put("paydunyaToken", checkout.token());
        out.put("callbackUrl", returnUrl);
        out.put("publicBaseUrl", paydunyaConfig.getPublicBaseUrl());
        out.put("amountFcfa", ClientAdhesionService.ADHESION_FEE_FCFA);
        out.put("status", "pending");
        out.put("message", "Ouvrez la page PayDunya pour payer votre adhésion PayFlex.");
        return out;
    }

    public Map<String, Object> adhesionPaymentStatus(long userId) {
        ensureClient(userId);
        Map<String, Object> row = jdbcTemplate.queryForMap(
            """
            SELECT adhesion_fee_paid, status, adhesion_paydunya_token
            FROM users WHERE id = ?
            """,
            userId
        );
        boolean paid = Boolean.TRUE.equals(row.get("adhesion_fee_paid"));
        if (paid || ClientAdhesionService.STATUS_ADHERED.equals(String.valueOf(row.get("status")))) {
            return Map.of("status", "adhered", "adhesionFeePaid", true);
        }
        String token = Objects.toString(row.get("adhesion_paydunya_token"), "");
        if (!token.isBlank()) {
            payDunyaService.fetchInvoiceStatus(token).ifPresent(pdStatus -> {
                if (isCompleted(pdStatus)) {
                    try {
                        clientAdhesionService.markAdhesionPaidByPaydunya(userId, token);
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
        out.put("paydunyaToken", token);
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
        String token = Objects.toString(row.get("paydunya_token"), "");
        if ("pending".equals(status) && !token.isBlank()) {
            payDunyaService.fetchInvoiceStatus(token).ifPresent(pdStatus -> {
                if (isCompleted(pdStatus)) {
                    try {
                        contributionWorkflowService.validateByPaydunya(contributionId, token);
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
        out.put("paydunyaToken", token);
        if ("validated".equals(status)) {
            // Le paiement est confirmé : la répartition automatique (si l'excédent dépassait le
            // reste à payer sur le produit visé) a déjà eu lieu — on la renvoie à l'app mobile
            // pour qu'elle affiche clairement le détail (produit(s) + montant(s) affectés).
            ContributionAllocationService.AllocationOutcome outcome =
                contributionAllocationService.findOutcomeForContribution(contributionId);
            out.put("allocations", outcome.lines());
            out.put("unallocatedSurplusFcfa", outcome.unallocatedSurplusFcfa());
            out.put("wasSplit", outcome.wasSplit());
        }
        return out;
    }

    /**
     * Traite l'IPN PayDunya. On NE fait PAS confiance aveuglément au POST : on revalide le
     * paiement en rappelant {@code confirm/{token}} avant de marquer la cotisation payée
     * (idempotent). {@code token} est extrait du corps IPN par le contrôleur.
     */
    @Transactional
    public void handleIpn(String token) {
        if (token == null || token.isBlank()) {
            return;
        }
        // Adhésion (250 FCFA) : le jeton est stocké sur l'utilisateur, pas sur une cotisation.
        Long adhesionUserId = findUserIdByAdhesionToken(token);
        if (adhesionUserId != null) {
            Optional<String> adhesionStatus = payDunyaService.fetchInvoiceStatus(token);
            if (adhesionStatus.isPresent() && isCompleted(adhesionStatus.get())) {
                try {
                    clientAdhesionService.markAdhesionPaidByPaydunya(adhesionUserId, token);
                } catch (IllegalArgumentException ignored) {
                    // déjà réglée
                }
            }
            return;
        }

        Long contributionId = findContributionIdByToken(token);
        if (contributionId == null) {
            return;
        }
        Optional<String> confirmed = payDunyaService.fetchInvoiceStatus(token);
        if (confirmed.isEmpty()) {
            return;
        }
        String status = confirmed.get();
        if (isCompleted(status)) {
            contributionWorkflowService.validateByPaydunya(contributionId, token);
            alertService.create(
                contributionId,
                ContributionValidationAlertService.TYPE_PAYDUNYA_APPROVED,
                "Paiement PayDunya confirmé (jeton " + token + ")."
            );
        } else if (isCanceledOrFailed(status)) {
            int updated = jdbcTemplate.update(
                """
                UPDATE contributions
                SET status = 'rejected', rejection_reason = ?, paid_at = NULL
                WHERE id = ? AND status = 'pending'
                """,
                "Paiement PayDunya annulé ou expiré.",
                contributionId
            );
            if (updated > 0) {
                contributionWorkflowService.notifyPaydunyaContributionCanceled(contributionId);
            }
            alertService.create(
                contributionId,
                ContributionValidationAlertService.TYPE_PAYDUNYA_CANCELED,
                "Paiement PayDunya annulé (jeton " + token + ")."
            );
        }
    }

    private static boolean isCompleted(String status) {
        if (status == null) {
            return false;
        }
        String s = status.toLowerCase();
        return s.contains("completed") || s.contains("success") || s.contains("approved");
    }

    private static boolean isCanceledOrFailed(String status) {
        if (status == null) {
            return false;
        }
        String s = status.toLowerCase();
        return s.contains("cancel") || s.contains("failed") || s.contains("expired");
    }

    private Map<String, Object> buildCustomerPayload(long userId, String overridePhone) {
        try {
            Map<String, Object> u = jdbcTemplate.queryForMap(
                "SELECT full_name, phone, email FROM users WHERE id = ?",
                userId
            );
            Map<String, Object> customer = new LinkedHashMap<>();
            customer.put("name", Objects.toString(u.get("full_name"), "Client PayFlex"));
            String email = Objects.toString(u.get("email"), "");
            if (!email.isBlank()) {
                customer.put("email", email);
            }
            String override = overridePhone == null ? "" : overridePhone.trim();
            String phone = !override.isBlank() ? override : Objects.toString(u.get("phone"), "");
            if (!phone.isBlank()) {
                customer.put("phone", phone.replaceAll("\\s", ""));
            }
            return customer;
        } catch (EmptyResultDataAccessException ex) {
            return Map.of("name", "Client PayFlex");
        }
    }

    private Map<String, Object> loadContribution(long id) {
        try {
            return jdbcTemplate.queryForMap(
                """
                SELECT id, user_id, status, reference_code, paydunya_token
                FROM contributions WHERE id = ?
                """,
                id
            );
        } catch (EmptyResultDataAccessException ex) {
            return null;
        }
    }

    private Long findContributionIdByToken(String token) {
        try {
            return jdbcTemplate.queryForObject(
                "SELECT id FROM contributions WHERE paydunya_token = ? LIMIT 1",
                Long.class,
                token
            );
        } catch (EmptyResultDataAccessException ex) {
            return null;
        }
    }

    private Long findUserIdByAdhesionToken(String token) {
        try {
            return jdbcTemplate.queryForObject(
                "SELECT id FROM users WHERE adhesion_paydunya_token = ? LIMIT 1",
                Long.class,
                token
            );
        } catch (EmptyResultDataAccessException ex) {
            return null;
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
}
