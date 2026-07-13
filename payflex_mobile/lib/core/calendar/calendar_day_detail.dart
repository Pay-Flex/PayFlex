/// Détail affiché quand l'utilisateur touche un jour du carnet.
class CalendarDayDetail {
  final int day;
  final int year;
  final int month;
  final String status;
  final String statusLabel;
  final bool isAnticipated;
  final bool isCatchup;
  final bool isGap;
  final double dailyAmount;
  final String scopeLabel;
  final String? contributionDate;
  final String? paymentModeLabel;
  final double? contributionAmount;
  final String? referenceCode;
  final String? productName;
  final String coverageNote;

  const CalendarDayDetail({
    required this.day,
    required this.year,
    required this.month,
    required this.status,
    required this.statusLabel,
    required this.isAnticipated,
    required this.isCatchup,
    required this.isGap,
    required this.dailyAmount,
    required this.scopeLabel,
    this.contributionDate,
    this.paymentModeLabel,
    this.contributionAmount,
    this.referenceCode,
    this.productName,
    this.coverageNote = '',
  });
}
