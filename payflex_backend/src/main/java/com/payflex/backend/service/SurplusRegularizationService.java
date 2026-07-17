package com.payflex.backend.service;

import org.springframework.dao.EmptyResultDataAccessException;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.sql.Timestamp;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Objects;

/**
 * Régularisation manuelle des « surplus non affectés » (voir {@link ContributionAllocationService}) :
 * excédents de cotisation qui n'ont pu être répartis sur aucun produit actif du client au moment
 * de la validation du paiement (tous les produits actifs étaient déjà complets). Le montant reste
 * tracé dans {@code contribution_unallocated_surplus} (statut {@code unassigned}) jusqu'à
 * intervention du centre :
 * <ul>
 *   <li><b>Réaffectation</b> : le montant devient une nouvelle cotisation {@code validated} sur un
 *       produit actif choisi du client (même mécanique que la cascade automatique).</li>
 *   <li><b>Remboursement / traitement hors système</b> : le surplus est marqué réglé avec une note
 *       libre de l'admin (ex. remboursement espèces au centre), sans nouvelle cotisation.</li>
 * </ul>
 */
@Service
public class SurplusRegularizationService {

    public static final String STATUS_UNASSIGNED = "unassigned";
    public static final String STATUS_REALLOCATED = "reallocated";
    public static final String STATUS_REFUNDED = "refunded_manual";

    private static final String NOTIF_TYPE_SURPLUS_RESOLVED = "contribution_surplus_resolved";

    private final JdbcTemplate jdbcTemplate;
    private final ProductDeliveryService productDeliveryService;
    private final UserInboxNotificationService inboxNotifications;

    public SurplusRegularizationService(
        JdbcTemplate jdbcTemplate,
        ProductDeliveryService productDeliveryService,
        UserInboxNotificationService inboxNotifications
    ) {
        this.jdbcTemplate = jdbcTemplate;
        this.productDeliveryService = productDeliveryService;
        this.inboxNotifications = inboxNotifications;
    }

    public record UnresolvedSurplus(
        long id,
        long clientUserId,
        String clientName,
        String clientPhone,
        double amountFcfa,
        String sourceProductName,
        Timestamp createdAt,
        Long allocationGroupId
    ) {}

    public record ActiveProductChoice(long productId, String productName, double remainingFcfa) {}

    public long countUnresolved() {
        Long n = jdbcTemplate.queryForObject(
            "SELECT COUNT(*) FROM contribution_unallocated_surplus WHERE status = ?",
            Long.class,
            STATUS_UNASSIGNED
        );
        return n == null ? 0L : n;
    }

    /** Surplus non résolus, tous clients confondus, du plus ancien au plus récent (traitement FIFO). */
    public List<UnresolvedSurplus> listUnresolved() {
        return jdbcTemplate.query(
            """
            SELECT cus.id, cus.user_id, cus.amount_fcfa, cus.created_at, cus.allocation_group_id,
                   u.full_name, u.phone,
                   p.name AS source_product_name
            FROM contribution_unallocated_surplus cus
            INNER JOIN users u ON u.id = cus.user_id
            LEFT JOIN contribution_allocation_groups cag ON cag.id = cus.allocation_group_id
            LEFT JOIN contributions c ON c.id = cag.anchor_contribution_id
            LEFT JOIN products p ON p.id = c.product_id
            WHERE cus.status = ?
            ORDER BY cus.created_at ASC
            """,
            (rs, i) -> new UnresolvedSurplus(
                rs.getLong("id"),
                rs.getLong("user_id"),
                rs.getString("full_name"),
                rs.getString("phone"),
                rs.getDouble("amount_fcfa"),
                rs.getString("source_product_name"),
                rs.getTimestamp("created_at"),
                (Long) rs.getObject("allocation_group_id")
            ),
            STATUS_UNASSIGNED
        );
    }

    /** Produits actifs (non complets) du client, éligibles à une réaffectation manuelle du surplus. */
    public List<ActiveProductChoice> activeProductChoicesForClient(long clientUserId) {
        List<ActiveProductChoice> out = new ArrayList<>();
        for (ProductDeliveryService.ProductProgress p : productDeliveryService.listProductProgress(clientUserId)) {
            if (!p.goalReached()) {
                out.add(new ActiveProductChoice(p.productId(), p.productName(), Math.max(0, p.productPrice() - p.totalValidated())));
            }
        }
        return out;
    }

