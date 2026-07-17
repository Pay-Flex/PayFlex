-- Répartition automatique d'une cotisation entre plusieurs produits (excédent > reste à payer).
--
-- Schéma choisi :
--   contribution_allocation_groups : 1 ligne = 1 paiement source qui a dû être réparti
--                                     (ancre = la cotisation initialement déclarée/payée).
--   contribution_allocations       : 1 ligne = 1 tranche affectée à un produit (=1 ligne `contributions`).
--   contributions.allocation_group_id : marque chaque ligne `contributions` issue d'une répartition,
--                                     pour affichage rapide côté historique client / admin sans jointure.
--   contribution_unallocated_surplus : trace le reliquat qui n'a pu être affecté à aucun produit
--                                     (aucun produit actif restant) — jamais perdu, toujours visible,
--                                     à régulariser manuellement par le centre.

CREATE TABLE IF NOT EXISTS contribution_allocation_groups (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    user_id BIGINT NOT NULL,
    source_amount_fcfa DECIMAL(14, 2) NOT NULL,
    payment_mode VARCHAR(40) NULL,
    anchor_contribution_id BIGINT NULL,
    unallocated_surplus_fcfa DECIMAL(14, 2) NOT NULL DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_cag_user FOREIGN KEY (user_id) REFERENCES users(id)
);

CREATE INDEX idx_cag_user ON contribution_allocation_groups (user_id);

CREATE TABLE IF NOT EXISTS contribution_allocations (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    allocation_group_id BIGINT NOT NULL,
    contribution_id BIGINT NOT NULL,
    product_id BIGINT NULL,
    amount_fcfa DECIMAL(14, 2) NOT NULL,
    goal_reached_now BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_ca_group FOREIGN KEY (allocation_group_id) REFERENCES contribution_allocation_groups(id) ON DELETE CASCADE,
    CONSTRAINT fk_ca_contribution FOREIGN KEY (contribution_id) REFERENCES contributions(id),
    CONSTRAINT fk_ca_product FOREIGN KEY (product_id) REFERENCES products(id)
);

CREATE INDEX idx_ca_group ON contribution_allocations (allocation_group_id);
CREATE INDEX idx_ca_contribution ON contribution_allocations (contribution_id);

CREATE TABLE IF NOT EXISTS contribution_unallocated_surplus (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    allocation_group_id BIGINT NOT NULL,
    user_id BIGINT NOT NULL,
    amount_fcfa DECIMAL(14, 2) NOT NULL,
    status VARCHAR(32) NOT NULL DEFAULT 'unassigned',
    resolved_by VARCHAR(150) NULL,
    resolved_note TEXT NULL,
    resolved_at TIMESTAMP NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_cus_group FOREIGN KEY (allocation_group_id) REFERENCES contribution_allocation_groups(id),
    CONSTRAINT fk_cus_user FOREIGN KEY (user_id) REFERENCES users(id)
);

CREATE INDEX idx_cus_status ON contribution_unallocated_surplus (status);
CREATE INDEX idx_cus_user ON contribution_unallocated_surplus (user_id);

ALTER TABLE contributions ADD COLUMN allocation_group_id BIGINT NULL;
CREATE INDEX idx_contrib_allocation_group ON contributions (allocation_group_id);
