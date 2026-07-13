-- Colonnes élargies pour les hash BCrypt (PIN mobile unique = ancien secret_code)
ALTER TABLE users MODIFY COLUMN pin VARCHAR(255) NULL;
ALTER TABLE users MODIFY COLUMN secret_code VARCHAR(255) NULL;

ALTER TABLE registration_requests MODIFY COLUMN pin VARCHAR(255) NOT NULL;
ALTER TABLE registration_requests MODIFY COLUMN secret_code VARCHAR(255) NULL;
