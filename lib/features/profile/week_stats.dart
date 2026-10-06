import '../../data/journal.dart';
import '../../data/plan.dart';

/// Numbers for one Monday–Sunday week.
class WeekStats {
  WeekStats(this.journal) : days = journal.week;
  final Journal journal;
  final List<DateTime> days;

  List<DayLog> get logs => [for (final d in days) journal.on(d)];
  int get moves => logs.fold(0, (a, d) => a + d.moves);
  int get minutes => (logs.fold(0, (a, d) => a + d.seconds) / 60).round();
  int get checkIns => logs.where((d) => d.checkIn != null).length;
  int get activeDays => logs.where((d) => d.moves > 0).length;

  /// Share of plan rules kept on days the plan had rules, or null.
  double? get planKept {
    final withRules = logs.where((d) => d.rules > 0).toList();
    final total = withRules.fold(0, (a, d) => a + d.rules);
    if (total == 0) return null;
    return withRules.fold(0, (a, d) => a + d.kept.length) / total;
  }

  /// Index of the day with the most moves, or null if none.
  int? get bestDay {
    var best = -1, most = 0;
    for (var i = 0; i < 7; i++) {
      if (logs[i].moves > most) {
        most = logs[i].moves;
        best = i;
      }
    }
    return best < 0 ? null : best;
  }

  /// The rule kept on the most days in the last 7 days, with its count.
  (PlanRule, int)? bestRule(List<PlanRule> rules) {
    (PlanRule, int)? best;
    for (final r in rules) {
      final n = keptDays(r.id).where((k) => k).length;
      if (n > 0 && (best == null || n > best.$2)) best = (r, n);
    }
    return best;
  }

  /// For the last 7 days ending today: whether [ruleId] was kept each day.
  List<bool> keptDays(String ruleId) {
    final t = journal.todayDate;
    return [for (var i = 6; i >= 0; i--) journal.on(t.subtract(Duration(days: i))).kept.contains(ruleId)];
  }
}
