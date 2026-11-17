import 'package:flutter_test/flutter_test.dart';
import 'package:focus_app/core/storage/app_boxes.dart';
import 'package:focus_app/features/focus/data/active_timer.dart';
import 'package:focus_app/features/focus/providers/timer_notifier.dart';
import 'package:focus_app/features/plans/data/plan.dart';
import 'package:focus_app/features/plans/data/task.dart';
import 'package:focus_app/features/plans/providers/plans_providers.dart';
import 'package:focus_app/features/progress/providers/progress_provider.dart';
import 'package:focus_app/features/settings/providers/settings_provider.dart';

import 'support/test_env.dart';

void main() {
  late TestEnv env;
  late Plan plan;
  late Task task;

  TimerNotifier timer() => env.container.read(timerNotifierProvider.notifier);
  TimerState state() => env.container.read(timerNotifierProvider);

  setUp(() async {
    env = await TestEnv.create();
    plan = await env.container
        .read(plansProvider.notifier)
        .create(name: 'Maths', colorValue: 0xFFB5D0FF, defaultFocusMinutes: 25);
    task = await env.container
        .read(allTasksProvider.notifier)
        .add(planId: plan.id, title: 'Integration practice', subject: 'Calculus');
  });

  tearDown(() => env.dispose());

  group('ActiveTimer maths', () {
    final start = DateTime(2026, 3, 2, 10);
    final running = ActiveTimer(
      taskId: 't',
      taskTitle: 'T',
      startedAt: start,
      plannedSeconds: 1500,
      endsAt: start.add(const Duration(seconds: 1500)),
    );

    test('remaining time comes from the wall clock and rounds up', () {
      expect(running.remainingAt(start), 1500);
      expect(running.remainingAt(start.add(const Duration(milliseconds: 1))), 1500);
      expect(running.remainingAt(start.add(const Duration(seconds: 1))), 1499);
      expect(running.remainingAt(start.add(const Duration(seconds: 1499, milliseconds: 500))), 1);
      expect(running.remainingAt(start.add(const Duration(seconds: 1500))), 0);
    });

    test('never goes negative, however late we look', () {
      expect(running.remainingAt(start.add(const Duration(days: 3))), 0);
      expect(running.elapsedAt(start.add(const Duration(days: 3))), 1500);
    });

    test('pausing freezes the remaining time; resuming moves the end time', () {
      final paused = running.paused(start.add(const Duration(minutes: 10)));
      expect(paused.isPaused, isTrue);
      expect(paused.remainingAt(start.add(const Duration(hours: 2))), 900);

      final resumedAt = start.add(const Duration(hours: 2));
      final resumed = paused.resumed(resumedAt);
      expect(resumed.isPaused, isFalse);
      expect(resumed.endsAt, resumedAt.add(const Duration(seconds: 900)));
      expect(resumed.elapsedAt(resumedAt), 600);
    });
  });

  group('running a session', () {
    test('starts with the plan\'s focus length and stores the end time in Hive', () async {
      await timer().start(task: task, plan: plan);

      expect(state().isRunning, isTrue);
      expect(state().remainingSeconds, 25 * 60);

      final stored = env.boxes.meta.get(MetaKeys.activeTimer) as ActiveTimer;
      expect(stored.startedAt, env.clock.now);
      expect(stored.endsAt, env.clock.now.add(const Duration(minutes: 25)));
      expect(stored.taskId, task.id);
    });

    test('falls back to the settings length when the plan is unknown', () async {
      await env.container.read(settingsProvider.notifier).setFocusMinutes(40);
      await timer().start(task: task);
      expect(state().remainingSeconds, 40 * 60);
    });

    test('an explicit length wins over plan and settings', () async {
      await timer().start(task: task, plan: plan, minutes: 15);
      expect(state().remainingSeconds, 15 * 60);
    });

    test('time passes without any ticks: one late tick shows the right time', () async {
      await timer().start(task: task, plan: plan);
      env.clock.advance(const Duration(minutes: 10, seconds: 30));
      await timer().tick();
      expect(state().remainingSeconds, 14 * 60 + 30);
      expect(state().progress, closeTo(0.42, 0.001));
    });

    test('reaching the end logs the session, awards XP and clears storage', () async {
      await timer().start(task: task, plan: plan);
      final startedAt = env.clock.now;
      env.clock.advance(const Duration(minutes: 25));
      await timer().tick();

      expect(state().isIdle, isTrue);
      expect(env.boxes.meta.get(MetaKeys.activeTimer), isNull);

      final sessions = env.container.read(sessionsProvider);
      expect(sessions, hasLength(1));
      expect(sessions.single.taskId, task.id);
      expect(sessions.single.planId, plan.id);
      expect(sessions.single.subject, 'Calculus');
      expect(sessions.single.startedAt, startedAt);
      expect(sessions.single.durationSeconds, 1500);
      expect(sessions.single.completed, isTrue);
      expect(env.boxes.sessions.length, 1);

      final finished = state().lastFinished!;
      expect(finished.completedFull, isTrue);
      expect(finished.logged, isTrue);
      expect(finished.reward?.xp, 60);
      expect(env.container.read(progressProvider).xp, 60);
      expect(env.container.read(progressProvider).totalFocusSeconds, 1500);
    });

    test('extra ticks after the end do not log the session twice', () async {
      await timer().start(task: task, plan: plan);
      env.clock.advance(const Duration(minutes: 30));
      await timer().tick();
      await timer().tick();
      await timer().finish();
      expect(env.container.read(sessionsProvider), hasLength(1));
      expect(env.container.read(progressProvider).xp, 60);
    });

    test('clearFinished drops the summary', () async {
      await timer().start(task: task, plan: plan);
      env.clock.advance(const Duration(minutes: 25));
      await timer().tick();
      timer().clearFinished();
      expect(state().lastFinished, isNull);
    });
  });

  group('pause and resume', () {
    test('paused time is not counted as focus', () async {
      await timer().start(task: task, plan: plan);
      env.clock.advance(const Duration(minutes: 10));
      await timer().pause();
      expect(state().isPaused, isTrue);
      expect(state().remainingSeconds, 15 * 60);

      env.clock.advance(const Duration(hours: 1));
      await timer().tick();
      expect(state().remainingSeconds, 15 * 60, reason: 'a paused timer does not move');

      await timer().resume();
      expect(state().isRunning, isTrue);
      env.clock.advance(const Duration(minutes: 15));
      await timer().tick();

      final session = env.container.read(sessionsProvider).single;
      expect(session.durationSeconds, 1500);
      expect(session.completed, isTrue);
    });

    test('pause and resume are no-ops in the wrong state', () async {
      await timer().pause();
      await timer().resume();
      expect(state().isIdle, isTrue);

      await timer().start(task: task, plan: plan);
      await timer().resume();
      expect(state().isRunning, isTrue);
      expect(state().remainingSeconds, 1500);
    });

    test('pausing after the end time completes the session instead', () async {
      await timer().start(task: task, plan: plan);
      env.clock.advance(const Duration(minutes: 26));
      await timer().pause();
      expect(state().isIdle, isTrue);
      expect(env.container.read(sessionsProvider).single.durationSeconds, 1500);
    });
  });

  group('finishing early', () {
    test('logs the time actually focused, without the completion bonus', () async {
      await timer().start(task: task, plan: plan);
      env.clock.advance(const Duration(minutes: 12, seconds: 20));
      await timer().finish();

      final session = env.container.read(sessionsProvider).single;
      expect(session.durationSeconds, 12 * 60 + 20);
      expect(session.plannedSeconds, 1500);
      expect(session.completed, isFalse);
      expect(env.container.read(progressProvider).xp, 24);
      expect(state().lastFinished!.completedFull, isFalse);
    });

    test('finishing while paused logs only the focused part', () async {
      await timer().start(task: task, plan: plan);
      env.clock.advance(const Duration(minutes: 5));
      await timer().pause();
      env.clock.advance(const Duration(minutes: 40));
      await timer().finish();
      expect(env.container.read(sessionsProvider).single.durationSeconds, 300);
    });

    test('under a minute is discarded, with no XP or streak', () async {
      await timer().start(task: task, plan: plan);
      env.clock.advance(const Duration(seconds: 45));
      await timer().finish();

      expect(env.container.read(sessionsProvider), isEmpty);
      expect(env.container.read(progressProvider).xp, 0);
      expect(env.container.read(progressProvider).currentStreak, 0);
      expect(state().lastFinished!.logged, isFalse);
      expect(state().isIdle, isTrue);
    });

    test('discard throws the timer away', () async {
      await timer().start(task: task, plan: plan);
      env.clock.advance(const Duration(minutes: 20));
      await timer().discard();
      expect(state().isIdle, isTrue);
      expect(state().lastFinished, isNull);
      expect(env.container.read(sessionsProvider), isEmpty);
      expect(env.boxes.meta.get(MetaKeys.activeTimer), isNull);
    });

    test('starting another task closes the current session first', () async {
      final other = await env.container
          .read(allTasksProvider.notifier)
          .add(planId: plan.id, title: 'Past paper');
      await timer().start(task: task, plan: plan);
      env.clock.advance(const Duration(minutes: 8));
      await timer().start(task: other, plan: plan);

      expect(env.container.read(sessionsProvider).single.taskId, task.id);
      expect(env.container.read(sessionsProvider).single.durationSeconds, 480);
      expect(state().active!.taskId, other.id);
      expect(state().remainingSeconds, 1500);
    });
  });

  group('app killed and relaunched', () {
    test('a running timer resumes with the right time left', () async {
      await timer().start(task: task, plan: plan);
      env.clock.advance(const Duration(minutes: 7));
      await env.restart();

      expect(state().isRunning, isTrue);
      expect(state().remainingSeconds, 18 * 60);
      expect(state().active!.taskTitle, 'Integration practice');
    });

    test('a timer that ran out while the app was closed is logged in full', () async {
      await timer().start(task: task, plan: plan);
      final startedAt = env.clock.now;
      env.clock.advance(const Duration(hours: 3));
      await env.restart();

      expect(state().remainingSeconds, 0);
      await timer().tick();

      expect(state().isIdle, isTrue);
      final session = env.container.read(sessionsProvider).single;
      expect(session.startedAt, startedAt);
      expect(session.durationSeconds, 1500);
      expect(session.completed, isTrue);
      expect(env.container.read(progressProvider).xp, 60);
    });

    test('a session that ended before midnight counts for that day\'s streak', () async {
      env.clock.set(DateTime(2026, 3, 2, 23, 30));
      await timer().start(task: task, plan: plan);
      env.clock.set(DateTime(2026, 3, 3, 9));
      await env.restart();
      await timer().tick();
      expect(env.container.read(progressProvider).lastActiveDay, DateTime(2026, 3, 2));
    });

    test('a paused timer stays paused across a restart', () async {
      await timer().start(task: task, plan: plan);
      env.clock.advance(const Duration(minutes: 10));
      await timer().pause();
      env.clock.advance(const Duration(days: 2));
      await env.restart();

      expect(state().isPaused, isTrue);
      expect(state().remainingSeconds, 15 * 60);
      await timer().tick();
      expect(state().isPaused, isTrue);
      expect(env.container.read(sessionsProvider), isEmpty);
    });

    test('logged sessions and XP are still there after a restart', () async {
      await timer().start(task: task, plan: plan);
      env.clock.advance(const Duration(minutes: 25));
      await timer().tick();
      await env.restart();

      expect(env.container.read(sessionsProvider), hasLength(1));
      expect(env.container.read(progressProvider).xp, 60);
      expect(env.container.read(progressProvider).badges.keys, contains('first_session'));
      expect(state().isIdle, isTrue);
    });
  });

  group('breaks', () {
    test('use the break length from settings and are never logged', () async {
      await env.container.read(settingsProvider.notifier).setBreakMinutes(10);
      await timer().startBreak();
      expect(state().active!.isBreak, isTrue);
      expect(state().remainingSeconds, 600);

      env.clock.advance(const Duration(minutes: 10));
      await timer().tick();

      expect(state().isIdle, isTrue);
      expect(state().lastFinished!.isBreak, isTrue);
      expect(env.container.read(sessionsProvider), isEmpty);
      expect(env.container.read(progressProvider).xp, 0);
    });

    test('starting focus during a break just drops the break', () async {
      await timer().startBreak();
      env.clock.advance(const Duration(minutes: 2));
      await timer().start(task: task, plan: plan);
      expect(state().active!.isBreak, isFalse);
      expect(env.container.read(sessionsProvider), isEmpty);
    });
  });

  group('per-task focus length', () {
    test("a task's own length wins over the plan's default", () async {
      final long = await env.container
          .read(allTasksProvider.notifier)
          .add(planId: plan.id, title: 'Past paper', focusMinutes: 90);
      final short = await env.container
          .read(allTasksProvider.notifier)
          .add(planId: plan.id, title: 'Flashcards', focusMinutes: 10);

      await timer().start(task: long, plan: plan);
      expect(state().active!.plannedSeconds, 90 * 60);

      await timer().start(task: short, plan: plan);
      expect(state().active!.plannedSeconds, 10 * 60);

      await timer().start(task: task, plan: plan);
      expect(state().active!.plannedSeconds, 25 * 60, reason: 'no own length: plan default');
    });

    test('an explicit length still overrides the task', () async {
      final long = await env.container
          .read(allTasksProvider.notifier)
          .add(planId: plan.id, title: 'Past paper', focusMinutes: 90);
      await timer().start(task: long, plan: plan, minutes: 5);
      expect(state().active!.plannedSeconds, 5 * 60);
    });

    test(
      'the length is saved, survives a restart, and can be cleared back to the default',
      () async {
        final notifier = env.container.read(allTasksProvider.notifier);
        final t = await notifier.add(planId: plan.id, title: 'Essay', focusMinutes: 45);
        await env.restart();
        final reloaded = env.container.read(allTasksProvider).firstWhere((x) => x.id == t.id);
        expect(reloaded.focusMinutes, 45);
        expect(reloaded.copyWith(title: 'Essay v2').focusMinutes, 45);

        await env.container
            .read(allTasksProvider.notifier)
            .save(reloaded.copyWith(focusMinutes: null));
        await env.restart();
        expect(
          env.container.read(allTasksProvider).firstWhere((x) => x.id == t.id).focusMinutes,
          isNull,
        );
      },
    );
  });
}
