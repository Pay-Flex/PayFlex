-- Rôles métier (application mobile / utilisateurs `users`)
CREATE TABLE IF NOT EXISTS roles (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    code VARCHAR(40) NOT NULL UNIQUE,
    label VARCHAR(120) NOT NULL,
    description VARCHAR(255) NULL,
    sort_order INT NOT NULL DEFAULT 0
);

CREATE TABLE IF NOT EXISTS permissions (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    code VARCHAR(80) NOT NULL UNIQUE,
    label VARCHAR(160) NOT NULL,
    category VARCHAR(80) NOT NULL DEFAULT 'mobile'
);

CREATE TABLE IF NOT EXISTS role_permissions (
    role_id BIGINT NOT NULL,
    permission_id BIGINT NOT NULL,
    PRIMARY KEY (role_id, permission_id),
    CONSTRAINT fk_role_permissions_role FOREIGN KEY (role_id) REFERENCES roles(id) ON DELETE CASCADE,
    CONSTRAINT fk_role_permissions_perm FOREIGN KEY (permission_id) REFERENCES permissions(id) ON DELETE CASCADE
);

INSERT INTO roles (code, label, description, sort_order)
SELECT 'client', 'Client', 'Utilisateur final (app mobile, inscription validée)', 10
WHERE NOT EXISTS (SELECT 1 FROM roles WHERE code = 'client');

INSERT INTO roles (code, label, description, sort_order)
SELECT 'agent', 'Agent terrain', 'Collecte et inscription de clients', 20
WHERE NOT EXISTS (SELECT 1 FROM roles WHERE code = 'agent');

INSERT INTO permissions (code, label, category)
SELECT 'MOBILE_CATALOG_VIEW', 'Voir le catalogue produits', 'mobile'
WHERE NOT EXISTS (SELECT 1 FROM permissions WHERE code = 'MOBILE_CATALOG_VIEW');

INSERT INTO permissions (code, label, category)
SELECT 'MOBILE_CONTRIBUTION_CREATE', 'Créer une cotisation depuis l''app', 'mobile'
WHERE NOT EXISTS (SELECT 1 FROM permissions WHERE code = 'MOBILE_CONTRIBUTION_CREATE');

INSERT INTO permissions (code, label, category)
SELECT 'MOBILE_REGISTRATION_AGENT', 'Enregistrer une inscription pour un tiers (agent)', 'mobile'
WHERE NOT EXISTS (SELECT 1 FROM permissions WHERE code = 'MOBILE_REGISTRATION_AGENT');

-- Liaisons par défaut : client = catalogue + cotisation ; agent = tout pour le terrain
INSERT IGNORE INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id FROM roles r CROSS JOIN permissions p WHERE r.code = 'client'
  AND p.code IN ('MOBILE_CATALOG_VIEW', 'MOBILE_CONTRIBUTION_CREATE');

INSERT IGNORE INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id FROM roles r CROSS JOIN permissions p WHERE r.code = 'agent'
  AND p.code IN ('MOBILE_CATALOG_VIEW', 'MOBILE_CONTRIBUTION_CREATE', 'MOBILE_REGISTRATION_AGENT');

-- Migrer users.role (varchar) -> users.role_id (FK)
ALTER TABLE users ADD COLUMN role_id BIGINT NULL;

UPDATE users u
INNER JOIN roles r ON r.code = u.role
SET u.role_id = r.id;

UPDATE users u
SET u.role_id = (SELECT id FROM roles WHERE code = 'client' LIMIT 1)
WHERE u.role_id IS NULL;

ALTER TABLE users MODIFY COLUMN role_id BIGINT NOT NULL;

ALTER TABLE users DROP COLUMN role;

ALTER TABLE users
    ADD CONSTRAINT fk_users_role FOREIGN KEY (role_id) REFERENCES roles(id);

CREATE INDEX idx_users_role_id ON users(role_id);

-- Comptes de démo pour tester les droits (PIN 9999)
INSERT INTO users (full_name, phone, role_id, city, profession, status, pin, secret_code, unique_code)
SELECT 'Demo Client Droits', '+22890909001', r.id, 'Lomé', 'Démo', 'valide', '9999', 'SEC-DEMO-CL-001', 'UNIQ-DEMO-CL-001'
FROM roles r WHERE r.code = 'client'
AND NOT EXISTS (SELECT 1 FROM users WHERE phone = '+22890909001');

INSERT INTO users (full_name, phone, role_id, city, profession, status, pin, secret_code, unique_code)
SELECT 'Demo Agent Droits', '+22890909002', r.id, 'Kara', 'Démo agent', 'valide', '9999', 'SEC-DEMO-AG-001', 'UNIQ-DEMO-AG-001'
FROM roles r WHERE r.code = 'agent'
AND NOT EXISTS (SELECT 1 FROM users WHERE phone = '+22890909002');

INSERT INTO agents (user_id, zone, active, collected_total)
SELECT u.id, 'Zone Démo', TRUE, 0
FROM users u
WHERE u.phone = '+22890909002'
  AND NOT EXISTS (SELECT 1 FROM agents a WHERE a.user_id = u.id);
