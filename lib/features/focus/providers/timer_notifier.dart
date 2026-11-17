import 'dart:async';

import 'package:riverpod/riverpod.dart';

import '../../../core/clock.dart';
import '../../../core/ids.dart';
import '../../../core/storage/app_boxes.dart';
import '../../plans/data/plan.dart';
import '../../plans/data/task.dart';
import '../../progress/providers/progress_provider.dart';
import '../../settings/providers/settings_provider.dart';
import '../data/active_timer.dart';
import '../data/focus_session.dart';

/// Sessions stopped before this are thrown away instead of logged.
const minLoggableSeconds = 60;

/// Summary of the timer that just ended, shown once on the focus screen.
class FinishedTimer {
  const FinishedTimer({
    required this.taskId,
    required this.taskTitle,
    required this.seconds,
    required this.completedFull,
    required this.isBreak,
    required this.logged,
    this.reward,
  });

  final String taskId;
  final String taskTitle;
  final int seconds;
  final bool completedFull;
  final bool isBreak;

  /// False when a focus session was too short to count.
  final bool logged;
  final RewardEvent? reward;
}

class TimerState {
  const TimerState({this.active, this.remainingSeconds = 0, this.lastFinished});

  final ActiveTimer? active;
  final int remainingSeconds;
  final FinishedTimer? lastFinished;

  bool get isIdle => active == null;
  bool get isPaused => active?.isPaused ?? false;
  bool get isRunning => active != null && !isPaused;

  /// 0 at the start, 1 when the planned time is used up.
  double get progress {
    final planned = active?.plannedSeconds ?? 0;
    if (planned <= 0) return 0;
    return (1 - remainingSeconds / planned).clamp(0.0, 1.0);
  }
}

/// All focus sessions ever logged, oldest first.
final sessionsProvider = NotifierProvider<SessionsNotifier, List<FocusSession>>(
  SessionsNotifier.new,
);

class SessionsNotifier extends Notifier<List<FocusSession>> {
  @override
  List<FocusSession> build() => ref.watch(boxesProvider).sessions.values.toList();

  Future<void> add(FocusSession session) async {
    state = [...state, session];
    await ref.read(boxesProvider).sessions.put(session.id, session);
  }
}

/// Whether the notifier refreshes itself once a second. Tests turn this off
/// and call [TimerNotifier.tick] by hand.
final timerTickerEnabledProvider = Provider<bool>((ref) => true);

final timerNotifierProvider = NotifierProvider<TimerNotifier, TimerState>(TimerNotifier.new);

/// The focus timer.
///
/// The source of truth is the [ActiveTimer] record in Hive, which holds the
/// planned end time. The once-a-second ticker only re-reads the wall clock to
/// refresh the UI; missing ticks (app in background, app killed) changes
/// nothing. On the next read the remaining time is simply recomputed, and a
/// timer whose end has passed is closed out as a completed session.
class TimerNotifier extends Notifier<TimerState> {
  Timer? _ticker;

  AppBoxes get _boxes => ref.read(boxesProvider);
  DateTime get _now => ref.read(clockProvider)();

  @override
  TimerState build() {
    ref.onDispose(_stopTicker);
    final stored = ref.watch(boxesProvider).meta.get(MetaKeys.activeTimer) as ActiveTimer?;
    if (stored == null) return const TimerState();
    // A timer that ran out while the app was closed shows 00:00 here and is
    // completed by the first tick(), so build() stays free of side effects.
    if (!stored.isPaused) _startTicker();
    return TimerState(active: stored, remainingSeconds: stored.remainingAt(_now));
  }

  /// Starts a focus session on [task]. Any session already in progress is
  /// finished (and logged) first. The length is, in order: [minutes], the
  /// task's own length, the plan's default, then the one in settings.
  Future<void> start({required Task task, Plan? plan, int? minutes}) async {
    await _closeCurrent();
    final length =
        minutes ??
        task.focusMinutes ??
        plan?.defaultFocusMinutes ??
        ref.read(settingsProvider).focusMinutes;
    final now = _now;
    await _begin(
      ActiveTimer(
        taskId: task.id,
        taskTitle: task.title,
        planId: task.planId,
        subject: task.subject,
        colorValue: plan?.colorValue ?? 0,
        startedAt: now,
        plannedSeconds: length * 60,
        endsAt: now.add(Duration(minutes: length)),
      ),
    );
  }

