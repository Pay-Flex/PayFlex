package com.payflex.backend.controller;

import com.payflex.backend.service.AdminAuditService;
import com.payflex.backend.service.ClientAdhesionService;
import com.payflex.backend.service.ContributionWorkflowService;
import com.payflex.backend.service.FedaPayPaymentService;
import com.payflex.backend.service.MobileApiService;
import com.payflex.backend.service.MobileLoginResolution;
import com.payflex.backend.service.MobileRecoveryService;
import com.payflex.backend.service.PermissionService;
import com.payflex.backend.service.RegistrationService;
import com.payflex.backend.service.PushNotificationService;
import com.payflex.backend.service.SupportChatService;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

import java.sql.Timestamp;
import java.time.Instant;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api/mobile")
public class MobileApiController {

    private static final Logger log = LoggerFactory.getLogger(MobileApiController.class);

    private static final String MESSAGE_SERVER_UNAVAILABLE =
        "Le service est momentanément indisponible. Réessayez plus tard ou contactez le support.";

    private final MobileApiService mobileApiService;
    private final MobileRecoveryService mobileRecoveryService;
    private final RegistrationService registrationService;
    private final PermissionService permissionService;
    private final AdminAuditService auditService;
    private final SupportChatService supportChatService;
    private final ContributionWorkflowService contributionWorkflowService;
    private final FedaPayPaymentService fedaPayPaymentService;
    private final PushNotificationService pushNotificationService;
    private final ClientAdhesionService clientAdhesionService;

    public MobileApiController(
        MobileApiService mobileApiService,
        MobileRecoveryService mobileRecoveryService,
        RegistrationService registrationService,
        PermissionService permissionService,
        AdminAuditService auditService,
        SupportChatService supportChatService,
        ContributionWorkflowService contributionWorkflowService,
        FedaPayPaymentService fedaPayPaymentService,
        PushNotificationService pushNotificationService,
        ClientAdhesionService clientAdhesionService
    ) {
        this.mobileApiService = mobileApiService;
        this.mobileRecoveryService = mobileRecoveryService;
        this.registrationService = registrationService;
        this.permissionService = permissionService;
        this.auditService = auditService;
        this.supportChatService = supportChatService;
        this.contributionWorkflowService = contributionWorkflowService;
        this.fedaPayPaymentService = fedaPayPaymentService;
        this.pushNotificationService = pushNotificationService;
        this.clientAdhesionService = clientAdhesionService;
    }

    @GetMapping("/health")
    public Map<String, String> health() {
        return Map.of("status", "ok");
    }

    @PostMapping("/auth/login")
    public ResponseEntity<?> login(@RequestBody Map<String, String> payload) {
        String identifier = payload.getOrDefault("identifier", "").trim();
        if (identifier.isEmpty()) {
            identifier = payload.getOrDefault("phone", "").trim();
        }
        String secret = payload.getOrDefault("pin", "").trim();
        String loginMode = payload.getOrDefault("loginMode", "").trim();
        log.info("Mobile login attempt mode={} identifier={} pinLen={}", loginMode, maskPhoneForLog(identifier), secret.length());
        if (identifier.isEmpty() || secret.isEmpty()) {
            return ResponseEntity.badRequest().body(Map.of("message", "Indiquez votre identifiant et votre mot de passe ou code PIN."));
        }
        MobileLoginResolution resolution = mobileApiService.resolveLogin(identifier, secret, null, loginMode);
        if (!resolution.isSuccess()) {
            log.warn(
                "Mobile login failed identifier={} code={} msg={}",
                maskPhoneForLog(identifier),
                resolution.errorCode(),
                resolution.failureMessage()
            );
            String msg = resolution.failureMessage() != null
                ? resolution.failureMessage()
                : "Connexion impossible : vérifiez le numéro ou l'e-mail et le mot de passe ou code PIN.";
            if (MobileLoginResolution.CODE_AMBIGUOUS.equals(resolution.errorCode())) {
                return ResponseEntity.status(409).body(Map.of(
                    "message", msg,
                    "errorCode", resolution.errorCode()
                ));
            }
            return ResponseEntity.status(401).body(Map.of(
                "message", msg,
                "errorCode", resolution.errorCode() != null ? resolution.errorCode() : MobileLoginResolution.CODE_INVALID_CREDENTIALS
            ));
        }
        Map<String, Object> user = resolution.profile();
        log.info(
            "Mobile login OK userId={} role={} status={} phone={}",
            user.get("id"),
            user.get("role"),
            user.get("status"),
            maskPhoneForLog(String.valueOf(user.get("phone")))
        );
        Object idObj = user.get("id");
        Object roleObj = user.get("role");
        if (idObj instanceof Number uid) {
            if ("agent".equals(roleObj)) {
                auditService.logAgent(uid.longValue(), "S'est connecté à l'application PayFlex.");
            } else {
                auditService.logClient(uid.longValue(), "S'est connecté à l'application PayFlex.");
            }
        }
        return ResponseEntity.ok(user);
    }

    /**
     * Mot de passe oublié — étape 1 : vérification identité (téléphone, nom, code unique PayFlex).
     */
    @PostMapping("/auth/recovery/request")
    public ResponseEntity<?> recoveryRequest(@RequestBody Map<String, String> payload) {
        try {
            Map<String, Object> out = mobileRecoveryService.requestRecovery(
                payload.getOrDefault("phone", ""),
                payload.getOrDefault("fullName", ""),
                payload.getOrDefault("uniqueCode", "")
            );
            return ResponseEntity.ok(Map.of(
                "resetToken", out.get("resetToken"),
                "expiresInMinutes", out.get("expiresInMinutes")
            ));
        } catch (IllegalArgumentException ex) {
            return ResponseEntity.badRequest().body(Map.of("message", ex.getMessage()));
        } catch (IllegalStateException ex) {
            return ResponseEntity.internalServerError().body(Map.of("message", ex.getMessage()));
        }
    }

