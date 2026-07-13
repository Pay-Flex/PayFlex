ALTER TABLE agents
    ADD COLUMN cash_debt_fcfa DECIMAL(14, 2) NOT NULL DEFAULT 0 AFTER weekly_schedule_json;

CREATE TABLE IF NOT EXISTS agent_cash_debt_events (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    agent_user_id BIGINT NOT NULL,
    amount_fcfa DECIMAL(14, 2) NOT NULL,
    collected_fcfa DECIMAL(14, 2) NULL,
    expected_fcfa DECIMAL(14, 2) NULL,
    note VARCHAR(500) NULL,
    created_by VARCHAR(120) NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_agent_cash_debt_user FOREIGN KEY (agent_user_id) REFERENCES users(id)
);

CREATE INDEX idx_agent_cash_debt_events_user ON agent_cash_debt_events (agent_user_id, created_at DESC);
