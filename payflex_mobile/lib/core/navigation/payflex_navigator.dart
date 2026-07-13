import 'dart:async';

import 'package:flutter/material.dart';

import '../services/session_timeout_service.dart';

/// Clé globale pour afficher des dialogues après une navigation (login, splash, etc.).
final payflexRootNavigatorKey = GlobalKey<NavigatorState>();

/// Enregistre la navigation comme activité utilisateur.
class PayflexSessionActivityObserver extends NavigatorObserver {
  void _bump() => unawaited(SessionTimeoutService.instance.recordActivity());

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) => _bump();

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) => _bump();

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) => _bump();
}

void showSessionExpiredSnackBar(BuildContext? context) {
  if (context == null) return;
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text('Session expirée pour votre sécurité. Reconnectez-vous.'),
      duration: Duration(seconds: 4),
    ),
  );
}