    /**
     * Mot de passe oublié — étape 2 : nouveau code PIN unique (avec jeton à usage unique).
     */
    @PostMapping("/auth/recovery/reset")
    public ResponseEntity<?> recoveryReset(@RequestBody Map<String, String> payload) {
        try {
            String newPin = payload.getOrDefault("newPin", "").trim();
            String legacySecret = payload.getOrDefault("newSecretCode", "").trim();
            if (!legacySecret.isEmpty() && !legacySecret.equals(newPin)) {
                return ResponseEntity.badRequest().body(Map.of(
                    "message", "Un seul code PIN est utilisé : les deux champs doivent être identiques."
                ));
            }
            mobileRecoveryService.resetCredentials(
                payload.getOrDefault("resetToken", ""),
                newPin
            );
            return ResponseEntity.ok(Map.of("message", "Votre code PIN a été mis à jour. Vous pouvez vous connecter."));
        } catch (IllegalArgumentException ex) {
            return ResponseEntity.badRequest().body(Map.of("message", ex.getMessage()));
        } catch (IllegalStateException ex) {
            return ResponseEntity.internalServerError().body(Map.of("message", ex.getMessage()));
        }
    }

    /**
     * Rechargement du profil (même payload que la connexion + id utilisateur attendu).
     */
    @PostMapping("/profile")
    public ResponseEntity<?> profile(@RequestBody Map<String, Object> payload) {
        String identifier = String.valueOf(payload.getOrDefault("identifier", "")).trim();
        if (identifier.isEmpty()) {
            identifier = String.valueOf(payload.getOrDefault("phone", "")).trim();
        }
        String pin = String.valueOf(payload.getOrDefault("pin", "")).trim();
        long userId;
        try {
            userId = Long.parseLong(payload.getOrDefault("userId", 0).toString());
        } catch (NumberFormatException ex) {
            return ResponseEntity.badRequest().body(Map.of("message", "Identifiant utilisateur invalide."));
        }
        if (identifier.isEmpty() || pin.isEmpty() || userId <= 0) {
            return ResponseEntity.badRequest().body(Map.of("message", "E-mail ou téléphone, code secret et identifiant requis."));
        }
        Map<String, Object> user = mobileApiService.profileByCredentials(identifier, pin, userId);
        if (user == null) {
            return ResponseEntity.status(401).body(Map.of("message", "Session invalide ou compte introuvable."));
        }
        return ResponseEntity.ok(user);
    }

    @GetMapping("/product-categories")
    public List<Map<String, Object>> productCategories() {
        return mobileApiService.productCategoriesForMobile();
    }

    @GetMapping("/products")
    public List<Map<String, Object>> products() {
        return mobileApiService.productsForMobile();
    }

    /**
     * Historique du chat support : même contrôle d’identité que {@link #profile(java.util.Map)}.
     */
    @PostMapping("/support-chat/history")
    public ResponseEntity<?> chatHistory(@RequestBody Map<String, Object> payload) {
        Long userId = verifyChatUserId(payload);
        if (userId == null) {
            return ResponseEntity.badRequest().body(Map.of("message", "Téléphone, code secret et identifiant requis."));
        }
        if (!credentialsMatch(payload, userId)) {
            return ResponseEntity.status(401).body(Map.of("message", "Session invalide ou compte introuvable."));
        }
        List<Map<String, Object>> rows = supportChatService.messagesForUser(userId, 500);
        List<Map<String, Object>> out = new ArrayList<>(rows.size());
        for (Map<String, Object> r : rows) {
            out.add(mapChatMessageRow(r));
        }
        return ResponseEntity.ok(out);
    }

    @PostMapping("/support-chat/send")
    public ResponseEntity<?> chatSend(@RequestBody Map<String, Object> payload) {
        Long userId = verifyChatUserId(payload);
        if (userId == null) {
            return ResponseEntity.badRequest().body(Map.of("message", "Téléphone, code secret et identifiant requis."));
        }
        if (!credentialsMatch(payload, userId)) {
            return ResponseEntity.status(401).body(Map.of("message", "Session invalide ou compte introuvable."));
        }
        String body = String.valueOf(payload.getOrDefault("body", "")).trim();
        if (body.isEmpty()) {
            return ResponseEntity.badRequest().body(Map.of("message", "Message vide."));
        }
        try {
            supportChatService.addMessage(userId, "client", body);
            auditService.logClient(userId, "A envoyé un message au support depuis l’application.");
        } catch (IllegalArgumentException ex) {
            return ResponseEntity.badRequest().body(Map.of("message", ex.getMessage()));
        }
        return ResponseEntity.ok(Map.of("ok", true));
    }

    @PostMapping("/support-chat/inbox")
    public ResponseEntity<?> chatInbox(@RequestBody Map<String, Object> payload) {
        Long userId = verifyChatUserId(payload);
        if (userId == null) {
            return ResponseEntity.badRequest().body(Map.of("message", "Identifiant requis."));
        }
        if (!credentialsMatch(payload, userId)) {
            return ResponseEntity.status(401).body(Map.of("message", "Session invalide."));
        }
        return ResponseEntity.ok(supportChatService.inboxSummary(userId));
    }

    @PostMapping("/support-chat/mark-read")
    public ResponseEntity<?> chatMarkRead(@RequestBody Map<String, Object> payload) {
        Long userId = verifyChatUserId(payload);
        if (userId == null || !credentialsMatch(payload, userId)) {
            return ResponseEntity.status(401).body(Map.of("message", "Session invalide."));
        }
        supportChatService.markAdminMessagesRead(userId);
        return ResponseEntity.ok(Map.of("ok", true));
    }

