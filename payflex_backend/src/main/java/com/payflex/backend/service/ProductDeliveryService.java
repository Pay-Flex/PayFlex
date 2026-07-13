package com.payflex.backend.service;

import org.springframework.dao.EmptyResultDataAccessException;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.Map;
import java.util.Objects;
import java.util.Optional;

/**
 * Clôture & livraison (phase 4.2) : objectif atteint → validation solde/carnet → remise outil.
 */
@Service
public class ProductDeliveryService {

    public static final String STATUS_AWAITING_CLOSURE = "awaiting_closure";
    public static final String STATUS_CLOSURE_VALIDATED = "closure_validated";
    public static final String STATUS_DELIVERED = "delivered";

    private final JdbcTemplate jdbcTemplate;
    private final UserInboxNotificationService inboxNotifications;
    private final AdminAuditService auditService;

    public ProductDeliveryService(
        JdbcTemplate jdbcTemplate,
        UserInboxNotificationService inboxNotifications,
        AdminAuditService auditService
    ) {
        this.jdbcTemplate = jdbcTemplate;
        this.inboxNotifications = inboxNotifications;
        this.auditService = auditService;
    }

    public record ProductProgress(
        long productId,
        String productName,
        double productPrice,
        double totalValidated,
        boolean goalReached
    ) {}

    public record DeliveryRow(
        long id,
        long userId,
        String clientName,
        String clientPhone,
        long productId,
        String productName,
        String status,
        double totalValidated,
        double productPrice,
        int catchupDaysSnapshot,
        String adminNote,
        String closedBy,
        String closedAt,
        String deliveredBy,
        String deliveredAt,
        String stockReference,
        String createdAt
    ) {
        public String statusLabel() {
            return switch (status == null ? "" : status) {
                case STATUS_AWAITING_CLOSURE -> "En attente de clôture";
                case STATUS_CLOSURE_VALIDATED -> "Clôture validée — à livrer";
                case STATUS_DELIVERED -> "Livré";
                default -> status;
            };
        }

        public double balanceGap() {
            return Math.max(0, productPrice - totalValidated);
        }
    }

    public long countAwaitingClosure() {
        Long n = jdbcTemplate.queryForObject(
            "SELECT COUNT(*) FROM client_product_deliveries WHERE status = ?",
            Long.class,
            STATUS_AWAITING_CLOSURE
        );
        return n == null ? 0L : n;
    }

    public long countAwaitingDelivery() {
        Long n = jdbcTemplate.queryForObject(
            "SELECT COUNT(*) FROM client_product_deliveries WHERE status = ?",
            Long.class,
            STATUS_CLOSURE_VALIDATED
        );
        return n == null ? 0L : n;
    }

    public List<DeliveryRow> listDeliveries(String statusFilter, int limit) {
        int lim = Math.min(Math.max(limit, 1), 200);
        StringBuilder sql = new StringBuilder(
            """
            SELECT d.id, d.user_id, u.full_name, u.phone, d.product_id, p.name AS product_name,
                   d.status, d.total_validated, d.product_price, d.catchup_days_snapshot,
                   d.admin_note, d.closed_by, d.closed_at, d.delivered_by, d.delivered_at,
                   d.stock_reference, d.created_at
            FROM client_product_deliveries d
            JOIN users u ON u.id = d.user_id
            JOIN products p ON p.id = d.product_id
            WHERE 1=1
            """
        );
        if (statusFilter != null && !statusFilter.isBlank()) {
            sql.append(" AND d.status = ? ");
            return jdbcTemplate.query(
                sql + " ORDER BY d.updated_at DESC LIMIT ?",
                (rs, i) -> mapDeliveryRow(rs),
                statusFilter.trim(),
                lim
            );
        }
        return jdbcTemplate.query(
            sql + " ORDER BY FIELD(d.status, ?, ?, ?), d.updated_at DESC LIMIT ?",
            (rs, i) -> mapDeliveryRow(rs),
            STATUS_AWAITING_CLOSURE,
            STATUS_CLOSURE_VALIDATED,
            STATUS_DELIVERED,
            lim
        );
    }

