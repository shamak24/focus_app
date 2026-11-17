import 'package:hive/hive.dart';

import '../../../core/dates.dart';
import '../../../core/storage/hive_fields.dart';

abstract final class TaskPriority {
  static const low = 0;
  static const medium = 1;
  static const high = 2;

  static String label(int priority) => switch (priority) {
    high => 'High',
    medium => 'Medium',
    _ => 'Low',
  };
}

const _unset = Object();

class Task {
  const Task({
    required this.id,
    required this.planId,
    required this.title,
    this.deadline,
    this.priority = TaskPriority.medium,
    this.done = false,
    this.subject = '',
    this.order = 0,
    this.completedAt,
    this.repeatsDaily = false,
    this.dayOffset,
    this.lastXpAt,
    this.focusMinutes,
  });

  final String id;
  final String planId;
  final String title;
  final DateTime? deadline;
  final int priority;

  /// Raw completion flag. Use [isDoneOn] in UI and logic: daily tasks reopen
  /// every morning even though this stays true.
  final bool done;
  final String subject;

  /// Position inside the plan.
  final int order;
  final DateTime? completedAt;

  /// Routine tasks that come back every day.
  final bool repeatsDaily;

  /// Preset tasks only: days relative to the date the user picks when they
  /// copy the preset (0 = that day, -3 = three days before).
  final int? dayOffset;

  /// When XP was last granted for finishing this task. Stops repeated
  /// check/uncheck from farming XP.
  final DateTime? lastXpAt;

  /// Focus session length for this task. Null uses the plan's default.
  final int? focusMinutes;

  bool isDoneOn(DateTime now) => repeatsDaily ? done && isSameDay(completedAt, now) : done;

  bool isOverdueOn(DateTime now) =>
      !repeatsDaily && !done && deadline != null && deadline!.isBefore(now);

  /// Finishing the task grants XP once, or once per day for daily tasks.
  bool canEarnXpOn(DateTime now) => lastXpAt == null || (repeatsDaily && !isSameDay(lastXpAt, now));

  Task copyWith({
    String? id,
    String? planId,
    String? title,
    Object? deadline = _unset,
    int? priority,
    bool? done,
    String? subject,
    int? order,
    Object? completedAt = _unset,
    bool? repeatsDaily,
    Object? dayOffset = _unset,
    Object? lastXpAt = _unset,
    Object? focusMinutes = _unset,
  }) => Task(
    id: id ?? this.id,
    planId: planId ?? this.planId,
    title: title ?? this.title,
    deadline: identical(deadline, _unset) ? this.deadline : deadline as DateTime?,
    priority: priority ?? this.priority,
    done: done ?? this.done,
    subject: subject ?? this.subject,
    order: order ?? this.order,
    completedAt: identical(completedAt, _unset) ? this.completedAt : completedAt as DateTime?,
    repeatsDaily: repeatsDaily ?? this.repeatsDaily,
    dayOffset: identical(dayOffset, _unset) ? this.dayOffset : dayOffset as int?,
    lastXpAt: identical(lastXpAt, _unset) ? this.lastXpAt : lastXpAt as DateTime?,
    focusMinutes: identical(focusMinutes, _unset) ? this.focusMinutes : focusMinutes as int?,
  );
}

class TaskAdapter extends TypeAdapter<Task> {
  @override
  final int typeId = 2;

  @override
  Task read(BinaryReader reader) {
    final f = readFields(reader);
    return Task(
      id: f[0] as String,
      planId: f[1] as String,
      title: f[2] as String,
      deadline: f[3] as DateTime?,
      priority: f[4] as int? ?? TaskPriority.medium,
      done: f[5] as bool? ?? false,
      subject: f[6] as String? ?? '',
      order: f[7] as int? ?? 0,
      completedAt: f[8] as DateTime?,
      repeatsDaily: f[9] as bool? ?? false,
      dayOffset: f[10] as int?,
      lastXpAt: f[11] as DateTime?,
      focusMinutes: f[12] as int?,
    );
  }

  @override
  void write(BinaryWriter writer, Task obj) => writeFields(writer, [
    obj.id,
    obj.planId,
    obj.title,
    obj.deadline,
    obj.priority,
    obj.done,
    obj.subject,
    obj.order,
    obj.completedAt,
    obj.repeatsDaily,
    obj.dayOffset,
    obj.lastXpAt,
    obj.focusMinutes,
  ]);
}
