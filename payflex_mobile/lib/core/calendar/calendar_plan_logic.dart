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
        if (cellDate.isBefore(todayDate)) {
          out[d] = 'orange';
        } else {
          out[d] = 'gris';
        }
      }
    }
    return out;
  }

  static int countOrange(Map<int, String> statuses) =>
      statuses.values.where((s) => s == 'orange').length;
}
