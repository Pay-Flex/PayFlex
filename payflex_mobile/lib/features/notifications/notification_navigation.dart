import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/auth_provider.dart';
import '../../core/providers/navigation_provider.dart';
import '../chat/chat_screen.dart';
import '../payment/adhesion_payment_screen.dart';

/// Redirige vers l’écran adapté selon le type de notification.
Future<void> navigateForClientNotification(
  BuildContext context,
  WidgetRef ref,
  Map<String, dynamic> notification,
) async {
  final type = (notification['type'] ?? '').toString();
  final title = (notification['title'] ?? '').toString().toLowerCase();
  final auth = ref.read(authProvider);

  Future<void> goHome() async {
    ref.read(navigationIndexProvider.notifier).setIndex(0);
    if (context.mounted && Navigator.canPop(context)) {
      Navigator.pop(context);
    }
  }

  switch (type) {
    case 'welcome':
      if (auth.needsAdhesionPayment) {
        await Navigator.push<bool>(
          context,
          MaterialPageRoute(builder: (_) => const AdhesionPaymentScreen()),
        );
      } else {
        await goHome();
      }
      return;
    case 'adhesion_paid':
      await goHome();
      return;
    case 'admin_message':
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ChatScreen()),
      );
      return;
    case 'agent_assigned':
      ref.read(navigationIndexProvider.notifier).setIndex(4);
      if (context.mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      return;
    case 'contribution_validated':
    case 'contribution_rejected':
      ref.read(navigationIndexProvider.notifier).setIndex(3);
      if (context.mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      return;
    default:
      if (title.contains('support') || title.contains('message')) {
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ChatScreen()),
        );
      } else if (title.contains('adhésion') || title.contains('adhesion')) {
        if (auth.needsAdhesionPayment) {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AdhesionPaymentScreen()),
          );
        } else {
          await goHome();
        }
      } else if (title.contains('cotisation')) {
        ref.read(navigationIndexProvider.notifier).setIndex(3);
        if (context.mounted && Navigator.canPop(context)) {
          Navigator.pop(context);
        }
      }
  }
}