    @PostMapping("/support-chat/delete-message")
    public ResponseEntity<?> chatDeleteMessage(@RequestBody Map<String, Object> payload) {
        Long userId = verifyChatUserId(payload);
        if (userId == null) {
            return ResponseEntity.badRequest().body(Map.of("message", "Identifiant requis."));
        }
        if (!credentialsMatch(payload, userId)) {
            return ResponseEntity.status(401).body(Map.of("message", "Session invalide."));
        }
        long messageId = parseLong(payload.get("messageId"));
        if (messageId <= 0) {
            return ResponseEntity.badRequest().body(Map.of("message", "Message invalide."));
        }
        int n = supportChatService.deleteMessage(messageId, userId);
        if (n == 0) {
            return ResponseEntity.status(404).body(Map.of("message", "Message introuvable."));
        }
        auditService.logClient(userId, "A supprimé un message du chat support (message #" + messageId + ").");
        return ResponseEntity.ok(Map.of("ok", true));
    }

    @PostMapping("/support-chat/delete-thread")
    public ResponseEntity<?> chatDeleteThread(@RequestBody Map<String, Object> payload) {
        Long userId = verifyChatUserId(payload);
        if (userId == null) {
            return ResponseEntity.badRequest().body(Map.of("message", "Identifiant requis."));
        }
        if (!credentialsMatch(payload, userId)) {
            return ResponseEntity.status(401).body(Map.of("message", "Session invalide."));
        }
        int n = supportChatService.deleteThread(userId);
        auditService.logClient(userId, "A effacé la conversation chat support (" + n + " message(s)).");
        return ResponseEntity.ok(Map.of("ok", true, "deleted", n));
    }

    @PostMapping("/devices/fcm-token")
    public ResponseEntity<?> registerFcmToken(@RequestBody Map<String, Object> payload) {
        Long userId = verifyChatUserId(payload);
        if (userId == null || !credentialsMatch(payload, userId)) {
            return ResponseEntity.status(401).body(Map.of("message", "Session invalide."));
        }
        String token = String.valueOf(payload.getOrDefault("fcmToken", "")).trim();
        pushNotificationService.saveFcmToken(userId, token);
        return ResponseEntity.ok(Map.of("ok", true));
    }

    private Long verifyChatUserId(Map<String, Object> payload) {
        try {
            long userId = Long.parseLong(payload.getOrDefault("userId", 0).toString());
            return userId > 0 ? userId : null;
        } catch (NumberFormatException ex) {
            return null;
        }
    }

    private boolean credentialsMatch(Map<String, Object> payload, long userId) {
        String phone = String.valueOf(payload.getOrDefault("phone", "")).trim();
        String pin = String.valueOf(payload.getOrDefault("pin", "")).trim();
        if (phone.isEmpty() || pin.isEmpty()) {
            return false;
        }
        return mobileApiService.profileByCredentials(phone, pin, userId) != null;
    }

    private static Map<String, Object> mapChatMessageRow(Map<String, Object> r) {
        Map<String, Object> m = new LinkedHashMap<>();
        m.put("id", r.get("id"));
        m.put("text", r.get("body"));
        String sender = String.valueOf(r.get("sender"));
        m.put("sender_role", "client".equals(sender) ? "user" : "admin");
        Object ts = r.get("created_at");
        if (ts instanceof Timestamp t) {
            m.put("timestamp", t.toInstant().toString());
        } else {
            m.put("timestamp", Instant.now().toString());
        }
        Object readAt = r.get("read_at");
        m.put("read", readAt != null);
        return m;
    }

