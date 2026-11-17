import 'package:hive/hive.dart';

import '../../../core/storage/hive_fields.dart';

class AppSettings {
  const AppSettings({
    this.themeId = 'peach',
    this.focusMinutes = 25,
    this.breakMinutes = 5,
    this.remindersEnabled = true,
    this.dailyReminderMinutes = const [],
    this.deadlineLeadMinutes = 60,
  });

  final String themeId;
  final int focusMinutes;
  final int breakMinutes;

  /// Master switch for study and deadline reminders. The "session finished"
  /// alert is part of the timer and is not affected.
  final bool remindersEnabled;

  /// Daily study reminders, as minutes after midnight (local time).
  final List<int> dailyReminderMinutes;

  /// How long before a deadline its reminder fires.
  final int deadlineLeadMinutes;

  AppSettings copyWith({
    String? themeId,
    int? focusMinutes,
    int? breakMinutes,
    bool? remindersEnabled,
    List<int>? dailyReminderMinutes,
    int? deadlineLeadMinutes,
  }) => AppSettings(
    themeId: themeId ?? this.themeId,
    focusMinutes: focusMinutes ?? this.focusMinutes,
    breakMinutes: breakMinutes ?? this.breakMinutes,
    remindersEnabled: remindersEnabled ?? this.remindersEnabled,
    dailyReminderMinutes: dailyReminderMinutes ?? this.dailyReminderMinutes,
    deadlineLeadMinutes: deadlineLeadMinutes ?? this.deadlineLeadMinutes,
  );
}

class AppSettingsAdapter extends TypeAdapter<AppSettings> {
  @override
  final int typeId = 4;

  @override
  AppSettings read(BinaryReader reader) {
    final f = readFields(reader);
    return AppSettings(
      themeId: f[0] as String? ?? 'peach',
      focusMinutes: f[1] as int? ?? 25,
      breakMinutes: f[2] as int? ?? 5,
      remindersEnabled: f[3] as bool? ?? true,
      dailyReminderMinutes: (f[4] as List?)?.cast<int>().toList() ?? const [],
      deadlineLeadMinutes: f[5] as int? ?? 60,
    );
  }

  @override
  void write(BinaryWriter writer, AppSettings obj) => writeFields(writer, [
    obj.themeId,
    obj.focusMinutes,
    obj.breakMinutes,
    obj.remindersEnabled,
    obj.dailyReminderMinutes,
    obj.deadlineLeadMinutes,
  ]);
}