    public Optional<DeliveryRow> findOpenDeliveryForClient(long clientUserId) {
        if (clientUserId <= 0) {
            return Optional.empty();
        }
        List<DeliveryRow> rows = jdbcTemplate.query(
            """
            SELECT d.id, d.user_id, u.full_name, u.phone, d.product_id, p.name AS product_name,
                   d.status, d.total_validated, d.product_price, d.catchup_days_snapshot,
                   d.admin_note, d.closed_by, d.closed_at, d.delivered_by, d.delivered_at,
                   d.stock_reference, d.created_at
            FROM client_product_deliveries d
            JOIN users u ON u.id = d.user_id
            JOIN products p ON p.id = d.product_id
            WHERE d.user_id = ? AND d.status IN (?, ?)
            ORDER BY d.id DESC
            LIMIT 1
            """,
            (rs, i) -> mapDeliveryRow(rs),
            clientUserId,
            STATUS_AWAITING_CLOSURE,
            STATUS_CLOSURE_VALIDATED
        );
        return rows.isEmpty() ? Optional.empty() : Optional.of(rows.get(0));
    }

    public Optional<ProductProgress> resolvePrimaryProductProgress(long clientUserId) {
        if (clientUserId <= 0) {
            return Optional.empty();
        }
        List<ProductProgress> rows = jdbcTemplate.query(
            """
            SELECT c.product_id, p.name AS product_name, p.price AS product_price,
                   COALESCE(SUM(CASE WHEN c.status = 'validated' THEN c.amount ELSE 0 END), 0) AS total_validated
            FROM contributions c
            JOIN products p ON p.id = c.product_id
            WHERE c.user_id = ? AND c.product_id IS NOT NULL
            GROUP BY c.product_id, p.name, p.price
            ORDER BY MAX(c.created_at) DESC
            LIMIT 1
            """,
            (rs, i) -> {
                double price = rs.getDouble("product_price");
                double total = rs.getDouble("total_validated");
                return new ProductProgress(
                    rs.getLong("product_id"),
                    rs.getString("product_name"),
                    price,
                    total,
                    total >= price && price > 0
                );
            },
            clientUserId
        );
        return rows.isEmpty() ? Optional.empty() : Optional.of(rows.get(0));
    }

    /** Crée ou met à jour un dossier « en attente de clôture » quand l’objectif est atteint. */
    @Transactional
    public void ensureAwaitingClosure(long clientUserId, long productId) {
        if (clientUserId <= 0 || productId <= 0) {
            return;
        }
        Optional<DeliveryRow> open = findOpenDeliveryForClient(clientUserId);
        if (open.isPresent()) {
            return;
        }
        ProductProgress progress = resolvePrimaryProductProgress(clientUserId).orElse(null);
        if (progress == null || progress.productId() != productId) {
            return;
        }
        int catchup = catchupDays(clientUserId);
        jdbcTemplate.update(
            """
            INSERT INTO client_product_deliveries (
                user_id, product_id, status, total_validated, product_price, catchup_days_snapshot
            ) VALUES (?, ?, ?, ?, ?, ?)
            """,
            clientUserId,
            productId,
            STATUS_AWAITING_CLOSURE,
            progress.totalValidated(),
            progress.productPrice(),
            catchup
        );
    }

    /** Ouvre manuellement un dossier clôture depuis la fiche client. */
    @Transactional
    public long openClosureCase(long clientUserId, String actorLogin) {
        if (findOpenDeliveryForClient(clientUserId).isPresent()) {
            throw new IllegalArgumentException("Un dossier clôture / livraison est déjà ouvert pour ce client.");
        }
        ProductProgress progress = resolvePrimaryProductProgress(clientUserId)
            .orElseThrow(() -> new IllegalArgumentException("Aucun produit / cotisation trouvé pour ce client."));
        int catchup = catchupDays(clientUserId);
        jdbcTemplate.update(
            """
            INSERT INTO client_product_deliveries (
                user_id, product_id, status, total_validated, product_price, catchup_days_snapshot, admin_note
            ) VALUES (?, ?, ?, ?, ?, ?, ?)
            """,
            clientUserId,
            progress.productId(),
            STATUS_AWAITING_CLOSURE,
            progress.totalValidated(),
            progress.productPrice(),
            catchup,
            "Dossier ouvert par " + actorLogin
        );
        Long id = jdbcTemplate.queryForObject("SELECT LAST_INSERT_ID()", Long.class);
        auditService.logEquipe(
            actorLogin,
            "Ouverture dossier clôture/livraison pour client #" + clientUserId + " (« " + progress.productName() + " »)."
        );
        return id == null ? 0L : id;
    }

