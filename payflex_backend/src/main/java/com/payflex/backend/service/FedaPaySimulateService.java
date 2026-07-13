package com.payflex.backend.service;

import com.payflex.backend.config.PayflexProperties;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.util.UriUtils;

import java.nio.charset.StandardCharsets;
import java.util.Map;
import java.util.UUID;
import java.util.concurrent.ConcurrentHashMap;

/**
 * Paiements mobile money simulés (sans appel API FedaPay) pour dev / démo / tunnel.
 */
@Service
public class FedaPaySimulateService {

    public static final String TX_PREFIX = "SIM-";

    private final PayflexProperties.Fedapay config;
    private final JdbcTemplate jdbcTemplate;
    private final ContributionWorkflowService contributionWorkflowService;
    private final ClientAdhesionService clientAdhesionService;
    private final Map<String, SimTransaction> transactions = new ConcurrentHashMap<>();

    public FedaPaySimulateService(
        PayflexProperties payflexProperties,
        JdbcTemplate jdbcTemplate,
        ContributionWorkflowService contributionWorkflowService,
        ClientAdhesionService clientAdhesionService
    ) {
        this.config = payflexProperties.getFedapay();
        this.jdbcTemplate = jdbcTemplate;
        this.contributionWorkflowService = contributionWorkflowService;
        this.clientAdhesionService = clientAdhesionService;
    }

    public record SimTransaction(
        String transactionId,
        String kind,
        long resourceId,
        long userId,
        int amountFcfa,
        String description,
        String callbackUrl,
        String status
    ) {}

    public FedaPayService.CheckoutResult createCheckout(
        String kind,
        long resourceId,
        long userId,
        int amountFcfa,
        String description,
        String callbackUrl
    ) {
        String txId = TX_PREFIX + UUID.randomUUID().toString().replace("-", "");
        SimTransaction tx = new SimTransaction(
            txId,
            kind,
            resourceId,
            userId,
            amountFcfa,
            description,
            callbackUrl,
            "pending"
        );
        transactions.put(txId, tx);
        String base = config.getPublicBaseUrl().replaceAll("/$", "");
        String paymentUrl = base
            + "/api/mobile/fedapay/simulate/page?tx="
            + UriUtils.encode(txId, StandardCharsets.UTF_8);
        return new FedaPayService.CheckoutResult(txId, paymentUrl, "pending");
    }

    public boolean isSimulatedTransaction(String transactionId) {
        return transactionId != null && transactionId.startsWith(TX_PREFIX);
    }

    public java.util.Optional<String> fetchStatus(String transactionId) {
        SimTransaction tx = transactions.get(transactionId);
        if (tx == null) {
            return java.util.Optional.empty();
        }
        return java.util.Optional.of(tx.status());
    }

    @Transactional
    public String confirm(String transactionId) {
        SimTransaction tx = requireTx(transactionId);
        if ("approved".equals(tx.status())) {
            return appendStatus(tx.callbackUrl(), "approved");
        }
        if ("contribution".equals(tx.kind())) {
            contributionWorkflowService.validateByFedaPay(tx.resourceId(), tx.transactionId());
        } else if ("adhesion".equals(tx.kind())) {
            clientAdhesionService.markAdhesionPaidByFedaPay(tx.userId(), tx.transactionId());
        }
        transactions.put(transactionId, copyWithStatus(tx, "approved"));
        return appendStatus(tx.callbackUrl(), "approved");
    }

    @Transactional
    public String cancel(String transactionId) {
        SimTransaction tx = requireTx(transactionId);
        if ("canceled".equals(tx.status()) || "cancelled".equals(tx.status())) {
            return appendStatus(tx.callbackUrl(), "canceled");
        }
        if ("contribution".equals(tx.kind())) {
            rejectSimulatedContribution(tx.resourceId());
        } else if ("adhesion".equals(tx.kind())) {
            jdbcTemplate.update(
                "UPDATE users SET adhesion_fedapay_transaction_id = NULL WHERE id = ? AND adhesion_fee_paid = FALSE",
                tx.userId()
            );
        }
        transactions.put(transactionId, copyWithStatus(tx, "canceled"));
        return appendStatus(tx.callbackUrl(), "canceled");
    }

