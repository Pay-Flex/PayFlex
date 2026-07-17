import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../calendar/calendar_day_detail.dart';
import '../calendar/calendar_plan_logic.dart';
import '../database/database_service.dart';
import '../finance/client_bonus_savings_logic.dart';
import '../network/mobile_api_service.dart';
import 'auth_provider.dart';

/// `null` = tous les articles combinés ; sinon id projet (`prod_12`).
typedef CalendarProductFilter = String?;

class FinanceState {
  final double balance;
  final List<ProjectModel> projects;
  final List<TransactionModel> transactions;
  final Map<int, String> calendarStatuses;
  /// Jours encore en orange sur le mois civil en cours (pour l’accueil).
  final int catchUpOrangeDaysCount;
  final int calendarViewYear;
  final int calendarViewMonth;
  /// Projet utilisé pour le carnet (profil courant ou premier projet).
  final ProjectModel? calendarActiveProject;
  /// Filtre carnet : null = combiné, sinon un article précis.
  final CalendarProductFilter calendarProductFilter;
  final int estimatedDaysRemaining;
  final DateTime? estimatedEndDate;
  final String calendarScopeLabel;
  final BonusSavingsSummary bonusSavings;

  /// `true` lorsque la dernière synchro serveur a échoué (réseau) : les données
  /// affichées proviennent du cache local SQLite.
  final bool isOffline;

  FinanceState({
    required this.balance,
    required this.projects,
    required this.transactions,
    this.calendarStatuses = const {},
    this.catchUpOrangeDaysCount = 0,
    int? calendarViewYear,
    int? calendarViewMonth,
    this.calendarActiveProject,
    this.calendarProductFilter,
    this.estimatedDaysRemaining = 0,
    this.estimatedEndDate,
    this.calendarScopeLabel = 'Tous les articles',
    this.bonusSavings = const BonusSavingsSummary(),
    this.isOffline = false,
  })  : calendarViewYear = calendarViewYear ?? DateTime.now().year,
        calendarViewMonth = calendarViewMonth ?? DateTime.now().month;

  FinanceState copyWith({
    double? balance,
    List<ProjectModel>? projects,
    List<TransactionModel>? transactions,
    Map<int, String>? calendarStatuses,
    int? catchUpOrangeDaysCount,
    int? calendarViewYear,
    int? calendarViewMonth,
    ProjectModel? calendarActiveProject,
    CalendarProductFilter? calendarProductFilter,
    int? estimatedDaysRemaining,
    DateTime? estimatedEndDate,
    String? calendarScopeLabel,
    BonusSavingsSummary? bonusSavings,
    bool? isOffline,
  }) {
    return FinanceState(
      balance: balance ?? this.balance,
      projects: projects ?? this.projects,
      transactions: transactions ?? this.transactions,
      calendarStatuses: calendarStatuses ?? this.calendarStatuses,
      catchUpOrangeDaysCount: catchUpOrangeDaysCount ?? this.catchUpOrangeDaysCount,
      calendarViewYear: calendarViewYear ?? this.calendarViewYear,
      calendarViewMonth: calendarViewMonth ?? this.calendarViewMonth,
      calendarActiveProject: calendarActiveProject ?? this.calendarActiveProject,
      calendarProductFilter: calendarProductFilter ?? this.calendarProductFilter,
      estimatedDaysRemaining: estimatedDaysRemaining ?? this.estimatedDaysRemaining,
      estimatedEndDate: estimatedEndDate ?? this.estimatedEndDate,
      calendarScopeLabel: calendarScopeLabel ?? this.calendarScopeLabel,
      bonusSavings: bonusSavings ?? this.bonusSavings,
      isOffline: isOffline ?? this.isOffline,
    );
  }
}

class ProjectModel {
  final String id;
  final String title;
  final double saved;
  final double total;
  final double dailySuggested;
  final double progress;

  ProjectModel({
    required this.id,
    required this.title,
    required this.saved,
    required this.total,
    required this.dailySuggested,
    required this.progress,
  });
}

class TransactionModel {
  final String id;
  final String title;
  final String date;
  final double amount;
  final String status;
  final String? rejectionReason;

  /// Non nul si cette ligne provient d'un paiement réparti automatiquement entre
  /// plusieurs produits (excédent cascadé) — sert à afficher le tag « répartition
  /// automatique » et à retrouver les autres lignes du même paiement.
  final int? allocationGroupId;

