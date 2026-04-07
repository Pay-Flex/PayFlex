import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/database_service.dart';

class FinanceState {
  final double balance;
  final List<ProjectModel> projects;
  final List<TransactionModel> transactions;
  final Map<int, String> calendarStatuses; // 'vert', 'orange', 'bleu', 'gris'

  FinanceState({
    required this.balance,
    required this.projects,
    required this.transactions,
    this.calendarStatuses = const {},
  });

  FinanceState copyWith({
    double? balance,
    List<ProjectModel>? projects,
    List<TransactionModel>? transactions,
    Map<int, String>? calendarStatuses,
  }) {
    return FinanceState(
      balance: balance ?? this.balance,
      projects: projects ?? this.projects,
      transactions: transactions ?? this.transactions,
      calendarStatuses: calendarStatuses ?? this.calendarStatuses,
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

  TransactionModel({
    required this.id,
    required this.title,
    required this.date,
    required this.amount,
  });

  factory TransactionModel.fromMap(Map<String, dynamic> map) {
    return TransactionModel(
      id: map['id'] as String,
      title: map['project_id'] ?? 'Cotisation', // Idéalement jointure DB
      date: map['date'] as String,
      amount: map['amount'] as double,
    );
  }
}

class FinanceNotifier extends Notifier<FinanceState> {
  final DatabaseService _db = DatabaseService();

  @override
  FinanceState build() {
    _loadData();
    return FinanceState(balance: 0, projects: [], transactions: []);
  }

  Future<void> _loadData() async {
    final projectsData = await _db.getProjects();
    
    // Si la base est vierge (premier lancement), on injecte un projet de démo !
    if (projectsData.isEmpty) {
      await _db.addProject('1', 'Moto Jakarta X-200', 450000, 2000); // 2000 Fcfa par jour
      // On recharge
      final pData = await _db.getProjects();
      projectsData.addAll(pData);
    }
    
    final transactionsData = await _db.getTransactions();

    double totalBalance = 0;
    
    final projects = projectsData.map((p) {
      final saved = p['saved_amount'] as double;
      final total = p['target_amount'] as double;
      final dailySuggested = p['daily_suggested'] as double;
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
    
    // -- ALGORITHME DU CARNET DIGITAL --
    Map<int, String> statuses = {};
    if (projects.isNotEmpty) {
      final activeProject = projects.first; // On prend le premier projet comme ref
      final int casesPayed = activeProject.dailySuggested > 0 
          ? (activeProject.saved / activeProject.dailySuggested).floor() 
          : 0;
          
      final int currentDay = DateTime.now().day; // Jour actuel
      
      for (int i = 1; i <= 31; i++) {
        if (i <= casesPayed) {
          // La case est payée
          if (i > currentDay) {
            statuses[i] = 'bleu'; // Payé en avance
          } else {
            // Pour faire simple: vert = à jour, orange = rattrapage (on simule ici)
            statuses[i] = 'vert'; 
          }
        } else {
          // La case n'est pas encore payée
          if (i < currentDay) {
             statuses[i] = 'orange'; // En retard / Rattrapage nécessaire
          } else {
             statuses[i] = 'gris'; // En attente
          }
        }
      }
    }

    state = state.copyWith(
      balance: totalBalance,
      projects: projects,
      transactions: transactions,
      calendarStatuses: statuses,
    );
  }

  Future<void> addTransaction(double amount, String projectTitle) async {
    final newId = DateTime.now().millisecondsSinceEpoch.toString();
    final String dateStr = 'Aujourd\'hui'; // Idéalement format Date
    
    // 1. Sauvegarde SQLite
    await _db.addTransaction(
      newId, 
      projectTitle, 
      amount, 
      dateStr, 
      'mobile_money', 
      'normal'
    );
    
    // 2. Mise à jour de l'objectif du projet
    // On trouve le projet (mock: id 1 ou on cherche par nom)
    await _db.updateProjectSavedAmount('1', amount);
    
    // 3. Rafraîchissement complet pour relancer l'algo des cases
    await _loadData();
  }
}

final financeProvider = NotifierProvider<FinanceNotifier, FinanceState>(() {
  return FinanceNotifier();
});
