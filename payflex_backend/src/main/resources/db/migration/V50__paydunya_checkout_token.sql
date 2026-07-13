-- PayDunya (2e passerelle mobile money) : on réutilise la table `contributions`
-- (colonne `payment_provider` déjà présente depuis V27) et on ajoute uniquement
-- le jeton de facture PayDunya, en miroir de `fedapay_transaction_id`.
ALTER TABLE contributions
    ADD COLUMN IF NOT EXISTS paydunya_token VARCHAR(120) NULL;

CREATE INDEX IF NOT EXISTS idx_contributions_paydunya_token ON contributions (paydunya_token);
