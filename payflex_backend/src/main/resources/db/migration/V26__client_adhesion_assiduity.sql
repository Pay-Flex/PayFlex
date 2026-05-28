-- Adhésion payante (250 FCFA espèces) + litiges + badge assiduité + autonomie client
ALTER TABLE users
    ADD COLUMN adhesion_fee_paid BOOLEAN NOT NULL DEFAULT FALSE,
    ADD COLUMN adhesion_paid_at TIMESTAMP NULL,
    ADD COLUMN adhesion_collected_by_user_id BIGINT NULL,
    ADD COLUMN adhesion_dispute_open BOOLEAN NOT NULL DEFAULT FALSE,
    ADD COLUMN adhesion_dispute_at TIMESTAMP NULL,
    ADD COLUMN adhesion_dispute_note VARCHAR(600) NULL,
    ADD COLUMN adhesion_dispute_resolved_at TIMESTAMP NULL,
    ADD COLUMN assiduity_badge VARCHAR(24) NOT NULL DEFAULT 'standard',
    ADD COLUMN self_managed BOOLEAN NOT NULL DEFAULT FALSE;

-- Clients déjà « valide » avant migration : adhésion à confirmer (statut inchangé)
UPDATE users u
INNER JOIN roles r ON r.id = u.role_id AND r.code = 'client'
SET u.adhesion_fee_paid = FALSE
WHERE u.status IN ('valide', 'adhere');

-- Anciens clients considérés adhérents si déjà actifs (évite de bloquer l'existant)
UPDATE users u
INNER JOIN roles r ON r.id = u.role_id AND r.code = 'client'
SET u.adhesion_fee_paid = TRUE, u.status = 'adhere', u.adhesion_paid_at = COALESCE(u.created_at, NOW())
WHERE u.status = 'valide'
  AND EXISTS (SELECT 1 FROM contributions c WHERE c.user_id = u.id AND c.status = 'validated' LIMIT 1);

CREATE INDEX IF NOT EXISTS idx_users_adhesion_dispute ON users (adhesion_dispute_open, adhesion_dispute_at);
CREATE INDEX IF NOT EXISTS idx_users_assiduity ON users (assiduity_badge);
