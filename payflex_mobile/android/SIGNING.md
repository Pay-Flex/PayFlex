# Signature Android (release) — PayFlex

Ce document explique comment est signé le build Android de production, comment
régénérer un keystore si besoin, et surtout **comment protéger les secrets**
associés.

## ⚠️ À lire avant tout

Le keystore de production (`android/keystore/payflex-release.jks`) et ses mots
de passe (`android/key.properties`) sont **volontairement absents du dépôt
git** (voir `.gitignore`). Ils vivent uniquement :

- sur les machines des personnes qui buildent la release ;
- dans un endroit sûr, séparé de ce dépôt (voir section « Sauvegarde »).

**Si ce keystore est perdu, il est IMPOSSIBLE de publier une mise à jour de
l'application déjà présente sur le Google Play Store.** Google Play exige que
toute mise à jour d'une app existante soit signée avec le même certificat que
la version publiée initialement (le keystore ci-dessus, une fois la première
version publiée). En cas de perte définitive :

- Google Play **App Signing** (si activé lors de la première publication) peut
  parfois permettre une réinitialisation de la clé d'upload via une demande
  officielle à Google — mais ce n'est pas garanti et prend du temps.
- Sans ce mécanisme, la seule option restante est de publier une **nouvelle
  application** sous un **nouveau nom de package**, en perdant tout
  l'historique (avis, installs, classement, utilisateurs qui ne seront pas mis
  à jour automatiquement).

➡️ **Sauvegardez ce fichier `.jks` comme vous sauvegarderiez la clé d'un
compte bancaire d'entreprise.**

## Fichiers concernés

| Fichier | Committé ? | Rôle |
|---|---|---|
| `android/keystore/payflex-release.jks` | ❌ Non (gitignored) | Le keystore de production lui-même. |
| `android/key.properties` | ❌ Non (gitignored) | Mots de passe + alias + chemin vers le keystore, lus par Gradle. |
| `android/key.properties.example` | ✅ Oui | Gabarit documenté, sans secret, pour savoir quoi remplir. |
| `android/app/build.gradle.kts` | ✅ Oui | Charge `key.properties` s'il existe et configure `signingConfigs["release"]`. |

## Comment le build release trouve la signature

`android/app/build.gradle.kts` :

1. Cherche `android/key.properties` au démarrage de la configuration Gradle.
2. S'il existe, charge `storePassword`, `keyPassword`, `keyAlias`, `storeFile`
   et construit `signingConfigs["release"]` avec ces valeurs.
3. `buildTypes.release.signingConfig` pointe vers cette config (plus jamais
   vers la config `debug`).
4. **S'il n'existe pas** : la configuration Gradle n'échoue pas immédiatement
   (pour ne pas casser `flutter run` en debug/profile sur une machine sans le
   keystore), mais **tout build release** (`assembleRelease`, `bundleRelease`,
   `flutter build apk/appbundle --release`, etc.) échoue explicitement avec un
   message d'erreur clair, avant toute tentative de signature. **Aucun
   fallback silencieux vers les clés debug n'est possible** : c'est exactement
   le problème que cette configuration corrige (l'app était précédemment
   signée en release avec les clés debug, ce qui bloque la publication sur le
   Play Store).

## Générer un nouveau keystore (première fois, ou remplacement volontaire)

> ⚠️ Ne régénérez **jamais** un nouveau keystore pour une app déjà publiée sur
> le Play Store sauf si vous savez exactement ce que vous faites (voir section
> ci-dessus sur la perte du keystore — un nouveau keystore = nouveau
> certificat = mise à jour refusée par Google Play).

Depuis `payflex_mobile/android/`, avec un JDK disponible (celui embarqué avec
Android Studio, ou tout JDK 17+ sur le PATH) :

```powershell
keytool -genkeypair -v `
  -keystore keystore/payflex-release.jks `
  -alias payflex-release `
  -keyalg RSA -keysize 2048 -validity 10000 `
  -storepass "VOTRE_STORE_PASSWORD" `
  -keypass "VOTRE_KEY_PASSWORD" `
  -dname "CN=PayFlex, OU=Mobile, O=PayFlex, L=Dakar, ST=Dakar, C=SN"
```

- `-validity 10000` ≈ 27 ans (standard recommandé par Google pour éviter
  qu'un certificat expiré ne bloque une future mise à jour).
- Utilisez des mots de passe forts générés aléatoirement (24-32 caractères
  alphanumériques minimum), jamais un mot de passe réutilisé ailleurs.
- `storePassword` et `keyPassword` peuvent être identiques ou différents ;
  les garder différents est légèrement plus sûr.

Ensuite, créez `android/key.properties` (copiez `key.properties.example`) :

```properties
storePassword=VOTRE_STORE_PASSWORD
keyPassword=VOTRE_KEY_PASSWORD
keyAlias=payflex-release
storeFile=keystore/payflex-release.jks
```

## Où stocker les mots de passe (jamais dans le repo)

- **Recommandé** : un gestionnaire de secrets d'équipe (1Password, Bitwarden
  Organizations, HashiCorp Vault, AWS/GCP Secrets Manager, etc.), avec le
  fichier `.jks` en pièce jointe chiffrée si l'outil le permet.
- **Minimum acceptable** : un coffre-fort de mots de passe personnel chiffré
  (1Password, Bitwarden, KeePass...) avec le `.jks` joint en tant que fichier,
  **pas seulement une copie sur le disque de cette machine**.
- Gardez au moins **une copie de sauvegarde** du `.jks` dans un endroit
  différent de la machine de build (stockage chiffré séparé, coffre
  d'entreprise, etc.). Une seule copie sur un seul poste = risque de perte
  totale en cas de panne disque, vol, ou reformatage.
- Ne partagez jamais `key.properties` ou le `.jks` par email/chat en clair ;
  utilisez le partage sécurisé de votre gestionnaire de secrets.

## Vérifier la signature d'un APK généré

```powershell
# Avec apksigner (build-tools Android)
apksigner verify --verbose build\app\outputs\flutter-apk\app-release.apk

# Ou avec jarsigner (JDK)
jarsigner -verify -verbose -certs build\app\outputs\flutter-apk\app-release.apk
```

Vous devez voir le certificat `CN=PayFlex, ...` (celui généré ci-dessus), et
non un certificat de debug (`CN=Android Debug`).

## Rappel — trafic HTTP en clair (cleartext)

`usesCleartextTraffic` n'est **plus activé en release** (voir
`android/app/src/main/AndroidManifest.xml`) : seul HTTPS est autorisé en
production. Il reste activé dans `android/app/src/debug/AndroidManifest.xml`
et `android/app/src/profile/AndroidManifest.xml`, pour continuer à tester en
local (USB/LAN, via `PAYFLEX_API_HOST`) sans configurer HTTPS sur un backend
de dev.
