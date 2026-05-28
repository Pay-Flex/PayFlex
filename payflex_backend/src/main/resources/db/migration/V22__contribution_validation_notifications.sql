ALTER TABLE contributions
    ADD COLUMN IF NOT EXISTS rejection_reason VARCHAR(500) NULL,
    ADD COLUMN IF NOT EXISTS validated_by_user_id BIGINT NULL;

CREATE TABLE IF NOT EXISTS client_notifications (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    user_id BIGINT NOT NULL,
    type VARCHAR(40) NOT NULL,
    title VARCHAR(200) NOT NULL,
    body TEXT NOT NULL,
    contribution_id BIGINT NULL,
    read_at TIMESTAMP NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_notif_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    INDEX idx_notif_user_unread (user_id, read_at, created_at DESC)
);

INSERT INTO permissions (code, label, category)
SELECT 'MOBILE_CONTRIBUTION_VALIDATE', 'Valider ou refuser une cotisation client (app agent)', 'mobile'
WHERE NOT EXISTS (SELECT 1 FROM permissions WHERE code = 'MOBILE_CONTRIBUTION_VALIDATE');

INSERT IGNORE INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id FROM roles r
JOIN permissions p ON p.code = 'MOBILE_CONTRIBUTION_VALIDATE'
WHERE r.code = 'agent';
