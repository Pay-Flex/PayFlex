-- E-mail client optionnel ; unique lorsqu'il est renseigné (plusieurs NULL autorisés en MySQL).
ALTER TABLE users
    ADD COLUMN email VARCHAR(180) NULL;

CREATE UNIQUE INDEX uk_users_email ON users (email);
