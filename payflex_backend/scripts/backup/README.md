# Sauvegarde & restauration de la base de données PayFlex

> **Contexte critique** : PayFlex gère l'épargne réelle de clients togolais
> (cotisations journalières, épargne bonus, dettes agents, historique de
> paiements). Une perte de la base sans sauvegarde exploitable serait
> **irréversible** et catastrophique pour les utilisateurs. Ce dossier
> fournit une stratégie complète de backup/restore, à activer **avant** toute
> mise en production.

## 0. SGBD et configuration réelle du projet

⚠️ **Correction importante par rapport à l'hypothèse initiale** : ce projet
utilise **MySQL 8+** (et non PostgreSQL). Confirmé dans :

- `payflex_backend/src/main/resources/application.yml` : `driver-class-name: com.mysql.cj.jdbc.Driver`, URL `jdbc:mysql://...`
- `payflex_backend/.env.example` : `PAYFLEX_DB_URL=jdbc:mysql://localhost:3306/payflexdb?...`
- `README.md` racine : « Base de données | MySQL 8+ »

Les outils utilisés ici sont donc **`mysqldump` / `mysql`** (pas `pg_dump` /
`pg_restore`). Toute la stratégie ci-dessous (rétention, planification,
stockage hors-site, tests de restauration) reste identique dans l'esprit ;
seuls les outils bas niveau changent.

Le backend configure la connexion via une URL JDBC unique
(`PAYFLEX_DB_URL`, `PAYFLEX_DB_USER`, `PAYFLEX_DB_PASSWORD` dans
`payflex_backend/.env`). Les outils `mysqldump`/`mysql` attendent ces
informations sous forme séparée (host/port/nom de base), donc les scripts de
ce dossier utilisent leur propre fichier `.env` (voir `.env.example`) avec des
variables `PAYFLEX_DB_HOST` / `PAYFLEX_DB_PORT` / `PAYFLEX_DB_NAME` en plus,
mais **réutilisent les mêmes noms** `PAYFLEX_DB_USER` / `PAYFLEX_DB_PASSWORD`
pour rester cohérents avec le reste du projet.

## 1. Fichiers de ce dossier

| Fichier | Rôle |
|---------|------|
| `backup-db.sh` | Sauvegarde (Linux/prod) — `mysqldump` + compression gzip + rétention GFS + upload hors-site optionnel |
| `backup-db.ps1` | Équivalent Windows (test en dev local) — compression `.zip` |
| `restore-db.sh` | Restauration (Linux) d'un dump dans une base cible, avec confirmation explicite |
| `restore-db.ps1` | Équivalent Windows |
| `verify-backup.sh` | Test de restauration automatisé dans une base temporaire jetable + sanity check |
| `.env.example` | Modèle de configuration (à copier en `.env`, jamais committer de vraies valeurs) |
| `README.md` | Ce document |

## 2. Prérequis

