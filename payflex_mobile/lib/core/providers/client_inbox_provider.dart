import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../network/mobile_api_service.dart';
import '../services/payflex_poll_config.dart';
import 'auth_provider.dart';
import 'payflex_auth_poll.dart';

class ClientInboxState {
  final int chatUnread;
  final int notificationsUnread;
  final String? bannerTitle;
  final String? bannerBody;
  final String? bannerType;
  final bool isLoading;
  final bool bannerDismissed;

  const ClientInboxState({
    this.chatUnread = 0,
    this.notificationsUnread = 0,
    this.bannerTitle,
    this.bannerBody,
    this.bannerType,
    this.isLoading = false,
    this.bannerDismissed = false,
  });

  bool get hasBanner =>
      !bannerDismissed &&
      bannerTitle != null &&
      bannerTitle!.isNotEmpty &&
      bannerBody != null &&
      bannerBody!.isNotEmpty;

  ClientInboxState copyWith({
    int? chatUnread,
    int? notificationsUnread,
    String? bannerTitle,
    String? bannerBody,
    String? bannerType,
    bool? isLoading,
    bool? bannerDismissed,
    bool clearBanner = false,
  }) {
    return ClientInboxState(
      chatUnread: chatUnread ?? this.chatUnread,
      notificationsUnread: notificationsUnread ?? this.notificationsUnread,
      bannerTitle: clearBanner ? null : (bannerTitle ?? this.bannerTitle),
      bannerBody: clearBanner ? null : (bannerBody ?? this.bannerBody),
      bannerType: clearBanner ? null : (bannerType ?? this.bannerType),
      isLoading: isLoading ?? this.isLoading,
      bannerDismissed: bannerDismissed ?? this.bannerDismissed,
    );
  }
}

class ClientInboxNotifier extends Notifier<ClientInboxState> {
  final _api = MobileApiService();
  Timer? _pollTimer;

  @override
  ClientInboxState build() {
    ref.onDispose(_stopPolling);
    ref.listen<AuthState>(authProvider, (prev, next) {
      if (payflexShouldPollMobile(next)) {
        _startPollingIfNeeded();
      } else {
        _stopPolling();
        if (!next.isAuthenticated) state = const ClientInboxState();
      }
    });
    if (payflexShouldPollMobile(ref.read(authProvider))) {
      Future.microtask(() {
        _startPollingIfNeeded();
        refresh(silent: false);
      });
    }
    return const ClientInboxState(isLoading: true);
  }

  void _startPollingIfNeeded() {
    if (_pollTimer != null) return;
    _pollTimer = Timer.periodic(PayflexPollConfig.inboxSummary, (_) => refresh(silent: true));
  }

  void _stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  Future<void> refresh({bool silent = false}) async {
    final auth = ref.read(authProvider);
    if ((auth.role != 'client' && auth.role != 'agent') ||
        !auth.isAuthenticated ||
        auth.userId == null ||
        auth.phone == null ||
        auth.pin == null) {
      state = const ClientInboxState();
      return;
    }

    if (!silent) {
      state = state.copyWith(isLoading: true);
    }

    final summary = await _api.fetchInboxSummary(
      userId: auth.userId!,
      phone: auth.phone!,
      pin: auth.pin!,
    );

    final chatUnread = summary.chatUnread;
    final notifUnread = summary.notificationsUnread;

    final hadBanner = state.hasBanner;
    final newBannerKey =
        '${summary.bannerType}|${summary.bannerTitle}|${summary.bannerBody}';
    final oldBannerKey = '${state.bannerType}|${state.bannerTitle}|${state.bannerBody}';

    state = ClientInboxState(
      chatUnread: chatUnread,
      notificationsUnread: notifUnread,
      bannerTitle: summary.bannerTitle,
      bannerBody: summary.bannerBody,
      bannerType: summary.bannerType,
      isLoading: false,
      bannerDismissed: hadBanner && newBannerKey != oldBannerKey ? false : state.bannerDismissed,
    );
  }

  void dismissBanner() {
    state = state.copyWith(bannerDismissed: true);
  }

  Future<void> markChatRead() async {
    final auth = ref.read(authProvider);
    if (auth.userId == null || auth.phone == null || auth.pin == null) return;
    await _api.markSupportChatRead(
      userId: auth.userId!,
      phone: auth.phone!,
      pin: auth.pin!,
    );
    await refresh(silent: true);
  }
}

final clientInboxProvider =
    NotifierProvider<ClientInboxNotifier, ClientInboxState>(() {
  return ClientInboxNotifier();
});
