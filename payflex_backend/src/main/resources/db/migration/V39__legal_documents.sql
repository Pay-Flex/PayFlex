CREATE TABLE legal_documents (
    code VARCHAR(32) NOT NULL PRIMARY KEY,
    title VARCHAR(200) NOT NULL,
    content TEXT NOT NULL,
    updated_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    updated_by VARCHAR(64) NULL
);

INSERT INTO legal_documents (code, title, content, updated_by) VALUES
(
    'cgu',
    'Conditions générales d''utilisation PayFlex',
    '1. Objet\nPayFlex permet aux clients de cotiser progressivement pour l''acquisition d''équipements professionnels.\n\n2. Inscription\nL''inscription est soumise à validation par PayFlex. Les informations fournies doivent être exactes.\n\n3. Cotisations\nLes versements sont enregistrés dans le carnet numérique. La validation des paiements mobile money ou espèces suit les règles affichées dans l''application.\n\n4. Adhésion\nUne cotisation d''adhésion peut être exigée avant l''accès complet aux services.\n\n5. Responsabilité\nPayFlex met en œuvre les moyens raisonnables pour assurer la disponibilité du service, sans garantie d''absence d''interruption.\n\n6. Contact\nPour toute question : support PayFlex via l''application.',
    'system'
),
(
    'privacy',
    'Règles de confidentialité PayFlex',
    '1. Données collectées\nIdentité, coordonnées, pièces justificatives, historique de cotisations et échanges support.\n\n2. Finalités\nGestion du compte, validation des paiements, suivi des projets et assistance client.\n\n3. Conservation\nLes données sont conservées pendant la durée du contrat et selon les obligations légales applicables.\n\n4. Partage\nPayFlex ne vend pas vos données. Seuls les agents assignés et le personnel autorisé y accèdent dans le cadre du service.\n\n5. Sécurité\nMots de passe et codes PIN sont stockés de manière sécurisée (hachage / chiffrement côté serveur).\n\n6. Vos droits\nVous pouvez demander la rectification ou la suppression de votre compte via le support PayFlex.',
    'system'
);
