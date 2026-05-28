# PayFlex — Site vitrine (Next.js)

Site vitrine public du projet PayFlex, remplaçant les pages HTML statiques à la racine du dépôt.

## Pages

| Route | Équivalent ancien |
|-------|-------------------|
| `/` | `index.html` |
| `/about` | `about.html` (+ `#team`, `#testimonials`) |
| `/feature` | `feature.html` |
| `/service` | `service.html` |
| `/catalogue` | `catalogue.html` |
| `/product/[id]` | `product.html` |
| `/contact` | `contact.html` |

## Démarrage

```bash
cd payflex_vitrine
npm install
npm run dev
```

Ouvrir [http://localhost:3000](http://localhost:3000).

## Build production

```bash
npm run build
npm start
```

## Assets

Les images sont dans `public/img/` (copiées depuis `PayFlex/img/`).

## Note

Ne supprimez pas les anciens fichiers HTML/CSS à la racine tant que cette vitrine n’est pas validée en local.
