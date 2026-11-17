/// One notification the app wants scheduled.
class PlannedReminder {
  const PlannedReminder.at({
    required this.id,
    required this.title,
    required this.body,
    required DateTime this.at,
    this.exact = false,
  }) : dailyMinuteOfDay = null;

  const PlannedReminder.daily({
    required this.id,
    required this.title,
    required this.body,
    required int minuteOfDay,
  }) : dailyMinuteOfDay = minuteOfDay,
       at = null,
       exact = false;

  final int id;
  final String title;
  final String body;

  /// One-off reminders: when to fire.
  final DateTime? at;

  /// Repeating reminders: minutes after local midnight, every day.
  final int? dailyMinuteOfDay;

  /// Ask the OS for to-the-minute delivery (used for "session finished").
  final bool exact;
}

/// The running timer as it should appear in the notification shade.
class OngoingTimer {
  const OngoingTimer({
    required this.title,
    required this.endsAt,
    this.subtitle = '',
    this.pausedRemainingSeconds,
    this.isBreak = false,
    this.themeId = '',
  });

  final String title;
  final bool isBreak;

  /// The app theme to draw the notification in.
  final String themeId;
  final String subtitle;

  /// Planned end on the wall clock. The system counts down to it by itself,
  /// so the notification stays correct with no updates from the app.
  final DateTime endsAt;

  /// Set while paused: the notification shows this frozen instead of a
  /// countdown.
  final int? pausedRemainingSeconds;

  bool get isPaused => pausedRemainingSeconds != null;

  @override
  bool operator ==(Object other) =>
      other is OngoingTimer &&
      other.title == title &&
      other.subtitle == subtitle &&
      other.endsAt == endsAt &&
      other.pausedRemainingSeconds == pausedRemainingSeconds &&
      other.isBreak == isBreak &&
      other.themeId == themeId;

  @override
  int get hashCode =>
      Object.hash(title, subtitle, endsAt, pausedRemainingSeconds, isBreak, themeId);
}

/// One task as the home-screen widget lists it.
class WidgetTaskInfo {
  const WidgetTaskInfo({
    required this.id,
    required this.title,
    required this.subtitle,
    this.colorValue = 0,
    this.doneDay,
  });

  final String id;
  final String title;
  final String subtitle;

  /// Plan colour; 0 for none.
  final int colorValue;

  /// yyyymmdd when this is a daily task already done that day.
  final int? doneDay;

  @override
  bool operator ==(Object other) =>
      other is WidgetTaskInfo &&
      other.id == id &&
      other.title == title &&
      other.subtitle == subtitle &&
      other.colorValue == colorValue &&
      other.doneDay == doneDay;

  @override
  int get hashCode => Object.hash(id, title, subtitle, colorValue, doneDay);
}

/// Everything the home-screen widgets show.
class HomeWidgetSnapshot {
  const HomeWidgetSnapshot({this.timer, this.tasks = const [], this.themeId = ''});

  final OngoingTimer? timer;

  /// Next tasks in order, most urgent first.
  final List<WidgetTaskInfo> tasks;
  final String themeId;

  @override
  bool operator ==(Object other) {
    if (other is! HomeWidgetSnapshot ||
        other.timer != timer ||
        other.themeId != themeId ||
        other.tasks.length != tasks.length) {
      return false;
    }
    for (var i = 0; i < tasks.length; i++) {
      if (other.tasks[i] != tasks[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(timer, themeId, Object.hashAll(tasks));
}

/// The app's only door to platform notifications and home-screen widgets.
/// Tests swap in a recording fake.
abstract class ReminderService {
  Future<void> init();

  /// Shows the system permission prompt if needed. Returns whether
  /// notifications are allowed.
  Future<bool> requestPermission();

  /// Whether reminders marked [PlannedReminder.exact] can fire on time.
  /// Without this they still fire, just possibly a few minutes late.
  Future<bool> canScheduleExact();

  /// Opens the system page where the user allows exact alarms.
  Future<void> requestExactAlarms();

  /// Makes the set of scheduled notifications equal to [reminders]: anything
  /// scheduled before and not in the list is cancelled.
  Future<void> replaceAll(List<PlannedReminder> reminders);

  /// Shows [timer] as a sticky notification with a live countdown, or
  /// removes it when [timer] is null.
  Future<void> showOngoing(OngoingTimer? timer);

  /// Redraws the home-screen widgets.
  Future<void> updateHomeWidgets(HomeWidgetSnapshot snapshot);
}

/// Does nothing. Used in tests and on platforms without notifications.
class NoopReminderService implements ReminderService {
  const NoopReminderService();

  @override
  Future<void> init() async {}

  @override
  Future<bool> requestPermission() async => false;

  @override
  Future<bool> canScheduleExact() async => true;

  @override
  Future<void> requestExactAlarms() async {}

  @override
  Future<void> replaceAll(List<PlannedReminder> reminders) async {}

  @override
  Future<void> showOngoing(OngoingTimer? timer) async {}

  @override
  Future<void> updateHomeWidgets(HomeWidgetSnapshot snapshot) async {}
}
