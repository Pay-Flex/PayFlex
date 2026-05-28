INSERT INTO users (full_name, phone, role, city, profession, status)
SELECT 'Jean Dupont', '+22890000001', 'agent', 'Lome', 'Collecte', 'valide'
WHERE NOT EXISTS (SELECT 1 FROM users WHERE phone = '+22890000001');

INSERT INTO users (full_name, phone, role, city, profession, status)
SELECT 'Marie Diallo', '+22890000002', 'agent', 'Kara', 'Collecte', 'valide'
WHERE NOT EXISTS (SELECT 1 FROM users WHERE phone = '+22890000002');

INSERT INTO users (full_name, phone, role, city, profession, status)
SELECT 'Aminata Sarr', '+22890000003', 'client', 'Lome', 'Couture', 'valide'
WHERE NOT EXISTS (SELECT 1 FROM users WHERE phone = '+22890000003');

INSERT INTO users (full_name, phone, role, city, profession, status)
SELECT 'Koffi Mensah', '+22890000004', 'client', 'Sokode', 'Menuiserie', 'pending'
WHERE NOT EXISTS (SELECT 1 FROM users WHERE phone = '+22890000004');

INSERT INTO products (code, name, category, price, availability, description)
SELECT 'PRD-001', 'Machine a coudre pro', 'Couture', 220000, 'in_stock', 'Machine robuste pour atelier couture'
WHERE NOT EXISTS (SELECT 1 FROM products WHERE code = 'PRD-001');

INSERT INTO products (code, name, category, price, availability, description)
SELECT 'PRD-002', 'Kit coiffure premium', 'Coiffure', 180000, 'in_stock', 'Kit professionnel de coiffure'
WHERE NOT EXISTS (SELECT 1 FROM products WHERE code = 'PRD-002');

INSERT INTO agents (user_id, zone, active, collected_total)
SELECT u.id, 'Zone Lomé Centre', TRUE, 2500000
FROM users u
WHERE u.phone = '+22890000001'
  AND NOT EXISTS (SELECT 1 FROM agents a WHERE a.user_id = u.id);

INSERT INTO agents (user_id, zone, active, collected_total)
SELECT u.id, 'Zone Kara Nord', TRUE, 1800000
FROM users u
WHERE u.phone = '+22890000002'
  AND NOT EXISTS (SELECT 1 FROM agents a WHERE a.user_id = u.id);

INSERT INTO contributions (user_id, product_id, agent_id, amount, payment_mode, status, reference_code, paid_at)
SELECT u.id, p.id, a.id, 25000, 'mobile_money', 'validated', 'PF-SEED-001', NOW()
FROM users u
JOIN products p ON p.code = 'PRD-001'
JOIN agents a ON a.user_id = (SELECT id FROM users WHERE phone = '+22890000001' LIMIT 1)
WHERE u.phone = '+22890000003'
  AND NOT EXISTS (SELECT 1 FROM contributions c WHERE c.reference_code = 'PF-SEED-001');
