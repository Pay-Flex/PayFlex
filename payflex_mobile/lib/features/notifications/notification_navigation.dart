import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/auth_provider.dart';
import '../../core/providers/navigation_provider.dart';
import '../agent/agent_client_detail_screen.dart';
import '../agent/agent_client_list_screen.dart';
import '../agent/agent_validation_queue_screen.dart';
import '../chat/chat_screen.dart';
import '../payment/adhesion_payment_screen.dart';

/// Redirige vers l’écran adapté selon le type de notification (client ou agent).
Future<void> navigateForClientNotification(
  BuildContext context,
  WidgetRef ref,
  Map<String, dynamic> notification,
) async {
  final auth = ref.read(authProvider);
  if (auth.role == 'agent') {
    await navigateForAgentNotification(context, ref, notification);
    return;
  }
  await _navigateForClientRole(context, ref, notification);
}

int? _relatedClientUserId(Map<String, dynamic> notification) {
  final raw =
      notification['related_client_user_id'] ?? notification['relatedClientUserId'];
  if (raw == null) return null;
  if (raw is int) return raw > 0 ? raw : null;
  if (raw is num) return raw.toInt() > 0 ? raw.toInt() : null;
  return int.tryParse(raw.toString());
}

String _clientNameFromNotification(Map<String, dynamic> notification) {
  final title = (notification['title'] ?? '').toString().trim();
  final parts = title.split('—');
  if (parts.length >= 2) {
    return parts.last.trim();
  }
  final body = (notification['body'] ?? '').toString();
  final m = RegExp(r'client\s+([^\.]+)', caseSensitive: false).firstMatch(body);
  if (m != null) return m.group(1)!.trim();
  return 'Client';
}

Future<void> _openAgentClientContext(
  BuildContext context,
  Map<String, dynamic> notification,
) async {
  final clientId = _relatedClientUserId(notification);
  final name = _clientNameFromNotification(notification);
  if (clientId != null) {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AgentClientDetailScreen(
          clientId: clientId,
          name: name,
          zone: '',
        ),
      ),
    );
    return;
  }
  await Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => const AgentClientListScreen()),
  );
}

Future<void> navigateForAgentNotification(
  BuildContext context,
  WidgetRef ref,
  Map<String, dynamic> notification,
) async {
  final type = (notification['type'] ?? '').toString();
  final title = (notification['title'] ?? '').toString().toLowerCase();

  switch (type) {
    case 'agent_contribution_pending':
    case 'agent_contribution_validated':
    case 'agent_contribution_rejected':
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const AgentValidationQueueScreen()),
      );
      return;
    case 'agent_client_chat':
      await _openAgentClientContext(context, notification);
      return;
    case 'agent_client_assigned':
    case 'agent_agent_assigned':
    case 'agent_adhesion_paid':
    case 'agent_account_approved':
    case 'agent_account_rejected':
    case 'agent_account_blocked':
    case 'agent_account_reactivated':
    case 'agent_catchup_alert':
    case 'agent_bonus_savings_credited':
    case 'agent_goal_reached':
    case 'agent_delivery_closure_validated':
    case 'agent_delivery_completed':
      await _openAgentClientContext(context, notification);
      return;
    default:
      if (title.contains('valider') ||
          title.contains('cotisation') ||
          title.contains('versement')) {
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AgentValidationQueueScreen()),
        );
      } else if (title.contains('message') || type.contains('chat')) {
        await _openAgentClientContext(context, notification);
      } else if (title.contains('inscription') ||
          title.contains('adhésion') ||
          title.contains('adhesion') ||
          title.contains('client')) {
        await _openAgentClientContext(context, notification);
      }
  }
}

Future<void> _navigateForClientRole(
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
    case 'contribution_pending':
      ref.read(navigationIndexProvider.notifier).setIndex(3);
      if (context.mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      return;
    case 'account_approved':
      if (auth.needsAdhesionPayment) {
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AdhesionPaymentScreen()),
        );
      } else {
        await goHome();
      }
      return;
    case 'account_rejected':
      await goHome();
      return;
    case 'bonus_savings_credited':
      await goHome();
      return;
    case 'catchup_alert':
      ref.read(navigationIndexProvider.notifier).setIndex(3);
      if (context.mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      return;
    case 'goal_reached':
    case 'delivery_closure_validated':
    case 'delivery_completed':
      ref.read(navigationIndexProvider.notifier).setIndex(0);
      if (context.mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      return;
    case 'account_blocked':
    case 'account_reactivated':
      ref.read(navigationIndexProvider.notifier).setIndex(4);
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
