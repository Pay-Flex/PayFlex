# PayFlex

Plateforme de **cotisation journalière** et de **financement d’équipements professionnels** pour artisans et travailleurs indépendants. Les clients cotisent à leur rythme via l’application mobile ; les agents terrain assurent la collecte et le suivi ; l’équipe PayFlex pilote l’ensemble depuis un panneau d’administration web.

---

## Table des matières

1. [Présentation](#présentation)
2. [Architecture](#architecture)
3. [Prérequis](#prérequis)
4. [Installation](#installation)
5. [Configuration](#configuration)
6. [Lancement en développement](#lancement-en-développement)
7. [Application mobile](#application-mobile)
8. [Build APK / AAB](#build-apk--aab)
9. [Fonctionnalités par rôle](#fonctionnalités-par-rôle)
10. [API mobile (aperçu)](#api-mobile-aperçu)
11. [Paiements PayDunya](#paiements-paydunya)
12. [Notifications](#notifications)
13. [Structure du dépôt](#structure-du-dépôt)
14. [Scripts utiles](#scripts-utiles)
15. [Documentation complémentaire](#documentation-complémentaire)
16. [Limitations connues](#limitations-connues)

---

## Présentation

PayFlex permet à un client de :

- Choisir un ou plusieurs **produits** (outils, équipements) dans un catalogue ;
- Définir une **cotisation journalière** ;
- Payer en **espèces** (via un agent) ou en **mobile money** (PayDunya) ;
- Suivre sa progression sur un **calendrier** (jours payés, jours « orange » de rattrapage) ;
- Bénéficier d’une **épargne bonus** mensuelle ;
- Recevoir son équipement après **clôture et livraison** validées par l’administration.

Les **agents** gèrent leurs clients, collectent les cotisations, valident les paiements mobile money et peuvent inscrire de nouveaux clients sur le terrain.

L’**administration** (admin ou gestionnaire) valide les inscriptions, supervise les cotisations, gère les zones, les produits, le chat support, les livraisons, les documents légaux et les offres d’emploi.

---

## Architecture

```
┌─────────────────┐     HTTPS/HTTP      ┌──────────────────────────────┐
│  payflex_mobile │ ◄──────────────────► │  payflex_backend (Spring Boot) │
│  (Flutter)      │   /api/mobile/*      │  Port 8088                     │
└─────────────────┘                      │  • API mobile JSON             │
                                         │  • Admin Thymeleaf (/admin)    │
                                         │  • Webhook/IPN PayDunya        │
                                         └──────────────┬───────────────┘
                                                        │
                                         ┌──────────────▼───────────────┐
                                         │  MySQL (payflexdb)           │
                                         │  Flyway (52 migrations)      │
                                         └──────────────────────────────┘

┌─────────────────┐
│ payflex_vitrine │  Site vitrine public (Next.js) — indépendant du backend
└─────────────────┘
```

| Composant | Technologie | Rôle |
|-----------|-------------|------|
| `payflex_backend` | Java 17, Spring Boot 3.4, Thymeleaf, Spring Security, Flyway | API mobile, panneau admin, webhooks paiement |
| `payflex_mobile` | Flutter 3.x, Riverpod, SQLite locale | Application client et agent (Android principal) |
| `payflex_vitrine` | Next.js, Tailwind | Site vitrine marketing |
| Base de données | MySQL 8+ | Données métier, audit, notifications |

---

## Prérequis

### Backend

- **JDK 17**
- **Maven 3.8+**
- **MySQL** (base `payflexdb`, créée automatiquement si `createDatabaseIfNotExist=true`)

### Mobile

- **Flutter SDK** (Dart ^3.10)
- **Android SDK** + `adb` (tests sur appareil physique)
- Optionnel : Xcode (iOS)

### Outils réseau (développement)

- `adb` pour le mode USB
- `cloudflared` ou `localtunnel` uniquement si vous avez besoin d’une URL HTTPS publique (webhook/IPN PayDunya, tests 4G)

---

## Installation

### 1. Cloner le dépôt

```powershell
git clone <url-du-depot> PayFlex
cd PayFlex
```

### 2. Backend

```powershell
cd payflex_backend
copy .env.example .env
# Éditer .env (voir section Configuration)
.\run-local.ps1
```

Au premier démarrage, Flyway applique les migrations (`V1` à `V52`). Un compte admin par défaut est créé (voir [Administration](#administration-web)).

### 3. Mobile

```powershell
cd payflex_mobile
flutter pub get
```

### 4. Site vitrine (optionnel)

```powershell
cd payflex_vitrine
npm install
npm run dev
```

Ouvrir http://localhost:3000

---

## Configuration

### Fichier `payflex_backend/.env`

Copier `.env.example` vers `.env`. **Ne jamais committer `.env`.**

| Variable | Description |
|----------|-------------|
| `PAYDUNYA_ENABLED` | Active/désactive l’intégration PayDunya |
| `PAYDUNYA_MODE` | `test` (sandbox) ou `live` (production) |
| `PAYDUNYA_MASTER_KEY` | Master key PayDunya — serveur uniquement |
| `PAYDUNYA_PRIVATE_KEY` | Private key PayDunya — serveur uniquement |
| `PAYDUNYA_TOKEN` | Token PayDunya — serveur uniquement |
| `PAYDUNYA_PUBLIC_KEY` | Clé publique (optionnelle) |
| `PAYFLEX_PUBLIC_URL` | URL publique du backend (webhook/IPN, callbacks) |
| `PAYFLEX_DB_URL` | JDBC MySQL (optionnel, défaut localhost) |
| `PAYFLEX_DB_USER` / `PAYFLEX_DB_PASSWORD` | Identifiants MySQL |
| `PAYFLEX_AGENT_CASH_AUTO_VALIDATE` | `false` = espèces agent en attente jusqu’au rapprochement admin |
| `PAYFLEX_VAULT_KEY` | Clé de chiffrement du coffre credentials (à changer en prod) |
| `PAYFLEX_CATCHUP_ALERT_THRESHOLD` | Seuil jours orange avant alerte (défaut : 5) |
| `PAYFLEX_AUTO_VALIDATE_HOURS` | Auto-validation mobile money si agent inactif (défaut : 24 h, 0 = désactivé) |

### Application mobile — URL du backend

La résolution d’URL est centralisée dans `payflex_mobile/lib/core/network/api_config.dart`.

| Mode | Commande / configuration |
|------|--------------------------|
| **USB** (recommandé, IP stable) | `adb reverse tcp:8088 tcp:8088` puis `.\scripts\run-usb.ps1` |
| **Wi‑Fi** | `.\scripts\run-wifi.ps1` — IP persistée dans l’app (SharedPreferences) |
| **Changement de Wi‑Fi** | Appui long sur le logo (écran connexion) → saisir la nouvelle IP PC — **sans rebuild** |
| **Tunnel LocalTunnel** | `.\scripts\run-tunnel.ps1` ou `--dart-define=PAYFLEX_USE_TUNNEL=true` + `PAYFLEX_TUNNEL_BASE=https://payflex-app.loca.lt` |
| **Production** | `.\scripts\build-apk.ps1 -Mode prod -ApiBase https://api.votredomaine.com` |

Priorité de résolution : override prefs (**debug uniquement**) → `PAYFLEX_API_BASE` (prod) → dart-define USB/LAN/tunnel.

**Passer en production** : mettre `PAYFLEX_PUBLIC_URL=https://api.votredomaine.com` dans le `.env` backend, puis builder l’app avec `-Mode prod -ApiBase https://api.votredomaine.com`. Pas de tunnel LocalTunnel en prod.

---

## Lancement en développement

### Backend

```powershell
cd payflex_backend
.\run-local.ps1
```

- Port : **8088**
- Santé API : http://localhost:8088/api/mobile/health
- Admin : http://localhost:8088/admin
- Login admin : http://localhost:8088/login

Logs (dans `payflex_backend/`) : `erreur.log`, `diagnostic.log`, `mobile-api.log`

### Mobile — USB (recommandé, pas d’IP à changer)

```powershell
adb reverse tcp:8088 tcp:8088
cd payflex_mobile
.\scripts\run-usb.ps1
```

URL stable `127.0.0.1:8088` via adb reverse — idéal pour Samsung / téléphone USB.

### Mobile — Wi‑Fi (même réseau PC + téléphone)

```powershell
cd payflex_mobile
.\scripts\run-wifi.ps1
```

Au premier lancement, l’IP LAN détectée est enregistrée dans l’app. Si le Wi‑Fi change plus tard : **appui long sur le logo** sur l’écran de connexion → modifier l’IP (`ipconfig` sur le PC).


### Mobile — LocalTunnel (4G / webhooks HTTPS)

URL fixe par sous-domaine : `https://payflex-app.loca.lt` (tant que personne d’autre ne prend le même sous-domaine).

```powershell
# Terminal 1
cd payflex_backend
.\run-local.ps1

# Terminal 2
npx localtunnel --port 8088 --subdomain payflex-app

# Terminal 3
cd payflex_mobile
.\scripts\run-tunnel.ps1
```

Dans `payflex_backend/.env` :

```env
PAYFLEX_PUBLIC_URL=https://payflex-app.loca.lt
```

Redémarrer le backend après modification du `.env` (webhook/IPN PayDunya, liens de paiement).

Build APK tunnel : `.\scripts\build-apk.ps1` (défaut `-Mode tunnel`).

Limites : PC allumé, backend et `npx localtunnel` actifs ; page de rappel `loca.lt` contournée automatiquement par l’app.

### Ordre de démarrage avec tunnel

1. Démarrer le backend (`run-local.ps1`)
2. Vérifier http://localhost:8088/api/mobile/health
3. Lancer le tunnel : `npx localtunnel --port 8088 --subdomain payflex-app`
4. Mettre à jour `PAYFLEX_PUBLIC_URL` dans `.env` et redémarrer le backend

Voir [TUNNEL.md](TUNNEL.md) pour le détail (ERR_TOO_MANY_REDIRECTS, 502, Cloudflare nommé, etc.).

---

## Application mobile

### Gestion de la version Flutter (FVM)

Le projet est épinglé sur **Flutter 3.38.9** via [FVM](https://fvm.app) (fichier `.fvmrc`). Après `dart pub global activate fvm` (puis ajout de `%LOCALAPPDATA%\Pub\Cache\bin` au `PATH`), utilisez `fvm flutter` à la place de `flutter` :

```powershell
fvm flutter --version      # version Flutter épinglée
fvm flutter pub get
fvm flutter run
fvm flutter build apk --release
```

Le dossier `.fvm/` (cache local du SDK) est ignoré par Git ; seul `.fvmrc` est versionné. Les scripts de `payflex_mobile/scripts/` utilisent déjà `fvm flutter`.

### Parcours d’authentification

| Étape | Description |
|-------|-------------|
| Splash | Logo, chargement session locale |
| Bienvenue | Choix inscription ou connexion |
| Sélection de rôle | Client ou agent |
| Inscription client | Formulaire multi-étapes : identité, lieu de travail, patron, photo, pièce d’identité, choix d’agent, CGU |
| Configuration PIN | Code PIN à 4 chiffres + code secret cotisation |
| Connexion | Téléphone + PIN ; biométrie optionnelle (`local_auth`) |
| Mot de passe oublié | Vérification identité (téléphone, nom, code unique) → nouveau PIN |
| Approbation admin | Compte `pending` : accès limité jusqu’à validation |

### Navigation client (5 onglets)

| Onglet | Fonction |
|--------|----------|
| **Accueil** | Solde, projets, épargne bonus, adhésion, agent rattaché, raccourcis (chat, notifications, offres d’emploi, signalement) |
| **Catalogue** | Produits par catégorie, panier, configuration cotisation journalière |
| **Paiement** | Déclaration cotisation (espèces / mobile money), adhésion PayDunya |
| **Suivi** | Calendrier mensuel (vert / orange / gris), détail projet |
| **Historique** | Transactions, reçus, rattrapage groupé (« combler les trous ») |

Fonctionnalités transverses : **profil** (édition, photo), **notifications** (inbox, épinglage, lecture), **chat support** (texte + pièces jointes), **signalement** multimédia, **offres d’emploi**.

### Navigation agent (4 onglets)

| Onglet | Fonction |
|--------|----------|
| **Accueil** | KPIs, file de validation, recherche clients, tournée de zone, inscriptions |
| **Clients** | Liste, détail (calendrier, historique, smartphone), collecte espèces |
| **Catalogue** | Consultation produits (mode agent) |
| **Profil** | Planning hebdomadaire, changement PIN, déconnexion |

Écrans agent dédiés : **collecte** (sélection jours, montant, code secret client), **file de validation** (mobile money en attente), **inscription client** (parcours complet + sélection produits), **registre des cotisations**, **confirmation adhésion espèces**, **tournée de zone**.

---

## Build APK / AAB

Script principal : `payflex_mobile/scripts/build-apk.ps1`

```powershell
cd payflex_mobile

# APK universel (défaut) — 32 + 64 bits, installable sur tous les téléphones
.\scripts\build-apk.ps1

# APK par architecture (plus léger, un fichier par type de processeur)
.\scripts\build-apk.ps1 -SplitPerAbi

# Mode Wi‑Fi LAN
.\scripts\build-apk.ps1 -Mode wifi -LanHost "192.168.1.68"

# Mode production
.\scripts\build-apk.ps1 -Mode prod -ApiBase "https://api.votredomaine.com"

# Bundle Play Store
.\scripts\build-apk.ps1 -Mode prod -ApiBase "https://api.votredomaine.com" -Target appbundle
```

**Fichier à distribuer (défaut)** : `payflex_mobile/build/app/outputs/flutter-apk/app-release.apk` — APK universel contenant `armeabi-v7a` (32 bits) et `arm64-v8a` (64 bits).

Avec `-SplitPerAbi` : `app-armeabi-v7a-release.apk` pour les anciens téléphones 32 bits, `app-arm64-v8a-release.apk` pour les téléphones récents 64 bits.

---

## Fonctionnalités par rôle

### Client (application mobile)

- **Inscription** en autonomie avec pièces justificatives et acceptation des CGU
- **Catalogue** et sélection de produits avec cotisation journalière personnalisée
- **Cotisation** :
  - Espèces : déclaration → validation par l’agent ou l’admin
  - Mobile money : initiation PayDunya (WebView intégrée) ou déclaration classique
- **Calendrier** : visualisation des jours cotisés, jours orange (rattrapage), alertes seuil configurable
- **Rattrapage** : écran « Combler les trous » pour payer plusieurs jours orange
- **Épargne bonus** : chaque mois civil, 1 jour de cotisation est prélevé — 50 % crédités au client, 50 % PayFlex
- **Adhésion** : frais d’adhésion (250 FCFA par défaut), paiement PayDunya ou confirmation agent (espèces) ; contestation possible
- **Livraison** : suivi du statut (objectif atteint → clôture → livraison)
- **Notifications** : inbox avec types (cotisation validée/rejetée, bonus, adhésion, rattrapage, etc.)
- **Chat support** : messagerie avec l’administration, pièces jointes
- **Signalement** : catégories (agent, cotisation, produit, fraude…), photo optionnelle
- **Offres d’emploi** : consultation des postes publiés par PayFlex
- **Biométrie** : connexion rapide après activation
- **Récupération de compte** : réinitialisation PIN via vérification d’identité

### Agent (application mobile)

- **Tableau de bord** : clients du secteur, dernières cotisations, indicateurs
- **Liste et fiche client** : calendrier, historique, produits souscrits, statut adhésion
- **Collecte espèces** : enregistrement par jours sélectionnés, synchronisation serveur
- **Validation** des cotisations mobile money en attente
- **Inscription client** sur le terrain (si permission `MOBILE_REGISTRATION_AGENT`)
- **Confirmation adhésion** payée en espèces
- **Ajout de produits** à un client existant
- **Vérification PIN client** avant opérations sensibles
- **Tournée de zone** : clients à visiter par secteur
- **Planning hebdomadaire** : disponibilités configurables
- **Changement de PIN** agent
- **Dette espèces** : suivi des montants collectés en attente de rapprochement admin, dette individuelle en cas d’écart constaté, notifications (manque constaté / remboursement enregistré) et ligne « dernier remboursement » dans le profil
- Accès **notifications**, **chat**, **signalements**, **offres d’emploi**

### Administration web (`/admin`)

Accessible aux rôles **ADMIN** et **GESTIONNAIRE** (permissions différenciées).

| Module | Fonctionnalités |
|--------|-----------------|
| **Tableau de bord** | KPIs (comptes, agents, clients, produits, collecte, en attente), graphiques, revenus PayFlex (adhésions + part épargne bonus), alertes rattrapage, badge sidebar « dettes agents actives » |
| **Inscriptions** | File d’attente, approbation/refus, modification, photos et pièces d’identité |
| **Comptes** | CRUD utilisateurs, statuts, export CSV/PDF |
| **Clients** | Fiche détaillée, agent assigné, adhésion, mode autonome, récupération credentials, impression clients assidus |
| **Produits & catégories** | CRUD avec images, prix, cotisation minimale |
| **Cotisations** | Liste, validation/rejet, validation groupée, rapprochement de caisse **par agent** (+ rapprochement global FIFO en secours), alerte dettes agents, auto-validation programmée |
| **Clôture & livraison** | Ouverture dossier, validation clôture, confirmation remise produit |
| **Agents** | Embauche (dossier, contrat, photo), zones, dette espèces, remboursement de dette (partiel ou total), historiques écarts + remboursements sur la fiche agent |
| **Gestionnaires** | CRUD réservé admin complet |
| **Zones** | Définition géographique, affectation agents/clients |
| **Chat support** | Threads par utilisateur, broadcast, pièces jointes, suppression messages |
| **CGU & confidentialité** | Édition des documents légaux servis à l’app mobile |
| **Offres d’emploi** | Publication, pièces jointes, activation |
| **Rôles & permissions** | Matrice de permissions (admin complet uniquement) |
| **Suppressions à valider** | Workflow de demande de suppression de compte |
| **Journal d’activité** | Audit des actions admin, export |

**Connexion admin** : http://localhost:8088/login — compte seed `admin` / `admin123` (à changer immédiatement en production).

#### Rapprochement de caisse par agent

Depuis la page **Cotisations**, le tableau « Caisse par agent » liste chaque agent ayant des espèces en attente (nombre de collectes, total attendu, dette actuelle). L’admin saisit le **montant compté** et rapproche agent par agent :

| Cas | Résultat |
|-----|----------|
| Compté **=** attendu | Toutes les cotisations en attente sont validées |
| Compté **<** attendu | Cotisations validées + **dette individuelle** créée pour l’agent (écart) |
| Compté **>** attendu | Toutes validées + **excédent signalé** (jamais enregistré) |

Le **rapprochement global FIFO** reste disponible en secours (section dépliante).

#### Dette agent & remboursement

- Dette individuelle portée par `agents.cash_debt_fcfa`, journal des écarts dans `agent_cash_debt_events`.
- **Remboursement** (partiel ou total) enregistrable par l’admin sur la fiche agent — table `agent_debt_repayments` (migration V52) ; historiques des écarts et des remboursements visibles sur la fiche agent.
- **Notifications agent** : manque constaté lors d’un rapprochement, remboursement enregistré ; ligne « dernier remboursement » dans le profil agent mobile.
- **Alertes admin** : alerte sur la page Cotisations + web push admin à la création d’une dette ; badge sidebar « dettes agents actives ».

#### Cohérence des totaux

Tous les montants « versé / collecté » affichés côté admin (fiche client, fiche agent, dashboard, graphiques) comptent uniquement les cotisations **validées**, alignés avec les totaux affichés dans l’app mobile (client et agent).

### Backend — services métier

| Service | Rôle |
|---------|------|
| `MobileApiService` | Orchestration API mobile |
| `RegistrationService` | Workflow inscriptions |
| `ContributionWorkflowService` | Validation/rejet cotisations, auto-validation |
| `PayDunyaService` / `PayDunyaPaymentService` | Paiements mobile money (cotisations + adhésion) |
| `ClientBonusSavingsService` | Crédit mensuel épargne bonus |
| `ProductDeliveryService` | Clôture et livraison produits |
| `ClientAdhesionService` | Frais et statut adhésion |
| `AgentMobileService` | Données agent (dashboard, clients, tournée) |
| `SupportChatService` | Messagerie support |
| `UserInboxNotificationService` | Notifications inbox |
| `PushNotificationService` | Poll push (sans Firebase) |
| `MobileRecoveryService` | Récupération PIN / credentials |
| `CredentialVaultService` | Coffre chiffré codes secrets |
| `LegalDocumentService` | Documents légaux versionnés |
| `JobOfferService` | Offres d’emploi |
| `AdminRevenueService` | Calcul revenus plateforme |
| `AdminAuditService` | Journal d’audit |

---

## API mobile (aperçu)

Base : `POST/GET /api/mobile/*` (authentification par `userId` + `phone` + `pin` dans le corps JSON).

| Domaine | Endpoints principaux |
|---------|---------------------|
| Santé | `GET /health` |
| Auth | `POST /auth/login`, `/auth/recovery/request`, `/auth/recovery/reset` |
| Profil | `POST /profile`, `/profile/update` |
| Catalogue | `GET /product-categories`, `/products` |
| Cotisations | `POST /contributions`, `/contributions/history`, `/contributions/pending`, `/contributions/validate`, `/contributions/reject` |
| PayDunya | `POST /contributions/paydunya/init`, `/contributions/paydunya/status`, `GET /contributions/paydunya/callback` |
| Adhésion | `POST /adhesion/paydunya/init`, `/adhesion/paydunya/status`, `/client/adhesion/dispute` |
| Épargne bonus | `POST /client/bonus-savings` |
| Calendrier | `POST /calendar-stats` |
| Notifications | `POST /notifications`, `/notifications/read`, `/notifications/pin`, `/push/poll` |
| Chat | `POST /support-chat/history`, `/support-chat/send`, `/support-chat/send-attachment`, `/support-chat/inbox` |
| Agent | `POST /agent/dashboard`, `/agent/clients`, `/agent/client-detail`, `/agent/zone-tour`, `/agent/profile/schedule`, `/agent/contributions/registry` |
| Inscription | `POST /registrations` (multipart), `GET /registrations/pending` |
| Légal & emploi | `GET /legal/documents`, `GET /job-offers`, `GET /job-offers/{id}` |
| Devices | `POST /devices/fcm-token` (ignoré — compatibilité) |

Webhook/IPN PayDunya : `POST /api/paydunya/webhook`

API admin JSON : `GET /api/admin/dashboard`

Actions admin (caisse agent) : `POST /admin/agents/{id}/reconcile-cash` (rapprochement de caisse par agent), `POST /admin/agents/{id}/debt-repayment` (enregistrement d’un remboursement de dette)

Exports admin : `GET /admin/export/{entity}.csv` (users, products, agents, contributions, audit)

---

## Paiements PayDunya

PayDunya est la **passerelle mobile money unique** (Flooz Moov, T-Money / Mixx by Yas, cartes) via
l’API « Checkout Invoice » (Paiement Avec Redirection). Elle couvre les cotisations **et** l’adhésion.

- `PAYDUNYA_MODE=test` = sandbox (aucun argent réel), `live` = production.
- Repli gracieux : sans clés (`PAYDUNYA_MASTER_KEY`/`PRIVATE_KEY`/`TOKEN`), le mobile money est masqué
  côté app → il ne reste que la déclaration classique / espèces.

Flux client :

1. `POST /contributions/paydunya/init` (cotisation) ou `/adhesion/paydunya/init` (adhésion 250 FCFA)
2. WebView intégrée dans l’app (l’utilisateur ne quitte pas PayFlex)
3. Retour `return_url` + IPN `POST /api/paydunya/webhook` ou polling → cotisation/adhésion validée + notification

Documentation détaillée : [payflex_backend/PAYDUNYA.md](payflex_backend/PAYDUNYA.md)

---

## Notifications

PayFlex **n’utilise pas Firebase**. Mécanisme :

1. Le backend écrit dans `client_notifications`
2. L’app interroge `POST /api/mobile/push/poll` (~12 s en premier plan, WorkManager ~15 min en arrière-plan Android)
3. Affichage via `flutter_local_notifications`

Limites : pas de push instantané iOS app tuée ; délais WorkManager sur Android.

Documentation : [payflex_mobile/PAYFLEX_PUSH.md](payflex_mobile/PAYFLEX_PUSH.md)

---

## Structure du dépôt

```
PayFlex/
├── README.md                 # Ce fichier
├── TUNNEL.md                 # Connexion mobile ↔ backend (Wi‑Fi, USB, tunnel)
├── payflex_backend/          # Backend Spring Boot
│   ├── .env.example
│   ├── run-local.ps1
│   ├── repair-flyway.ps1
│   ├── PAYDUNYA.md
│   ├── pom.xml
│   ├── src/main/java/      # Controllers, services, config
│   ├── src/main/resources/
│   │   ├── application.yml
│   │   ├── db/migration/   # Flyway V1–V52
│   │   ├── templates/      # Pages admin Thymeleaf
│   │   └── static/         # CSS/JS admin
│   └── uploads/              # Photos, produits, pièces jointes
├── payflex_mobile/           # Application Flutter
│   ├── lib/
│   │   ├── core/           # API, thème, providers, services
│   │   └── features/       # Écrans (auth, agent, catalogue, payment…)
│   ├── scripts/
│   │   ├── build-apk.ps1
│   │   ├── run-usb.ps1
│   │   ├── run-wifi.ps1
│   │   ├── run-tunnel.ps1
│   │   └── pull-logs.ps1
│   └── PAYFLEX_PUSH.md
├── payflex_vitrine/          # Site vitrine Next.js
└── (fichiers HTML/CSS legacy à la racine — remplacés progressivement par payflex_vitrine)
```

---

## Scripts utiles

| Script | Emplacement | Usage |
|--------|-------------|-------|
| `run-local.ps1` | `payflex_backend/` | Charge `.env` et démarre Spring Boot |
| `repair-flyway.ps1` | `payflex_backend/` | Répare l’historique Flyway après échec de migration |
| `run-wifi.ps1` | `payflex_mobile/scripts/` | `flutter run` avec IP LAN auto-détectée |
| `run-tunnel.ps1` | `payflex_mobile/scripts/` | `flutter run` via LocalTunnel (`payflex-app.loca.lt`) |
| `run-usb.ps1` | `payflex_mobile/scripts/` | `adb reverse` + `flutter run` |
| `build-apk.ps1` | `payflex_mobile/scripts/` | Build APK/AAB release (tunnel, wifi, prod) |
| `pull-logs.ps1` | `payflex_mobile/scripts/` | Récupère les logs app depuis un téléphone USB |

---

## Documentation complémentaire

| Fichier | Contenu |
|---------|---------|
| [TUNNEL.md](TUNNEL.md) | Wi‑Fi, USB, Cloudflare, LocalTunnel, erreurs courantes |
| [payflex_backend/PAYDUNYA.md](payflex_backend/PAYDUNYA.md) | Clés PayDunya, sandbox, webhook/IPN, tests |
| [payflex_mobile/PAYFLEX_PUSH.md](payflex_mobile/PAYFLEX_PUSH.md) | Architecture notifications sans Firebase |
| [payflex_vitrine/README.md](payflex_vitrine/README.md) | Site vitrine Next.js |

---

## Limitations connues

### Réseau et tunnels

- **LocalTunnel** (`*.loca.lt`) : sous-domaine fixe `payflex-app` ; PC + tunnel actifs ; adapté aux tests 4G, pas à la production.
- **Quick tunnels Cloudflare** : URL change à chaque redémarrage ; mettre à jour `.env`, l’app mobile et le dashboard PayDunya.
- **Production** : domaine fixe + `PAYFLEX_PUBLIC_URL` backend + `build-apk.ps1 -Mode prod -ApiBase https://api.votredomaine.com`.

### Notifications

- Pas de push temps réel type FCM quand l’application est fermée longtemps (surtout iOS).
- WorkManager Android peut retarder le poll (optimisation batterie).

### Échelle

- Architecture monolithique Spring Boot + MySQL ; pas de cluster ni file de messages dédiée.
- API mobile authentifiée par PIN dans le corps des requêtes — prévoir HTTPS obligatoire en production.
- Session admin limitée à 1 connexion simultanée par compte.

### Sécurité

- Changer le mot de passe admin seed (`admin` / `admin123`) avant toute exposition réseau.
- Régénérer `PAYFLEX_VAULT_KEY` et toutes les clés PayDunya en production.
- Ne jamais exposer les clés PayDunya (`PAYDUNYA_MASTER_KEY` / `PRIVATE_KEY` / `TOKEN`) côté mobile ou front.

---

## Licence

Projet privé PayFlex — usage interne. Consulter les détenteurs du dépôt pour toute redistribution.

