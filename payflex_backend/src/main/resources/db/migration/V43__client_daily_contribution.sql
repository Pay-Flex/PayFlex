-- Cotisation journalière validée par l'agent pour le financement client.
ALTER TABLE users ADD COLUMN daily_contribution DECIMAL(14, 2) NULL;
