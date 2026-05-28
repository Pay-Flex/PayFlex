-- Cotisation journalière minimale configurable (app mobile : simulateur et garde-fous).
ALTER TABLE products
    ADD COLUMN min_daily_contribution DECIMAL(14, 2) NOT NULL DEFAULT 200;

UPDATE products
SET min_daily_contribution = GREATEST(200.0, ROUND(price / 300))
WHERE TRUE;
