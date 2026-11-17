import 'dart:async';

import 'package:riverpod/riverpod.dart';

import '../../core/clock.dart';
import '../focus/data/active_timer.dart';
import '../focus/providers/timer_notifier.dart';
import '../plans/providers/plans_providers.dart';
import '../settings/providers/settings_provider.dart';
import 'reminder_planner.dart';
import 'reminder_service.dart';

/// Overridden in `main()` with the real notification service.
final reminderServiceProvider = Provider<ReminderService>((ref) => const NoopReminderService());

/// Whether the "session complete" alert can fire exactly on time. Re-checked
/// when the app comes back to the foreground, since the user grants it on a
/// system settings page.
final exactAlarmsAllowedProvider = FutureProvider<bool>(
  (ref) => ref.watch(reminderServiceProvider).canScheduleExact(),
);

/// Keeps scheduled notifications in step with the app's data.
///
/// This is the one place scheduling happens. Whenever tasks, settings or the
/// running timer change, the full list is recomputed by [planReminders] and
/// handed to the service, which replaces whatever was scheduled before.
/// Watch this provider once, at the root of the app, to switch it on.
final reminderSyncProvider = Provider<ReminderSync>((ref) {
  final sync = ReminderSync(ref);
  ref.listen(userTasksProvider, (_, _) => sync.schedule());
  ref.listen(settingsProvider, (_, _) => sync.schedule());
  ref.listen(
    timerNotifierProvider.select((s) => (s.active?.endsAt, s.active?.isPaused)),
    (_, _) => sync.schedule(),
  );
  ref.listen(ongoingTimerProvider, (_, next) => sync.showOngoing(next), fireImmediately: true);
  ref.listen(
    homeWidgetSnapshotProvider,
    (_, next) => sync.updateHomeWidgets(next),
    fireImmediately: true,
  );
  ref.onDispose(sync.dispose);
  sync.schedule();
  return sync;
});

/// What the ongoing notification should show right now. Changes only when
/// the timer starts, pauses, resumes or stops, or the theme changes; not on
/// every tick.
final ongoingTimerProvider = Provider<OngoingTimer?>(
  (ref) => ongoingTimerFor(
    ref.watch(timerNotifierProvider.select((s) => s.active)),
    themeId: ref.watch(settingsProvider.select((s) => s.themeId)),
  ),
);

/// How many tasks the widget is sent. It shows three, but daily tasks done
/// today are included (hidden until midnight), so send a few spare.
const _widgetTaskCount = 8;

/// What the home-screen widgets show: the timer and the next open tasks.
final homeWidgetSnapshotProvider = Provider<HomeWidgetSnapshot>((ref) {
  ref.watch(todayProvider);
  final now = ref.watch(clockProvider)();
  final plans = {for (final p in ref.watch(userPlansProvider)) p.id: p};
  final defaultMinutes = ref.watch(settingsProvider.select((s) => s.focusMinutes));
  final today = now.year * 10000 + now.month * 100 + now.day;

  final candidates =
      ref.watch(userTasksProvider).where((t) => t.repeatsDaily || !t.isDoneOn(now)).toList()
        ..sort(compareUpNext);

  return HomeWidgetSnapshot(
    timer: ref.watch(ongoingTimerProvider),
    themeId: ref.watch(settingsProvider.select((s) => s.themeId)),
    tasks: [
      for (final t in candidates.take(_widgetTaskCount))
        WidgetTaskInfo(
          id: t.id,
          title: t.title,
          subtitle:
              '${t.focusMinutes ?? plans[t.planId]?.defaultFocusMinutes ?? defaultMinutes} min',
          colorValue: plans[t.planId]?.colorValue ?? 0,
          doneDay: t.repeatsDaily && t.isDoneOn(now) ? today : null,
        ),
    ],
  );
});

/// How [timer] should look in the notification shade, or null for nothing.
OngoingTimer? ongoingTimerFor(ActiveTimer? timer, {String themeId = ''}) {
  if (timer == null) return null;
  return OngoingTimer(
    title: timer.taskTitle,
    subtitle: timer.isBreak ? '' : timer.subject,
    endsAt: timer.endsAt,
    pausedRemainingSeconds: timer.pausedRemainingSeconds,
    isBreak: timer.isBreak,
    themeId: themeId,
  );
}

class ReminderSync {
  ReminderSync(this._ref);

  final Ref _ref;
  bool _queued = false;
  bool _disposed = false;
  Future<void> _running = Future.value();

  /// Requests a resync. Several calls in the same turn of the event loop
  /// collapse into one, and runs never overlap.
  void schedule() {
    if (_queued || _disposed) return;
    _queued = true;
    _running = _running.then((_) async {
      await Future<void>.delayed(Duration.zero);
      _queued = false;
      if (_disposed) return;
      await syncNow();
    });
  }

  /// Shows or hides the ongoing timer notification. Queued with the resyncs,
  /// so updates reach the platform in order and [idle] waits for them.
  void showOngoing(OngoingTimer? timer) {
    if (_disposed) return;
    _running = _running.then((_) async {
      try {
        await _ref.read(reminderServiceProvider).showOngoing(timer);
      } catch (_) {
        // Best-effort, like the scheduled reminders.
      }
    });
  }

  /// Redraws the home-screen widgets, queued with everything else.
  void updateHomeWidgets(HomeWidgetSnapshot snapshot) {
    if (_disposed) return;
    _running = _running.then((_) async {
      try {
        await _ref.read(reminderServiceProvider).updateHomeWidgets(snapshot);
      } catch (_) {
        // Best-effort, like the scheduled reminders.
      }
    });
  }

  /// Completes once every resync requested so far has finished.
  Future<void> get idle => _running;

  Future<void> syncNow() async {
    final reminders = planReminders(
      tasks: _ref.read(userTasksProvider),
      plans: _ref.read(plansProvider),
      settings: _ref.read(settingsProvider),
      timer: _ref.read(timerNotifierProvider).active,
      now: _ref.read(clockProvider)(),
    );
    try {
      await _ref.read(reminderServiceProvider).replaceAll(reminders);
    } catch (_) {
      // Reminders are best-effort; a platform failure must never break the app.
    }
  }

  void dispose() => _disposed = true;
}