    @PostMapping("/contributions")
    public ResponseEntity<?> createContribution(@RequestBody Map<String, Object> payload) {
        String collectorPhone = String.valueOf(payload.getOrDefault("collectorPhone", "")).trim();
        String collectorPin = String.valueOf(payload.getOrDefault("collectorPin", "")).trim();
        long collectorUserId;
        try {
            collectorUserId = Long.parseLong(payload.getOrDefault("collectorUserId", 0).toString());
        } catch (NumberFormatException ex) {
            collectorUserId = 0L;
        }
        String clientPhone = String.valueOf(payload.getOrDefault("clientPhone", "")).trim();
        String referenceCode = String.valueOf(payload.getOrDefault("referenceCode", "")).trim();
        boolean agentCollect = !collectorPhone.isEmpty()
            && !collectorPin.isEmpty()
            && collectorUserId > 0;

        long userId;
        try {
            userId = Long.parseLong(payload.getOrDefault("userId", 0).toString());
        } catch (NumberFormatException ex) {
            userId = 0L;
        }
        Long productId;
        try {
            productId = payload.get("productId") == null ? null : Long.parseLong(payload.get("productId").toString());
        } catch (NumberFormatException ex) {
            productId = null;
        }
        Long agentRowIdPayload = null;
        try {
            if (payload.get("agentId") != null) {
                agentRowIdPayload = Long.parseLong(payload.get("agentId").toString());
            }
        } catch (NumberFormatException ex) {
            agentRowIdPayload = null;
        }
        double amount;
        try {
            amount = Double.parseDouble(payload.getOrDefault("amount", 0).toString());
        } catch (NumberFormatException ex) {
            amount = 0;
        }
        String paymentMode = payload.getOrDefault("paymentMode", "mobile_money").toString();
        Integer catchupYear = parseNullableInt(payload.get("catchupYear"));
        Integer catchupMonth = parseNullableInt(payload.get("catchupMonth"));
        Integer catchupDay = parseNullableInt(payload.get("catchupDay"));

        if (amount <= 0) {
            return ResponseEntity.badRequest().body(Map.of("message", "Montant ou client manquant : vérifiez les informations."));
        }

        if (agentCollect) {
            Map<String, Object> collector = mobileApiService.profileByCredentials(collectorPhone, collectorPin, collectorUserId);
            if (collector == null) {
                return ResponseEntity.status(401).body(Map.of("message", "Session agent invalide. Reconnectez-vous."));
            }
            if (!"agent".equals(String.valueOf(collector.get("role")))) {
                return ResponseEntity.status(403).body(Map.of("message", "Seul un agent terrain peut enregistrer ce type de collecte."));
            }
            if ("cash".equalsIgnoreCase(paymentMode) == false) {
                return ResponseEntity.badRequest().body(Map.of("message", "Mode paiement attendu : espèces (cash) pour une collecte agent."));
            }
            long clientUserId = userId;
            if (clientUserId <= 0) {
                clientUserId = mobileApiService.findClientUserIdByPhone(clientPhone);
            }
            if (clientUserId <= 0) {
                return ResponseEntity.badRequest().body(Map.of(
                    "message",
                    "Client introuvable sur le centre. Vérifiez le numéro ou que le compte est validé côté PayFlex."
                ));
            }
            if (!permissionService.userHasPermission(clientUserId, PermissionService.MOBILE_CONTRIBUTION_CREATE)) {
                return ResponseEntity.status(403).body(Map.of("message", "Ce client ne peut pas encore enregistrer de cotisation. Contactez le support."));
            }
            if (!mobileApiService.isClientAssignedToAgent(clientUserId, collectorUserId)) {
                return ResponseEntity.status(403).body(Map.of(
                    "message",
                    "Ce client n'est pas rattaché à votre agent PayFlex. Vérifiez l'assignation en centre."
                ));
            }
            Long agentRowId = mobileApiService.findAgentRowIdByUserId(collectorUserId);
            if (agentRowId == null) {
                return ResponseEntity.status(403).body(Map.of("message", "Profil agent incomplet côté centre. Contactez l'administration."));
            }
            String ref = referenceCode.isEmpty() ? null : "PF-AGENT-TX-" + referenceCode;
            long id = mobileApiService.createAgentCashContribution(
                clientUserId,
                productId,
                agentRowId,
                amount,
                paymentMode,
                ref,
                catchupYear,
                catchupMonth,
                catchupDay
            );
            String status = "pending";
            String message = "Collecte enregistrée. Elle sera confirmée au centre après rapprochement.";
            try {
                contributionWorkflowService.validateAgentCashCollection(id, collectorUserId);
                status = "validated";
                message = "Collecte espèces enregistrée et confirmée immédiatement.";
                auditService.logAgent(
                    collectorUserId,
                    "A saisi et confirmé une collecte de " + Math.round(amount) + " FCFA en espèces."
                );
                auditService.logClient(
                    clientUserId,
                    "Collecte espèces de " + Math.round(amount) + " FCFA confirmée par votre agent PayFlex."
                );
            } catch (IllegalArgumentException ex) {
                auditService.logAgent(
                    collectorUserId,
                    "A saisi une collecte de " + Math.round(amount) + " FCFA en espèces (en attente de validation au centre)."
                );
                auditService.logClient(
                    clientUserId,
                    "Collecte espèces enregistrée par l’agent : " + Math.round(amount) + " FCFA — à confirmer au centre."
                );
                message = ex.getMessage() != null ? ex.getMessage() : message;
            }
            return ResponseEntity.ok(Map.of(
                "id", id,
                "status", status,
                "message", message
            ));
        }

        if (userId <= 0) {
            return ResponseEntity.badRequest().body(Map.of("message", "Montant ou client manquant : vérifiez les informations."));
        }
        if (!permissionService.userHasPermission(userId, PermissionService.MOBILE_CONTRIBUTION_CREATE)) {
            return ResponseEntity.status(403).body(Map.of("message", "Vous ne pouvez pas enregistrer ce versement avec votre profil actuel. Contactez le support."));
        }
        long id = mobileApiService.createContribution(
            userId,
            productId,
            agentRowIdPayload,
            amount,
            paymentMode,
            catchupYear,
            catchupMonth,
            catchupDay
        );
        String ref = mobileApiService.referenceCodeForContribution(id);
        auditService.logClient(
            userId,
            "A déclaré un versement de " + Math.round(amount) + " FCFA depuis l'application ("
                + AdminAuditService.modePaiement(paymentMode)
                + ") — en attente de validation par l'agent ou le centre."
        );
        return ResponseEntity.ok(Map.of(
            "id", id,
            "status", "pending",
            "referenceCode", ref == null ? "" : ref,
            "message", "Versement enregistré. Vous serez notifié après validation par votre agent PayFlex (ou le centre si besoin).",
            "fedapayEnabled", fedaPayPaymentService.isAvailable()
        ));
    }

    @PostMapping("/contributions/history")
    public ResponseEntity<?> contributionHistory(@RequestBody Map<String, Object> payload) {
        long userId = parseLong(payload.get("userId"));
        if (userId <= 0) {
            return ResponseEntity.badRequest().body(Map.of("message", "Client manquant."));
        }
        if (!credentialsMatch(payload, userId)) {
            return ResponseEntity.status(401).body(Map.of("message", "Session invalide."));
        }
        return ResponseEntity.ok(Map.of("items", mobileApiService.contributionHistoryForClient(userId)));
    }

