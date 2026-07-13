-- Anti-spam alertes rattrapage (une fois par mois calendaire) + objectif produit déjà notifié.
ALTER TABLE users
    ADD COLUMN IF NOT EXISTS catchup_alert_sent_month VARCHAR(7) NULL,
    ADD COLUMN IF NOT EXISTS goal_notified_for_product_id BIGINT NULL;
