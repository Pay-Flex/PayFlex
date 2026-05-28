ALTER TABLE contributions
    ADD COLUMN IF NOT EXISTS fedapay_transaction_id VARCHAR(80) NULL,
    ADD COLUMN IF NOT EXISTS payment_provider VARCHAR(40) NULL,
    ADD COLUMN IF NOT EXISTS auto_validated_at TIMESTAMP NULL,
    ADD COLUMN IF NOT EXISTS auto_validated_reason VARCHAR(200) NULL;

CREATE INDEX IF NOT EXISTS idx_contributions_fedapay_tx ON contributions (fedapay_transaction_id);
CREATE INDEX IF NOT EXISTS idx_contributions_pending_created ON contributions (status, payment_mode, created_at);

CREATE TABLE IF NOT EXISTS contribution_validation_alerts (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    contribution_id BIGINT NOT NULL,
    alert_type VARCHAR(48) NOT NULL,
    message VARCHAR(500) NOT NULL,
    read_at TIMESTAMP NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_cva_contribution FOREIGN KEY (contribution_id) REFERENCES contributions(id) ON DELETE CASCADE
);