  TransactionModel({
    required this.id,
    required this.title,
    required this.date,
    required this.amount,
    required this.status,
    this.rejectionReason,
    this.allocationGroupId,
  });

  factory TransactionModel.fromMap(Map<String, dynamic> map) {
    return TransactionModel(
      id: map['id'] as String,
      title: map['project_id'] ?? 'Cotisation',
      date: map['date'] as String,
      amount: (map['amount'] as num?)?.toDouble() ?? 0,
      status: map['status'] as String? ?? 'validated',
      rejectionReason: map['rejection_reason'] as String?,
      allocationGroupId: (map['allocation_group_id'] as num?)?.toInt(),
    );
  }
}

class FinanceNotifier extends Notifier<FinanceState> {
  final DatabaseService _db = DatabaseService();
  final MobileApiService _api = MobileApiService();
  int _calendarYear = DateTime.now().year;
  int _calendarMonth = DateTime.now().month;
  CalendarProductFilter _calendarProductFilter;

  FinanceNotifier() : _calendarProductFilter = null;

  @override
  FinanceState build() {
    _loadData();
    return FinanceState(balance: 0, projects: [], transactions: []);
  }

  Future<void> reload() => _loadData();

  void setCalendarMonth(int year, int month) {
    _calendarYear = year;
    _calendarMonth = month;
    _loadData();
  }

  void setCalendarProductFilter(CalendarProductFilter projectId) {
    _calendarProductFilter = projectId;
    _loadData();
  }

  List<ProjectModel> _scopedProjects(List<ProjectModel> all) {
    if (_calendarProductFilter == null || _calendarProductFilter!.isEmpty) {
      return all;
    }
    return all.where((p) => p.id == _calendarProductFilter).toList();
  }

