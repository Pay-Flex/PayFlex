import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../navigation/payflex_navigator.dart';
import '../theme/app_typography.dart';
import 'local_notification_service.dart';

const _prefKey = 'payflex_notif_permission_prompted_v1';

BuildContext? _resolveContext(BuildContext? context) {
  if (context != null && context.mounted) return context;
  final root = payflexRootNavigatorKey.currentContext;
  if (root != null && root.mounted) return root;
  return null;
}

/// Demande l’autorisation notifications (dialogue explicatif puis système Android/iOS).
/// Une seule fois par installation, sauf si l’utilisateur n’a pas encore été sollicité.
Future<void> requestPayflexNotificationsIfNeeded([BuildContext? context]) async {
  final ctx = _resolveContext(context);
  if (ctx == null) return;

  final prefs = await SharedPreferences.getInstance();
  if (prefs.getBool(_prefKey) == true) {
    await LocalNotificationService.requestPermissions();
    return;
  }

  final accept = await showDialog<bool>(
    context: ctx,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(
        'Restez informé',
        style: AppTypography.manrope(fontWeight: FontWeight.w800, fontSize: 18),
      ),
      content: Text(
        'PayFlex vous alerte pour les cotisations validées, les messages du centre, '
        'l’épargne bonus et les annonces importantes.\n\n'
        'Autorisez les notifications pour ne rien manquer.',
        style: AppTypography.inter(fontSize: 14, height: 1.45),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text('Plus tard', style: AppTypography.inter(fontWeight: FontWeight.w600)),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text('Activer', style: AppTypography.inter(fontWeight: FontWeight.w700)),
        ),
      ],
    ),
  );

  await prefs.setBool(_prefKey, true);
  if (accept == true) {
    await LocalNotificationService.requestPermissions();
  }
}