  /// Starts a break. Breaks are not logged and earn no XP.
  Future<void> startBreak({int? minutes}) async {
    await _closeCurrent();
    final length = minutes ?? ref.read(settingsProvider).breakMinutes;
    final now = _now;
    await _begin(
      ActiveTimer(
        taskId: '',
        taskTitle: 'Break',
        startedAt: now,
        plannedSeconds: length * 60,
        endsAt: now.add(Duration(minutes: length)),
        isBreak: true,
      ),
    );
  }

  Future<void> pause() async {
    final active = state.active;
    if (active == null || active.isPaused) return;
    final now = _now;
    if (active.remainingAt(now) == 0) return tick();
    _stopTicker();
    final paused = active.paused(now);
    state = TimerState(active: paused, remainingSeconds: paused.remainingAt(now));
    await _boxes.meta.put(MetaKeys.activeTimer, paused);
  }

  Future<void> resume() async {
    final active = state.active;
    if (active == null || !active.isPaused) return;
    final now = _now;
    final resumed = active.resumed(now);
    state = TimerState(active: resumed, remainingSeconds: resumed.remainingAt(now));
    _startTicker();
    await _boxes.meta.put(MetaKeys.activeTimer, resumed);
  }

  /// Ends the timer now. Focus time so far is logged if it is at least
  /// [minLoggableSeconds].
  Future<void> finish() async {
    final active = state.active;
    if (active == null) return;
    final now = _now;
    await _complete(active, active.elapsedAt(now), full: active.remainingAt(now) == 0, at: now);
  }

  /// Drops the timer without logging anything.
  Future<void> discard() async {
    if (state.active == null) return;
    _stopTicker();
    state = const TimerState();
    await _boxes.meta.delete(MetaKeys.activeTimer);
  }

  /// Clears the "session finished" summary once the UI has shown it.
  void clearFinished() {
    if (state.lastFinished == null) return;
    state = TimerState(active: state.active, remainingSeconds: state.remainingSeconds);
  }

  /// Re-reads the wall clock. Called by the ticker, on app resume and on
  /// launch. Completes the session if its end time has passed.
  Future<void> tick() async {
    final active = state.active;
    if (active == null || active.isPaused) return;
    final now = _now;
    final remaining = active.remainingAt(now);
    if (remaining > 0) {
      if (remaining != state.remainingSeconds) {
        state = TimerState(active: active, remainingSeconds: remaining);
      }
      return;
    }
    // Credit the session to the moment it actually ended, which may be well
    // before now if the app was closed.
    await _complete(active, active.plannedSeconds, full: true, at: active.endsAt);
  }

  Future<void> _begin(ActiveTimer timer) async {
    state = TimerState(active: timer, remainingSeconds: timer.remainingAt(_now));
    _startTicker();
    await _boxes.meta.put(MetaKeys.activeTimer, timer);
  }

  Future<void> _closeCurrent() async {
    final active = state.active;
    if (active == null) return;
    if (active.isBreak) return discard();
    await finish();
  }

  Future<void> _complete(
    ActiveTimer timer,
    int elapsedSeconds, {
    required bool full,
    required DateTime at,
  }) async {
    _stopTicker();
    // Remove the stored timer first so a crash from here on cannot log the
    // same session twice on the next launch.
    await _boxes.meta.delete(MetaKeys.activeTimer);

    RewardEvent? reward;
    final logged = !timer.isBreak && elapsedSeconds >= minLoggableSeconds;
    if (logged) {
      await ref
          .read(sessionsProvider.notifier)
          .add(
            FocusSession(
              id: newId(),
              taskId: timer.taskId,
              taskTitle: timer.taskTitle,
              planId: timer.planId,
              subject: timer.subject,
              startedAt: timer.startedAt,
              durationSeconds: elapsedSeconds,
              plannedSeconds: timer.plannedSeconds,
              completed: full,
            ),
          );
      reward = await ref
          .read(progressProvider.notifier)
          .recordSession(
            seconds: elapsedSeconds,
            plannedSeconds: timer.plannedSeconds,
            completedFull: full,
            at: at,
          );
    }

    state = TimerState(
      lastFinished: FinishedTimer(
        taskId: timer.taskId,
        taskTitle: timer.taskTitle,
        seconds: elapsedSeconds,
        completedFull: full,
        isBreak: timer.isBreak,
        logged: logged,
        reward: reward,
      ),
    );
  }

  void _startTicker() {
    if (_ticker != null || !ref.read(timerTickerEnabledProvider)) return;
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => tick());
  }

  void _stopTicker() {
    _ticker?.cancel();
    _ticker = null;
  }
}
