package com.payflex.backend.service;

import org.springframework.dao.EmptyResultDataAccessException;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.ArrayList;
import java.util.List;
import java.util.Map;

/**
 * Répartition automatique d'une cotisation entre plusieurs produits actifs du client, lorsque le
 * montant validé dépasse ce qu'il reste à payer sur le produit visé.
 *
 * <p><b>Algorithme</b> (voir aussi {@link ProductDeliveryService#listProductProgress(long)} pour
 * l'ordre des produits) :</p>
 * <ol>
 *   <li>Le produit visé par la cotisation est traité EN PREMIER.</li>
 *   <li>S'il reste un surplus après avoir complété (ou tenté de compléter) le produit visé, on
 *       cascade vers les AUTRES produits actifs du client (non encore complets), dans l'ordre de
 *       leur sélection ({@code client_product_selections.created_at ASC}, à défaut date de la
 *       1ère cotisation sur ce produit — approximation documentée faute de colonne d'ordre dédiée).</li>
 *   <li>Cascade bornée à {@link #MAX_CASCADE_ITERATIONS} produits par garde-fou explicite (la
 *       liste des produits actifs d'un client est de toute façon finie).</li>
 *   <li>S'il reste un surplus après avoir épuisé tous les produits actifs disponibles : il est
 *       crédité comme <b>« surplus non affecté »</b> ({@code contribution_unallocated_surplus}) —
 *       jamais perdu, jamais ignoré silencieusement. Le client et le centre sont notifiés pour
 *       affectation manuelle. C'est le choix retenu (plutôt qu'un rejet pur) car à ce stade le
 *       paiement est déjà confirmé/encaissé : le rejeter reviendrait à faire disparaître un
 *       versement réel sans contrepartie pour le client.</li>
 * </ol>
 *
 * <p><b>Persistance</b> : quand aucune répartition n'est nécessaire (montant ≤ reste à payer sur
 * le produit visé), la cotisation d'origine est simplement validée telle quelle — comportement
 * strictement inchangé, aucune ligne de traçage créée. Dès qu'une répartition a lieu (cascade
 * et/ou surplus non affecté et/ou redirection vers un autre produit), la cotisation d'origine
 * (« ancre ») est réutilisée pour la 1ère tranche allouée, les tranches suivantes sont de
 * nouvelles lignes {@code contributions} (déjà {@code status='validated'}), et l'ensemble est relié
 * par {@code contribution_allocation_groups} / {@code contribution_allocations} /
 * {@code contributions.allocation_group_id}.</p>
 */
@Service
public class ContributionAllocationService {

    /** Garde-fou anti-boucle infinie demandé explicitement (liste de produits déjà finie en pratique). */
    public static final int MAX_CASCADE_ITERATIONS = 20;
    private static final double EPSILON = 0.009;

    private final JdbcTemplate jdbcTemplate;
    private final ProductDeliveryService productDeliveryService;

    public ContributionAllocationService(JdbcTemplate jdbcTemplate, ProductDeliveryService productDeliveryService) {
        this.jdbcTemplate = jdbcTemplate;
        this.productDeliveryService = productDeliveryService;
    }

    public record AllocationLine(
        long contributionId,
        long productId,
        String productName,
        double amountFcfa,
        boolean goalReachedNow
    ) {}

    public record AllocationOutcome(
        long anchorContributionId,
        long clientUserId,
        double originalAmountFcfa,
        List<AllocationLine> lines,
        double unallocatedSurplusFcfa,
        Long allocationGroupId
    ) {
        /** true dès qu'une répartition a réellement eu lieu (cascade, redirection ou surplus non affecté). */
        public boolean wasSplit() {
            return allocationGroupId != null;
        }
    }

    private record PlannedLine(long productId, String productName, double amount, boolean goalReached) {}

    private record ContributionSnapshot(
        long id,
        long userId,
        Long productId,
        Long agentId,
        double amount,
        String paymentMode,
        String referenceCode,
        String paymentProvider
    ) {}

