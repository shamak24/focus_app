import 'package:hive/hive.dart';

import '../../../core/storage/hive_fields.dart';

/// One logged stretch of focus time.
///
/// The plan and subject are copied in at log time so stats still make sense
/// after the task or plan is deleted.
class FocusSession {
  const FocusSession({
    required this.id,
    required this.taskId,
    required this.startedAt,
    required this.durationSeconds,
    this.planId = '',
    this.subject = '',
    this.taskTitle = '',
    this.plannedSeconds = 0,
    this.completed = false,
  });

  final String id;
  final String taskId;
  final DateTime startedAt;

  /// Time actually focused. Paused time is not counted.
  final int durationSeconds;
  final String planId;
  final String subject;
  final String taskTitle;
  final int plannedSeconds;

  /// True when the timer ran its full planned length.
  final bool completed;
}

class FocusSessionAdapter extends TypeAdapter<FocusSession> {
  @override
  final int typeId = 3;

  @override
  FocusSession read(BinaryReader reader) {
    final f = readFields(reader);
    return FocusSession(
      id: f[0] as String,
      taskId: f[1] as String,
      startedAt: f[2] as DateTime,
      durationSeconds: f[3] as int,
      planId: f[4] as String? ?? '',
      subject: f[5] as String? ?? '',
      taskTitle: f[6] as String? ?? '',
      plannedSeconds: f[7] as int? ?? 0,
      completed: f[8] as bool? ?? false,
    );
  }

  @override
  void write(BinaryWriter writer, FocusSession obj) => writeFields(writer, [
    obj.id,
    obj.taskId,
    obj.startedAt,
    obj.durationSeconds,
    obj.planId,
    obj.subject,
    obj.taskTitle,
    obj.plannedSeconds,
    obj.completed,
  ]);
}
