import 'package:flutter_test/flutter_test.dart';
import 'package:focus_app/features/focus/data/active_timer.dart';
import 'package:focus_app/features/focus/providers/timer_notifier.dart';
import 'package:focus_app/features/focus/timer_notification_actions.dart';
import 'package:focus_app/features/plans/data/plan.dart';
import 'package:focus_app/features/plans/data/task.dart';
import 'package:focus_app/features/plans/providers/plans_providers.dart';
import 'package:focus_app/features/reminders/reminder_planner.dart';
import 'package:focus_app/features/reminders/reminder_service.dart';
import 'package:focus_app/features/reminders/reminder_sync.dart';
import 'package:focus_app/features/settings/data/app_settings.dart';
import 'package:focus_app/features/settings/providers/settings_provider.dart';

import 'support/test_env.dart';

void main() {
  final now = DateTime(2026, 3, 2, 10);
  final plans = [Plan(id: 'p1', name: 'Maths', colorValue: 1, createdAt: now)];

  Task due(String id, DateTime deadline, {bool done = false, bool daily = false}) => Task(
    id: id,
    planId: 'p1',
    title: 'Task $id',
    deadline: deadline,
    done: done,
    repeatsDaily: daily,
  );

  List<PlannedReminder> plan({
    List<Task> tasks = const [],
    AppSettings settings = const AppSettings(),
    ActiveTimer? timer,
  }) => planReminders(tasks: tasks, plans: plans, settings: settings, timer: timer, now: now);

  ActiveTimer running({bool isBreak = false}) => ActiveTimer(
    taskId: 't',
    taskTitle: 'Essay',
    startedAt: now,
    plannedSeconds: 1500,
    endsAt: now.add(const Duration(minutes: 25)),
    isBreak: isBreak,
  );

  group('planReminders', () {
    test('nothing to schedule by default', () {
      expect(plan(), isEmpty);
    });

    test('a running timer gets one exact alert at its end time', () {
      final r = plan(timer: running()).single;
      expect(r.id, ReminderIds.timerEnd);
      expect(r.at, now.add(const Duration(minutes: 25)));
      expect(r.exact, isTrue);
      expect(r.title, 'Focus session complete');
      expect(r.body, contains('Essay'));
    });

    test('breaks get their own wording; paused or expired timers get nothing', () {
      expect(plan(timer: running(isBreak: true)).single.title, 'Break is over');
      expect(plan(timer: running().paused(now)), isEmpty);
      expect(
        planReminders(
          tasks: const [],
          plans: plans,
          settings: const AppSettings(),
          timer: running(),
          now: now.add(const Duration(hours: 1)),
        ),
        isEmpty,
      );
    });

    test('daily study reminders use the chosen times', () {
      final r = plan(settings: const AppSettings(dailyReminderMinutes: [480, 1140]));
      expect([for (final x in r) (x.id, x.dailyMinuteOfDay)], [(100, 480), (101, 1140)]);
      expect(r.every((x) => x.at == null), isTrue);
    });

    test('deadline reminders fire the lead time before the deadline', () {
      final r = plan(
        tasks: [due('a', DateTime(2026, 3, 3, 18))],
        settings: const AppSettings(deadlineLeadMinutes: 180),
      ).single;
      expect(r.at, DateTime(2026, 3, 3, 15));
      expect(r.title, 'Due soon: Task a');
      expect(r.body, 'Due Today 6:00 PM · Maths');
      expect(r.exact, isFalse);
    });

    test('skips done, daily, undated and already-passed reminders', () {
      final r = plan(
        tasks: [
          due('done', DateTime(2026, 3, 3, 18), done: true),
          due('daily', DateTime(2026, 3, 3, 18), daily: true),
          const Task(id: 'undated', planId: 'p1', title: 'x'),
          due('too-late', now.add(const Duration(minutes: 30))),
          due('overdue', now.subtract(const Duration(days: 1))),
          due('ok', DateTime(2026, 3, 3, 18)),
        ],
      );
      expect(r.map((x) => x.title), ['Due soon: Task ok']);
    });

    test('the master switch turns off study and deadline reminders, not the timer', () {
      final r = plan(
        tasks: [due('a', DateTime(2026, 3, 3, 18))],
        settings: const AppSettings(remindersEnabled: false, dailyReminderMinutes: [480]),
        timer: running(),
      );
      expect(r.map((x) => x.id), [ReminderIds.timerEnd]);
    });

    test('keeps only the nearest deadlines, soonest first, with unique ids', () {
      final r = plan(tasks: [for (var i = 60; i >= 1; i--) due('t$i', now.add(Duration(days: i)))]);
      expect(r, hasLength(maxDeadlineReminders));
      expect(r.first.title, 'Due soon: Task t1');
      expect(r.last.title, 'Due soon: Task t$maxDeadlineReminders');
      expect(r.map((x) => x.id).toSet(), hasLength(maxDeadlineReminders));
      expect(r.every((x) => x.id >= ReminderIds.deadlineBase), isTrue);
    });

    test('stableHash is deterministic and matches FNV-1a', () {
      expect(stableHash(''), 0x811C9DC5);
      expect(stableHash('a'), 0xE40C292C);
      expect(stableHash('foobar'), 0xBF9CF968);
    });
  });

  group('ReminderSync', () {
    late TestEnv env;

    setUp(() async => env = await TestEnv.create(now: now));
    tearDown(() => env.dispose());

    Future<void> settle() => env.container.read(reminderSyncProvider).idle;

    test('syncs once at start, then again when tasks, settings or the timer change', () async {
      env.container.read(reminderSyncProvider);
      await settle();
      expect(env.reminders.calls, hasLength(1));
      expect(env.reminders.last, isEmpty);

      final plan = await env.container
          .read(plansProvider.notifier)
          .create(name: 'Maths', colorValue: 1, defaultFocusMinutes: 25);
      final task = await env.container
          .read(allTasksProvider.notifier)
          .add(planId: plan.id, title: 'Essay', deadline: DateTime(2026, 3, 3, 18));
      await settle();
      expect(env.reminders.last.single.title, 'Due soon: Essay');

      await env.container.read(settingsProvider.notifier).addDailyReminder(480);
      await settle();
      expect(env.reminders.last, hasLength(2));

      await env.container.read(timerNotifierProvider.notifier).start(task: task, plan: plan);
      await settle();
      expect(env.reminders.last.any((r) => r.id == ReminderIds.timerEnd), isTrue);

      await env.container.read(timerNotifierProvider.notifier).pause();
      await settle();
      expect(env.reminders.last.any((r) => r.id == ReminderIds.timerEnd), isFalse);

      await env.container.read(allTasksProvider.notifier).toggleDone(task.id);
      await settle();
      expect(env.reminders.last.map((r) => r.title), ['Time to focus']);
    });

    test('several changes in one go collapse into a single sync', () async {
      env.container.read(reminderSyncProvider);
      await settle();
      final before = env.reminders.calls.length;

      final settings = env.container.read(settingsProvider.notifier);
      final a = settings.addDailyReminder(480);
      final b = settings.setDeadlineLeadMinutes(15);
      final c = settings.setFocusMinutes(30);
      await Future.wait([a, b, c]);
      await settle();

      expect(env.reminders.calls.length, before + 1);
    });

    test('the ongoing notification follows the timer: shown, paused, resumed, hidden', () async {
      env.container.read(reminderSyncProvider);
      await settle();
      final ongoing = env.reminders.ongoing;
      expect(ongoing, [null]);

      final plan = await env.container
          .read(plansProvider.notifier)
          .create(name: 'Maths', colorValue: 1, defaultFocusMinutes: 25);
      final task = await env.container
          .read(allTasksProvider.notifier)
          .add(planId: plan.id, title: 'Essay', subject: 'Algebra');
      final timer = env.container.read(timerNotifierProvider.notifier);

      await timer.start(task: task, plan: plan);
      await settle();
      expect(ongoing.last!.title, 'Essay');
      expect(ongoing.last!.subtitle, 'Algebra');
      expect(ongoing.last!.endsAt, now.add(const Duration(minutes: 25)));
      expect(ongoing.last!.isPaused, isFalse);

      env.clock.advance(const Duration(minutes: 5));
      await timer.tick();
      await settle();
      expect(ongoing, hasLength(2), reason: 'ticks alone do not resend it');

      await timer.pause();
      await settle();
      expect(ongoing.last!.pausedRemainingSeconds, 20 * 60);

      env.clock.advance(const Duration(minutes: 3));
      await timer.resume();
      await settle();
      expect(ongoing.last!.isPaused, isFalse);
      expect(ongoing.last!.endsAt, now.add(const Duration(minutes: 28)));

      await timer.finish();
      await settle();
      expect(ongoing.last, isNull);

      await timer.startBreak(minutes: 5);
      await settle();
      expect(ongoing.last!.isBreak, isTrue);
      await timer.discard();
      await settle();
      expect(ongoing.last, isNull);
    });

    test('notification buttons pause, resume and stop the timer', () async {
      env.container.read(reminderSyncProvider);
      final plan = await env.container
          .read(plansProvider.notifier)
          .create(name: 'Maths', colorValue: 1, defaultFocusMinutes: 25);
      final task = await env.container
          .read(allTasksProvider.notifier)
          .add(planId: plan.id, title: 'Essay');
      final timer = env.container.read(timerNotifierProvider.notifier);
      TimerState state() => env.container.read(timerNotifierProvider);

      await timer.start(task: task, plan: plan);
      env.clock.advance(const Duration(minutes: 10));

      await applyTimerAction(env.container, TimerActions.pause);
      expect(state().isPaused, isTrue);
      await applyTimerAction(env.container, TimerActions.pause);
      expect(state().isPaused, isTrue, reason: 'a repeated tap changes nothing');

      await applyTimerAction(env.container, TimerActions.resume);
      expect(state().isRunning, isTrue);

      await applyTimerAction(env.container, TimerActions.stop);
      expect(state().isIdle, isTrue);
      expect(state().lastFinished!.logged, isTrue);
      expect(state().lastFinished!.seconds, 10 * 60);
      expect(env.container.read(sessionsProvider), hasLength(1));

      await applyTimerAction(env.container, 'unknown');
      await settle();
      expect(env.reminders.ongoing.last, isNull);
    });

    test('exact alarm permission is read from the service and re-checked on invalidate', () async {
      env.reminders.exactAllowed = false;
      expect(await env.container.read(exactAlarmsAllowedProvider.future), isFalse);

      env.reminders.exactAllowed = true;
      expect(
        await env.container.read(exactAlarmsAllowedProvider.future),
        isFalse,
        reason: 'cached until re-checked',
      );
      env.container.invalidate(exactAlarmsAllowedProvider);
      expect(await env.container.read(exactAlarmsAllowedProvider.future), isTrue);
    });

    test('the ongoing notification is redrawn in the new colours when the theme changes', () async {
      env.container.read(reminderSyncProvider);
      final plan = await env.container
          .read(plansProvider.notifier)
          .create(name: 'Maths', colorValue: 1, defaultFocusMinutes: 25);
      final task = await env.container
          .read(allTasksProvider.notifier)
          .add(planId: plan.id, title: 'Essay');
      await env.container.read(timerNotifierProvider.notifier).start(task: task, plan: plan);
      await settle();
      expect(env.reminders.ongoing.last!.themeId, 'peach');

      await env.container.read(settingsProvider.notifier).setTheme('midnight');
      await settle();
      expect(env.reminders.ongoing.last!.themeId, 'midnight');
      expect(env.reminders.ongoing.last!.title, 'Essay');
    });

    test('home widgets get the timer and the next tasks, most urgent first', () async {
      env.container.read(reminderSyncProvider);
      final plan = await env.container
          .read(plansProvider.notifier)
          .create(name: 'Maths', colorValue: 0xFFB5D0FF, defaultFocusMinutes: 25);
      final tasks = env.container.read(allTasksProvider.notifier);
      await tasks.add(planId: plan.id, title: 'Later', deadline: now.add(const Duration(days: 3)));
      final soon = await tasks.add(
        planId: plan.id,
        title: 'Soon',
        deadline: now.add(const Duration(hours: 2)),
        focusMinutes: 45,
      );
      final daily = await tasks.add(planId: plan.id, title: 'Vocab', repeatsDaily: true);
      final done = await tasks.add(planId: plan.id, title: 'Done already');
      await tasks.toggleDone(done.id);
      await tasks.toggleDone(daily.id);
      await settle();

      var snap = env.reminders.widgets.last;
      expect(snap.timer, isNull);
      expect(snap.themeId, 'peach');
      expect(snap.tasks.map((t) => t.title), [
        'Soon',
        'Later',
        'Vocab',
      ], reason: 'done one-off tasks are left out; done daily tasks are sent for after midnight');
      expect(snap.tasks.first.subtitle, '45 min');
      expect(snap.tasks[1].subtitle, '25 min');
      expect(snap.tasks.first.colorValue, 0xFFB5D0FF);
      expect(snap.tasks.last.doneDay, now.year * 10000 + now.month * 100 + now.day);
      expect(snap.tasks.first.doneDay, isNull);

      await env.container.read(timerNotifierProvider.notifier).start(task: soon, plan: plan);
      await settle();
      snap = env.reminders.widgets.last;
      expect(snap.timer!.title, 'Soon');
      expect(snap.timer!.endsAt, now.add(const Duration(minutes: 45)));
    });

    test('the widget start button starts focus on that task with its own length', () async {
      final plan = await env.container
          .read(plansProvider.notifier)
          .create(name: 'Maths', colorValue: 1, defaultFocusMinutes: 25);
      final task = await env.container
          .read(allTasksProvider.notifier)
          .add(planId: plan.id, title: 'Past paper', focusMinutes: 90);

      await applyTimerAction(env.container, '${TimerActions.startPrefix}${task.id}');
      final state = env.container.read(timerNotifierProvider);
      expect(state.active!.taskId, task.id);
      expect(state.active!.plannedSeconds, 90 * 60);

      await applyTimerAction(env.container, '${TimerActions.startPrefix}no-such-task');
      expect(
        env.container.read(timerNotifierProvider).active!.taskId,
        task.id,
        reason: 'a deleted task leaves the timer alone',
      );
    });
  });
}
