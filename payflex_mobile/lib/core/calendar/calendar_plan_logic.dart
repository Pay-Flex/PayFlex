/// Couleurs du carnet : vert (respecté), orange (rattrapage), bleu (anticipé), gris (à venir / neutre).
class CalendarPlanLogic {
  CalendarPlanLogic._();

  /// Statuts par jour du mois [year]/[month] (clés = jour 1..31).
  static Map<int, String> buildDayStatuses({
    required double savedAmount,
    required double dailySuggested,
    required Set<int> validatedCatchUpDaysInMonth,
    required int year,
    required int month,
    Set<int>? pendingCatchUpDays,
  }) {
    final daily = dailySuggested;
    final slotsTotal = daily > 0 ? (savedAmount / daily).floor() : 0;
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    final lastDay = DateTime(year, month + 1, 0).day;
    var slotsRemaining = slotsTotal;
    final out = <int, String>{};

    for (var d = 1; d <= lastDay; d++) {
      final cellDate = DateTime(year, month, d);
      final isFuture = cellDate.isAfter(todayDate);

      if (validatedCatchUpDaysInMonth.contains(d)) {
        out[d] = isFuture ? 'bleu' : 'vert';
        slotsRemaining -= 1;
        continue;
      }

      if (slotsRemaining > 0) {
        out[d] = isFuture ? 'bleu' : 'vert';
        slotsRemaining -= 1;
      } else {
        // PDF : gris = non payé ; orange = rattrapage (affiché via pendingCatchUpDays)
        if (cellDate.isBefore(todayDate)) {
          out[d] = 'gris';
        } else {
          out[d] = 'gris';
        }
      }
    }

    if (pendingCatchUpDays != null) {
      for (final d in pendingCatchUpDays) {
        if (out.containsKey(d) && out[d] == 'gris') {
          out[d] = 'orange';
        }
      }
    }
    return out;
  }

  /// Jours passés non couverts (bouton « Combler les trous »).
  static int countGaps(Map<int, String> statuses) =>
      statuses.values.where((s) => s == 'gris' || s == 'orange').length;

  static int countOrange(Map<int, String> statuses) =>
      statuses.values.where((s) => s == 'orange').length;

  static int estimateDaysRemaining({
    required double targetAmount,
    required double savedAmount,
    required double dailySuggested,
  }) {
    if (dailySuggested <= 0) return 0;
    final remaining = targetAmount - savedAmount;
    if (remaining <= 0) return 0;
    return (remaining / dailySuggested).ceil();
  }

  static DateTime? estimateEndDate({
    required double targetAmount,
    required double savedAmount,
    required double dailySuggested,
    DateTime? from,
  }) {
    final days = estimateDaysRemaining(
      targetAmount: targetAmount,
      savedAmount: savedAmount,
      dailySuggested: dailySuggested,
    );
    if (days <= 0) return null;
    final base = from ?? DateTime.now();
    return DateTime(base.year, base.month, base.day).add(Duration(days: days));
  }
}
