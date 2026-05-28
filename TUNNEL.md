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

Les quick tunnels `*.trycloudflare.com` **changent à chaque redémarrage**. Pour le dev mobile, préférez :

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

En mode debug, l’app utilise **déjà le Wi‑Fi par défaut** — pas besoin de Cloudflare.

---

## URL HTTPS publique fixe (webhooks FedaPay, tests 4G)

Les quick tunnels Cloudflare **ne conviennent pas** (URL aléatoire). Solutions stables :

| Solution | URL fixe | Coût |
|----------|----------|------|
| **Cloudflare Tunnel nommé** + votre domaine | `https://api.votredomaine.com` | Gratuit (domaine sur Cloudflare) |
| **Serveur VPS** (OVH, Hetzner…) | IP ou domaine | Payant |
| **ngrok** domaine réservé | `https://xxx.ngrok-free.app` | Payant |

### Cloudflare Tunnel nommé (gratuit, URL fixe)

1. Avoir un domaine géré par Cloudflare (ex. `payflex.tg`)
2. `cloudflared tunnel login`
3. Créer un tunnel nommé et un enregistrement DNS `api.votredomaine.com`
4. Mettre à jour `payflex_backend/.env` :

```env
PAYFLEX_PUBLIC_URL=https://api.votredomaine.com
```

5. App mobile :

```text
flutter run --dart-define=PAYFLEX_API_BASE=https://api.votredomaine.com
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

Mettre à jour manuellement :

- `payflex_backend/.env` → `PAYFLEX_PUBLIC_URL`
- `payflex_mobile/lib/core/network/api_config.dart` → `defaultTunnelBase`
- Dashboard FedaPay → webhook URL

Webhook FedaPay : `{PAYFLEX_PUBLIC_URL}/api/fedapay/webhook`
