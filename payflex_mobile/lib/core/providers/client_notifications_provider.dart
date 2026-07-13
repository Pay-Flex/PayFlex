import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../network/mobile_api_service.dart';
import '../services/payflex_poll_config.dart';
import 'auth_provider.dart';
import 'client_inbox_provider.dart';
import 'finance_provider.dart';
import 'payflex_auth_poll.dart';

class ClientNotificationsState {
  final int unreadCount;
  final List<Map<String, dynamic>> items;
  final bool isLoading;
  final String? lastSnackMessage;

  const ClientNotificationsState({
    this.unreadCount = 0,
    this.items = const [],
    this.isLoading = false,
    this.lastSnackMessage,
  });

  ClientNotificationsState copyWith({
    int? unreadCount,
    List<Map<String, dynamic>>? items,
    bool? isLoading,
    String? lastSnackMessage,
    bool clearSnack = false,
  }) {
    return ClientNotificationsState(
      unreadCount: unreadCount ?? this.unreadCount,
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      lastSnackMessage: clearSnack ? null : (lastSnackMessage ?? this.lastSnackMessage),
    );
  }
}

class ClientNotificationsNotifier extends Notifier<ClientNotificationsState> {
  final _api = MobileApiService();
  Timer? _pollTimer;
  final Set<int> _processedContributionIds = {};

  @override
  ClientNotificationsState build() {
    ref.onDispose(_stopPolling);
    ref.listen<AuthState>(authProvider, (prev, next) {
      if (payflexShouldPollMobile(next)) {
        _startPollingIfNeeded();
      } else {
        _stopPolling();
        if (!next.isAuthenticated) state = const ClientNotificationsState();
      }
    });
    if (payflexShouldPollMobile(ref.read(authProvider))) {
      Future.microtask(() {
        _startPollingIfNeeded();
        refresh(silent: false);
      });
    }
    return const ClientNotificationsState(isLoading: true);
  }

  void _startPollingIfNeeded() {
    if (_pollTimer != null) return;
    _pollTimer = Timer.periodic(PayflexPollConfig.notifications, (_) => refresh(silent: true));
  }

  void _stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  Future<void> refresh({bool silent = false, bool unreadOnly = true}) async {
    final auth = ref.read(authProvider);
    if ((auth.role != 'client' && auth.role != 'agent') ||
        !auth.isAuthenticated ||
        auth.userId == null ||
        auth.phone == null ||
        auth.pin == null) {
      state = const ClientNotificationsState();
      return;
    }

    if (!silent) {
      state = state.copyWith(isLoading: true);
    }

    final res = await _api.fetchClientNotifications(
      userId: auth.userId!,
      phone: auth.phone!,
      pin: auth.pin!,
      unreadOnly: unreadOnly,
    );

    String? snack;
    for (final n in res.items) {
      final type = (n['type'] ?? '').toString();
      final cid = (n['contribution_id'] as num?)?.toInt();
      if (cid == null || _processedContributionIds.contains(cid)) continue;

      if (type == 'contribution_validated') {
        await ref.read(financeProvider.notifier).applyServerContributionStatus(
          contributionId: cid.toString(),
          status: 'validated',
        );
        _processedContributionIds.add(cid);
        snack = (n['title'] ?? 'Cotisation confirmée').toString();
      } else if (type == 'contribution_rejected') {
        await ref.read(financeProvider.notifier).applyServerContributionStatus(
          contributionId: cid.toString(),
          status: 'rejected',
          rejectionReason: (n['body'] ?? '').toString(),
        );
        _processedContributionIds.add(cid);
        snack = (n['title'] ?? 'Cotisation refusée').toString();
      } else if (type == 'bonus_savings_credited') {
        await ref.read(financeProvider.notifier).reload();
        snack = (n['title'] ?? 'Épargne bonus créditée').toString();
      }
    }

    state = ClientNotificationsState(
      unreadCount: res.unreadCount,
      items: res.items,
      isLoading: false,
      lastSnackMessage: snack,
    );
  }

