import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../database/database_service.dart';
import '../network/mobile_api_service.dart';
import 'local_notification_service.dart';

/// Push PayFlex sans Firebase : le serveur écrit dans `client_notifications`,
/// l'app interroge l'API et affiche des [LocalNotificationService].
class PayflexPushSyncService {
  PayflexPushSyncService._();
  static final PayflexPushSyncService instance = PayflexPushSyncService._();

  final _db = DatabaseService();
  /// Client HTTP sans suivi d'activité — la sync push ne doit pas prolonger la session.
  final _api = MobileApiService(client: http.Client());
  final Set<int> _shownNotificationIds = {};
  int _lastChatUnread = 0;

  /// À appeler après connexion client et au retour au premier plan.
  Future<void> syncNow({
    required int userId,
    required String phone,
    required String pin,
  }) async {
    if (kIsWeb) return;
    await LocalNotificationService.init();

    final cursor = await _db.loadPushCursor(userId);
    var lastNotifId = cursor?.notificationId ?? 0;

    final poll = await _api.pollPushInbox(
      userId: userId,
      phone: phone,
      pin: pin,
      afterNotificationId: lastNotifId,
    );
    if (poll == null) return;

    for (final n in poll.newNotifications) {
      final id = (n['id'] as num?)?.toInt();
      if (id == null || id <= 0) continue;
      if (_shownNotificationIds.contains(id)) continue;
      final title = (n['title'] ?? 'PayFlex').toString();
      final body = (n['body'] ?? '').toString();
      if (body.isEmpty) continue;
      await LocalNotificationService.showPayFlexAlert(
        title: title,
        body: body,
        payload: 'notification:$id',
      );
      _shownNotificationIds.add(id);
      if (id > lastNotifId) lastNotifId = id;
    }

    final chatUnread = poll.chatUnread;
    if (poll.latestChatPreview != null &&
        poll.latestChatPreview!.isNotEmpty &&
        chatUnread > _lastChatUnread) {
      await LocalNotificationService.showPayFlexAlert(
        title: poll.latestChatTitle ?? 'Message PayFlex',
        body: poll.latestChatPreview!,
        payload: 'chat',
      );
    }
    _lastChatUnread = chatUnread;

    await _db.savePushCursor(
      userId: userId,
      notificationId: poll.latestNotificationId > lastNotifId
          ? poll.latestNotificationId
          : lastNotifId,
    );
  }

  void resetSession() {
    _shownNotificationIds.clear();
    _lastChatUnread = 0;
  }
}
