# PayFlex — Notifications push réelles (backend)

Ce document décrit la mise en place du **push réel** :

- **Mobile (client + agent)** : Firebase Cloud Messaging (FCM).
- **Admin / support (postes bureau)** : Web Push (VAPID) dans le navigateur.

> Tout est **gardé** : sans configuration, le backend démarre normalement et
> l'application retombe sur le modèle historique « pull » (poll mobile
> `POST /api/mobile/push/poll` + inbox admin par polling). Aucun crash.

---

## Architecture

| Canal | Déclencheur backend | Transport | Repli si non configuré |
|-------|---------------------|-----------|------------------------|
| Mobile | `UserInboxNotificationService.notifyUser(...)` (toutes les notifs inbox) | FCM → app Flutter | Poll mobile existant |
| Admin | Nouveau message support client, nouvelle inscription | Web Push VAPID → navigateur | Badges/polling admin existants |

Nouvelles tables (migration **V49**) : `user_device_tokens`, `admin_push_subscriptions`.

Nouveaux endpoints :

- `POST /api/mobile/devices/register-token` — enregistre le jeton FCM d'un appareil (client/agent).
- `POST /api/mobile/devices/unregister-token` — retire le jeton (déconnexion).
- `GET  /admin/web-push/config` — clé publique VAPID + état (session admin requise).
- `POST /admin/web-push/subscribe` — enregistre l'abonnement Web Push du poste.
- `POST /admin/web-push/unsubscribe` — retire l'abonnement.

---

## 1. Mobile — Firebase Cloud Messaging

### a) Créer le projet Firebase (à faire par vous)

1. [Console Firebase](https://console.firebase.google.com/) → **Ajouter un projet**.
2. Ajouter une **app Android** avec le package `com.payflex.app.payflex_mobile`.
3. Télécharger le fichier **`google-services.json`** et le déposer dans :
   `payflex_mobile/android/app/google-services.json`
   > Sans ce fichier, le plugin Gradle Google Services n'est **pas** appliqué
   > (voir `android/app/build.gradle.kts`) et l'app compile quand même (push mobile désactivé).

### b) Clé de compte de service (backend)

1. Console Firebase → **Paramètres du projet** → **Comptes de service** →
   **Générer une nouvelle clé privée** → télécharge un JSON.
2. Stocker ce JSON **hors du dépôt Git** (ex. `C:/secrets/payflex-firebase-service-account.json`).
3. Renseigner dans `.env` :
   ```
   PAYFLEX_FIREBASE_CREDENTIALS=C:/secrets/payflex-firebase-service-account.json
   ```
4. Redémarrer le backend. Au démarrage, le log affiche :
   - `Firebase Admin SDK initialisé — push FCM actif.` ✅
   - ou `FCM désactivé (...)` si le fichier est absent/illisible.

---

## 2. Admin / support — Web Push (VAPID)

### a) Générer une paire de clés VAPID (à faire une fois)

Option simple avec Node.js (paquet `web-push`) :

```bash
npx web-push generate-vapid-keys
```

Sortie :

```
Public Key:  BASE64URL_PUBLIC...
Private Key: BASE64URL_PRIVATE...
```

### b) Configurer le backend

Dans `.env` :

```
PAYFLEX_VAPID_PUBLIC_KEY=BASE64URL_PUBLIC...
PAYFLEX_VAPID_PRIVATE_KEY=BASE64URL_PRIVATE...
PAYFLEX_VAPID_SUBJECT=mailto:support@payflex.app
```

Redémarrer. Log attendu : `Web Push admin actif (VAPID configuré).`

### c) Côté admin (automatique)

- Une **cloche** apparaît dans l'en-tête de toutes les pages admin.
- Au clic, le navigateur demande l'autorisation puis s'abonne (service worker `/sw.js`).
- Les postes abonnés reçoivent une notification navigateur (même onglet fermé, navigateur ouvert)
  pour : **nouveau message support**, **nouvelle inscription**.
- Si les clés VAPID ne sont pas configurées, la cloche se masque automatiquement.

> **HTTPS requis** : le Web Push ne fonctionne que sur `https://` (ou `http://localhost`).
> En tunnel (LocalTunnel/Cloudflare), l'admin doit être servi en HTTPS — c'est déjà le cas
> via `PAYFLEX_PUBLIC_URL` (voir `TUNNEL.md`).

---

## Sécurité / secrets

- Ne **committez jamais** `google-services.json` (service account), la clé privée VAPID
  ni le `.env`. Le `.gitignore` couvre `.env` ; ajoutez le service account s'il est dans le repo.
- La clé **publique** VAPID est exposée au navigateur (normal). La clé **privée** reste serveur.
