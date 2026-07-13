# Notifications PayFlex (sans Firebase)

## Principe

PayFlex n’utilise **ni Firebase, ni OneSignal, ni autre store cloud** pour les push.

1. Le **backend** écrit les alertes dans `client_notifications` (cotisations, adhésion, messages admin, etc.).
2. L’**app mobile** interroge régulièrement `POST /api/mobile/push/poll`.
3. Pour chaque nouveauté, l’app affiche une **notification locale système** (`flutter_local_notifications`).

## Quand l’utilisateur est averti

| Situation | Mécanisme |
|-----------|-----------|
| App ouverte / récente | Poll toutes les ~12 s (`clientInboxProvider`) |
| Retour au premier plan | `PayflexPushLifecycle` |
| App en arrière-plan (Android) | `workmanager` toutes les ~15 min (réseau requis) |

## Limites (honnêtes)

- **Pas de push instantané** comme FCM quand l’app est tuée depuis longtemps sur iOS.
- **Android** : WorkManager peut retarder le poll (économie batterie).
- Pour une alerte immédiate avec app fermée sans Google : héberger **ntfy** sur votre VPS (option future) — toujours sans Firebase.

## API

```http
POST /api/mobile/push/poll
{ "userId", "phone", "pin", "afterNotificationId": 123 }
```

Réponse : `newNotifications`, `latestNotificationId`, `chatUnread`, `latestChatTitle`, `latestChatPreview`.

## Ancien endpoint FCM

`POST /api/mobile/devices/fcm-token` reste accepté mais **ignoré** (compatibilité).
