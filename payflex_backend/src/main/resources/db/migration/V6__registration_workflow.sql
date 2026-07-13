ALTER TABLE users
ADD COLUMN IF NOT EXISTS secret_code VARCHAR(64) NULL,
ADD COLUMN IF NOT EXISTS assigned_agent_user_id BIGINT NULL,
ADD COLUMN IF NOT EXISTS profile_photo_path VARCHAR(255) NULL,
ADD COLUMN IF NOT EXISTS id_document_path VARCHAR(255) NULL,
ADD COLUMN IF NOT EXISTS workplace_name VARCHAR(180) NULL,
ADD COLUMN IF NOT EXISTS workplace_address VARCHAR(255) NULL,
ADD COLUMN IF NOT EXISTS boss_name VARCHAR(180) NULL,
ADD COLUMN IF NOT EXISTS boss_phone VARCHAR(40) NULL,
ADD COLUMN IF NOT EXISTS unique_code VARCHAR(64) NULL;

CREATE TABLE IF NOT EXISTS registration_requests (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    full_name VARCHAR(150) NOT NULL,
    phone VARCHAR(40) NOT NULL,
    city VARCHAR(120),
    profession VARCHAR(120),
    gender VARCHAR(20),
    submitted_by VARCHAR(20) NOT NULL DEFAULT 'self', -- self|agent
    requested_role VARCHAR(20) NOT NULL DEFAULT 'client',
    submitted_by_agent_user_id BIGINT NULL,
    assigned_agent_user_id BIGINT NULL,
    pin VARCHAR(20) NOT NULL,
    secret_code VARCHAR(64) NOT NULL,
    unique_code VARCHAR(64) NOT NULL,
    workplace_name VARCHAR(180),
    workplace_address VARCHAR(255),
    boss_name VARCHAR(180),
    boss_phone VARCHAR(40),
    profile_photo_path VARCHAR(255),
    id_document_path VARCHAR(255),
    status VARCHAR(20) NOT NULL DEFAULT 'pending', -- pending|approved|rejected
    admin_note TEXT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    reviewed_at TIMESTAMP NULL,
    reviewed_by_admin VARCHAR(100) NULL,
    CONSTRAINT fk_regreq_submit_agent FOREIGN KEY (submitted_by_agent_user_id) REFERENCES users(id),
    CONSTRAINT fk_regreq_assign_agent FOREIGN KEY (assigned_agent_user_id) REFERENCES users(id)
);

CREATE INDEX idx_regreq_status_created ON registration_requests(status, created_at);
CREATE INDEX idx_regreq_phone ON registration_requests(phone);
