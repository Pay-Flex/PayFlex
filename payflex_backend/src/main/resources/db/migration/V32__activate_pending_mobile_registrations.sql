-- Inscriptions mobile déjà reçues avant correctif « profil métier » (artisan_fin, etc.) :
-- activer le dossier et le compte client associé.

UPDATE registration_requests
SET status = 'approved',
    reviewed_at = COALESCE(reviewed_at, NOW()),
    reviewed_by_admin = COALESCE(reviewed_by_admin, 'auto-migrate'),
    admin_note = COALESCE(admin_note, 'Activation automatique (migration V32).')
WHERE status = 'pending'
  AND submitted_by = 'self';

UPDATE users u
INNER JOIN roles r ON r.id = u.role_id AND r.code = 'client'
INNER JOIN registration_requests reg ON reg.status = 'approved'
  AND reg.submitted_by = 'self'
  AND (
    TRIM(u.phone) = TRIM(reg.phone)
    OR REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(TRIM(u.phone), ' ', ''), '-', ''), '(', ''), ')', ''), '+', '')
       = REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(TRIM(reg.phone), ' ', ''), '-', ''), '(', ''), ')', ''), '+', '')
  )
SET u.status = 'valide'
WHERE u.status = 'pending';

-- Comptes clients sans ligne users : créés à partir du dossier approuvé (PIN déjà hashé sur reg).
INSERT INTO users (
  full_name, phone, role_id, city, profession, gender, status, pin, secret_code, unique_code,
  assigned_agent_user_id, profile_photo_path, id_document_path, workplace_name, workplace_address, boss_name, boss_phone
)
SELECT
  reg.full_name,
  reg.phone,
  (SELECT id FROM roles WHERE code = 'client' LIMIT 1),
  reg.city,
  reg.profession,
  reg.gender,
  'valide',
  reg.pin,
  reg.secret_code,
  reg.unique_code,
  reg.assigned_agent_user_id,
  reg.profile_photo_path,
  reg.id_document_path,
  reg.workplace_name,
  reg.workplace_address,
  reg.boss_name,
  reg.boss_phone
FROM registration_requests reg
WHERE reg.status = 'approved'
  AND reg.submitted_by = 'self'
  AND NOT EXISTS (
    SELECT 1 FROM users u
    INNER JOIN roles r ON r.id = u.role_id AND r.code = 'client'
    WHERE TRIM(u.phone) = TRIM(reg.phone)
       OR REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(TRIM(u.phone), ' ', ''), '-', ''), '(', ''), ')', ''), '+', '')
          = REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(TRIM(reg.phone), ' ', ''), '-', ''), '(', ''), ')', ''), '+', '')
  );
