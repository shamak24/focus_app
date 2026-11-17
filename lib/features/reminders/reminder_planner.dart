import '../../core/dates.dart';
import '../focus/data/active_timer.dart';
import '../plans/data/plan.dart';
import '../plans/data/task.dart';
import '../settings/data/app_settings.dart';
import 'reminder_service.dart';

abstract final class ReminderIds {
  static const timerEnd = 1;

  /// The sticky countdown shown while a timer runs. Never scheduled, so it
  /// is left alone when the scheduled reminders are replaced.
  static const ongoingTimer = 2;
  static const dailyBase = 100;
  static const deadlineBase = 1000;
}

/// Android caps how many alarms one app may hold, so only the nearest
/// deadlines are scheduled. The list is rebuilt whenever tasks change, which
/// rolls later deadlines in as earlier ones pass.
const maxDeadlineReminders = 40;

/// Decides every notification that should exist right now. Pure: the same
/// inputs always give the same list, so it is easy to test.
List<PlannedReminder> planReminders({
  required List<Task> tasks,
  required List<Plan> plans,
  required AppSettings settings,
  required ActiveTimer? timer,
  required DateTime now,
}) {
  final out = <PlannedReminder>[];

  if (timer != null && !timer.isPaused && timer.endsAt.isAfter(now)) {
    out.add(
      PlannedReminder.at(
        id: ReminderIds.timerEnd,
        title: timer.isBreak ? 'Break is over' : 'Focus session complete',
        body: timer.isBreak
            ? 'Ready for the next session?'
            : 'Nice work on "${timer.taskTitle}". Time for a short break.',
        at: timer.endsAt,
        exact: true,
      ),
    );
  }

  if (!settings.remindersEnabled) return out;

  final times = settings.dailyReminderMinutes;
  for (var i = 0; i < times.length; i++) {
    out.add(
      PlannedReminder.daily(
        id: ReminderIds.dailyBase + i,
        title: 'Time to focus',
        body: 'Pick a task and start a session.',
        minuteOfDay: times[i],
      ),
    );
  }

  final planNames = {for (final p in plans) p.id: p.name};
  final lead = Duration(minutes: settings.deadlineLeadMinutes);
  final upcoming = <(DateTime, Task)>[
    for (final t in tasks)
      if (!t.repeatsDaily &&
          !t.done &&
          t.deadline != null &&
          t.deadline!.subtract(lead).isAfter(now))
        (t.deadline!.subtract(lead), t),
  ]..sort((a, b) => a.$1.compareTo(b.$1));

  final usedIds = <int>{};
  for (final (fireAt, task) in upcoming.take(maxDeadlineReminders)) {
    var id = ReminderIds.deadlineBase + stableHash(task.id) % 0x3FFFFFFF;
    while (!usedIds.add(id)) {
      id++;
    }
    final plan = planNames[task.planId];
    out.add(
      PlannedReminder.at(
        id: id,
        title: 'Due soon: ${task.title}',
        body: 'Due ${formatDeadline(task.deadline!, fireAt)}${plan == null ? '' : ' · $plan'}',
        at: fireAt,
      ),
    );
  }
  return out;
}

/// FNV-1a. Unlike `String.hashCode` this is guaranteed to give the same value
/// on every run and platform.
int stableHash(String input) {
  var hash = 0x811C9DC5;
  for (final unit in input.codeUnits) {
    hash = ((hash ^ unit) * 0x01000193) & 0xFFFFFFFF;
  }
  return hash;
}