    /**
     * Fait passer une cotisation de {@code pending} à {@code validated}, en répartissant
     * automatiquement l'éventuel excédent sur les autres produits actifs du client. L'appelant
     * doit s'être assuré au préalable que la cotisation est bien en statut {@code pending}
     * (cohérent avec le reste de {@code ContributionWorkflowService}).
     */
    @Transactional
    public AllocationOutcome allocateAndValidate(long contributionId) {
        ContributionSnapshot snap = loadSnapshot(contributionId);
        if (snap == null) {
            throw new IllegalArgumentException("Cotisation introuvable.");
        }

        if (snap.productId() == null || snap.productId() <= 0 || snap.amount() <= 0) {
            // Pas de produit rattaché (cas rare / legacy) : rien à répartir, validation simple.
            jdbcTemplate.update(
                "UPDATE contributions SET status = 'validated', paid_at = NOW() WHERE id = ?",
                contributionId
            );
            return new AllocationOutcome(contributionId, snap.userId(), snap.amount(), List.of(), 0, null);
        }

        List<ProductDeliveryService.ProductProgress> order = buildCascadeOrder(snap.userId(), snap.productId());

        double budget = snap.amount();
        List<PlannedLine> planned = new ArrayList<>();
        int iterations = 0;
        for (ProductDeliveryService.ProductProgress candidate : order) {
            if (budget <= EPSILON || iterations >= MAX_CASCADE_ITERATIONS) {
                break;
            }
            iterations++;
            double remaining = Math.max(0, candidate.productPrice() - candidate.totalValidated());
            if (remaining <= EPSILON) {
                continue;
            }
            double take = Math.min(budget, remaining);
            boolean goalReached = candidate.totalValidated() + take >= candidate.productPrice() - EPSILON;
            planned.add(new PlannedLine(candidate.productId(), candidate.productName(), take, goalReached));
            budget -= take;
        }
        double unallocatedSurplus = Math.max(0, budget);

        boolean unchanged = planned.size() == 1
            && unallocatedSurplus <= EPSILON
            && planned.get(0).productId() == snap.productId()
            && Math.abs(planned.get(0).amount() - snap.amount()) <= EPSILON;

        if (unchanged) {
            PlannedLine only = planned.get(0);
            jdbcTemplate.update(
                "UPDATE contributions SET status = 'validated', paid_at = NOW() WHERE id = ?",
                contributionId
            );
            return new AllocationOutcome(
                contributionId,
                snap.userId(),
                snap.amount(),
                List.of(new AllocationLine(contributionId, only.productId(), only.productName(), only.amount(), only.goalReached())),
                0,
                null
            );
        }

        long groupId = insertAllocationGroup(snap, unallocatedSurplus);
        List<AllocationLine> finalLines = new ArrayList<>();
        for (int i = 0; i < planned.size(); i++) {
            PlannedLine line = planned.get(i);
            long lineContributionId = (i == 0)
                ? reuseAnchorForLine(contributionId, line, groupId)
                : insertAdditionalLine(snap, line, groupId, i + 1);
            insertAllocationRow(groupId, lineContributionId, line.productId(), line.amount(), line.goalReached());
            finalLines.add(new AllocationLine(lineContributionId, line.productId(), line.productName(), line.amount(), line.goalReached()));
        }
        if (planned.isEmpty()) {
            // Aucun produit actif ne peut absorber ce paiement (tous complets) : l'ancre reste
            // validée (montant confirmé encaissé) mais sans produit ; tout part en surplus non affecté.
            jdbcTemplate.update(
                """
                UPDATE contributions
                SET status = 'validated', paid_at = NOW(), product_id = NULL, allocation_group_id = ?
                WHERE id = ?
                """,
                groupId,
                contributionId
            );
        }

        return new AllocationOutcome(contributionId, snap.userId(), snap.amount(), finalLines, unallocatedSurplus, groupId);
    }

