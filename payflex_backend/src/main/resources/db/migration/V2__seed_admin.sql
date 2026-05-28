INSERT INTO admin_users (username, password, enabled, full_name, email)
SELECT 'admin', '{noop}admin123', TRUE, 'Administrateur PayFlex', 'admin@payflex.local'
WHERE NOT EXISTS (
    SELECT 1 FROM admin_users WHERE username = 'admin'
);

INSERT INTO admin_authorities (username, authority)
SELECT 'admin', 'ROLE_ADMIN'
WHERE NOT EXISTS (
    SELECT 1 FROM admin_authorities WHERE username = 'admin' AND authority = 'ROLE_ADMIN'
);
