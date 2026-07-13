import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../network/mobile_api_service.dart';
import '../services/payflex_poll_config.dart';
import 'auth_provider.dart';
import 'navigation_provider.dart';
import 'payflex_auth_poll.dart';

class AgentDataState {
  final Map<String, dynamic>? dashboard;
  final List<Map<String, dynamic>> clients;
  final List<Map<String, dynamic>> registry;
  final bool isLoading;
  final bool isRefreshing;
  final DateTime? lastUpdated;

  const AgentDataState({
    this.dashboard,
    this.clients = const [],
    this.registry = const [],
    this.isLoading = false,
    this.isRefreshing = false,
    this.lastUpdated,
  });

  bool get hasDashboard => dashboard?['hasData'] == true;

  AgentDataState copyWith({
    Map<String, dynamic>? dashboard,
    List<Map<String, dynamic>>? clients,
    List<Map<String, dynamic>>? registry,
    bool? isLoading,
    bool? isRefreshing,
    DateTime? lastUpdated,
  }) {
    return AgentDataState(
      dashboard: dashboard ?? this.dashboard,
      clients: clients ?? this.clients,
      registry: registry ?? this.registry,
      isLoading: isLoading ?? this.isLoading,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }
}

class AgentDataNotifier extends Notifier<AgentDataState> {
  final _api = MobileApiService();
  Timer? _pollTimer;

  @override
  AgentDataState build() {
    ref.onDispose(_stopPolling);
    ref.listen<AuthState>(authProvider, (prev, next) {
      if (payflexShouldPollAgent(next)) {
        _startPollingIfNeeded();
      } else {
        _stopPolling();
        if (!payflexShouldPollAgent(next)) state = const AgentDataState();
      }
    });
    if (payflexShouldPollAgent(ref.read(authProvider))) {
      Future.microtask(() {
        _startPollingIfNeeded();
        refresh(silent: false);
      });
    }
    return const AgentDataState(isLoading: true);
  }

  void _startPollingIfNeeded() {
    if (_pollTimer != null) return;
    _pollTimer = Timer.periodic(PayflexPollConfig.agentDashboard, (_) {
      final nav = ref.read(agentNavigationIndexProvider);
      if (nav <= 1) refresh(silent: true);
    });
  }

  void _stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  Future<void> refresh({bool silent = false}) async {
    final auth = ref.read(authProvider);
    if (auth.userId == null || auth.role != 'agent') return;

    if (!silent) {
      state = state.copyWith(isLoading: state.dashboard == null, isRefreshing: state.dashboard != null);
    }

    final dash = await _api.fetchAgentDashboard(
      userId: auth.userId!,
      phone: auth.phone ?? '',
      pin: auth.pin ?? '',
    );
    final remote = await _api.fetchAgentClients(
      userId: auth.userId!,
      phone: auth.phone ?? '',
      pin: auth.pin ?? '',
    );
    final registry = await _api.fetchAgentContributionRegistry(
      userId: auth.userId!,
      phone: auth.phone ?? '',
      pin: auth.pin ?? '',
    );

    final clients = <Map<String, dynamic>>[];
    if (remote != null && remote['items'] is List) {
      for (final item in remote['items'] as List) {
        if (item is Map) clients.add(Map<String, dynamic>.from(item));
      }
    }

    final registryItems = <Map<String, dynamic>>[];
    if (registry != null && registry['items'] is List) {
      for (final item in registry['items'] as List) {
        if (item is Map) registryItems.add(Map<String, dynamic>.from(item));
      }
    }

    state = state.copyWith(
      dashboard: dash,
      clients: clients,
      registry: registryItems,
      isLoading: false,
      isRefreshing: false,
      lastUpdated: DateTime.now(),
    );
  }

  Future<Map<String, dynamic>?> fetchClientDetail(int clientUserId) async {
    final auth = ref.read(authProvider);
    if (auth.userId == null) return null;
    return _api.fetchAgentClientDetail(
      userId: auth.userId!,
      phone: auth.phone ?? '',
      pin: auth.pin ?? '',
      clientUserId: clientUserId,
    );
  }
}

final agentDataProvider = NotifierProvider<AgentDataNotifier, AgentDataState>(AgentDataNotifier.new);
