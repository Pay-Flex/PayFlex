-- Archive chiffrée des identifiants saisis à l'inscription (avant hash BCrypt en base).
ALTER TABLE registration_requests
    ADD COLUMN pin_vault_cipher VARCHAR(512) NULL AFTER account_password,
    ADD COLUMN account_password_vault_cipher VARCHAR(512) NULL AFTER pin_vault_cipher;
