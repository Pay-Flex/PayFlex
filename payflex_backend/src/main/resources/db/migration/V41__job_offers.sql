CREATE TABLE job_offers (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    title VARCHAR(200) NOT NULL,
    summary VARCHAR(500) NULL,
    description TEXT NOT NULL,
    location VARCHAR(120) NULL,
    profile_requirements VARCHAR(500) NULL,
    starts_at DATE NULL,
    ends_at DATE NULL,
    active BOOLEAN NOT NULL DEFAULT TRUE,
    sort_order INT NOT NULL DEFAULT 100,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NULL,
    updated_by VARCHAR(80) NULL
);

CREATE TABLE job_offer_attachments (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    offer_id BIGINT NOT NULL,
    file_url VARCHAR(512) NOT NULL,
    file_name VARCHAR(255) NOT NULL,
    mime_type VARCHAR(120) NULL,
    sort_order INT NOT NULL DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_job_offer_attachment_offer FOREIGN KEY (offer_id) REFERENCES job_offers (id) ON DELETE CASCADE
);

CREATE INDEX idx_job_offers_active_sort ON job_offers (active, sort_order, id DESC);

INSERT INTO job_offers (title, summary, description, location, profile_requirements, starts_at, ends_at, active, sort_order, updated_by)
VALUES (
    'Agent de collecte — Lomé',
    'Rejoignez l’équipe terrain PayFlex pour accompagner les clients au quotidien.',
    'Mission : collecter les cotisations, accompagner les nouveaux adhérents et assurer le lien avec le centre PayFlex.\n\nAvantages : formation, outils mobile, évolution possible vers gestionnaire de zone.',
    'Lomé',
    'Expérience terrain, smartphone, bon relationnel',
    '2026-06-01',
    '2026-12-31',
    TRUE,
    10,
    'system'
);
