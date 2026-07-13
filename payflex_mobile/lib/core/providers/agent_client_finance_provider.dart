import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../calendar/calendar_day_detail.dart';
import '../calendar/calendar_plan_logic.dart';
import '../database/database_service.dart';
import '../finance/client_bonus_savings_logic.dart';
import 'agent_provider.dart';
import 'finance_provider.dart';

/// Finance d'un client vu par l'agent (même logique que l'app client).
class AgentClientFinanceState {
  final int? clientUserId;
  final bool loading;
  final Map<String, dynamic>? detail;
  final List<ProjectModel> projects;
  final List<TransactionModel> transactions;
  final Map<int, String> calendarStatuses;
  final int catchUpOrangeDaysCount;
  final int calendarViewYear;
  final int calendarViewMonth;
  final CalendarProductFilter calendarProductFilter;
  final int estimatedDaysRemaining;
  final DateTime? estimatedEndDate;
  final String calendarScopeLabel;
  final BonusSavingsSummary bonusSavings;

  AgentClientFinanceState({
    this.clientUserId,
    this.loading = false,
    this.detail,
    this.projects = const [],
    this.transactions = const [],
    this.calendarStatuses = const {},
    this.catchUpOrangeDaysCount = 0,
    int? calendarViewYear,
    int? calendarViewMonth,
    this.calendarProductFilter,
    this.estimatedDaysRemaining = 0,
    this.estimatedEndDate,
    this.calendarScopeLabel = 'Tous les articles',
    this.bonusSavings = const BonusSavingsSummary(),
  })  : calendarViewYear = calendarViewYear ?? DateTime.now().year,
        calendarViewMonth = calendarViewMonth ?? DateTime.now().month;

  bool get hasData => detail?['hasData'] == true;

  AgentClientFinanceState copyWith({
    int? clientUserId,
    bool? loading,
    Map<String, dynamic>? detail,
    List<ProjectModel>? projects,
    List<TransactionModel>? transactions,
    Map<int, String>? calendarStatuses,
    int? catchUpOrangeDaysCount,
    int? calendarViewYear,
    int? calendarViewMonth,
    CalendarProductFilter? calendarProductFilter,
    int? estimatedDaysRemaining,
    DateTime? estimatedEndDate,
    String? calendarScopeLabel,
    BonusSavingsSummary? bonusSavings,
  }) {
    return AgentClientFinanceState(
      clientUserId: clientUserId ?? this.clientUserId,
      loading: loading ?? this.loading,
      detail: detail ?? this.detail,
      projects: projects ?? this.projects,
      transactions: transactions ?? this.transactions,
      calendarStatuses: calendarStatuses ?? this.calendarStatuses,
      catchUpOrangeDaysCount: catchUpOrangeDaysCount ?? this.catchUpOrangeDaysCount,
      calendarViewYear: calendarViewYear ?? this.calendarViewYear,
      calendarViewMonth: calendarViewMonth ?? this.calendarViewMonth,
      calendarProductFilter: calendarProductFilter ?? this.calendarProductFilter,
      estimatedDaysRemaining: estimatedDaysRemaining ?? this.estimatedDaysRemaining,
      estimatedEndDate: estimatedEndDate ?? this.estimatedEndDate,
      calendarScopeLabel: calendarScopeLabel ?? this.calendarScopeLabel,
      bonusSavings: bonusSavings ?? this.bonusSavings,
    );
  }
}

class AgentClientFinanceNotifier extends Notifier<AgentClientFinanceState> {
  final DatabaseService _db = DatabaseService();
  CalendarProductFilter _productFilter;

  AgentClientFinanceNotifier() : _productFilter = null;

  @override
  AgentClientFinanceState build() => AgentClientFinanceState();

  Future<void> loadForClient(int clientUserId) async {
    if (state.clientUserId != clientUserId) {
      _productFilter = null;
    }
    await _load(clientUserId);
  }

  Future<void> reload() async {
    final id = state.clientUserId;
    if (id != null) await _load(id);
  }

  void setCalendarMonth(int year, int month) {
    state = state.copyWith(calendarViewYear: year, calendarViewMonth: month);
    _rebuildCalendar();
  }

  void setCalendarProductFilter(CalendarProductFilter projectId) {
    _productFilter = projectId;
    _rebuildCalendar();
  }

  List<ProjectModel> _scopedProjects(List<ProjectModel> all) {
    if (_productFilter == null || _productFilter!.isEmpty) return all;
    return all.where((p) => p.id == _productFilter).toList();
  }

  String _scopeLabel(List<ProjectModel> scoped) {
    if (_productFilter == null || scoped.length > 1) {
      return scoped.isEmpty ? 'Aucun article' : 'Tous les articles (${scoped.length})';
    }
    return scoped.first.title;
  }