    @Transactional
    public void validateClosure(long deliveryId, String actorLogin, String adminNote, boolean forceDespiteCatchup) {
        DeliveryRow row = requireDelivery(deliveryId);
        if (!STATUS_AWAITING_CLOSURE.equals(row.status())) {
            throw new IllegalArgumentException("Ce dossier n'est pas en attente de clôture.");
        }
        ProductProgress live = resolvePrimaryProductProgress(row.userId())
            .orElseThrow(() -> new IllegalArgumentException("Produit client introuvable."));
        if (live.totalValidated() < live.productPrice()) {
            throw new IllegalArgumentException(
                "Solde insuffisant : "
                    + Math.round(live.totalValidated())
                    + " FCFA validés pour un objectif de "
                    + Math.round(live.productPrice())
                    + " FCFA."
            );
        }
        int catchup = catchupDays(row.userId());
        if (catchup > 0 && !forceDespiteCatchup) {
            throw new IllegalArgumentException(
                "Le carnet signale encore "
                    + catchup
                    + " jour(s) de rattrapage. Cochez « Forcer la clôture » après vérification manuelle."
            );
        }
        String note = adminNote == null || adminNote.isBlank()
            ? "Clôture validée par " + actorLogin
            : adminNote.trim();
        jdbcTemplate.update(
            """
            UPDATE client_product_deliveries
            SET status = ?, total_validated = ?, product_price = ?, catchup_days_snapshot = ?,
                admin_note = ?, closed_by = ?, closed_at = NOW()
            WHERE id = ?
            """,
            STATUS_CLOSURE_VALIDATED,
            live.totalValidated(),
            live.productPrice(),
            catchup,
            note,
            actorLogin,
            deliveryId
        );
        auditService.logClient(
            row.userId(),
            "Clôture PayFlex validée pour « " + row.productName() + " » — livraison en préparation."
        );
        auditService.logEquipe(
            actorLogin,
            "Clôture validée — client #"
                + row.userId()
                + ", dossier #"
                + deliveryId
                + " ("
                + Math.round(live.totalValidated())
                + " / "
                + Math.round(live.productPrice())
                + " FCFA)."
        );
        inboxNotifications.notifyClientAndAssignedAgent(
            row.userId(),
            "delivery_closure_validated",
            "Clôture validée",
            "Votre solde et votre carnet ont été validés pour « "
                + row.productName()
                + " ». Le centre prépare la remise de votre équipement.",
            "Clôture validée — {client}",
            "La clôture PayFlex de {client} (« " + row.productName() + " ») est validée. Préparez ou planifiez la livraison.",
            null
        );
    }

    @Transactional
    public void confirmDelivery(long deliveryId, String actorLogin, String deliveryNote, String stockReference) {
        DeliveryRow row = requireDelivery(deliveryId);
        if (!STATUS_CLOSURE_VALIDATED.equals(row.status())) {
            throw new IllegalArgumentException("Validez d'abord la clôture avant d'enregistrer la livraison.");
        }
        String note = deliveryNote == null || deliveryNote.isBlank() ? null : deliveryNote.trim();
        String stock = stockReference == null || stockReference.isBlank() ? null : stockReference.trim();
        String combinedNote = row.adminNote();
        if (note != null) {
            combinedNote = combinedNote == null || combinedNote.isBlank()
                ? "[Livraison] " + note
                : combinedNote + "\n[Livraison] " + note;
        }
        jdbcTemplate.update(
            """
            UPDATE client_product_deliveries
            SET status = ?, delivered_by = ?, delivered_at = NOW(), admin_note = ?, stock_reference = ?
            WHERE id = ?
            """,
            STATUS_DELIVERED,
            actorLogin,
            combinedNote,
            stock,
            deliveryId
        );
        auditService.logClient(
            row.userId(),
            "Équipement livré : « " + row.productName() + " » (dossier #" + deliveryId + ")."
        );
        auditService.logEquipe(
            actorLogin,
            "Livraison enregistrée — client #"
                + row.userId()
                + ", dossier #"
                + deliveryId
                + (stock != null ? ", stock " + stock : "")
                + "."
        );
        inboxNotifications.notifyClientAndAssignedAgent(
            row.userId(),
            "delivery_completed",
            "Équipement livré",
            "Votre équipement PayFlex « "
                + row.productName()
                + " » a été remis. Merci pour votre assiduité !",
            "Livraison effectuée — {client}",
            "L'équipement de {client} (« " + row.productName() + " ») a été livré par le centre PayFlex.",
            null
        );
        jdbcTemplate.update(
            "UPDATE users SET goal_notified_for_product_id = NULL WHERE id = ?",
            row.userId()
        );
    }

