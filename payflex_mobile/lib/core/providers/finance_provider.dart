import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../calendar/calendar_plan_logic.dart';
import '../database/database_service.dart';
import '../network/mobile_api_service.dart';
import 'auth_provider.dart';

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

  FinanceState({
    required this.balance,
    required this.projects,
    required this.transactions,
    this.calendarStatuses = const {},
    this.catchUpOrangeDaysCount = 0,
    int? calendarViewYear,
    int? calendarViewMonth,
    this.calendarActiveProject,
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

  TransactionModel({
    required this.id,
    required this.title,
    required this.date,
    required this.amount,
    required this.status,
    this.rejectionReason,
  });

  factory TransactionModel.fromMap(Map<String, dynamic> map) {
    return TransactionModel(
      id: map['id'] as String,
      title: map['project_id'] ?? 'Cotisation',
      date: map['date'] as String,
      amount: (map['amount'] as num?)?.toDouble() ?? 0,
      status: map['status'] as String? ?? 'validated',
      rejectionReason: map['rejection_reason'] as String?,
    );
  }
}

class FinanceNotifier extends Notifier<FinanceState> {
  final DatabaseService _db = DatabaseService();
  final MobileApiService _api = MobileApiService();
  int _calendarYear = DateTime.now().year;
  int _calendarMonth = DateTime.now().month;

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

  Future<void> _loadData() async {
    await _syncFromServerIfPossible();
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

    if (activeProject != null) {
      final catchUpView =
          await _db.getValidatedCatchupDaysForMonth(activeProject.id, _calendarYear, _calendarMonth);
      statuses = CalendarPlanLogic.buildDayStatuses(
        savedAmount: activeProject.saved,
        dailySuggested: activeProject.dailySuggested,
        validatedCatchUpDaysInMonth: catchUpView,
        year: _calendarYear,
        month: _calendarMonth,
      );

      final now = DateTime.now();
      final catchUpNow = await _db.getValidatedCatchupDaysForMonth(activeProject.id, now.year, now.month);
      final stNow = CalendarPlanLogic.buildDayStatuses(
        savedAmount: activeProject.saved,
        dailySuggested: activeProject.dailySuggested,
        validatedCatchUpDaysInMonth: catchUpNow,
        year: now.year,
        month: now.month,
      );
      orangeCurrentMonth = CalendarPlanLogic.countOrange(stNow);
    }

    state = state.copyWith(
      balance: totalBalance,
      projects: projects,
      transactions: transactions,
      calendarStatuses: statuses,
      catchUpOrangeDaysCount: orangeCurrentMonth,
      calendarViewYear: _calendarYear,
      calendarViewMonth: _calendarMonth,
      calendarActiveProject: activeProject,
    );

    _pushCatchupSnapshotIfNeeded(orangeCurrentMonth);
  }

  Future<void> _syncFromServerIfPossible() async {
    try {
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
        return;
      }
      final items = await _api.fetchContributionHistory(userId: uid, phone: phone, pin: pin);
      await _db.replaceFinanceFromServer(userId: uid, contributions: items);
    } catch (_) {
      // Hors-ligne: on garde le cache local.
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
    final projectId = await _db.resolveProjectIdForContribution(clientUserId: contributorUserId);
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
      if (auth.userId != null) {
        final productIdApi = int.tryParse(projectId.replaceAll(RegExp(r'[^0-9]'), ''));
        final apiRes = await _api.sendContribution(
          userId: auth.userId!,
          amount: daily,
          paymentMode: type,
          productId: productIdApi,
          catchupYear: year,
          catchupMonth: month,
          catchupDay: day,
        );
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
}

final financeProvider = NotifierProvider<FinanceNotifier, FinanceState>(() {
  return FinanceNotifier();
});