    /**
     * Reconstitue le résultat d'allocation d'une cotisation déjà validée (pour l'exposer dans une
     * réponse API : validation immédiate agent cash, statut PayDunya, etc.). Si la cotisation n'a
     * jamais été répartie, renvoie une sortie « ligne unique » sans {@code allocationGroupId}.
     */
    public AllocationOutcome findOutcomeForContribution(long contributionId) {
        Map<String, Object> row;
        try {
            row = jdbcTemplate.queryForMap(
                """
                SELECT c.id, c.user_id, c.product_id, c.amount, c.allocation_group_id, p.name AS product_name
                FROM contributions c
                LEFT JOIN products p ON p.id = c.product_id
                WHERE c.id = ?
                """,
                contributionId
            );
        } catch (EmptyResultDataAccessException ex) {
            return new AllocationOutcome(contributionId, 0, 0, List.of(), 0, null);
        }
        long userId = ((Number) row.get("user_id")).longValue();
        Object groupIdObj = row.get("allocation_group_id");
        if (groupIdObj == null) {
            Object productIdObj = row.get("product_id");
            double amount = row.get("amount") instanceof Number n ? n.doubleValue() : 0;
            if (productIdObj == null) {
                return new AllocationOutcome(contributionId, userId, amount, List.of(), 0, null);
            }
            long productId = ((Number) productIdObj).longValue();
            boolean goalReached = productDeliveryService.listProductProgress(userId).stream()
                .filter(p -> p.productId() == productId)
                .anyMatch(ProductDeliveryService.ProductProgress::goalReached);
            return new AllocationOutcome(
                contributionId,
                userId,
                amount,
                List.of(new AllocationLine(contributionId, productId, (String) row.get("product_name"), amount, goalReached)),
                0,
                null
            );
        }
        long groupId = ((Number) groupIdObj).longValue();
        Map<String, Object> group = jdbcTemplate.queryForMap(
            "SELECT source_amount_fcfa, unallocated_surplus_fcfa FROM contribution_allocation_groups WHERE id = ?",
            groupId
        );
        List<AllocationLine> lines = jdbcTemplate.query(
            """
            SELECT ca.contribution_id, ca.product_id, ca.amount_fcfa, ca.goal_reached_now, p.name AS product_name
            FROM contribution_allocations ca
            LEFT JOIN products p ON p.id = ca.product_id
            WHERE ca.allocation_group_id = ?
            ORDER BY ca.id ASC
            """,
            (rs, i) -> new AllocationLine(
                rs.getLong("contribution_id"),
                rs.getLong("product_id"),
                rs.getString("product_name"),
                rs.getDouble("amount_fcfa"),
                rs.getBoolean("goal_reached_now")
            ),
            groupId
        );
        double sourceAmount = ((Number) group.get("source_amount_fcfa")).doubleValue();
        double surplus = ((Number) group.get("unallocated_surplus_fcfa")).doubleValue();
        return new AllocationOutcome(contributionId, userId, sourceAmount, lines, surplus, groupId);
    }

    /**
     * Détail d'un groupe de répartition par son id (pour l'historique client / fiche admin).
     * Retourne {@code null} si le groupe n'existe pas.
     */
    public AllocationOutcome findOutcomeByGroupId(long groupId) {
        Map<String, Object> group;
        try {
            group = jdbcTemplate.queryForMap(
                "SELECT user_id, source_amount_fcfa, unallocated_surplus_fcfa, anchor_contribution_id FROM contribution_allocation_groups WHERE id = ?",
                groupId
            );
        } catch (EmptyResultDataAccessException ex) {
            return null;
        }
        List<AllocationLine> lines = jdbcTemplate.query(
            """
            SELECT ca.contribution_id, ca.product_id, ca.amount_fcfa, ca.goal_reached_now, p.name AS product_name
            FROM contribution_allocations ca
            LEFT JOIN products p ON p.id = ca.product_id
            WHERE ca.allocation_group_id = ?
            ORDER BY ca.id ASC
            """,
            (rs, i) -> new AllocationLine(
                rs.getLong("contribution_id"),
                rs.getLong("product_id"),
                rs.getString("product_name"),
                rs.getDouble("amount_fcfa"),
                rs.getBoolean("goal_reached_now")
            ),
            groupId
        );
        Object anchorObj = group.get("anchor_contribution_id");
        long anchorId = anchorObj == null ? 0L : ((Number) anchorObj).longValue();
        return new AllocationOutcome(
            anchorId,
            ((Number) group.get("user_id")).longValue(),
            ((Number) group.get("source_amount_fcfa")).doubleValue(),
            lines,
            ((Number) group.get("unallocated_surplus_fcfa")).doubleValue(),
            groupId
        );
    }

    /**
     * Ordre de cascade : le produit visé d'abord, puis les autres produits actifs (non complets)
     * du client dans l'ordre de sélection croissant (voir {@link ProductDeliveryService#listProductProgress(long)}).
     */
    private List<ProductDeliveryService.ProductProgress> buildCascadeOrder(long clientUserId, long targetProductId) {
        List<ProductDeliveryService.ProductProgress> all = productDeliveryService.listProductProgress(clientUserId);
        List<ProductDeliveryService.ProductProgress> order = new ArrayList<>();
        ProductDeliveryService.ProductProgress target = all.stream()
            .filter(p -> p.productId() == targetProductId)
            .findFirst()
            .orElseGet(() -> loadStandaloneProductProgress(clientUserId, targetProductId));
        if (target != null) {
            order.add(target);
        }
        for (ProductDeliveryService.ProductProgress p : all) {
            if (p.productId() != targetProductId) {
                order.add(p);
            }
        }
        return order;
    }

