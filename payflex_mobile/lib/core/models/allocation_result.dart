import '../utils/money_format.dart';

/// Une ligne de répartition : une partie du paiement affectée à un produit donné.
/// Correspond à une ligne `contributions` + `contribution_allocations` côté backend.
class AllocationLine {
  const AllocationLine({
    required this.contributionId,
    required this.productId,
    required this.productName,
    required this.amountFcfa,
    required this.goalReachedNow,
  });

  final int contributionId;
  final int productId;
  final String productName;
  final double amountFcfa;
  final bool goalReachedNow;

  factory AllocationLine.fromJson(Map<String, dynamic> json) {
    return AllocationLine(
      contributionId: (json['contributionId'] as num?)?.toInt() ?? 0,
      productId: (json['productId'] as num?)?.toInt() ?? 0,
      productName: json['productName']?.toString().trim().isNotEmpty == true
          ? json['productName'].toString().trim()
          : 'Produit',
      amountFcfa: (json['amountFcfa'] as num?)?.toDouble() ?? 0,
      goalReachedNow: json['goalReachedNow'] == true,
    );
  }
}

/// Résultat complet d'une répartition automatique d'un paiement entre plusieurs produits.
class AllocationResult {
  const AllocationResult({
    required this.sourceAmountFcfa,
    required this.lines,
    required this.unallocatedSurplusFcfa,
  });

  final double sourceAmountFcfa;
  final List<AllocationLine> lines;
  final double unallocatedSurplusFcfa;

  /// Une répartition a réellement eu lieu dès qu'il y a plus d'une ligne, ou qu'un
  /// surplus est resté non affecté (aucun produit actif pour l'absorber).
  bool get wasSplit => lines.length > 1 || unallocatedSurplusFcfa > 0;

  static AllocationResult? tryParse(Map<String, dynamic>? json) {
    if (json == null) return null;
    final rawLines = json['allocations'];
    if (rawLines is! List || rawLines.isEmpty) return null;
    final lines = rawLines
        .whereType<Map>()
        .map((e) => AllocationLine.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    if (lines.isEmpty) return null;
    final surplus = (json['unallocatedSurplusFcfa'] as num?)?.toDouble() ?? 0;
    final source = (json['sourceAmountFcfa'] as num?)?.toDouble() ??
        lines.fold<double>(0, (sum, l) => sum + l.amountFcfa) + surplus;
    final result = AllocationResult(
      sourceAmountFcfa: source,
      lines: lines,
      unallocatedSurplusFcfa: surplus,
    );
    return result.wasSplit ? result : null;
  }

  /// Message client clair en français, ex :
  /// « Votre paiement de 500 FCFA a été réparti : 200 FCFA pour compléter Produit A
  /// (objectif atteint), 300 FCFA pour Produit B. »
  String toFrenchMessage() {
    if (lines.length <= 1 && unallocatedSurplusFcfa <= 0) {
      return 'Paiement de ${formatFcfaLong(sourceAmountFcfa)} enregistré.';
    }
    final parts = lines.map((l) {
      final suffix = l.goalReachedNow ? ' (objectif atteint)' : '';
      return '${formatFcfaLong(l.amountFcfa)} pour ${l.productName}$suffix';
    }).join(', ');
    var msg = 'Votre paiement de ${formatFcfaLong(sourceAmountFcfa)} a été réparti : $parts.';
    if (unallocatedSurplusFcfa > 0) {
      msg +=
          ' ${formatFcfaLong(unallocatedSurplusFcfa)} restent en attente d’affectation (aucun autre produit actif) — contactez votre agent PayFlex.';
    }
    return msg;
  }
}
