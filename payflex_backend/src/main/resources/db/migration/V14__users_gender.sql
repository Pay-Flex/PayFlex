-- Profil mobile : genre issu des demandes d'inscription
ALTER TABLE users
    ADD COLUMN gender VARCHAR(24) NULL;
