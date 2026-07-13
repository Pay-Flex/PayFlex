-- Jetons usage unique pour la réinitialisation PIN / code secret (app mobile).
CREATE TABLE IF NOT EXISTS mobile_password_reset_tokens (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    user_id BIGINT NOT NULL,
    token VARCHAR(96) NOT NULL,
    expires_at TIMESTAMP NOT NULL,
    used_at TIMESTAMP NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_mprt_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    CONSTRAINT uk_mprt_token UNIQUE (token)
);

CREATE INDEX idx_mprt_user_created ON mobile_password_reset_tokens(user_id, created_at);