  ({double saved, double total, double daily}) _aggregateScope(List<ProjectModel> scoped) {
    var saved = 0.0;
    var total = 0.0;
    var daily = 0.0;
    for (final p in scoped) {
      saved += p.saved;
      total += p.total;
      daily += p.dailySuggested;
    }
    return (saved: saved, total: total, daily: daily);
  }

  Future<void> _load(int clientUserId) async {
    state = state.copyWith(clientUserId: clientUserId, loading: state.detail == null);
    final detail = await ref.read(agentDataProvider.notifier).fetchClientDetail(clientUserId);
    if (detail == null || detail['hasData'] != true) {
      state = state.copyWith(loading: false, detail: detail);
      return;
    }

    final products = detail['products'] is List
        ? (detail['products'] as List).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
        : <Map<String, dynamic>>[];
    final contributions = detail['contributions'] is List
        ? (detail['contributions'] as List).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
        : <Map<String, dynamic>>[];

    await _db.syncClientFinanceForAgent(
      serverClientUserId: clientUserId,
      clientName: detail['fullName']?.toString() ?? 'Client',
      agentUserId: 0,
      products: products,
      totalProject: (detail['totalProjectFcfa'] as num?)?.toDouble() ?? 0,
      dailyContribution: (detail['dailyContributionFcfa'] as num?)?.toDouble() ?? 0,
      collected: (detail['collectedFcfa'] as num?)?.toDouble() ?? 0,
    );
    await _db.syncAgentClientContributions(clientUserId: clientUserId, contributions: contributions);

    final totalDaily = (detail['dailyContributionFcfa'] as num?)?.toDouble() ?? 0;
    final projects = products.map((raw) {
      final productId = (raw['product_id'] as num?)?.toInt();
      if (productId == null) return null;
      final pid = 'prod_$productId';
      final name = raw['name']?.toString() ?? 'Article';
      final qty = (raw['quantity'] as num?)?.toInt() ?? 1;
      final lineTotal = (raw['line_total'] as num?)?.toDouble() ?? 0;
      final collectedP = (raw['collected_fcfa'] as num?)?.toDouble() ?? 0;
      final dailyMin = (raw['daily_min'] as num?)?.toDouble() ?? 0;
      final lineDaily = dailyMin * qty;
      return ProjectModel(
        id: pid,
        title: qty > 1 ? '$name ×$qty' : name,
        saved: collectedP,
        total: lineTotal,
        dailySuggested: lineDaily > 0 ? lineDaily : (totalDaily > 0 && products.length == 1 ? totalDaily : dailyMin),
        progress: lineTotal > 0 ? collectedP / lineTotal : 0,
      );
    }).whereType<ProjectModel>().toList();

    final txData = await _db.getTransactionsForClient(clientUserId);
    final transactions = txData.map((t) => TransactionModel.fromMap(t)).toList();

    final bonusRaw = detail['bonusSavings'];
    final bonus = bonusRaw is Map
        ? BonusSavingsSummary.fromMap(Map<String, dynamic>.from(bonusRaw))
        : const BonusSavingsSummary();

    state = state.copyWith(
      loading: false,
      detail: detail,
      projects: projects,
      transactions: transactions,
      bonusSavings: bonus,
    );
    await _rebuildCalendar();
  }

  Future<void> _rebuildCalendar() async {
    final scoped = _scopedProjects(state.projects);
    final scopeLabel = _scopeLabel(scoped);
    final agg = _aggregateScope(scoped);
    var saved = agg.saved;
    var total = agg.total;
    var daily = agg.daily;
    if (_productFilter == null && state.detail != null) {
      final d = state.detail!;
      saved = (d['collectedFcfa'] as num?)?.toDouble() ?? saved;
      total = (d['totalProjectFcfa'] as num?)?.toDouble() ?? total;
      daily = (d['dailyContributionFcfa'] as num?)?.toDouble() ?? daily;
    }
    final y = state.calendarViewYear;
    final m = state.calendarViewMonth;

    Map<int, String> statuses = {};
    var orangeCurrentMonth = 0;
    var estimatedDays = 0;
    DateTime? estimatedEnd;

    if (scoped.isNotEmpty && daily > 0) {
      estimatedDays = CalendarPlanLogic.estimateDaysRemaining(
        targetAmount: total,
        savedAmount: saved,
        dailySuggested: daily,
      );
      estimatedEnd = CalendarPlanLogic.estimateEndDate(
        targetAmount: total,
        savedAmount: saved,
        dailySuggested: daily,
      );

      final validatedCatchUp = <int>{};
      final pendingCatchUp = <int>{};
      for (final p in scoped) {
        validatedCatchUp.addAll(await _db.getValidatedCatchupDaysForMonth(p.id, y, m));
        pendingCatchUp.addAll(await _db.getPendingCatchupDaysForMonth(p.id, y, m));
      }

      statuses = CalendarPlanLogic.buildDayStatuses(
        savedAmount: saved,
        dailySuggested: daily,
        validatedCatchUpDaysInMonth: validatedCatchUp,
        year: y,
        month: m,
        pendingCatchUpDays: pendingCatchUp,
      );

      final now = DateTime.now();
      final validatedNow = <int>{};
      final pendingNow = <int>{};
      for (final p in scoped) {
        validatedNow.addAll(await _db.getValidatedCatchupDaysForMonth(p.id, now.year, now.month));
        pendingNow.addAll(await _db.getPendingCatchupDaysForMonth(p.id, now.year, now.month));
      }
      final stNow = CalendarPlanLogic.buildDayStatuses(
        savedAmount: saved,
        dailySuggested: daily,
        validatedCatchUpDaysInMonth: validatedNow,
        year: now.year,
        month: now.month,
        pendingCatchUpDays: pendingNow,
      );
      orangeCurrentMonth = CalendarPlanLogic.countGaps(stNow);
    }

    state = state.copyWith(
      calendarStatuses: statuses,
      catchUpOrangeDaysCount: orangeCurrentMonth,
      estimatedDaysRemaining: estimatedDays,
      estimatedEndDate: estimatedEnd,
      calendarScopeLabel: scopeLabel,
      calendarProductFilter: _productFilter,
    );
  }