    @PostMapping("/contributions/fedapay/init")
    public ResponseEntity<?> initFedaPayContribution(@RequestBody Map<String, Object> payload) {
        long userId = parseLong(payload.get("userId"));
        if (userId <= 0) {
            return ResponseEntity.badRequest().body(Map.of("message", "Client manquant."));
        }
        if (!permissionService.userHasPermission(userId, PermissionService.MOBILE_CONTRIBUTION_CREATE)) {
            return ResponseEntity.status(403).body(Map.of("message", "Profil non autorisé à cotiser."));
        }
        double amount;
        try {
            amount = Double.parseDouble(payload.getOrDefault("amount", 0).toString());
        } catch (NumberFormatException ex) {
            amount = 0;
        }
        if (amount <= 0) {
            return ResponseEntity.badRequest().body(Map.of("message", "Montant invalide."));
        }
        Long productId = null;
        try {
            if (payload.get("productId") != null) {
                productId = Long.parseLong(payload.get("productId").toString());
            }
        } catch (NumberFormatException ignored) {
            productId = null;
        }
        Long agentRowId = null;
        try {
            if (payload.get("agentId") != null) {
                agentRowId = Long.parseLong(payload.get("agentId").toString());
            }
        } catch (NumberFormatException ignored) {
            agentRowId = null;
        }
        if (!fedaPayPaymentService.isAvailable()) {
            return ResponseEntity.ok(Map.of(
                "fedapayEnabled", false,
                "message", "FedaPay non configuré. Utilisez la déclaration classique."
            ));
        }
        try {
            Map<String, Object> result = fedaPayPaymentService.initMobileMoneyPayment(userId, productId, agentRowId, amount);
            return ResponseEntity.ok(result);
        } catch (IllegalArgumentException | IllegalStateException ex) {
            return ResponseEntity.badRequest().body(Map.of("message", ex.getMessage()));
        }
    }

    @PostMapping("/contributions/fedapay/status")
    public ResponseEntity<?> fedaPayContributionStatus(@RequestBody Map<String, Object> payload) {
        long userId = parseLong(payload.get("userId"));
        long contributionId = parseLong(payload.get("contributionId"));
        if (userId <= 0 || contributionId <= 0) {
            return ResponseEntity.badRequest().body(Map.of("message", "Paramètres manquants."));
        }
        try {
            return ResponseEntity.ok(fedaPayPaymentService.paymentStatus(contributionId, userId));
        } catch (IllegalArgumentException ex) {
            return ResponseEntity.badRequest().body(Map.of("message", ex.getMessage()));
        }
    }

    @GetMapping(value = "/contributions/fedapay/callback", produces = "text/html;charset=UTF-8")
    public ResponseEntity<String> fedaPayCallback(
        @RequestParam long contributionId,
        @RequestParam(required = false) String status
    ) {
        String label = status == null || status.isBlank() ? "en cours" : status;
        if (contributionId > 0) {
            try {
                long ownerId = resolveContributionOwner(contributionId);
                if (ownerId > 0) {
                    Map<String, Object> synced = fedaPayPaymentService.paymentStatus(contributionId, ownerId);
                    label = String.valueOf(synced.getOrDefault("status", label));
                }
            } catch (Exception ignored) {
                // webhook ou bouton « Vérifier » dans l'app
            }
        }
        String html = """
            <!DOCTYPE html><html lang="fr"><head><meta charset="UTF-8">
            <meta name="viewport" content="width=device-width,initial-scale=1">
            <title>PayFlex</title>
            <style>body{font-family:system-ui,sans-serif;text-align:center;padding:2rem;background:#f0f9ff;color:#0f172a}
            h1{font-size:1.25rem}p{color:#475569}</style></head><body>
            <h1>Paiement enregistré</h1>
            <p>Statut : %s</p>
            <p>Fermez cet écran ou appuyez sur « J'ai terminé le paiement » dans PayFlex.</p>
            </body></html>
            """.formatted(label);
        return ResponseEntity.ok().header("Content-Type", "text/html;charset=UTF-8").body(html);
    }

    private long resolveContributionOwner(long contributionId) {
        try {
            Long userId = mobileApiService.findContributionUserId(contributionId);
            return userId == null ? 0L : userId;
        } catch (Exception ex) {
            return 0L;
        }
    }

    @PostMapping("/contributions/pending")
    public ResponseEntity<?> pendingContributionsForValidator(@RequestBody Map<String, Object> payload) {
        long validatorUserId = parseLong(payload.get("validatorUserId"));
        if (validatorUserId <= 0 || !credentialsMatch(payload, validatorUserId)) {
            return ResponseEntity.status(401).body(Map.of("message", "Session invalide."));
        }
        Map<String, Object> profile = mobileApiService.profileByCredentials(
            String.valueOf(payload.getOrDefault("phone", "")).trim(),
            String.valueOf(payload.getOrDefault("pin", "")).trim(),
            validatorUserId
        );
        if (profile == null) {
            return ResponseEntity.status(401).body(Map.of("message", "Session invalide."));
        }
        String role = String.valueOf(profile.get("role"));
        if (!"agent".equals(role)) {
            return ResponseEntity.status(403).body(Map.of("message", "Réservé aux agents PayFlex."));
        }
        if (!permissionService.userHasPermission(validatorUserId, PermissionService.MOBILE_CONTRIBUTION_VALIDATE)) {
            return ResponseEntity.status(403).body(Map.of("message", "Validation des cotisations non autorisée pour ce profil."));
        }
        return ResponseEntity.ok(Map.of("items", contributionWorkflowService.listPendingForAgentValidator(validatorUserId)));
    }

    @PostMapping("/contributions/validate")
    public ResponseEntity<?> validateContribution(@RequestBody Map<String, Object> payload) {
        long validatorUserId = parseLong(payload.get("validatorUserId"));
        long contributionId = parseLong(payload.get("contributionId"));
        if (validatorUserId <= 0 || contributionId <= 0 || !credentialsMatch(payload, validatorUserId)) {
            return ResponseEntity.badRequest().body(Map.of("message", "Paramètres ou session invalides."));
        }
        try {
            contributionWorkflowService.validateByAgent(contributionId, validatorUserId);
            return ResponseEntity.ok(Map.of("ok", true, "status", "validated"));
        } catch (IllegalArgumentException ex) {
            return ResponseEntity.badRequest().body(Map.of("message", ex.getMessage()));
        }
    }

