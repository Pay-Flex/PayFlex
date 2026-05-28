import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Notifications locales (complément au polling) lorsque l'app est ouverte ou en arrière-plan léger.
class LocalNotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized) return;
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: android);
    await _plugin.initialize(initSettings);
    _initialized = true;
  }

  static Future<void> showPayFlexAlert({
    required String title,
    required String body,
  }) async {
    if (kIsWeb) return;
    if (!_initialized) await init();
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'payflex_alerts',
        'Alertes PayFlex',
        channelDescription: 'Messages et notifications PayFlex',
        importance: Importance.high,
        priority: Priority.high,
      ),
    );
    await _plugin.show(
      DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title,
      body.length > 200 ? '${body.substring(0, 197)}…' : body,
      details,
    );
  }
}