    private void rejectSimulatedContribution(long contributionId) {
        try {
            contributionWorkflowService.rejectByBackoffice(
                contributionId,
                "Paiement simulé annulé par l'utilisateur.",
                "simulate"
            );
        } catch (IllegalArgumentException ex) {
            // déjà traité
        }
    }

    public String renderSimulatePage(String transactionId) {
        SimTransaction tx = requireTx(transactionId);
        String confirmUrl = config.getPublicBaseUrl().replaceAll("/$", "")
            + "/api/mobile/fedapay/simulate/confirm?tx="
            + UriUtils.encode(tx.transactionId(), StandardCharsets.UTF_8);
        String cancelUrl = config.getPublicBaseUrl().replaceAll("/$", "")
            + "/api/mobile/fedapay/simulate/cancel?tx="
            + UriUtils.encode(tx.transactionId(), StandardCharsets.UTF_8);
        String label = tx.description() == null || tx.description().isBlank()
            ? "Paiement PayFlex"
            : tx.description();
        return """
            <!DOCTYPE html><html lang="fr"><head><meta charset="UTF-8">
            <meta name="viewport" content="width=device-width,initial-scale=1">
            <title>PayFlex — Simulation paiement</title>
            <style>
              body{font-family:system-ui,-apple-system,sans-serif;margin:0;background:#f0f9ff;color:#0f172a}
              .wrap{max-width:420px;margin:0 auto;padding:1.5rem}
              .card{background:#fff;border-radius:16px;padding:1.5rem;box-shadow:0 8px 24px rgba(15,23,42,.08);border:1px solid #e2e8f0}
              .badge{display:inline-block;background:#dbeafe;color:#1d4ed8;font-size:.7rem;font-weight:700;padding:.25rem .6rem;border-radius:999px;margin-bottom:.75rem}
              h1{font-size:1.15rem;margin:0 0 .5rem}
              .amt{font-size:1.75rem;font-weight:800;color:#0f766e;margin:.5rem 0 1rem}
              p{color:#475569;font-size:.9rem;line-height:1.45;margin:.4rem 0}
              .btns{display:flex;flex-direction:column;gap:.65rem;margin-top:1.25rem}
              a.btn{display:block;text-align:center;text-decoration:none;font-weight:700;padding:.85rem 1rem;border-radius:12px}
              .ok{background:#0d9488;color:#fff}
              .no{background:#f1f5f9;color:#334155;border:1px solid #cbd5e1}
            </style></head><body><div class="wrap"><div class="card">
            <span class="badge">MODE SIMULATION</span>
            <h1>%s</h1>
            <div class="amt">%d FCFA</div>
            <p>Aucun appel FedaPay réel. Choisissez le résultat pour tester cotisation ou adhésion.</p>
            <div class="btns">
              <a class="btn ok" href="%s">Confirmer le paiement</a>
              <a class="btn no" href="%s">Annuler</a>
            </div>
            </div></div></body></html>
            """.formatted(escapeHtml(label), tx.amountFcfa(), confirmUrl, cancelUrl);
    }

    private static SimTransaction copyWithStatus(SimTransaction tx, String status) {
        return new SimTransaction(
            tx.transactionId(),
            tx.kind(),
            tx.resourceId(),
            tx.userId(),
            tx.amountFcfa(),
            tx.description(),
            tx.callbackUrl(),
            status
        );
    }

    private SimTransaction requireTx(String transactionId) {
        if (transactionId == null || !transactionId.startsWith(TX_PREFIX)) {
            throw new IllegalArgumentException("Transaction simulation invalide.");
        }
        SimTransaction tx = transactions.get(transactionId);
        if (tx == null) {
            throw new IllegalArgumentException("Session de paiement simulée expirée ou introuvable.");
        }
        return tx;
    }

    private static String appendStatus(String callbackUrl, String status) {
        if (callbackUrl == null || callbackUrl.isBlank()) {
            return "/";
        }
        String sep = callbackUrl.contains("?") ? "&" : "?";
        return callbackUrl + sep + "status=" + status;
    }

    private static String escapeHtml(String raw) {
        if (raw == null) {
            return "";
        }
        return raw
            .replace("&", "&amp;")
            .replace("<", "&lt;")
            .replace(">", "&gt;")
            .replace("\"", "&quot;");
    }
}