    public void enrichProfileMap(Map<String, Object> profile) {
        Object idObj = profile.get("id");
        if (!(idObj instanceof Number n)) {
            return;
        }
        long userId = n.longValue();
        if (!"client".equalsIgnoreCase(Objects.toString(profile.get("role"), ""))) {
            return;
        }
        findOpenDeliveryForClient(userId).ifPresentOrElse(
            d -> {
                profile.put("deliveryStatus", d.status());
                profile.put("deliveryProductName", d.productName());
                profile.put("deliveryProductPrice", d.productPrice());
                profile.put("deliveryTotalValidated", d.totalValidated());
                profile.put("deliveryId", d.id());
            },
            () -> resolvePrimaryProductProgress(userId).ifPresent(p -> {
                if (p.goalReached()) {
                    profile.put("deliveryStatus", "goal_reached");
                    profile.put("deliveryProductName", p.productName());
                    profile.put("deliveryProductPrice", p.productPrice());
                    profile.put("deliveryTotalValidated", p.totalValidated());
                }
            })
        );
    }

    private int catchupDays(long userId) {
        try {
            Integer n = jdbcTemplate.queryForObject(
                "SELECT COALESCE(catchup_pending_cached, 0) FROM users WHERE id = ?",
                Integer.class,
                userId
            );
            return n == null ? 0 : Math.max(0, n);
        } catch (EmptyResultDataAccessException ex) {
            return 0;
        }
    }

    private DeliveryRow requireDelivery(long deliveryId) {
        try {
            return jdbcTemplate.queryForObject(
                """
                SELECT d.id, d.user_id, u.full_name, u.phone, d.product_id, p.name AS product_name,
                       d.status, d.total_validated, d.product_price, d.catchup_days_snapshot,
                       d.admin_note, d.closed_by, d.closed_at, d.delivered_by, d.delivered_at,
                       d.stock_reference, d.created_at
                FROM client_product_deliveries d
                JOIN users u ON u.id = d.user_id
                JOIN products p ON p.id = d.product_id
                WHERE d.id = ?
                """,
                (rs, i) -> mapDeliveryRow(rs),
                deliveryId
            );
        } catch (EmptyResultDataAccessException ex) {
            throw new IllegalArgumentException("Dossier clôture / livraison introuvable.");
        }
    }

    private static DeliveryRow mapDeliveryRow(java.sql.ResultSet rs) throws java.sql.SQLException {
        return new DeliveryRow(
            rs.getLong("id"),
            rs.getLong("user_id"),
            rs.getString("full_name"),
            rs.getString("phone"),
            rs.getLong("product_id"),
            rs.getString("product_name"),
            rs.getString("status"),
            rs.getDouble("total_validated"),
            rs.getDouble("product_price"),
            rs.getInt("catchup_days_snapshot"),
            rs.getString("admin_note"),
            rs.getString("closed_by"),
            rs.getString("closed_at") != null ? rs.getString("closed_at") : null,
            rs.getString("delivered_by"),
            rs.getString("delivered_at") != null ? rs.getString("delivered_at") : null,
            rs.getString("stock_reference"),
            rs.getString("created_at") != null ? rs.getString("created_at") : null
        );
    }
}
