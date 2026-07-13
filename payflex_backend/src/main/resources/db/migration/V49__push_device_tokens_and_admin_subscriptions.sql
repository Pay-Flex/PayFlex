-- Push réel PayFlex :
--  1) user_device_tokens      : jetons FCM des apps mobiles (client + agent)
--  2) admin_push_subscriptions : abonnements Web Push (VAPID) des postes admin/support
-- Le modèle « pull » historique (client_notifications + /api/mobile/push/poll)
-- reste en place comme repli si Firebase / VAPID ne sont pas configurés.

CREATE TABLE IF NOT EXISTS user_device_tokens (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    user_id BIGINT NOT NULL,
    role VARCHAR(20) NULL,
    token VARCHAR(512) NOT NULL,
    platform VARCHAR(20) NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT uq_device_token UNIQUE (token),
    INDEX idx_device_user (user_id),
    CONSTRAINT fk_device_token_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS admin_push_subscriptions (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    admin_username VARCHAR(100) NOT NULL,
    endpoint VARCHAR(500) NOT NULL,
    p256dh VARCHAR(255) NOT NULL,
    auth VARCHAR(255) NOT NULL,
    user_agent VARCHAR(255) NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT uq_admin_push_endpoint UNIQUE (endpoint),
    INDEX idx_admin_push_user (admin_username)
);
