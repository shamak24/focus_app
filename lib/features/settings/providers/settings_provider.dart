import 'package:riverpod/riverpod.dart';

import '../../../core/storage/app_boxes.dart';
import '../data/app_settings.dart';

final settingsProvider = NotifierProvider<SettingsNotifier, AppSettings>(SettingsNotifier.new);

/// Id of the selected app theme. The UI maps it to colours; see
/// `core/design/clay_theme.dart`.
final themeProvider = Provider<String>(
  (ref) => ref.watch(settingsProvider.select((s) => s.themeId)),
);

class SettingsNotifier extends Notifier<AppSettings> {
  static const minFocusMinutes = 5;
  static const maxFocusMinutes = 120;
  static const minBreakMinutes = 1;
  static const maxBreakMinutes = 30;
  static const maxDailyReminders = 6;

  @override
  AppSettings build() =>
      ref.watch(boxesProvider).meta.get(MetaKeys.settings) as AppSettings? ?? const AppSettings();

  Future<void> _set(AppSettings next) async {
    state = next;
    await ref.read(boxesProvider).meta.put(MetaKeys.settings, next);
  }

  Future<void> setTheme(String themeId) => _set(state.copyWith(themeId: themeId));

  Future<void> setFocusMinutes(int minutes) =>
      _set(state.copyWith(focusMinutes: minutes.clamp(minFocusMinutes, maxFocusMinutes)));

  Future<void> setBreakMinutes(int minutes) =>
      _set(state.copyWith(breakMinutes: minutes.clamp(minBreakMinutes, maxBreakMinutes)));

  Future<void> setRemindersEnabled(bool enabled) => _set(state.copyWith(remindersEnabled: enabled));

  Future<void> setDeadlineLeadMinutes(int minutes) =>
      _set(state.copyWith(deadlineLeadMinutes: minutes));

  Future<void> addDailyReminder(int minuteOfDay) {
    final times = {...state.dailyReminderMinutes, minuteOfDay % (24 * 60)}.toList()..sort();
    if (times.length > maxDailyReminders) return Future.value();
    return _set(state.copyWith(dailyReminderMinutes: times));
  }

  Future<void> removeDailyReminder(int minuteOfDay) => _set(
    state.copyWith(
      dailyReminderMinutes: state.dailyReminderMinutes.where((m) => m != minuteOfDay).toList(),
    ),
  );
}