  Future<CalendarDayDetail> buildCalendarDayDetail({
    required int day,
    required int year,
    required int month,
    required String status,
  }) async {
    final scoped = _scopedProjects(state.projects);
    final scopeLabel = _scopeLabel(scoped);
    final agg = _aggregateScope(scoped);
    final projectIds = scoped.map((p) => p.id).toList();

    final today = DateTime.now();
    final cellDate = DateTime(year, month, day);
    final isFuture = cellDate.isAfter(DateTime(today.year, today.month, today.day));

    final statusLabel = switch (status) {
      'vert' => 'À jour',
      'orange' => 'Rattrapage',
      'bleu' => 'Anticipé',
      'gris' => 'Non payé',
      _ => 'À venir',
    };
    final isAnticipated = status == 'bleu' || (status == 'vert' && isFuture);
    final isCatchup = status == 'orange';
    final isGap = status == 'gris';

    final tx = await _db.findCatchupTransactionForDay(
      projectIds: projectIds,
      year: year,
      month: month,
      day: day,
    );

    String? contributionDate;
    String? paymentModeLabel;
    double? contributionAmount;
    String? referenceCode;
    String? productName;
    var coverageNote = '';

    if (tx != null) {
      final rawDate = tx['date']?.toString() ?? '';
      final parsed = DateTime.tryParse(rawDate);
      contributionDate = parsed != null
          ? '${parsed.day.toString().padLeft(2, '0')}/${parsed.month.toString().padLeft(2, '0')}/${parsed.year}'
          : rawDate;
      contributionAmount = (tx['amount'] as num?)?.toDouble();
      referenceCode = tx['id']?.toString();
      productName = tx['product_title']?.toString();
      final mode = tx['type']?.toString() ?? '';
      paymentModeLabel = mode == 'cash' ? 'Espèces' : 'Mobile money';
      final st = tx['status']?.toString() ?? '';
      if (st == 'pending') {
        coverageNote = 'Versement en attente de validation.';
      }
    } else if (status == 'bleu' || (status == 'vert' && !isCatchup)) {
      coverageNote = isAnticipated
          ? 'Jour couvert par l\'épargne cumulée (anticipé).'
          : 'Jour couvert selon le rythme journalier.';
    } else if (isGap) {
      coverageNote = 'Aucune cotisation pour couvrir cette date.';
    } else if (isCatchup) {
      coverageNote = 'Date passée non couverte — rattrapage possible.';
    }

    return CalendarDayDetail(
      day: day,
      year: year,
      month: month,
      status: status,
      statusLabel: statusLabel,
      isAnticipated: isAnticipated,
      isCatchup: isCatchup,
      isGap: isGap,
      dailyAmount: agg.daily,
      scopeLabel: scopeLabel,
      contributionDate: contributionDate,
      paymentModeLabel: paymentModeLabel,
      contributionAmount: contributionAmount,
      referenceCode: referenceCode,
      productName: productName,
      coverageNote: coverageNote,
    );
  }
}

final agentClientFinanceProvider =
    NotifierProvider<AgentClientFinanceNotifier, AgentClientFinanceState>(AgentClientFinanceNotifier.new);

/// Sélecteur pratique quand l'écran connaît l'id client affiché.
AgentClientFinanceState watchAgentClientFinance(WidgetRef ref, int clientUserId) {
  final fin = ref.watch(agentClientFinanceProvider);
  if (fin.clientUserId != clientUserId) {
    Future.microtask(() => ref.read(agentClientFinanceProvider.notifier).loadForClient(clientUserId));
  }
  return fin;
}
