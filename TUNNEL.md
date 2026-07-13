# Connexion mobile ↔ backend (développement)

## Erreur ERR_TOO_MANY_REDIRECTS sur `/login` (tunnel HTTPS)

Souvent causé par le backend qui **ignore** `X-Forwarded-Proto` : Spring renvoie des `Location:` en **`http://`**, Cloudflare renvoie le navigateur en **`https://`** → boucle.

**Correction** : `server.forward-headers-strategy: framework` dans `payflex_backend/src/main/resources/application.yml` (déjà présent dans ce projet). Après modification, redémarrer le backend.

Ensuite : vider les cookies pour `*.trycloudflare.com` (bouton « Supprimer les cookies » du navigateur).

---

## Erreur 502 Bad Gateway (Cloudflare)

Le tunnel **fonctionne**, mais le backend local **ne répond pas** sur `http://localhost:8088`.

Vérifications :

1. Terminal 1 : `cd payflex_backend` puis `.\run-local.ps1` — attendre « Started PayflexBackendApplication »
2. Test local : http://localhost:8088/api/mobile/health → doit renvoyer du JSON
3. **Ensuite seulement** lancer cloudflared (Terminal 2)

Ordre obligatoire : **backend d’abord**, tunnel ensuite.

---

## Recommandé : sans tunnel (URL stable)

Pour le dev quotidien sur le même réseau ou en USB, préférez :

### Option A — USB (le plus fiable)

```powershell
adb reverse tcp:8088 tcp:8088
cd payflex_mobile
.\scripts\run-usb.ps1
```

URL fixe côté app : `http://127.0.0.1:8088`

### Option B — Wi‑Fi (même réseau PC + téléphone)

```powershell
ipconfig
# Repérer l’IPv4 Wi‑Fi (ex. 192.168.1.68)

cd payflex_mobile
.\scripts\run-wifi.ps1
# ou : flutter run --dart-define=PAYFLEX_API_HOST=192.168.1.68
```

URL fixe : `http://192.168.1.68:8088` (tant que l’IP du PC ne change pas).

En mode debug, l’app utilise **déjà le Wi‑Fi par défaut** — pas besoin de tunnel.

---

## LocalTunnel (HTTPS public, tests 4G / webhooks)

Prérequis : **Node.js** (`npx`), backend sur le port **8088**.

```powershell
# Terminal 1
cd payflex_backend
.\run-local.ps1

# Terminal 2
npx localtunnel --port 8088 --subdomain payflex-app

# Terminal 3 (app)
cd payflex_mobile
.\scripts\run-tunnel.ps1
```

URL affichée : `https://payflex-app.loca.lt`

### Configuration backend

```env
PAYFLEX_PUBLIC_URL=https://payflex-app.loca.lt
```

Redémarrer le backend après modification du `.env`. Webhook/IPN PayDunya : `{PAYFLEX_PUBLIC_URL}/api/paydunya/webhook`

### URLs utiles

| Service | URL |
|---------|-----|
| Santé API mobile | `https://payflex-app.loca.lt/api/mobile/health` |
| Panneau admin | `https://payflex-app.loca.lt/admin` |
| Connexion admin | `https://payflex-app.loca.lt/login` |

### Page de vérification `loca.lt`

LocalTunnel peut afficher une page « saisir l’IP » dans un navigateur. L’app PayFlex envoie automatiquement `Bypass-Tunnel-Reminder: true`.

Test manuel :

```powershell
curl -H "Bypass-Tunnel-Reminder: true" https://payflex-app.loca.lt/api/mobile/health
```

### Build APK (testeurs distants)

```powershell
cd payflex_mobile
.\scripts\build-apk.ps1
# défaut : -Mode tunnel -TunnelUrl https://payflex-app.loca.lt
```

Le PC doit rester allumé avec backend + `npx localtunnel` actifs pendant les tests.

---

## URL HTTPS publique fixe (production)

Les quick tunnels Cloudflare **ne conviennent pas** (URL aléatoire). Solutions stables :

| Solution | URL fixe | Coût |
|----------|----------|------|
| **Cloudflare Tunnel nommé** + votre domaine | `https://api.votredomaine.com` | Gratuit (domaine sur Cloudflare) |
| **Serveur VPS** (OVH, Hetzner…) | IP ou domaine | Payant |
| **ngrok** domaine réservé | `https://xxx.ngrok-free.app` | Payant |

### Passer en production

1. Backend : `PAYFLEX_PUBLIC_URL=https://api.votredomaine.com` dans `.env`
2. Mobile : `.\scripts\build-apk.ps1 -Mode prod -ApiBase "https://api.votredomaine.com"`
3. Dashboard PayDunya : IPN vers `https://api.votredomaine.com/api/paydunya/webhook`

En prod, l’override URL dans l’app (SharedPreferences) est **ignoré** — seule l’URL compilée compte.

### Cloudflare Tunnel nommé (gratuit, URL fixe)

1. Avoir un domaine géré par Cloudflare (ex. `payflex.tg`)
2. `cloudflared tunnel login`
3. Créer un tunnel nommé et un enregistrement DNS `api.votredomaine.com`
4. Mettre à jour `payflex_backend/.env` :

```env
PAYFLEX_PUBLIC_URL=https://api.votredomaine.com
```

Doc : https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/

### Quick tunnel (temporaire uniquement)

```powershell
# Terminal 1
cd payflex_backend
.\run-local.ps1

# Terminal 2 — URL change à chaque fois !
cloudflared tunnel --url http://localhost:8088
```

Mettre à jour manuellement `PAYFLEX_PUBLIC_URL` dans `.env` et redémarrer le backend.

---

## Admin inaccessible via tunnel HTTPS

1. **`PAYFLEX_PUBLIC_URL`** = URL HTTPS exacte du tunnel (pas `localhost`).
2. **Redémarrer** le backend après changement de `.env`.
3. Boucle sur `/login` : vider les cookies du domaine tunnel ; vérifier `forward-headers-strategy: framework` dans `application.yml`.
