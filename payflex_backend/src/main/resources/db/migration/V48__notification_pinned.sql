-- Épinglage / suivi des notifications inbox mobile (client et agent).
ALTER TABLE client_notifications
    ADD COLUMN pinned TINYINT(1) NOT NULL DEFAULT 0;

CREATE INDEX idx_client_notif_user_pinned ON client_notifications (user_id, pinned, created_at);
