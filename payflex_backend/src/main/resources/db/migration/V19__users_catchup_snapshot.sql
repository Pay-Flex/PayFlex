-- Snapshot synchronisé depuis l’app mobile pour alertes admin (jours de rattrapage / mois).
ALTER TABLE users ADD COLUMN catchup_pending_cached INT NOT NULL DEFAULT 0;
ALTER TABLE users ADD COLUMN catchup_snapshot_month VARCHAR(7) NULL;
