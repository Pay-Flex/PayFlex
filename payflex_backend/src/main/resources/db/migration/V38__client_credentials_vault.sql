ALTER TABLE users
    ADD COLUMN pin_vault_cipher VARCHAR(512) NULL AFTER account_password,
    ADD COLUMN account_password_vault_cipher VARCHAR(512) NULL AFTER pin_vault_cipher;

CREATE TABLE client_credential_recovery_requests (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    user_id BIGINT NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'open',
    source VARCHAR(32) NOT NULL DEFAULT 'mobile',
    note TEXT NULL,
    requested_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    resolved_at TIMESTAMP NULL,
    resolved_by VARCHAR(64) NULL,
    CONSTRAINT fk_ccrr_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    INDEX idx_ccrr_status (status),
    INDEX idx_ccrr_user (user_id)
);
