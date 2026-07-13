import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import '../network/mobile_api_service.dart';
import 'local_notification_service.dart';

/// Handler des messages reçus quand l'app est en arrière-plan / terminée.
/// Doit être une fonction top-level annotée `@pragma('vm:entry-point')`.
/// Sur Android, les messages « notification » sont affichés automatiquement par
/// le système ; ce handler ne sert qu'aux payloads « data » éventuels.
@pragma('vm:entry-point')
Future<void> payflexFirebaseBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp();
  } catch (_) {
    // Firebase non configuré : rien à faire.
  }
}

/// Push mobile réel via Firebase Cloud Messaging (FCM).
///
/// Entièrement gardé : si Firebase n'est pas configuré (pas de
/// `google-services.json`), [isAvailable] reste faux et l'app retombe sur le
/// poll PayFlex existant ([PayflexPushSyncService]).
class PayflexFcmService {
  PayflexFcmService._();
  static final PayflexFcmService instance = PayflexFcmService._();

  final MobileApiService _api = MobileApiService();

  bool _available = false;
  bool _initialized = false;
  String? _token;

  int? _userId;
  String? _phone;
  String? _pin;
  String _role = '';

  bool get isAvailable => _available;

  /// Initialise Firebase + les écouteurs de messages. Idempotent et non bloquant.
  Future<void> init() async {
    if (_initialized || kIsWeb) return;
    _initialized = true;
    try {
      await Firebase.initializeApp();
      _available = true;
    } catch (e) {
      _available = false;
      if (kDebugMode) {
        debugPrint('FCM indisponible (Firebase non configuré) : $e — repli sur le poll PayFlex.');
      }
      return;
    }

    try {
      FirebaseMessaging.onBackgroundMessage(payflexFirebaseBackgroundHandler);

      // Premier plan : afficher une alerte locale (FCM ne le fait pas de lui-même).
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

      // Ouverture depuis une notification : trace de debug (la navigation in-app
      // reste pilotée par le poll/inbox existant).
      FirebaseMessaging.onMessageOpenedApp.listen(_handleOpened);

      // Rafraîchissement du jeton : ré-enregistrer si une session est active.
      FirebaseMessaging.instance.onTokenRefresh.listen((token) {
        _token = token;
        _registerCurrentToken();
      });
    } catch (e) {
      if (kDebugMode) {
        debugPrint('FCM : échec configuration des écouteurs : $e');
      }
    }
  }

  /// Demande l'autorisation notifications côté FCM (iOS surtout) et récupère le jeton.
  Future<void> registerForUser({
    required int userId,
    required String phone,
    required String pin,
    String role = '',
  }) async {
    _userId = userId;
    _phone = phone;
    _pin = pin;
    _role = role;
    if (!_available) return;
    try {
      await FirebaseMessaging.instance.requestPermission();
      _token = await FirebaseMessaging.instance.getToken();
      await _registerCurrentToken();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('FCM : impossible d\'obtenir/enregistrer le jeton : $e');
      }
    }
  }

  Future<void> _registerCurrentToken() async {
    final token = _token;
    final userId = _userId;
    final phone = _phone;
    final pin = _pin;
    if (token == null || token.isEmpty || userId == null || phone == null || pin == null) {
      return;
    }
    await _api.registerFcmToken(
      userId: userId,
      phone: phone,
      pin: pin,
      fcmToken: token,
      platform: defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android',
      role: _role,
    );
  }

  /// Déconnexion : retire le jeton côté backend et oublie la session.
  Future<void> unregister() async {
    final token = _token;
    if (_available && token != null && token.isNotEmpty) {
      await _api.unregisterFcmToken(fcmToken: token);
    }
    _userId = null;
    _phone = null;
    _pin = null;
    _role = '';
  }

  void _handleForegroundMessage(RemoteMessage message) {
    final notif = message.notification;
    final title = notif?.title ?? message.data['title'];
    final body = notif?.body ?? message.data['body'] ?? '';
    if (title == null || title.isEmpty) return;
    final type = message.data['type'];
    LocalNotificationService.showPayFlexAlert(
      title: title,
      body: body,
      payload: type == 'admin_message' || (type != null && type.toString().contains('chat'))
          ? 'chat'
          : (message.data['contribution_id'] != null
              ? 'notification:${message.data['contribution_id']}'
              : 'notification'),
    );
  }

  void _handleOpened(RemoteMessage message) {
    if (kDebugMode) {
      debugPrint('FCM ouverture notification : ${message.data}');
    }
  }
}
