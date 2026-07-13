-- Profils métier mobile (apprenti, artisan_fin, artisan_actif, etc.)
ALTER TABLE registration_requests MODIFY COLUMN requested_role VARCHAR(64) NOT NULL DEFAULT 'client';
