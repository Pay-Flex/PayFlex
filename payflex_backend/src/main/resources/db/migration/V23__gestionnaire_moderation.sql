ALTER TABLE activity_journal
    ADD COLUMN IF NOT EXISTS action_kind VARCHAR(40) NULL,
    ADD COLUMN IF NOT EXISTS entity_type VARCHAR(40) NULL,
    ADD COLUMN IF NOT EXISTS entity_id BIGINT NULL,
    ADD COLUMN IF NOT EXISTS reason TEXT NULL,
    ADD COLUMN IF NOT EXISTS actor_username VARCHAR(80) NULL;

CREATE INDEX IF NOT EXISTS idx_activity_journal_gestionnaire
    ON activity_journal (profile, actor_username, created_at DESC);

CREATE TABLE IF NOT EXISTS admin_deletion_requests (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    entity_type VARCHAR(40) NOT NULL,
    entity_id BIGINT NOT NULL,
    entity_label VARCHAR(255) NOT NULL,
    reason TEXT NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'pending',
    requested_by VARCHAR(80) NOT NULL,
    requested_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    reviewed_by VARCHAR(80) NULL,
    reviewed_at TIMESTAMP NULL,
    review_note TEXT NULL,
    INDEX idx_del_req_status (status, requested_at DESC),
    INDEX idx_del_req_entity (entity_type, entity_id)
);
