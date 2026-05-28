-- Mot de passe compte distinct du code PIN (connexion avec l'un ou l'autre).
ALTER TABLE users ADD COLUMN account_password VARCHAR(255) NULL AFTER secret_code;

ALTER TABLE registration_requests ADD COLUMN account_password VARCHAR(255) NULL AFTER secret_code;