  String _scopeLabel(List<ProjectModel> scoped) {
    if (_calendarProductFilter == null || scoped.length > 1) {
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

  Future<void> _loadData() async {
    final offline = await _syncFromServerIfPossible();
    final projectsData = await _db.getProjects();
    final transactionsData = await _db.getTransactions();

    double totalBalance = 0;

    final projects = projectsData.map((p) {
      final saved = (p['saved_amount'] as num?)?.toDouble() ?? 0;
      final total = (p['target_amount'] as num?)?.toDouble() ?? 0;
      final dailySuggested = (p['daily_suggested'] as num?)?.toDouble() ?? 0;
      totalBalance += saved;

      return ProjectModel(
        id: p['id'].toString(),
        title: p['title'] as String,
        saved: saved,
        total: total,
        dailySuggested: dailySuggested,
        progress: total > 0 ? saved / total : 0,
      );
    }).toList();

    final transactions = transactionsData.map((t) => TransactionModel.fromMap(t)).toList();

    final activePid = await _db.resolveActiveProjectId(projectsData);
    ProjectModel? activeProject;
    if (activePid != null) {
      try {
        activeProject = projects.firstWhere((p) => p.id == activePid);
      } catch (_) {
        activeProject = projects.isNotEmpty ? projects.first : null;
      }
    } else {
      activeProject = projects.isNotEmpty ? projects.first : null;
    }

    Map<int, String> statuses = {};
    var orangeCurrentMonth = 0;
    var estimatedDays = 0;
    DateTime? estimatedEnd;
    final scoped = _scopedProjects(projects);
    final scopeLabel = _scopeLabel(scoped);
    final agg = _aggregateScope(scoped);

    if (scoped.isNotEmpty && agg.daily > 0) {
      estimatedDays = CalendarPlanLogic.estimateDaysRemaining(
        targetAmount: agg.total,
        savedAmount: agg.saved,
        dailySuggested: agg.daily,
      );
      estimatedEnd = CalendarPlanLogic.estimateEndDate(
        targetAmount: agg.total,
        savedAmount: agg.saved,
        dailySuggested: agg.daily,
      );

      final validatedCatchUp = <int>{};
      final pendingCatchUp = <int>{};
      for (final p in scoped) {
        validatedCatchUp.addAll(
          await _db.getValidatedCatchupDaysForMonth(p.id, _calendarYear, _calendarMonth),
        );
        pendingCatchUp.addAll(
          await _db.getPendingCatchupDaysForMonth(p.id, _calendarYear, _calendarMonth),
        );
      }

      statuses = CalendarPlanLogic.buildDayStatuses(
        savedAmount: agg.saved,
        dailySuggested: agg.daily,
        validatedCatchUpDaysInMonth: validatedCatchUp,
        year: _calendarYear,
        month: _calendarMonth,
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
        savedAmount: agg.saved,
        dailySuggested: agg.daily,
        validatedCatchUpDaysInMonth: validatedNow,
        year: now.year,
        month: now.month,
        pendingCatchUpDays: pendingNow,
      );
      orangeCurrentMonth = CalendarPlanLogic.countGaps(stNow);
    }

    final bonusSavings = await _resolveBonusSavings(
      projects: projects,
      transactions: transactions,
      totalDaily: agg.daily > 0 ? agg.daily : projects.fold(0.0, (s, p) => s + p.dailySuggested),
    );

    state = state.copyWith(
      balance: totalBalance,
      projects: projects,
      transactions: transactions,
      calendarStatuses: statuses,
      catchUpOrangeDaysCount: orangeCurrentMonth,
      calendarViewYear: _calendarYear,
      calendarViewMonth: _calendarMonth,
      calendarActiveProject: activeProject,
      calendarProductFilter: _calendarProductFilter,
      estimatedDaysRemaining: estimatedDays,
      estimatedEndDate: estimatedEnd,
      calendarScopeLabel: scopeLabel,
      bonusSavings: bonusSavings,
      isOffline: offline,
    );

    _pushCatchupSnapshotIfNeeded(orangeCurrentMonth);
  }

  Future<BonusSavingsSummary> _resolveBonusSavings({
    required List<ProjectModel> projects,
    required List<TransactionModel> transactions,
    required double totalDaily,
  }) async {
    try {
      final auth = ref.read(authProvider);
      final uid = auth.userId;
      final phone = auth.phone;
      final pin = auth.pin;
      if (auth.isAuthenticated &&
          auth.role == 'client' &&
          uid != null &&
          phone != null &&
          pin != null &&
          pin.isNotEmpty) {
        final remote = await _api.fetchBonusSavings(userId: uid, phone: phone, pin: pin);
        if (remote != null) return BonusSavingsSummary.fromMap(remote);
      }
    } catch (_) {}

    final now = DateTime.now();
    final monthly = ClientBonusSavingsLogic.monthlyClientBonus(totalDaily);
    final lines = projects
        .map(
          (p) => BonusSavingsLine(
            productName: p.title,
            quantity: 1,
            unitDailyMin: p.dailySuggested,
            monthlyBonus: ClientBonusSavingsLogic.monthlyLineBonus(
              unitDailyMin: p.dailySuggested,
              quantity: 1,
            ),
          ),
        )
        .toList();
    return BonusSavingsSummary(
      accruedFcfa: 0,
      monthlyFcfa: monthly,
      activeMonths: 0,
      officialDaysThisMonth: ClientBonusSavingsLogic.officialDaysInMonth(now.year, now.month),
      dailyContribution: totalDaily,
      lines: lines,
      creditedInDatabase: false,
    );
  }

  /// Retourne `true` si le serveur était injoignable (mode hors-ligne, cache
  /// local conservé). Retourne `false` si la synchro a réussi ou n'était pas
  /// applicable (utilisateur non authentifié).
  Future<bool> _syncFromServerIfPossible() async {
    final auth = ref.read(authProvider);
    final uid = auth.userId;
    final phone = auth.phone;
    final pin = auth.pin;
    if (!auth.isAuthenticated ||
        auth.role != 'client' ||
        uid == null ||
        phone == null ||
        pin == null ||
        pin.isEmpty) {
      return false;
    }
    try {
      final items = await _api.fetchContributionHistory(userId: uid, phone: phone, pin: pin);
      await _db.replaceFinanceFromServer(userId: uid, contributions: items);
      return false;
    } catch (_) {
      // Hors-ligne: on garde le cache local.
      return true;
    }
  }

  void _pushCatchupSnapshotIfNeeded(int orangeCount) {
    try {
      final auth = ref.read(authProvider);
      if (!auth.isAuthenticated || auth.userId == null) return;
      final phone = auth.phone;
      final pin = auth.pin;
      if (phone == null || pin == null || phone.isEmpty || pin.isEmpty) return;
      final now = DateTime.now();
      final ym = '${now.year}-${now.month.toString().padLeft(2, '0')}';
      unawaited(
        MobileApiService().postCatchupSnapshot(
          userId: auth.userId!,
          phone: phone,
          pin: pin,
          orangeDays: orangeCount,
          yearMonth: ym,
        ),
      );
    } catch (_) {}
  }

  /// Cotisation libre (montant au choix).
  Future<bool> addContribution(
    double amount, {
    required String paymentMode,
    int? contributorUserId,
    String? transactionId,
  }) async {
    final newId = transactionId ?? DateTime.now().millisecondsSinceEpoch.toString();
    final dateStr = DateTime.now().toIso8601String();

    final projectId = await _db.resolveProjectIdForContribution(clientUserId: contributorUserId);
    if (projectId == null || projectId.isEmpty) {
      return false;
    }
    final type = paymentMode == 'cash' ? 'cash' : 'mobile_money';
    final status = paymentMode == 'cash' ? 'validated' : 'pending';

    await _db.addTransaction(
      newId,
      projectId,
      amount,
      dateStr,
      type,
      status,
      clientUserId: contributorUserId,
    );

    await _loadData();
    return true;
  }

  /// Applique le résultat serveur (validation / refus agent ou centre) sur le carnet local.
  Future<void> applyServerContributionStatus({
    required String contributionId,
    required String status,
    String? rejectionReason,
  }) async {
    await _db.updateTransactionStatus(
      contributionId,
      status,
      reason: rejectionReason,
    );
    await _loadData();
  }

  /// Rattrapage pour un jour précis du carnet (montant = cotisation journalière du projet).
  Future<bool> applyCatchUpForDay({
    required int year,
    required int month,
    required int day,
    required String paymentMode,
    int? contributorUserId,
  }) async {
    String? projectId = _calendarProductFilter;
    if (projectId == null || projectId.isEmpty) {
      projectId = await _db.resolveProjectIdForContribution(clientUserId: contributorUserId);
    }
    if (projectId == null || projectId.isEmpty) return false;

    final pmap = await _db.getProjectById(projectId);
    if (pmap == null) return false;
    final daily = (pmap['daily_suggested'] as num?)?.toDouble() ?? 0;
    if (daily <= 0) return false;

    String newId = '${DateTime.now().millisecondsSinceEpoch}_cu';
    final dateStr = DateTime.now().toIso8601String();
    final type = paymentMode == 'cash' ? 'cash' : 'mobile_money';
    final status = paymentMode == 'cash' ? 'validated' : 'pending';

    try {
      final auth = ref.read(authProvider);
      final authPhone = auth.phone;
      final authPin = auth.pin;
      if (auth.userId != null &&
          authPhone != null &&
          authPhone.isNotEmpty &&
          authPin != null &&
          authPin.isNotEmpty) {
        final productIdApi = int.tryParse(projectId.replaceAll(RegExp(r'[^0-9]'), ''));
        final apiRes = await _api.sendContribution(
          userId: auth.userId!,
          phone: authPhone,
          pin: authPin,
          amount: daily,
          paymentMode: type,
          productId: productIdApi,
          catchupYear: year,
          catchupMonth: month,
          catchupDay: day,
        );
          if (apiRes != null && apiRes['error'] != null) {
            return false;
          }
        final sid = apiRes?['id']?.toString();
        if (sid != null && sid.isNotEmpty) {
          newId = sid;
        }
      }
    } catch (_) {}

    await _db.addTransaction(
      newId,
      projectId,
      daily,
      dateStr,
      type,
      status,
      clientUserId: contributorUserId,
      catchupYear: year,
      catchupMonth: month,
      catchupDay: day,
    );

    await _loadData();
    return true;
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
        coverageNote = 'Versement en attente de validation agent ou centre.';
      }
    } else if (status == 'bleu' || (status == 'vert' && !isCatchup)) {
      coverageNote = isAnticipated
          ? 'Jour couvert par votre épargne cumulée (paiement anticipé sur le plan).'
          : 'Jour couvert par votre épargne cumulée selon le rythme journalier.';
    } else if (isGap) {
      coverageNote = 'Aucune cotisation enregistrée pour couvrir cette date.';
    } else if (isCatchup) {
      coverageNote = 'Date passée non couverte — vous pouvez rattraper ce jour.';
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

final financeProvider = NotifierProvider<FinanceNotifier, FinanceState>(() {
  return FinanceNotifier();
});