    /** Choix de produits actifs, pré-calculés pour tous les clients apparaissant dans {@code rows} (évite le N+1 côté vue). */
    public Map<Long, List<ActiveProductChoice>> activeProductChoicesByClient(List<UnresolvedSurplus> rows) {
        Map<Long, List<ActiveProductChoice>> out = new LinkedHashMap<>();
        for (UnresolvedSurplus row : rows) {
            out.computeIfAbsent(row.clientUserId(), this::activeProductChoicesForClient);
        }
        return out;
    }

    /**
     * Réaffecte le surplus à un produit actif du client : nouvelle cotisation {@code validated},
     * comme le fait la cascade automatique de {@link ContributionAllocationService}.
     */
    @Transactional
    public void reallocateToProduct(long surplusId, long targetProductId, String adminUsername) {
        UnresolvedSurplusRow row = loadUnassigned(surplusId);
        boolean clientHasProduct = productDeliveryService.listProductProgress(row.userId).stream()
            .anyMatch(p -> p.productId() == targetProductId);
        if (!clientHasProduct) {
            throw new IllegalArgumentException("Ce produit n'est pas dans la sélection active de ce client.");
        }
        String ref = "PF-SURPLUS-" + surplusId;
        jdbcTemplate.update(
            """
            INSERT INTO contributions (
                user_id, product_id, agent_id, amount, payment_mode, status, reference_code,
                paid_at, payment_provider, allocation_group_id
            )
            VALUES (?, ?, NULL, ?, 'regularisation', 'validated', ?, NOW(), NULL, ?)
            """,
            row.userId,
            targetProductId,
            row.amountFcfa,
            ref,
            row.allocationGroupId
        );
        Long newContributionId = jdbcTemplate.queryForObject("SELECT LAST_INSERT_ID()", Long.class);

        String productName = productDeliveryService.listProductProgress(row.userId).stream()
            .filter(p -> p.productId() == targetProductId)
            .map(ProductDeliveryService.ProductProgress::productName)
            .findFirst()
            .orElse("le produit choisi");

        String note = "Réaffecté au produit « " + productName + " » (nouvelle cotisation #" + newContributionId + ") par " + adminUsername + ".";
        markResolved(surplusId, STATUS_REALLOCATED, adminUsername, note);

        inboxNotifications.notifyUser(
            row.userId,
            NOTIF_TYPE_SURPLUS_RESOLVED,
            "Excédent régularisé",
            "Votre excédent de " + Math.round(row.amountFcfa) + " FCFA en attente d'affectation a été crédité sur « "
                + productName + " ».",
            newContributionId
        );
    }

    /** Marque le surplus comme remboursé / traité hors système (espèces, virement, etc.), sans nouvelle cotisation. */
    @Transactional
    public void markRefundedOutOfSystem(long surplusId, String note, String adminUsername) {
        UnresolvedSurplusRow row = loadUnassigned(surplusId);
        String safeNote = note == null || note.isBlank()
            ? "Traité hors système par " + adminUsername + "."
            : note.trim();
        markResolved(surplusId, STATUS_REFUNDED, adminUsername, safeNote);

        inboxNotifications.notifyUser(
            row.userId,
            NOTIF_TYPE_SURPLUS_RESOLVED,
            "Excédent régularisé",
            "Votre excédent de " + Math.round(row.amountFcfa) + " FCFA en attente d'affectation a été traité par le centre PayFlex : "
                + safeNote,
            null
        );
    }

    private record UnresolvedSurplusRow(long id, long userId, double amountFcfa, Long allocationGroupId) {}

    private UnresolvedSurplusRow loadUnassigned(long surplusId) {
        try {
            Map<String, Object> row = jdbcTemplate.queryForMap(
                "SELECT id, user_id, amount_fcfa, allocation_group_id, status FROM contribution_unallocated_surplus WHERE id = ?",
                surplusId
            );
            if (!STATUS_UNASSIGNED.equals(Objects.toString(row.get("status"), ""))) {
                throw new IllegalArgumentException("Ce surplus a déjà été régularisé.");
            }
            return new UnresolvedSurplusRow(
                ((Number) row.get("id")).longValue(),
                ((Number) row.get("user_id")).longValue(),
                row.get("amount_fcfa") instanceof Number n ? n.doubleValue() : 0,
                row.get("allocation_group_id") == null ? null : ((Number) row.get("allocation_group_id")).longValue()
            );
        } catch (EmptyResultDataAccessException ex) {
            throw new IllegalArgumentException("Surplus introuvable.");
        }
    }

    private void markResolved(long surplusId, String status, String adminUsername, String note) {
        jdbcTemplate.update(
            """
            UPDATE contribution_unallocated_surplus
            SET status = ?, resolved_by = ?, resolved_note = ?, resolved_at = NOW()
            WHERE id = ?
            """,
            status,
            adminUsername,
            note,
            surplusId
        );
    }
}
