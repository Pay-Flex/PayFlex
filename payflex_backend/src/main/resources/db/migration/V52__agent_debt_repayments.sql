CREATE TABLE IF NOT EXISTS agent_debt_repayments (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    agent_user_id BIGINT NOT NULL,
    amount_fcfa DECIMAL(14, 2) NOT NULL,
    note VARCHAR(500) NULL,
    created_by VARCHAR(120) NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_agent_debt_repayment_user FOREIGN KEY (agent_user_id) REFERENCES users(id)
);

CREATE INDEX idx_agent_debt_repayments_user ON agent_debt_repayments (agent_user_id, created_at DESC);

-- Les alertes centre peuvent désormais exister sans cotisation liée (ex. dette de caisse agent).
ALTER TABLE contribution_validation_alerts MODIFY contribution_id BIGINT NULL;
