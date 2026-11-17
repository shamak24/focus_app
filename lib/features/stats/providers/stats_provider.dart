import 'package:riverpod/riverpod.dart';

import '../../../core/clock.dart';
import '../../../core/dates.dart';
import '../../focus/data/focus_session.dart';
import '../../focus/providers/timer_notifier.dart';
import '../../plans/data/plan.dart';
import '../../plans/data/task.dart';
import '../../plans/providers/plans_providers.dart';

class DayTotal {
  const DayTotal(this.day, this.seconds);

  final DateTime day;
  final int seconds;
}

class NamedTotal {
  const NamedTotal({required this.label, required this.seconds, this.colorValue});

  final String label;
  final int seconds;

  /// Plan colour, when the row is a plan that still exists.
  final int? colorValue;
}

class StatsSnapshot {
  const StatsSnapshot({
    required this.todaySeconds,
    required this.weekSeconds,
    required this.totalSeconds,
    required this.sessionsThisWeek,
    required this.tasksDoneThisWeek,
    required this.lastSevenDays,
    required this.byPlan,
    required this.bySubject,
  });

  final int todaySeconds;

  /// Monday to now.
  final int weekSeconds;
  final int totalSeconds;
  final int sessionsThisWeek;
  final int tasksDoneThisWeek;

  /// Oldest first; the last entry is today.
  final List<DayTotal> lastSevenDays;

  /// All-time focus per plan and per subject, largest first.
  final List<NamedTotal> byPlan;
  final List<NamedTotal> bySubject;
}

StatsSnapshot computeStats({
  required List<FocusSession> sessions,
  required List<Task> tasks,
  required List<Plan> plans,
  required DateTime now,
}) {
  final today = dayOf(now);
  final weekStart = startOfWeek(now);
  final days = [for (var i = 6; i >= 0; i--) addDays(today, -i)];
  final perDay = {for (final d in days) d: 0};
  final perPlan = <String, int>{};
  final perSubject = <String, int>{};
  var todaySeconds = 0, weekSeconds = 0, totalSeconds = 0, sessionsThisWeek = 0;

  for (final s in sessions) {
    final day = dayOf(s.startedAt);
    totalSeconds += s.durationSeconds;
    if (day == today) todaySeconds += s.durationSeconds;
    if (!day.isBefore(weekStart)) {
      weekSeconds += s.durationSeconds;
      sessionsThisWeek++;
    }
    if (perDay.containsKey(day)) perDay[day] = perDay[day]! + s.durationSeconds;
    perPlan[s.planId] = (perPlan[s.planId] ?? 0) + s.durationSeconds;
    final subject = s.subject.trim();
    perSubject[subject] = (perSubject[subject] ?? 0) + s.durationSeconds;
  }

  final plansById = {for (final p in plans) p.id: p};
  List<NamedTotal> ranked(Iterable<NamedTotal> rows) =>
      rows.toList()..sort((a, b) => b.seconds.compareTo(a.seconds));

  return StatsSnapshot(
    todaySeconds: todaySeconds,
    weekSeconds: weekSeconds,
    totalSeconds: totalSeconds,
    sessionsThisWeek: sessionsThisWeek,
    tasksDoneThisWeek: tasks.where((t) {
      final at = t.completedAt;
      return t.done && at != null && !at.isBefore(weekStart);
    }).length,
    lastSevenDays: [for (final d in days) DayTotal(d, perDay[d]!)],
    byPlan: ranked(
      perPlan.entries.map(
        (e) => NamedTotal(
          label: plansById[e.key]?.name ?? 'Deleted plan',
          seconds: e.value,
          colorValue: plansById[e.key]?.colorValue,
        ),
      ),
    ),
    bySubject: ranked(
      perSubject.entries.map(
        (e) => NamedTotal(label: e.key.isEmpty ? 'No subject' : e.key, seconds: e.value),
      ),
    ),
  );
}

final statsProvider = Provider<StatsSnapshot>((ref) {
  ref.watch(todayProvider);
  return computeStats(
    sessions: ref.watch(sessionsProvider),
    tasks: ref.watch(userTasksProvider),
    plans: ref.watch(plansProvider),
    now: ref.watch(clockProvider)(),
  );
});