    /** Filet de sécurité si le produit visé n'apparaît pas encore dans listProductProgress (edge-case). */
    private ProductDeliveryService.ProductProgress loadStandaloneProductProgress(long clientUserId, long productId) {
        try {
            Map<String, Object> row = jdbcTemplate.queryForMap(
                """
                SELECT p.id AS product_id, p.name AS product_name,
                       COALESCE(p.price, 0) * COALESCE(NULLIF(cps.quantity, 0), 1) AS product_price,
                       COALESCE((
                           SELECT SUM(amount) FROM contributions
                           WHERE user_id = ? AND product_id = p.id AND status = 'validated'
                       ), 0) AS total_validated
                FROM products p
                LEFT JOIN client_product_selections cps ON cps.product_id = p.id AND cps.user_id = ?
                WHERE p.id = ?
                """,
                clientUserId,
                clientUserId,
                productId
            );
            double price = ((Number) row.get("product_price")).doubleValue();
            double validated = ((Number) row.get("total_validated")).doubleValue();
            return new ProductDeliveryService.ProductProgress(
                productId,
                (String) row.get("product_name"),
                price,
                validated,
                validated >= price && price > 0
            );
        } catch (EmptyResultDataAccessException ex) {
            return null;
        }
    }

    private ContributionSnapshot loadSnapshot(long contributionId) {
        try {
            Map<String, Object> row = jdbcTemplate.queryForMap(
                """
                SELECT id, user_id, product_id, agent_id, amount, payment_mode, reference_code, payment_provider
                FROM contributions WHERE id = ?
                """,
                contributionId
            );
            return new ContributionSnapshot(
                ((Number) row.get("id")).longValue(),
                ((Number) row.get("user_id")).longValue(),
                row.get("product_id") == null ? null : ((Number) row.get("product_id")).longValue(),
                row.get("agent_id") == null ? null : ((Number) row.get("agent_id")).longValue(),
                row.get("amount") instanceof Number n ? n.doubleValue() : 0,
                (String) row.get("payment_mode"),
                (String) row.get("reference_code"),
                (String) row.get("payment_provider")
            );
        } catch (EmptyResultDataAccessException ex) {
            return null;
        }
    }

    private long insertAllocationGroup(ContributionSnapshot snap, double unallocatedSurplus) {
        jdbcTemplate.update(
            """
            INSERT INTO contribution_allocation_groups
              (user_id, source_amount_fcfa, payment_mode, anchor_contribution_id, unallocated_surplus_fcfa)
            VALUES (?, ?, ?, ?, ?)
            """,
            snap.userId(),
            snap.amount(),
            snap.paymentMode(),
            snap.id(),
            unallocatedSurplus
        );
        Long groupId = jdbcTemplate.queryForObject("SELECT LAST_INSERT_ID()", Long.class);
        if (unallocatedSurplus > EPSILON) {
            jdbcTemplate.update(
                """
                INSERT INTO contribution_unallocated_surplus (allocation_group_id, user_id, amount_fcfa)
                VALUES (?, ?, ?)
                """,
                groupId,
                snap.userId(),
                unallocatedSurplus
            );
        }
        return groupId == null ? 0L : groupId;
    }

    private long reuseAnchorForLine(long contributionId, PlannedLine line, long groupId) {
        jdbcTemplate.update(
            """
            UPDATE contributions
            SET product_id = ?, amount = ?, status = 'validated', paid_at = NOW(), allocation_group_id = ?
            WHERE id = ?
            """,
            line.productId(),
            line.amount(),
            groupId,
            contributionId
        );
        return contributionId;
    }

    private long insertAdditionalLine(ContributionSnapshot snap, PlannedLine line, long groupId, int index) {
        String baseRef = snap.referenceCode() == null || snap.referenceCode().isBlank()
            ? "PF-ALLOC-" + snap.id()
            : snap.referenceCode();
        String ref = baseRef + "-A" + index;
        jdbcTemplate.update(
            """
            INSERT INTO contributions (
                user_id, product_id, agent_id, amount, payment_mode, status, reference_code,
                paid_at, payment_provider, allocation_group_id
            )
            VALUES (?, ?, ?, ?, ?, 'validated', ?, NOW(), ?, ?)
            """,
            snap.userId(),
            line.productId(),
            snap.agentId(),
            line.amount(),
            snap.paymentMode(),
            ref,
            snap.paymentProvider(),
            groupId
        );
        Long id = jdbcTemplate.queryForObject("SELECT LAST_INSERT_ID()", Long.class);
        return id == null ? 0L : id;
    }

    private void insertAllocationRow(long groupId, long contributionId, long productId, double amount, boolean goalReached) {
        jdbcTemplate.update(
            """
            INSERT INTO contribution_allocations
              (allocation_group_id, contribution_id, product_id, amount_fcfa, goal_reached_now)
            VALUES (?, ?, ?, ?, ?)
            """,
            groupId,
            contributionId,
            productId,
            amount,
            goalReached
        );
    }
}