    @PostMapping("/contributions/reject")
    public ResponseEntity<?> rejectContribution(@RequestBody Map<String, Object> payload) {
        long validatorUserId = parseLong(payload.get("validatorUserId"));
        long contributionId = parseLong(payload.get("contributionId"));
        String reason = String.valueOf(payload.getOrDefault("reason", "")).trim();
        if (validatorUserId <= 0 || contributionId <= 0 || !credentialsMatch(payload, validatorUserId)) {
            return ResponseEntity.badRequest().body(Map.of("message", "Paramètres ou session invalides."));
        }
        try {
            contributionWorkflowService.rejectByAgent(contributionId, validatorUserId, reason);
            return ResponseEntity.ok(Map.of("ok", true, "status", "rejected"));
        } catch (IllegalArgumentException ex) {
            return ResponseEntity.badRequest().body(Map.of("message", ex.getMessage()));
        }
    }

    @PostMapping("/notifications")
    public ResponseEntity<?> clientNotifications(@RequestBody Map<String, Object> payload) {
        long userId = parseLong(payload.get("userId"));
        if (userId <= 0 || !credentialsMatch(payload, userId)) {
            return ResponseEntity.status(401).body(Map.of("message", "Session invalide."));
        }
        boolean unreadOnly = Boolean.parseBoolean(String.valueOf(payload.getOrDefault("unreadOnly", "false")));
        int unread = contributionWorkflowService.countUnreadNotifications(userId);
        return ResponseEntity.ok(Map.of(
            "unreadCount", unread,
            "items", contributionWorkflowService.listNotificationsForClient(userId, unreadOnly)
        ));
    }

    @PostMapping("/notifications/read")
    public ResponseEntity<?> markNotificationsRead(@RequestBody Map<String, Object> payload) {
        long userId = parseLong(payload.get("userId"));
        if (userId <= 0 || !credentialsMatch(payload, userId)) {
            return ResponseEntity.status(401).body(Map.of("message", "Session invalide."));
        }
        @SuppressWarnings("unchecked")
        List<Number> rawIds = payload.get("notificationIds") instanceof List<?> list
            ? (List<Number>) list
            : List.of();
        List<Long> ids = rawIds.stream().map(Number::longValue).toList();
        contributionWorkflowService.markNotificationsRead(userId, ids);
        return ResponseEntity.ok(Map.of("ok", true));
    }

    @PostMapping("/notifications/unread")
    public ResponseEntity<?> markNotificationsUnread(@RequestBody Map<String, Object> payload) {
        long userId = parseLong(payload.get("userId"));
        if (userId <= 0 || !credentialsMatch(payload, userId)) {
            return ResponseEntity.status(401).body(Map.of("message", "Session invalide."));
        }
        @SuppressWarnings("unchecked")
        List<Number> rawIds = payload.get("notificationIds") instanceof List<?> list
            ? (List<Number>) list
            : List.of();
        List<Long> ids = rawIds.stream().filter(n -> n.longValue() > 0).map(Number::longValue).toList();
        if (ids.isEmpty()) {
            return ResponseEntity.badRequest().body(Map.of("message", "notificationIds requis."));
        }
        contributionWorkflowService.markNotificationsUnread(userId, ids);
        return ResponseEntity.ok(Map.of("ok", true));
    }

    @PostMapping("/notifications/delete")
    public ResponseEntity<?> deleteNotification(@RequestBody Map<String, Object> payload) {
        long userId = parseLong(payload.get("userId"));
        long notificationId = parseLong(payload.get("notificationId"));
        if (userId <= 0 || notificationId <= 0 || !credentialsMatch(payload, userId)) {
            return ResponseEntity.status(401).body(Map.of("message", "Session invalide."));
        }
        if (!contributionWorkflowService.deleteNotification(userId, notificationId)) {
            return ResponseEntity.status(404).body(Map.of("message", "Notification introuvable."));
        }
        return ResponseEntity.ok(Map.of("ok", true));
    }

    private static long parseLong(Object v) {
        if (v == null) {
            return 0L;
        }
        try {
            return Long.parseLong(v.toString());
        } catch (NumberFormatException ex) {
            return 0L;
        }
    }

    private static Integer parseNullableInt(Object v) {
        if (v == null) {
            return null;
        }
        try {
            int n = Integer.parseInt(v.toString());
            return n > 0 ? n : null;
        } catch (NumberFormatException ex) {
            return null;
        }
    }

    /**
     * Synchronise le nombre de jours « rattrapage » du carnet (app cliente) pour les alertes du tableau de bord admin.
     */
    @PostMapping("/calendar-stats")
    public ResponseEntity<?> calendarStats(@RequestBody Map<String, Object> payload) {
        long userId;
        try {
            userId = Long.parseLong(payload.getOrDefault("userId", 0).toString());
        } catch (NumberFormatException ex) {
            return ResponseEntity.badRequest().body(Map.of("message", "Identifiant utilisateur invalide."));
        }
        if (userId <= 0) {
            return ResponseEntity.badRequest().body(Map.of("message", "Identifiant utilisateur requis."));
        }
        if (!credentialsMatch(payload, userId)) {
            return ResponseEntity.status(401).body(Map.of("message", "Session invalide ou compte introuvable."));
        }
        int orangeDays;
        try {
            orangeDays = Integer.parseInt(payload.getOrDefault("orangeDays", 0).toString());
        } catch (NumberFormatException ex) {
            orangeDays = 0;
        }
        if (orangeDays < 0) {
            orangeDays = 0;
        }
        String yearMonth = String.valueOf(payload.getOrDefault("yearMonth", "")).trim();
        mobileApiService.updateCatchupPendingSnapshot(userId, orangeDays, yearMonth.isEmpty() ? null : yearMonth);
        return ResponseEntity.ok(Map.of("ok", true));
    }

