-- Compte « gestionnaire » : même tableau de bord que l’admin, avec des actions sensibles réservées au compte administrateur principal (voir SecurityConfig / @PreAuthorize).
INSERT INTO admin_users (username, password, enabled, full_name, email)
SELECT 'gestionnaire', '{noop}gestionnaire123', TRUE, 'Gestionnaire PayFlex', 'gestionnaire@payflex.local'
WHERE NOT EXISTS (
    SELECT 1 FROM admin_users WHERE username = 'gestionnaire'
);

INSERT INTO admin_authorities (username, authority)
SELECT 'gestionnaire', 'ROLE_GESTIONNAIRE'
WHERE NOT EXISTS (
    SELECT 1 FROM admin_authorities WHERE username = 'gestionnaire' AND authority = 'ROLE_GESTIONNAIRE'
);
