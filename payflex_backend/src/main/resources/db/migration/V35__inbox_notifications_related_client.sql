-- Contexte client pour les notifications agent (push pull PayFlex).
ALTER TABLE client_notifications
    ADD COLUMN IF NOT EXISTS related_client_user_id BIGINT NULL;

CREATE INDEX IF NOT EXISTS idx_client_notif_user_id ON client_notifications (user_id, id);