    /** Liste publique des agents pour le choix du parrain à l'inscription client. */
    @GetMapping("/agents/choices")
    public ResponseEntity<?> registrationAgentChoices() {
        var agents = registrationService.agentOptions().stream()
            .map(a -> Map.<String, Object>of("id", a.id(), "fullName", a.fullName()))
            .toList();
        return ResponseEntity.ok(Map.of("agents", agents));
    }

    @PostMapping("/agent/clients")
    public ResponseEntity<?> agentClients(@RequestBody Map<String, Object> payload) {
        long agentUserId = parseLong(payload.get("userId"));
        if (agentUserId <= 0 || !credentialsMatch(payload, agentUserId)) {
            return ResponseEntity.status(401).body(Map.of("message", "Session invalide."));
        }
        return ResponseEntity.ok(Map.of(
            "adhesionFeeFcfa", ClientAdhesionService.ADHESION_FEE_FCFA,
            "items", clientAdhesionService.listAgentClients(agentUserId)
        ));
    }

    @PostMapping("/agent/adhesion/paid")
    public ResponseEntity<?> agentMarkAdhesionPaid(@RequestBody Map<String, Object> payload) {
        long agentUserId = parseLong(payload.get("userId"));
        long clientUserId = parseLong(payload.get("clientUserId"));
        if (agentUserId <= 0 || !credentialsMatch(payload, agentUserId)) {
            return ResponseEntity.status(401).body(Map.of("message", "Session invalide."));
        }
        if (clientUserId <= 0) {
            return ResponseEntity.badRequest().body(Map.of("message", "Client requis."));
        }
        try {
            clientAdhesionService.markAdhesionPaidByAgent(clientUserId, agentUserId);
            return ResponseEntity.ok(Map.of(
                "ok", true,
                "status", ClientAdhesionService.STATUS_ADHERED,
                "adhesionFeeFcfa", ClientAdhesionService.ADHESION_FEE_FCFA
            ));
        } catch (IllegalArgumentException ex) {
            return ResponseEntity.badRequest().body(Map.of("message", ex.getMessage()));
        }
    }

    @PostMapping("/client/adhesion/dispute")
    public ResponseEntity<?> clientReportAdhesionDispute(@RequestBody Map<String, Object> payload) {
        long userId = parseLong(payload.get("userId"));
        if (userId <= 0 || !credentialsMatch(payload, userId)) {
            return ResponseEntity.status(401).body(Map.of("message", "Session invalide."));
        }
        String note = payload.get("note") == null ? "" : payload.get("note").toString();
        try {
            clientAdhesionService.reportAdhesionDispute(userId, note);
            return ResponseEntity.ok(Map.of("ok", true, "message", "Signalement envoyé au centre PayFlex."));
        } catch (IllegalArgumentException ex) {
            return ResponseEntity.badRequest().body(Map.of("message", ex.getMessage()));
        }
    }

    @GetMapping("/registrations/pending")
    public ResponseEntity<?> pendingRegistrationByPhone(@RequestParam String phone) {
        return registrationService.findPendingIdByPhone(phone)
            .map(id -> ResponseEntity.ok(Map.of("id", id, "status", "approved")))
            .orElseGet(() -> ResponseEntity.notFound().build());
    }

    @PostMapping("/adhesion/fedapay/init")
    public ResponseEntity<?> initFedaPayAdhesion(@RequestBody Map<String, Object> payload) {
        long userId = parseLong(payload.get("userId"));
        if (userId <= 0 || !credentialsMatch(payload, userId)) {
            return ResponseEntity.status(401).body(Map.of("message", "Session invalide."));
        }
        if (!fedaPayPaymentService.isAvailable()) {
            return ResponseEntity.ok(Map.of(
                "fedapayEnabled", false,
                "message", "Paiement mobile non configuré. Réglez l'adhésion en espèces auprès de votre agent PayFlex."
            ));
        }
        try {
            return ResponseEntity.ok(fedaPayPaymentService.initAdhesionPayment(userId));
        } catch (IllegalArgumentException ex) {
            return ResponseEntity.badRequest().body(Map.of("message", ex.getMessage()));
        } catch (IllegalStateException ex) {
            return ResponseEntity.status(502).body(Map.of(
                "message", ex.getMessage() != null ? ex.getMessage() : "Paiement mobile temporairement indisponible."
            ));
        }
    }

    @PostMapping("/adhesion/fedapay/status")
    public ResponseEntity<?> fedaPayAdhesionStatus(@RequestBody Map<String, Object> payload) {
        long userId = parseLong(payload.get("userId"));
        if (userId <= 0 || !credentialsMatch(payload, userId)) {
            return ResponseEntity.status(401).body(Map.of("message", "Session invalide."));
        }
        try {
            return ResponseEntity.ok(fedaPayPaymentService.adhesionPaymentStatus(userId));
        } catch (IllegalArgumentException ex) {
            return ResponseEntity.badRequest().body(Map.of("message", ex.getMessage()));
        }
    }

