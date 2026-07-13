import 'package:flutter/foundation.dart';
import 'package:workmanager/workmanager.dart';

import '../database/database_service.dart';
import 'payflex_push_sync_service.dart';

const payflexBackgroundPushTask = 'payflex_push_poll';

@pragma('vm:entry-point')
void payflexBackgroundPushDispatcher() {
  Workmanager().executeTask((taskName, _) async {
    if (taskName != payflexBackgroundPushTask) return false;
    try {
      final session = await DatabaseService().loadRemoteSession();
      if (session == null) return true;
      final userId = session['userId'] as int?;
      final phone = session['phone'] as String?;
      final pin = session['pin'] as String?;
      if (userId == null || phone == null || pin == null) return true;
      await PayflexPushSyncService.instance.syncNow(
        userId: userId,
        phone: phone,
        pin: pin,
      );
      return true;
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('PayflexBackgroundPush: $e\n$st');
      }
      return false;
    }
  });
}

Future<void> initPayflexBackgroundPush() async {
  if (kIsWeb) return;
  await Workmanager().initialize(payflexBackgroundPushDispatcher);
}

Future<void> schedulePayflexBackgroundPush() async {
  if (kIsWeb) return;
  await Workmanager().registerPeriodicTask(
    payflexBackgroundPushTask,
    payflexBackgroundPushTask,
    frequency: const Duration(minutes: 15),
    constraints: Constraints(networkType: NetworkType.connected),
    existingWorkPolicy: ExistingWorkPolicy.keep,
  );
}

Future<void> cancelPayflexBackgroundPush() async {
  if (kIsWeb) return;
  await Workmanager().cancelByUniqueName(payflexBackgroundPushTask);
}
