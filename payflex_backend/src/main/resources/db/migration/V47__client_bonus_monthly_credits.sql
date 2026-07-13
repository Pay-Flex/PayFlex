-- Épargne bonus créditée en base : 1 jour de cotisation / mois partagé 50 % client / 50 % PayFlex.
-- Idempotent : peut être rejouée après un échec Flyway partiel.

SET @db := DATABASE();

SET @col_exists := (
    SELECT COUNT(*)
    FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = @db
      AND TABLE_NAME = 'users'
      AND COLUMN_NAME = 'bonus_savings_fcfa'
);
SET @sql_col := IF(
    @col_exists = 0,
    'ALTER TABLE users ADD COLUMN bonus_savings_fcfa DECIMAL(14, 2) NOT NULL DEFAULT 0',
    'SELECT 1'
);
PREPARE stmt_col FROM @sql_col;
EXECUTE stmt_col;
DEALLOCATE PREPARE stmt_col;

CREATE TABLE IF NOT EXISTS client_bonus_monthly_credits (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    user_id BIGINT NOT NULL,
    `year_month` CHAR(7) NOT NULL,
    daily_contribution_fcfa DECIMAL(14, 2) NOT NULL,
    client_share_fcfa DECIMAL(14, 2) NOT NULL,
    company_share_fcfa DECIMAL(14, 2) NOT NULL,
    validated_contributions_count INT NOT NULL DEFAULT 0,
    credited_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_bonus_credit_user FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE,
    CONSTRAINT uk_bonus_credit_user_month UNIQUE (user_id, `year_month`)
);

SET @idx_exists := (
    SELECT COUNT(*)
    FROM information_schema.STATISTICS
    WHERE TABLE_SCHEMA = @db
      AND TABLE_NAME = 'client_bonus_monthly_credits'
      AND INDEX_NAME = 'idx_bonus_credit_year_month'
);
SET @sql_idx := IF(
    @idx_exists = 0,
    'CREATE INDEX idx_bonus_credit_year_month ON client_bonus_monthly_credits (`year_month`)',
    'SELECT 1'
);
PREPARE stmt_idx FROM @sql_idx;
EXECUTE stmt_idx;
DEALLOCATE PREPARE stmt_idx;
