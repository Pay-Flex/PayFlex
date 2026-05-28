# FedaPay (sandbox) — PayFlex

## Sécurité des clés

| Clé | Préfixe | Où la mettre |
|-----|---------|----------------|
| **Secrète** | `sk_sandbox_…` | Fichier `.env` local ou variable `FEDAPAY_API_KEY` — **serveur uniquement** |
| **Publique** | `pk_sandbox_…` | `FEDAPAY_PUBLIC_KEY` (optionnel, app mobile / widget plus tard) |
| **Webhook** | `whsec_…` | `FEDAPAY_WEBHOOK_SECRET` (dashboard FedaPay → Webhooks) |

**Ne jamais :**

- committer `.env`, `application-local.yml` ou coller les clés dans `application.yml` / le code ;
- envoyer `sk_…` dans l’app mobile ou le front admin ;
- partager les clés dans un chat public (régénérez-les sur [FedaPay Sandbox](https://sandbox.fedapay.com) si elles ont fuité).

Le dépôt ignore déjà : `.env`, `.env.*` (sauf `.env.example`), `secrets/`.

## Configuration locale (recommandé)

```powershell
cd payflex_backend
copy .env.example .env
# Éditez .env avec vos clés (déjà fait si vous avez reçu le fichier .env)
.\run-local.ps1
```

`run-local.ps1` charge `.env` puis lance `mvn spring-boot:run`.

Alternative sans script :

```powershell
$env:FEDAPAY_API_KEY="sk_sandbox_..."
$env:FEDAPAY_PUBLIC_KEY="pk_sandbox_..."
$env:FEDAPAY_SANDBOX="true"
mvn spring-boot:run
```

Sans `FEDAPAY_API_KEY`, l’app mobile utilise la **déclaration classique** (en attente agent / centre).

## Webhook

URL à enregistrer dans le tableau de bord FedaPay (nécessite une URL **publique**, ex. ngrok) :

```
{PAYFLEX_PUBLIC_URL}/api/fedapay/webhook
```

Copiez le **secret du endpoint** dans `FEDAPAY_WEBHOOK_SECRET` du fichier `.env`.

Événements utiles : `transaction.approved`, `transaction.canceled`.

## Flux client (dans l’app mobile)

1. Paiement mobile money → `POST /api/mobile/contributions/fedapay/init`
2. **WebView intégrée** dans PayFlex (écran « Paiement sécurisé ») — pas de sortie vers Chrome/Safari
3. Retour callback FedaPay détecté dans la WebView + bouton « J’ai terminé le paiement »
4. Webhook ou polling serveur → cotisation `validated` + notification client

## Tests locaux

1. Compte [FedaPay Sandbox](https://sandbox.fedapay.com)
2. **Backend** : `.\run-local.ps1` (port 8088)
3. **Tunnel** : `cloudflared tunnel --url http://localhost:8088` puis mettre l’URL dans `.env` :
   `PAYFLEX_PUBLIC_URL=https://….trycloudflare.com`
4. **Redémarrer le backend** après chaque changement d’URL tunnel (sinon les anciens liens FedaPay pointent vers un domaine mort → `ERR_CONNECTION_REFUSED`)
5. Webhook FedaPay : `{PAYFLEX_PUBLIC_URL}/api/fedapay/webhook` + secret dans `.env`
6. **Nouveau paiement** à chaque test (ne pas réutiliser une transaction créée avec un ancien tunnel)

### Numéros sandbox (opérateur « Momo Test »)

| Numéro | Résultat |
|--------|----------|
| `66000001` | Succès (MTN test) |
| `64000001` | Succès (Moov test) |
| `66000000` | Échec volontaire |
| Autre numéro | Souvent échec |

Si FedaPay affiche « Transaction échouée » avec un numéro de test valide : vérifiez que les clés `sk_sandbox_…` du `.env` correspondent au compte sandbox FedaPay.

### Après paiement dans l’app

Même si la page de retour affiche une erreur réseau, appuyez sur **« J’ai terminé le paiement »** : l’app interroge le serveur (USB/Wi‑Fi) qui vérifie le statut chez FedaPay.
