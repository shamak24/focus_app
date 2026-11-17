import 'package:riverpod/riverpod.dart';

/// Returns the current wall-clock time.
///
/// Everything that depends on "now" reads it through [clockProvider] so tests
/// can move time forward without waiting.
typedef Clock = DateTime Function();

final clockProvider = Provider<Clock>((ref) => DateTime.now);

/// The current calendar day. Widgets that depend on "today" (daily tasks,
/// streaks, stats) watch this; the app shell calls [TodayNotifier.refresh]
/// when the app returns to the foreground so they roll over after midnight.
final todayProvider = NotifierProvider<TodayNotifier, DateTime>(TodayNotifier.new);

class TodayNotifier extends Notifier<DateTime> {
  DateTime _read() {
    final now = ref.read(clockProvider)();
    return DateTime(now.year, now.month, now.day);
  }

  @override
  DateTime build() => _read();

  void refresh() {
    final today = _read();
    if (today != state) state = today;
  }
}
