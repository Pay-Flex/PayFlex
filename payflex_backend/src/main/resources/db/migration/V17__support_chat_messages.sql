CREATE TABLE IF NOT EXISTS support_chat_messages (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    user_id BIGINT NOT NULL,
    sender ENUM ('client', 'admin') NOT NULL,
    body VARCHAR(4000) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_support_chat_user FOREIGN KEY (user_id) REFERENCES users (id)
);

CREATE INDEX idx_support_chat_user_created ON support_chat_messages (user_id, created_at);