  Future<void> markAllRead() async {
    final auth = ref.read(authProvider);
    if (auth.userId == null || auth.phone == null || auth.pin == null) return;
    await _api.markClientNotificationsRead(
      userId: auth.userId!,
      phone: auth.phone!,
      pin: auth.pin!,
    );
    await refresh(silent: true, unreadOnly: false);
    await ref.read(clientInboxProvider.notifier).refresh(silent: true);
  }

  Future<void> markOneRead(int notificationId) async {
    final auth = ref.read(authProvider);
    if (auth.userId == null || auth.phone == null || auth.pin == null) return;
    _patchLocal(notificationId, read: true);
    await _api.markClientNotificationsRead(
      userId: auth.userId!,
      phone: auth.phone!,
      pin: auth.pin!,
      notificationIds: [notificationId],
    );
    await ref.read(clientInboxProvider.notifier).refresh(silent: true);
  }

  Future<bool> markOneUnread(int notificationId) async {
    final auth = ref.read(authProvider);
    if (auth.userId == null || auth.phone == null || auth.pin == null) return false;
    final ok = await _api.markClientNotificationsUnread(
      userId: auth.userId!,
      phone: auth.phone!,
      pin: auth.pin!,
      notificationIds: [notificationId],
    );
    if (ok) {
      _patchLocal(notificationId, read: false);
      await ref.read(clientInboxProvider.notifier).refresh(silent: true);
    }
    return ok;
  }

  Future<bool> deleteOne(int notificationId) async {
    final auth = ref.read(authProvider);
    if (auth.userId == null || auth.phone == null || auth.pin == null) return false;
    final ok = await _api.deleteClientNotification(
      userId: auth.userId!,
      phone: auth.phone!,
      pin: auth.pin!,
      notificationId: notificationId,
    );
    if (ok) {
      final next = state.items.where((n) => (n['id'] as num?)?.toInt() != notificationId).toList();
      final wasUnread = state.items.any(
        (n) => (n['id'] as num?)?.toInt() == notificationId && n['read'] != true,
      );
      state = state.copyWith(
        items: next,
        unreadCount: wasUnread ? (state.unreadCount - 1).clamp(0, 9999) : state.unreadCount,
      );
      await ref.read(clientInboxProvider.notifier).refresh(silent: true);
    }
    return ok;
  }

  Future<bool> togglePin(int notificationId) async {
    final auth = ref.read(authProvider);
    if (auth.userId == null || auth.phone == null || auth.pin == null) return false;

    final current = state.items.cast<Map<String, dynamic>?>().firstWhere(
      (n) => (n?['id'] as num?)?.toInt() == notificationId,
      orElse: () => null,
    );
    if (current == null) return false;

    final nextPinned = current['pinned'] != true;
    final ok = await _api.setClientNotificationPinned(
      userId: auth.userId!,
      phone: auth.phone!,
      pin: auth.pin!,
      notificationId: notificationId,
      pinned: nextPinned,
    );
    if (ok) {
      _patchPin(notificationId, pinned: nextPinned);
    }
    return ok;
  }

  void _patchLocal(int notificationId, {required bool read}) {
    final next = state.items.map((n) {
      if ((n['id'] as num?)?.toInt() != notificationId) return n;
      return Map<String, dynamic>.from(n)..['read'] = read;
    }).toList();
    final unread = next.where((n) => n['read'] != true).length;
    state = state.copyWith(items: next, unreadCount: unread);
  }

  void _patchPin(int notificationId, {required bool pinned}) {
    final next = state.items.map((n) {
      if ((n['id'] as num?)?.toInt() != notificationId) return n;
      return Map<String, dynamic>.from(n)..['pinned'] = pinned;
    }).toList();
    next.sort((a, b) {
      final ap = a['pinned'] == true ? 1 : 0;
      final bp = b['pinned'] == true ? 1 : 0;
      if (ap != bp) return bp.compareTo(ap);
      return 0;
    });
    state = state.copyWith(items: next);
  }

  void clearSnack() {
    state = state.copyWith(clearSnack: true);
  }
}

final clientNotificationsProvider =
    NotifierProvider<ClientNotificationsNotifier, ClientNotificationsState>(() {
  return ClientNotificationsNotifier();
});
