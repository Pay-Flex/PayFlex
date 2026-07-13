-- Adhésion payée par mobile money via PayDunya : on stocke le jeton de facture
-- PayDunya (Checkout Invoice) directement sur l'utilisateur.
ALTER TABLE users
    ADD COLUMN IF NOT EXISTS adhesion_paydunya_token VARCHAR(120) NULL;

CREATE INDEX IF NOT EXISTS idx_users_adhesion_paydunya_token ON users (adhesion_paydunya_token);
