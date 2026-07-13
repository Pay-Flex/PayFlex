# PayDunya — PayFlex

PayDunya est la **passerelle mobile money unique** de PayFlex (Flooz Moov, T-Money / Mixx by Yas,
cartes) via l'API **« Checkout Invoice »** (Paiement Avec Redirection). Elle couvre les cotisations
**et** l'adhésion (250 FCFA). Le montant est verrouillé côté serveur (`total_amount`).

## Sécurité des clés

| Clé | Variable | Où la mettre |
|-----|----------|--------------|
| **Master key** | `PAYDUNYA_MASTER_KEY` | Fichier `.env` local — **serveur uniquement** |
| **Private key** | `PAYDUNYA_PRIVATE_KEY` | `.env` — **serveur uniquement** |
| **Token** | `PAYDUNYA_TOKEN` | `.env` — **serveur uniquement** |
| **Public key** | `PAYDUNYA_PUBLIC_KEY` | Optionnelle (intégration côté client) |

**Ne jamais :** committer `.env`, coller les clés dans `application.yml` / le code, ou envoyer les
clés d'API dans l'app mobile ou le front admin.

Le dépôt ignore déjà : `.env`, `.env.*` (sauf `.env.example`), `secrets/`.

## Configuration locale

```powershell
cd payflex_backend
copy .env.example .env
# Éditez .env avec vos clés PayDunya (compte Business → « Intégrez notre API »)
.\run-local.ps1
```

Clés : compte **PayDunya Business** → « Intégrez notre API » → configurer une application, puis
récupérer Master key / Private key / Token.

- `PAYDUNYA_MODE=test` = **sandbox** (aucun argent réel), `live` = production.
- Repli gracieux : sans clés (`PAYDUNYA_MASTER_KEY`/`PRIVATE_KEY`/`TOKEN` vides), le mobile money
  est **masqué** côté app → il ne reste que la déclaration classique / espèces. L'app ne plante pas.

## Webhook / IPN

URL à enregistrer dans le tableau de bord PayDunya (nécessite une URL **publique**, ex. LocalTunnel) :

```
{PAYFLEX_PUBLIC_URL}/api/paydunya/webhook
```

PayDunya poste l'IPN en `application/x-www-form-urlencoded`. On **ne fait pas confiance** au POST :
le serveur revalide le paiement via `checkout-invoice/confirm/{token}` avant de marquer payé
(idempotent). L'IPN distingue **adhésion** (jeton stocké sur l'utilisateur) et **cotisation**
(jeton stocké sur la cotisation).

## Flux client (app mobile)

### Cotisation
1. Paiement mobile money → `POST /api/mobile/contributions/paydunya/init`
2. **WebView intégrée** dans PayFlex (écran « Paiement sécurisé ») — pas de sortie navigateur
3. Retour `return_url` PayFlex détecté + bouton « J'ai terminé le paiement »
4. IPN ou polling serveur (`/contributions/paydunya/status`) → cotisation `validated` + notification

### Adhésion (250 FCFA)
1. `POST /api/mobile/adhesion/paydunya/init` (`total_amount = 250`, `custom_data.kind = "adhesion"`)
2. WebView PayDunya, retour `/api/mobile/adhesion/paydunya/callback`
3. IPN ou `/adhesion/paydunya/status` → `markAdhesionPaidByPaydunya` (adhésion confirmée)
4. Alternative : paiement **en espèces** auprès de l'agent parrain (confirmation dans l'app agent)

## Tests locaux

1. Compte PayDunya Business en mode **test** (`PAYDUNYA_MODE=test`)
2. **Backend** : `.\run-local.ps1` (port 8088)
3. **Tunnel** : `npx localtunnel --port 8088` (ou Cloudflare) puis mettre l'URL dans `.env` :
   `PAYFLEX_PUBLIC_URL=https://….loca.lt`
4. **Redémarrer le backend** après chaque changement d'URL tunnel (sinon les anciens liens PayDunya
   pointent vers un domaine mort → `ERR_CONNECTION_REFUSED`)
5. IPN PayDunya : `{PAYFLEX_PUBLIC_URL}/api/paydunya/webhook`
6. **Nouveau paiement** à chaque test (ne pas réutiliser une facture créée avec un ancien tunnel)

### Après paiement dans l'app

Même si la page de retour affiche une erreur réseau, appuyez sur **« J'ai terminé le paiement »** :
l'app interroge le serveur (USB/Wi-Fi) qui vérifie le statut de la facture chez PayDunya.
