ALTER TABLE contributions ADD COLUMN catchup_year INT NULL;
ALTER TABLE contributions ADD COLUMN catchup_month INT NULL;
ALTER TABLE contributions ADD COLUMN catchup_day INT NULL;

CREATE INDEX IF NOT EXISTS idx_contributions_catchup ON contributions (user_id, catchup_year, catchup_month, catchup_day);