- **Linux (prod)** : `mysql-client` (fournit `mysqldump` et `mysql`), `gzip`. Optionnel : [`rclone`](https://rclone.org/) pour l'upload hors-site.
- **Windows (dev/test)** : client MySQL dans le `PATH` (`mysqldump.exe`/`mysql.exe`, fourni par MySQL Server, MySQL Workbench ou XAMPP). PowerShell 5+ (natif sur Windows 10/11).

Rendre les scripts shell exécutables **avant leur premier lancement** (obligatoire sous Linux, sans effet sous Windows) :

```bash
chmod +x backup-db.sh restore-db.sh verify-backup.sh
```

## 3. Configuration

```bash
cd payflex_backend/scripts/backup
cp .env.example .env
# Éditer .env : au minimum PAYFLEX_DB_PASSWORD, PAYFLEX_BACKUP_DIR,
# et éventuellement PAYFLEX_BACKUP_RCLONE_REMOTE pour l'offsite.
```

Le fichier `.env` de ce dossier est **indépendant** de `payflex_backend/.env**`
(qui reste la seule source de vérité pour le backend Spring Boot). Gardez les
deux synchronisés côté identifiants (même utilisateur/mot de passe MySQL),
mais ce dossier n'a pas besoin de connaître les clés PayDunya, Firebase, etc.

**Ne committez jamais** le fichier `.env` réel (déjà couvert par les règles
`.gitignore` habituelles du projet — vérifiez que `scripts/backup/.env` est
bien ignoré, sinon ajoutez-le à `.gitignore`).

## 4. Lancer une sauvegarde manuellement

**Linux / prod :**

```bash
cd payflex_backend/scripts/backup
./backup-db.sh
```

**Windows / dev local (test) :**

```powershell
cd payflex_backend\scripts\backup
.\backup-db.ps1
```

Chaque exécution :

1. Dump complet de la base (`mysqldump --single-transaction` pour un instantané cohérent sans verrouiller les tables InnoDB en écriture, `--routines --triggers --events` pour ne rien oublier).
2. Compression (`gzip` sous Linux, `.zip` sous Windows).
3. Nommage horodaté : `payflex_<nom_base>_<AAAAMMJJ>_<HHMMSS>.sql.gz`.
4. Upload hors-site optionnel via `rclone` (si configuré).
5. Nettoyage des sauvegardes expirées selon la politique de rétention GFS (section suivante).

## 5. Stratégie de rétention retenue : GFS (grandfather-father-son)

**Pourquoi GFS et pas un simple « garder les N derniers » ?** Un client qui
détecte une anomalie de données (ex: cotisation dupliquée, solde erroné, dette
agent incohérente) 3 semaines après les faits ne peut pas être aidé si seules
les 7 dernières sauvegardes existent. GFS donne une **profondeur temporelle
croissante** tout en gardant un espace disque raisonnable :

| Palier | Rétention par défaut | Fréquence effective | Objectif |
|--------|----------------------|----------------------|----------|
| Quotidien (son) | 7 jours | 1 sauvegarde/jour | Récupération rapide d'un incident récent (erreur de manip, bug de la veille) |
| Hebdomadaire (father) | 4 semaines | 1 sauvegarde/dimanche | Récupération sur un mois glissant sans garder 30 fichiers |
| Mensuel (grandfather) | 3 mois | 1 sauvegarde le 1er du mois | Audit/litige sur un trimestre, conformité |

Espace disque approximatif conservé en permanence : **7 + 4 + 3 = 14
sauvegardes** maximum (au lieu de ~90 avec une rétention quotidienne pure sur
3 mois), pour une couverture qui remonte à 3 mois.

Ces valeurs sont **configurables** via `.env` (`PAYFLEX_BACKUP_RETENTION_DAILY`
/ `_WEEKLY` / `_MONTHLY`). Ajustez selon la croissance réelle de la base et
l'espace disque disponible.

**Implémentation pragmatique** (voir commentaires dans `backup-db.sh`) : le
script classe chaque fichier existant selon son âge et sa date (dimanche =
candidat hebdomadaire, 1er du mois = candidat mensuel), puis supprime tout
fichier ne correspondant à aucun palier actif. Cela suppose une exécution
quotidienne sans interruption prolongée — voir section 8 (limites).

## 6. Restaurer un dump

**Toujours en dernier recours / test — jamais sans confirmation explicite.**

**Linux :**

```bash
cd payflex_backend/scripts/backup
./restore-db.sh /var/backups/payflex/db/payflex_payflexdb_20260717_030000.sql.gz

# Vers une base de test (ne touche pas la base configurée par défaut) :
./restore-db.sh <dump.sql.gz> --target-db payflexdb_test

# Sans confirmation interactive (scripts/CI — à utiliser avec prudence) :
./restore-db.sh <dump.sql.gz> --force
```

**Windows :**

```powershell
.\restore-db.ps1 -DumpFile .\backups\payflex_payflexdb_20260717_030000.zip
.\restore-db.ps1 -DumpFile <dump.zip> -TargetDb payflexdb_test
```

Garde-fous intégrés :

- Vérifie que le fichier de dump existe et est lisible avant toute action.
- Affiche clairement la base cible et si elle existe déjà (donc sera écrasée).
- Exige de taper **`CONFIRMER`** (littéralement) avant d'écraser une base existante — aucune option `-y`/`--yes` silencieuse par défaut.
- Journalise chaque étape avec horodatage (création base, début/fin restauration, durée).

Après restauration, **redémarrez le backend** : Flyway validera la cohérence
du schéma migré au démarrage (`spring.flyway.enabled=true` dans
`application.yml`).

## 7. Stockage hors-site (ne pas dépendre uniquement du disque du serveur)

Un serveur qui crashe, un disque qui meurt, ou un VPS supprimé par erreur ne
doit **jamais** emporter à la fois la base de prod ET ses sauvegardes. La
règle classique est **3-2-1** : 3 copies, sur 2 supports différents, dont **1
hors-site**.

### Exemple concret avec `rclone` (portable, gratuit/économique)

[`rclone`](https://rclone.org/) est un outil open-source qui synchronise des
fichiers vers ~70 fournisseurs de stockage objet (S3, Backblaze B2, Google
Cloud Storage, Wasabi, OVH Object Storage, etc.) avec la même syntaxe. Il ne
suppose aucun hébergeur particulier — vous pouvez changer de fournisseur sans
réécrire les scripts.

**Installation (Linux) :**

```bash
curl https://rclone.org/install.sh | sudo bash
```

**Configuration interactive (une seule fois) :**

```bash
rclone config
# Suivre l'assistant : choisir le type de stockage (ex: "s3" pour AWS S3/
# compatible S3 comme Backblaze B2 ou OVH, "google cloud storage" pour GCS),
# renseigner les clés d'accès du fournisseur choisi, donner un nom au remote
# (ex: "payflex-b2").
```

Exemple avec **Backblaze B2** (souvent le moins cher pour du stockage froid
de backups) : type de remote `b2`, renseigner `account` (Key ID) et `key`
(Application Key) depuis la console B2.

**Brancher dans le script** : renseignez dans `.env` de ce dossier :

```env
PAYFLEX_BACKUP_RCLONE_REMOTE=payflex-b2
PAYFLEX_BACKUP_RCLONE_PATH=payflex-backups-prod/db
```

`backup-db.sh` (et `backup-db.ps1`) détectent automatiquement ces variables
et exécutent, après chaque sauvegarde réussie :

```bash
rclone copy <fichier_backup> payflex-b2:payflex-backups-prod/db --log-level ERROR
```

**Vérifier manuellement le contenu distant :**

```bash
rclone ls payflex-b2:payflex-backups-prod/db
```

**Recommandation** : configurez également une politique de rétention/cycle
de vie côté fournisseur (ex: règles de lifecycle S3/B2 pour supprimer les
objets de plus de N mois), en miroir de la rétention locale, pour éviter une
facturation de stockage qui grossit indéfiniment.

## 8. Planification (exécution automatique quotidienne)

**Heure creuse suggérée** : entre **02h00 et 04h00** (heure locale du
serveur), moment où le trafic client/agent est quasi nul (l'app mobile est
peu utilisée la nuit) et où `--single-transaction` aura le moins d'impact
sur les écritures concurrentes.

### Linux — cron (cible probable en production)

```bash
crontab -e
```

Ajouter :

```cron
# Sauvegarde PayFlex quotidienne à 03h00, logs redirigés (le script logge déjà
# dans PAYFLEX_BACKUP_LOG_FILE si défini, la redirection ci-dessous est un filet de sécurité)
0 3 * * * /chemin/vers/payflex_backend/scripts/backup/backup-db.sh >> /var/log/payflex/backup-cron.log 2>&1
```

Vérifications utiles :

```bash
crontab -l                     # lister les tâches planifiées
grep CRON /var/log/syslog      # confirmer l'exécution (Debian/Ubuntu)
```

### Windows — Planificateur de tâches (dev local uniquement)

Via PowerShell (à exécuter en administrateur) :

```powershell
$action = New-ScheduledTaskAction -Execute "powershell.exe" `
  -Argument "-NoProfile -ExecutionPolicy Bypass -File `"C:\Users\chami\Desktop\PayFlex\payflex_backend\scripts\backup\backup-db.ps1`""
$trigger = New-ScheduledTaskTrigger -Daily -At 3:00AM
Register-ScheduledTask -TaskName "PayFlex - Backup DB quotidien" -Action $action -Trigger $trigger -Description "Sauvegarde quotidienne MySQL PayFlex (dev/test local)"
```

Ou via l'interface graphique : **Planificateur de tâches** → *Créer une
tâche* → Déclencheur *Quotidien 03:00* → Action *Démarrer un programme* :
`powershell.exe` avec arguments
`-NoProfile -ExecutionPolicy Bypass -File "C:\...\backup-db.ps1"`.

## 9. Test de restauration périodique (obligatoire, pas optionnel)

**Une sauvegarde jamais restaurée n'est pas une sauvegarde fiable.** Un dump
corrompu, une base mal exportée (droits manquants sur `--routines`, encodage
incorrect...) ne se découvre souvent qu'au moment où on en a besoin — trop
tard. D'où l'exigence d'un test **récurrent**, pas seulement au moment de la
mise en place.

**Fréquence recommandée : mensuelle** (ex: 1er lundi du mois), idéalement sur
un serveur/instance MySQL de test séparé de la prod.

```bash
cd payflex_backend/scripts/backup
./verify-backup.sh                                    # vérifie la sauvegarde la plus récente
./verify-backup.sh /chemin/vers/dump_specifique.sql.gz # ou une sauvegarde ciblée
```

Ce que fait `verify-backup.sh` :

1. Crée une base temporaire jetable (`payflex_verify_restore_<timestamp>`).
2. Restaure le dump dedans.
3. Sanity check : compte les lignes de la table `users` (configurable via
   `PAYFLEX_BACKUP_VERIFY_TABLE`) et échoue explicitement si la table est
   illisible.
4. Supprime la base temporaire dans tous les cas (succès ou échec), via un
   `trap` — aucune base résiduelle ne s'accumule.

### Checklist manuelle complémentaire (à faire en plus, périodiquement)

- [ ] Le script `verify-backup.sh` se termine avec le statut « succès ».
- [ ] Le nombre de lignes de `users` est cohérent avec l'attendu (proche du dashboard admin production).
- [ ] Vérifier 2-3 tables métier clés en plus (`contributions`, `agents`, `admin_users`) — requête manuelle rapide dans la base temporaire avant sa suppression, ou adapter temporairement `PAYFLEX_BACKUP_VERIFY_TABLE`.
- [ ] La date de la dernière ligne dans une table à forte fréquence d'écriture (ex: `contributions`) correspond à la date du dump, pas à une sauvegarde bien plus ancienne restaurée par erreur.
- [ ] La taille du fichier de dump n'a pas chuté anormalement par rapport aux jours précédents (un dump anormalement petit peut indiquer un échec silencieux partiel).
- [ ] Le test de restauration a bien été exécuté sur une instance qui n'affecte pas la production (base temporaire dédiée + idéalement serveur MySQL séparé).

## 10. Résumé opérationnel (checklist de mise en place initiale)

1. `cp .env.example .env` puis renseigner les identifiants MySQL et le dossier de backup.
2. `chmod +x backup-db.sh restore-db.sh verify-backup.sh`.
3. Lancer `./backup-db.sh` une première fois manuellement, vérifier le fichier produit.
4. Configurer `rclone` et renseigner `PAYFLEX_BACKUP_RCLONE_REMOTE`/`_PATH` pour l'offsite.
5. Planifier `backup-db.sh` en cron quotidien (03h00) en prod.
6. Planifier/exécuter `verify-backup.sh` mensuellement, avec la checklist manuelle.
7. Documenter/communiquer à l'équipe où sont stockées les sauvegardes et qui a accès aux identifiants de restauration en cas d'incident.

## 11. Hypothèses et limites connues

- **SGBD confirmé MySQL 8+** (pas PostgreSQL, voir section 0) — hypothèse initiale du ticket corrigée après lecture de `application.yml`/`.env.example`/README.
- **Pas de variable d'environnement dédiée pour host/port/nom de base** dans le projet existant (tout est encodé dans `PAYFLEX_DB_URL`). Les nouvelles variables `PAYFLEX_DB_HOST`/`PAYFLEX_DB_PORT`/`PAYFLEX_DB_NAME` sont introduites uniquement dans le `.env.example` de **ce dossier** (aucune modification de `payflex_backend/.env.example` ni du code Java) ; vous pouvez si vous le souhaitez, dans un second temps, harmoniser en ajoutant ces mêmes variables au `.env.example` principal — non fait ici pour respecter la contrainte de ne pas toucher aux fichiers en cours d'usage par d'autres workers.
- **Algorithme de rétention GFS pragmatique** basé sur la date du nom de fichier (dimanche = hebdo, 1er du mois = mensuel), pas sur un système de tags/métadonnées séparé. Fonctionne bien pour un cron quotidien fiable ; en cas d'interruption prolongée (serveur éteint plusieurs jours), certains paliers hebdo/mensuel peuvent être manqués jusqu'à la prochaine occurrence.
- **`date -d` (GNU coreutils)** requis dans `backup-db.sh` — présent par défaut sur les distributions Linux courantes (Debian/Ubuntu/RHEL). Non testé sur macOS (BSD `date`, syntaxe différente) — non pertinent ici puisque la prod visée est Linux.
- **Compression Windows en `.zip`** (`Compress-Archive`, natif PowerShell) plutôt qu'en `.gz`, faute d'outil gzip natif sous Windows sans dépendance supplémentaire. `restore-db.ps1` sait décompresser les `.zip` produits par `backup-db.ps1`.
- **`--single-transaction`** garantit un dump cohérent pour les tables **InnoDB** (moteur par défaut MySQL 8, utilisé par les migrations Flyway du projet). Si une table du schéma utilisait MyISAM, cette garantie ne s'appliquerait pas à cette table spécifique — vérifiez `SHOW TABLE STATUS` si un doute existe.
- **Chiffrement des sauvegardes au repos** non implémenté ici (ni localement, ni côté stockage distant au-delà du chiffrement natif éventuel du fournisseur S3/B2/GCS). À considérer en complément si le disque de backup ou le bucket distant n'est pas déjà chiffré, étant donné la sensibilité des données (identité, téléphone, montants financiers des clients).
- **Ce dossier ne modifie aucun fichier Java, Thymeleaf, migration SQL, ni rien dans `payflex_mobile/`**, conformément à la contrainte de travail en parallèle. Seule une courte section a été ajoutée dans le `README.md` racine (voir section suivante) pour référencer cette documentation.
