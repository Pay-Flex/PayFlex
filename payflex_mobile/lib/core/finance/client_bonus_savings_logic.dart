/// Épargne bonus : le jour « hors plan officiel » (mois − 1) est partagé 50 % client / 50 % PayFlex.
class ClientBonusSavingsLogic {
  ClientBonusSavingsLogic._();

  static int officialDaysInMonth(int year, int month) {
    final days = DateTime(year, month + 1, 0).day;
    return days > 0 ? days - 1 : 0;
  }

  static double monthlyClientBonus(double dailyContribution) =>
      dailyContribution > 0 ? dailyContribution / 2 : 0;

  static double monthlyLineBonus({required double unitDailyMin, required int quantity}) {
    if (unitDailyMin <= 0 || quantity <= 0) return 0;
    return (unitDailyMin * quantity) / 2;
  }

  static int activeMonthsFromTransactions(List<Map<String, dynamic>> transactions) {
    final months = <String>{};
    for (final t in transactions) {
      if ((t['status']?.toString() ?? '') != 'validated') continue;
      final raw = t['date']?.toString() ?? '';
      final dt = DateTime.tryParse(raw);
      if (dt == null) continue;
      months.add('${dt.year}-${dt.month.toString().padLeft(2, '0')}');
    }
    return months.length;
  }

  static double accruedBonus({
    required double dailyContribution,
    required int activeMonths,
  }) =>
      activeMonths * monthlyClientBonus(dailyContribution);
}

class BonusSavingsLine {
  final String productName;
  final int quantity;
  final double unitDailyMin;
  final double monthlyBonus;

  const BonusSavingsLine({
    required this.productName,
    required this.quantity,
    required this.unitDailyMin,
    required this.monthlyBonus,
  });

  factory BonusSavingsLine.fromMap(Map<String, dynamic> map) {
    return BonusSavingsLine(
      productName: map['productName']?.toString() ?? 'Article',
      quantity: (map['quantity'] as num?)?.toInt() ?? 1,
      unitDailyMin: (map['unitDailyMinFcfa'] as num?)?.toDouble() ?? 0,
      monthlyBonus: (map['monthlyBonusFcfa'] as num?)?.toDouble() ?? 0,
    );
  }
}

class BonusSavingsSummary {
  final double accruedFcfa;
  final double monthlyFcfa;
  final int activeMonths;
  final int officialDaysThisMonth;
  final double dailyContribution;
  final List<BonusSavingsLine> lines;
  final String? ruleLabel;
  final String? lastCreditedYearMonth;
  final bool currentMonthCredited;
  final bool creditedInDatabase;

  const BonusSavingsSummary({
    this.accruedFcfa = 0,
    this.monthlyFcfa = 0,
    this.activeMonths = 0,
    this.officialDaysThisMonth = 0,
    this.dailyContribution = 0,
    this.lines = const [],
    this.ruleLabel,
    this.lastCreditedYearMonth,
    this.currentMonthCredited = false,
    this.creditedInDatabase = false,
  });

  factory BonusSavingsSummary.fromMap(Map<String, dynamic> map) {
    final rawLines = map['bonusLines'];
    final lines = rawLines is List
        ? rawLines
            .whereType<Map>()
            .map((e) => BonusSavingsLine.fromMap(Map<String, dynamic>.from(e)))
            .toList()
        : <BonusSavingsLine>[];
    return BonusSavingsSummary(
      accruedFcfa: (map['bonusSavingsFcfa'] as num?)?.toDouble() ?? 0,
      monthlyFcfa: (map['bonusSavingsMonthlyFcfa'] as num?)?.toDouble() ?? 0,
      activeMonths: (map['activeMonthsCount'] as num?)?.toInt() ?? 0,
      officialDaysThisMonth: (map['officialDaysThisMonth'] as num?)?.toInt() ?? 0,
      dailyContribution: (map['dailyContributionFcfa'] as num?)?.toDouble() ?? 0,
      lines: lines,
      ruleLabel: map['ruleLabel']?.toString(),
      lastCreditedYearMonth: map['lastCreditedYearMonth']?.toString(),
      currentMonthCredited: map['currentMonthCredited'] == true,
      creditedInDatabase: map['creditedInDatabase'] == true,
    );
  }

  bool get hasData => accruedFcfa > 0 || monthlyFcfa > 0 || dailyContribution > 0;
}
