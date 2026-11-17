import 'package:hive/hive.dart';

import '../../../core/storage/hive_fields.dart';

/// The timer that is running or paused right now, as stored in Hive.
///
/// Nothing here counts ticks. A running timer is just a planned end time, and
/// the remaining time is always worked out from the wall clock. That keeps it
/// correct while the app is in the background, and lets it resume after the
/// app is killed.
class ActiveTimer {
  const ActiveTimer({
    required this.taskId,
    required this.taskTitle,
    required this.startedAt,
    required this.plannedSeconds,
    required this.endsAt,
    this.planId = '',
    this.subject = '',
    this.colorValue = 0,
    this.pausedRemainingSeconds,
    this.isBreak = false,
  });

  final String taskId;
  final String taskTitle;
  final String planId;
  final String subject;
  final int colorValue;
  final DateTime startedAt;
  final int plannedSeconds;

  /// Planned end on the wall clock. Only meaningful while running.
  final DateTime endsAt;

  /// Set while paused: the time left when pause was pressed.
  final int? pausedRemainingSeconds;
  final bool isBreak;

  bool get isPaused => pausedRemainingSeconds != null;

  /// Seconds left at [now], never negative. Rounded up so a fresh 25-minute
  /// timer reads 25:00 and reaches 00:00 exactly at [endsAt].
  int remainingAt(DateTime now) {
    final paused = pausedRemainingSeconds;
    if (paused != null) return paused < 0 ? 0 : paused;
    final ms = endsAt.difference(now).inMilliseconds;
    return ms <= 0 ? 0 : (ms / 1000).ceil();
  }

  /// Seconds focused so far at [now], capped at the planned length.
  int elapsedAt(DateTime now) {
    final elapsed = plannedSeconds - remainingAt(now);
    return elapsed < 0 ? 0 : (elapsed > plannedSeconds ? plannedSeconds : elapsed);
  }

  ActiveTimer paused(DateTime now) => _copy(pausedRemainingSeconds: remainingAt(now));

  ActiveTimer resumed(DateTime now) => _copy(
    endsAt: now.add(Duration(seconds: pausedRemainingSeconds ?? remainingAt(now))),
    pausedRemainingSeconds: null,
  );

  ActiveTimer _copy({DateTime? endsAt, required int? pausedRemainingSeconds}) => ActiveTimer(
    taskId: taskId,
    taskTitle: taskTitle,
    planId: planId,
    subject: subject,
    colorValue: colorValue,
    startedAt: startedAt,
    plannedSeconds: plannedSeconds,
    endsAt: endsAt ?? this.endsAt,
    pausedRemainingSeconds: pausedRemainingSeconds,
    isBreak: isBreak,
  );
}

class ActiveTimerAdapter extends TypeAdapter<ActiveTimer> {
  @override
  final int typeId = 6;

  @override
  ActiveTimer read(BinaryReader reader) {
    final f = readFields(reader);
    return ActiveTimer(
      taskId: f[0] as String,
      taskTitle: f[1] as String,
      planId: f[2] as String? ?? '',
      subject: f[3] as String? ?? '',
      colorValue: f[4] as int? ?? 0,
      startedAt: f[5] as DateTime,
      plannedSeconds: f[6] as int,
      endsAt: f[7] as DateTime,
      pausedRemainingSeconds: f[8] as int?,
      isBreak: f[9] as bool? ?? false,
    );
  }

  @override
  void write(BinaryWriter writer, ActiveTimer obj) => writeFields(writer, [
    obj.taskId,
    obj.taskTitle,
    obj.planId,
    obj.subject,
    obj.colorValue,
    obj.startedAt,
    obj.plannedSeconds,
    obj.endsAt,
    obj.pausedRemainingSeconds,
    obj.isBreak,
  ]);
}
