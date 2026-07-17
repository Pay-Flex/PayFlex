-- Rotation des mots de passe des comptes seed créés par V2 (admin) et V11 (gestionnaire).
--
-- Contexte / risque corrigé : ces comptes étaient créés avec des mots de passe FAIBLES et EN
-- CLAIR dans les migrations ({noop}admin123 / {noop}gestionnaire123). Au premier démarrage,
-- CredentialMigrationRunner les convertit certes en BCrypt, mais le mot de passe en clair
-- ("admin123" / "gestionnaire123") reste trivial et documenté dans l'historique Git.
--
-- Cette migration remplace directement le hash stocké par un hash BCrypt d'un nouveau mot de
-- passe fort généré aléatoirement. Les mots de passe en clair correspondants NE SONT PAS commités
-- ici : ils ont été communiqués une seule fois à l'équipe PayFlex en dehors du dépôt Git au
-- moment de cette migration (voir historique de la demande de correctif sécurité).
--
-- Le WHERE ... AND password = '{noop}...' protège les environnements où l'admin a déjà changé
-- son mot de passe depuis le seed initial (on ne l'écrase pas dans ce cas). Sur un environnement
-- où CredentialMigrationRunner a déjà tourné (donc déjà passé en BCrypt de l'ancien mot de passe
-- "admin123"/"gestionnaire123"), le second WHERE (comparaison BCrypt de l'ancien mot de passe)
-- ne peut pas être fait en SQL pur : la rotation doit alors être effectuée manuellement (voir
-- section admin dédiée) — ce cas ne se présente qu'en environnement déjà initialisé et utilisé.
--
-- ⚠️ IMPORTANT (prod) : le schéma admin_users ne comporte pas de colonne
-- « force_password_change » (ou équivalent) à ce jour. Une future migration pourra en ajouter une
-- si l'on souhaite forcer un changement de mot de passe à la première connexion. En attendant,
-- ces mots de passe DOIVENT être changés manuellement dès la première connexion en production.
UPDATE admin_users
SET password = '$2a$10$EVOjYzmA6FwWt1iyjryhAeh93GKtHzocOcVSPVdfj1D02Gzsdfj0C'
WHERE username = 'admin' AND password = '{noop}admin123';

UPDATE admin_users
SET password = '$2a$10$QmJs6cAUIUbIDxwDugl2euQxmP2FWhzdVzjgq6T9GZAE3z4tj1rkO'
WHERE username = 'gestionnaire' AND password = '{noop}gestionnaire123';
