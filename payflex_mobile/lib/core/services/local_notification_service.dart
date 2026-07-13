import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Color;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';


/// Alertes système affichées par l'app après sync API (push PayFlex sans Firebase).
class LocalNotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized) return;
    const android = AndroidInitializationSettings('@drawable/ic_stat_payflex');
    const darwin = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const initSettings = InitializationSettings(
      android: android,
      iOS: darwin,
      macOS: darwin,
    );
    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (details) {
        if (kDebugMode) {
          debugPrint('Notification tap: ${details.payload}');
        }
      },
    );
    _initialized = true;
  }

  static Future<void> requestPermissions() async {
    if (kIsWeb || !_initialized) return;
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.requestNotificationsPermission();
    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    await ios?.requestPermissions(alert: true, badge: true, sound: true);
  }

  static Future<void> showPayFlexAlert({
    required String title,
    required String body,
    String? payload,
  }) async {
    if (kIsWeb) return;
    if (!_initialized) await init();
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'payflex_alerts_v2',
        'Alertes PayFlex',
        channelDescription: 'Messages et notifications PayFlex',
        importance: Importance.high,
        priority: Priority.high,
        icon: 'ic_stat_payflex',
        color: Color(0xFFF9A825),
        largeIcon: DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
      ),
    );
    await _plugin.show(
      DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title,
      body.length > 200 ? '${body.substring(0, 197)}…' : body,
      details,
      payload: payload,
    );
  }
}
