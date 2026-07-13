import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/welcome_screen.dart';
import '../navigation/payflex_navigator.dart';
import '../providers/auth_provider.dart';
import '../services/payflex_background_push.dart';
import '../services/payflex_fcm_service.dart';
import '../services/payflex_push_sync_service.dart';
import '../services/session_timeout_service.dart';

/// Relance la sync push au retour au premier plan et surveille l'expiration de session.
class PayflexPushLifecycle extends ConsumerStatefulWidget {
  final Widget child;
  const PayflexPushLifecycle({super.key, required this.child});

  @override
  ConsumerState<PayflexPushLifecycle> createState() => _PayflexPushLifecycleState();
}

class _PayflexPushLifecycleState extends ConsumerState<PayflexPushLifecycle>
    with WidgetsBindingObserver {
  Timer? _inactivityTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startInactivityTimer();
  }

  @override
  void dispose() {
    _stopInactivityTimer();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
        _stopInactivityTimer();
        break;
      case AppLifecycleState.resumed:
        unawaited(_onResumed());
        break;
      case AppLifecycleState.detached:
        break;
    }
  }

  Future<void> _onResumed() async {
    final expired = await _enforceSessionTimeoutIfNeeded(showMessage: true);
    if (!mounted) return;
    if (!expired) {
      _startInactivityTimer();
      // Ne pas appeler recordActivity() ici : le retour au premier plan n'est pas une activité utilisateur.
      _syncIfLoggedIn();
    }
  }

  void _startInactivityTimer() {
    _inactivityTimer?.cancel();
    _inactivityTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      unawaited(_enforceSessionTimeoutIfNeeded(showMessage: true));
    });
  }

  void _stopInactivityTimer() {
    _inactivityTimer?.cancel();
    _inactivityTimer = null;
  }

  Future<bool> _enforceSessionTimeoutIfNeeded({required bool showMessage}) async {
    if (!await SessionTimeoutService.instance.isExpired()) return false;

    final auth = ref.read(authProvider);
    if (!auth.isAuthenticated) return false;

    await ref.read(authProvider.notifier).logout();
    if (!mounted) return true;

    payflexRootNavigatorKey.currentState?.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const WelcomeScreen()),
      (_) => false,
    );

    if (showMessage) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        showSessionExpiredSnackBar(payflexRootNavigatorKey.currentContext);
      });
    }
    return true;
  }

  void _syncIfLoggedIn() {
    final auth = ref.read(authProvider);
    if ((auth.role != 'client' && auth.role != 'agent') ||
        !auth.isAuthenticated ||
        auth.userId == null ||
        auth.phone == null ||
        auth.pin == null) {
      return;
    }
    PayflexPushSyncService.instance.syncNow(
      userId: auth.userId!,
      phone: auth.phone!,
      pin: auth.pin!,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) {
        unawaited(SessionTimeoutService.instance.recordActivity());
      },
      child: widget.child,
    );
  }
}

/// Active le push après connexion (client ou agent).
///
/// Chemin principal : FCM (push réel) via [PayflexFcmService]. Le poll PayFlex
/// est conservé comme repli (Firebase non configuré, jeton indisponible, etc.).
Future<void> activatePayflexPushForClient({
  int? userId,
  String? phone,
  String? pin,
  String role = '',
}) async {
  await schedulePayflexBackgroundPush();
  if (userId != null && userId > 0 && phone != null && pin != null) {
    // Enregistrement du jeton FCM (no-op si Firebase non configuré).
    unawaited(PayflexFcmService.instance.registerForUser(
      userId: userId,
      phone: phone,
      pin: pin,
      role: role,
    ));
    await PayflexPushSyncService.instance.syncNow(
      userId: userId,
      phone: phone,
      pin: pin,
    );
  }
}

Future<void> deactivatePayflexPush() async {
  await PayflexFcmService.instance.unregister();
  PayflexPushSyncService.instance.resetSession();
  await cancelPayflexBackgroundPush();
}
