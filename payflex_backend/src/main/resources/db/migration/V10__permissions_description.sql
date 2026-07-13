-- Libellés lisibles pour l’admin : ce que chaque permission autorise concrètement
ALTER TABLE permissions ADD COLUMN description VARCHAR(512) NULL;

UPDATE permissions SET description = 'Permet de consulter le catalogue : liste des produits, prix et détails affichés dans l’application.'
WHERE code = 'MOBILE_CATALOG_VIEW';

UPDATE permissions SET description = 'Permet d’enregistrer un versement ou une cotisation pour un produit (paiement déclaré depuis le téléphone).'
WHERE code = 'MOBILE_CONTRIBUTION_CREATE';

UPDATE permissions SET description = 'Permet à un agent d’enregistrer une inscription au nom d’une autre personne (formulaire terrain).'
WHERE code = 'MOBILE_REGISTRATION_AGENT';