    @GetMapping(value = "/adhesion/fedapay/callback", produces = "text/html;charset=UTF-8")
    public ResponseEntity<String> fedaPayAdhesionCallback(
        @RequestParam long userId,
        @RequestParam(required = false) String status
    ) {
        String label = status == null || status.isBlank() ? "en cours" : status;
        if (userId > 0) {
            try {
                Map<String, Object> synced = fedaPayPaymentService.adhesionPaymentStatus(userId);
                label = String.valueOf(synced.getOrDefault("status", label));
            } catch (Exception ignored) {
                // webhook ou bouton « Vérifier » dans l'app
            }
        }
        String html = """
            <!DOCTYPE html><html lang="fr"><head><meta charset="UTF-8">
            <meta name="viewport" content="width=device-width,initial-scale=1">
            <title>PayFlex</title>
            <style>body{font-family:system-ui,sans-serif;text-align:center;padding:2rem;background:#f0f9ff;color:#0f172a}
            h1{font-size:1.25rem}p{color:#475569}</style></head><body>
            <h1>Adhésion PayFlex</h1>
            <p>Statut : %s</p>
            <p>Fermez cet écran ou appuyez sur « J'ai terminé le paiement » dans PayFlex.</p>
            </body></html>
            """.formatted(label);
        return ResponseEntity.ok(html);
    }

    @PostMapping(value = "/registrations", consumes = {"multipart/form-data"})
    public ResponseEntity<?> register(
        @RequestParam String fullName,
        @RequestParam String phone,
        @RequestParam(required = false) String email,
        @RequestParam(required = false) String city,
        @RequestParam(required = false) String profession,
        @RequestParam(required = false) String gender,
        @RequestParam(defaultValue = "self") String submittedBy,
        @RequestParam(required = false, defaultValue = "client") String requestedRole,
        @RequestParam(required = false) String clientProfile,
        @RequestParam(required = false) Long submittedByAgentUserId,
        @RequestParam(required = false) Long assignedAgentUserId,
        @RequestParam String pin,
        @RequestParam(required = false, defaultValue = "") String accountPassword,
        @RequestParam(required = false, defaultValue = "") String secretCode,
        @RequestParam String uniqueCode,
        @RequestParam(required = false) String workplaceName,
        @RequestParam(required = false) String workplaceAddress,
        @RequestParam(required = false) String bossName,
        @RequestParam(required = false) String bossPhone,
        @RequestParam(required = false) MultipartFile profilePhoto,
        @RequestParam(required = false) MultipartFile idDocument,
        @RequestParam(required = false, defaultValue = "false") String idDocumentWaived
    ) {
        if ("agent".equalsIgnoreCase(submittedBy)) {
            if (submittedByAgentUserId == null || submittedByAgentUserId <= 0) {
                return ResponseEntity.badRequest().body(Map.of("message", "En tant qu'agent, vous devez être identifié pour déposer cette demande."));
            }
            if (!permissionService.userHasPermission(submittedByAgentUserId, PermissionService.MOBILE_REGISTRATION_AGENT)) {
                return ResponseEntity.status(403).body(Map.of("message", "Votre profil ne permet pas d'enregistrer quelqu'un d'autre. Demandez une mise à jour à l'équipe PayFlex."));
            }
        }
        String roleToStore = requestedRole == null || requestedRole.isBlank() ? "client" : requestedRole.trim();
        if (clientProfile != null && !clientProfile.isBlank()) {
            roleToStore = clientProfile.trim();
        }
        if (roleToStore.length() > 40) {
            roleToStore = roleToStore.substring(0, 40);
        }
        try {
            boolean waived = parseIdDocumentWaived(idDocumentWaived);
            String pinTrim = pin == null ? "" : pin.trim();
            String passwordTrim = accountPassword == null ? "" : accountPassword.trim();
            if (passwordTrim.isEmpty()) {
                return ResponseEntity.badRequest().body(Map.of(
                    "message", "Mot de passe requis (minimum 6 caractères)."
                ));
            }
            long id = registrationService.submit(
                new RegistrationService.RegistrationInput(
                    fullName, phone, email, city, profession, gender, submittedBy, roleToStore,
                    submittedByAgentUserId, assignedAgentUserId, pinTrim, pinTrim, passwordTrim, uniqueCode,
                    workplaceName, workplaceAddress, bossName, bossPhone, waived
                ),
                profilePhoto,
                idDocument
            );
            log.info(
                "Mobile registration OK id={} phone={} role={} agentId={}",
                id,
                maskPhoneForLog(phone),
                roleToStore,
                assignedAgentUserId
            );
            return ResponseEntity.ok(Map.of(
                "id", id,
                "status", "approved",
                "accountStatus", ClientAdhesionService.STATUS_AWAITING_ADHESION,
                "adhesionFeeFcfa", ClientAdhesionService.ADHESION_FEE_FCFA,
                "message", "Compte créé. Finalisez votre adhésion (250 FCFA) pour activer cotisations et paiements."
            ));
        } catch (IllegalArgumentException ex) {
            log.warn("Mobile registration rejected phone={} reason={}", maskPhoneForLog(phone), ex.getMessage());
            return ResponseEntity.badRequest().body(Map.of("message", ex.getMessage()));
        } catch (Exception ex) {
            log.error("Inscription mobile échouée", ex);
            return ResponseEntity.internalServerError().body(Map.of("message", MESSAGE_SERVER_UNAVAILABLE));
        }
    }

    private static boolean parseIdDocumentWaived(String raw) {
        if (raw == null || raw.isBlank()) {
            return false;
        }
        String s = raw.trim().toLowerCase();
        return "true".equals(s) || "1".equals(s) || "on".equals(s) || "yes".equals(s);
    }

    private static String maskPhoneForLog(String phoneRaw) {
        if (phoneRaw == null || phoneRaw.isBlank()) {
            return "(vide)";
        }
        String digits = phoneRaw.replaceAll("\\D", "");
        if (digits.length() <= 4) {
            return "****";
        }
        return "***" + digits.substring(digits.length() - 4);
    }
}
