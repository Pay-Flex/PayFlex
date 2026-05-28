ALTER TABLE support_chat_messages
    ADD COLUMN IF NOT EXISTS read_at TIMESTAMP NULL,
    ADD COLUMN IF NOT EXISTS broadcast_batch_id VARCHAR(64) NULL;

CREATE INDEX IF NOT EXISTS idx_support_chat_unread
    ON support_chat_messages (user_id, sender, read_at);

CREATE TABLE IF NOT EXISTS admin_message_broadcasts (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    target_type VARCHAR(20) NOT NULL,
    zone_id BIGINT NULL,
    title VARCHAR(200) NULL,
    body TEXT NOT NULL,
    recipient_count INT NOT NULL DEFAULT 0,
    sent_by VARCHAR(80) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_broadcast_created (created_at DESC)
);

ALTER TABLE users
    ADD COLUMN IF NOT EXISTS fcm_token VARCHAR(512) NULL;
