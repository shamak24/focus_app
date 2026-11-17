import 'package:flutter_test/flutter_test.dart';
import 'package:focus_app/core/dates.dart';
import 'package:focus_app/core/ids.dart';
import 'package:focus_app/core/storage/app_boxes.dart';
import 'package:focus_app/features/focus/data/active_timer.dart';
import 'package:focus_app/features/focus/data/focus_session.dart';
import 'package:focus_app/features/plans/data/plan.dart';
import 'package:focus_app/features/plans/data/task.dart';
import 'package:focus_app/features/progress/data/progress.dart';
import 'package:focus_app/features/settings/data/app_settings.dart';
import 'package:focus_app/features/settings/providers/settings_provider.dart';

import 'support/test_env.dart';

void main() {
  late TestEnv env;

  setUp(() async => env = await TestEnv.create(seed: false));
  tearDown(() => env.dispose());

  group('Hive adapters round-trip through disk', () {
    test('Plan', () async {
      final plan = Plan(
        id: 'p1',
        name: 'Chemistry',
        colorValue: 0xFFCDBDFA,
        isPreset: true,
        defaultFocusMinutes: 50,
        description: 'Organic',
        createdAt: DateTime(2026, 1, 5, 8, 30),
      );
      await env.boxes.plans.put(plan.id, plan);
      await env.restart();

      final read = env.boxes.plans.get('p1')!;
      expect(read.name, 'Chemistry');
      expect(read.colorValue, 0xFFCDBDFA);
      expect(read.isPreset, isTrue);
      expect(read.defaultFocusMinutes, 50);
      expect(read.description, 'Organic');
      expect(read.createdAt, DateTime(2026, 1, 5, 8, 30));
    });

    test('Task, with and without optional fields', () async {
      final full = Task(
        id: 't1',
        planId: 'p1',
        title: 'Titration lab',
        deadline: DateTime(2026, 3, 9, 18),
        priority: TaskPriority.high,
        done: true,
        subject: 'Lab',
        order: 4,
        completedAt: DateTime(2026, 3, 8, 12),
        repeatsDaily: true,
        dayOffset: -3,
        lastXpAt: DateTime(2026, 3, 8, 12),
      );
      const bare = Task(id: 't2', planId: 'p1', title: 'Bare');
      await env.boxes.tasks.putAll({'t1': full, 't2': bare});
      await env.restart();

      final a = env.boxes.tasks.get('t1')!;
      expect(a.title, 'Titration lab');
      expect(a.deadline, DateTime(2026, 3, 9, 18));
      expect(a.priority, TaskPriority.high);
      expect(a.done, isTrue);
      expect(a.subject, 'Lab');
      expect(a.order, 4);
      expect(a.completedAt, DateTime(2026, 3, 8, 12));
      expect(a.repeatsDaily, isTrue);
      expect(a.dayOffset, -3);
      expect(a.lastXpAt, DateTime(2026, 3, 8, 12));

      final b = env.boxes.tasks.get('t2')!;
      expect(b.deadline, isNull);
      expect(b.completedAt, isNull);
      expect(b.dayOffset, isNull);
      expect(b.priority, TaskPriority.medium);
      expect(b.done, isFalse);
    });

    test('FocusSession', () async {
      await env.boxes.sessions.put(
        's1',
        FocusSession(
          id: 's1',
          taskId: 't1',
          startedAt: DateTime(2026, 3, 2, 9, 15),
          durationSeconds: 1500,
          planId: 'p1',
          subject: 'Lab',
          taskTitle: 'Titration lab',
          plannedSeconds: 1500,
          completed: true,
        ),
      );
      await env.restart();

      final s = env.boxes.sessions.get('s1')!;
      expect(s.taskId, 't1');
      expect(s.startedAt, DateTime(2026, 3, 2, 9, 15));
      expect(s.durationSeconds, 1500);
      expect(s.planId, 'p1');
      expect(s.subject, 'Lab');
      expect(s.taskTitle, 'Titration lab');
      expect(s.plannedSeconds, 1500);
      expect(s.completed, isTrue);
    });

    test('AppSettings', () async {
      await env.boxes.meta.put(
        MetaKeys.settings,
        const AppSettings(
          themeId: 'midnight',
          focusMinutes: 45,
          breakMinutes: 10,
          remindersEnabled: false,
          dailyReminderMinutes: [480, 1140],
          deadlineLeadMinutes: 180,
        ),
      );
      await env.restart();

      final s = env.boxes.meta.get(MetaKeys.settings) as AppSettings;
      expect(s.themeId, 'midnight');
      expect(s.focusMinutes, 45);
      expect(s.breakMinutes, 10);
      expect(s.remindersEnabled, isFalse);
      expect(s.dailyReminderMinutes, [480, 1140]);
      expect(s.deadlineLeadMinutes, 180);
    });

    test('Progress, including the badge map', () async {
      await env.boxes.meta.put(
        MetaKeys.progress,
        Progress(
          xp: 470,
          badges: {'first_session': DateTime(2026, 3, 1, 9), 'streak_3': DateTime(2026, 3, 3, 9)},
          currentStreak: 3,
          bestStreak: 5,
          lastActiveDay: DateTime(2026, 3, 3),
          totalSessions: 12,
          totalFocusSeconds: 18000,
          tasksCompleted: 7,
        ),
      );
      await env.restart();

      final p = env.boxes.meta.get(MetaKeys.progress) as Progress;
      expect(p.xp, 470);
      expect(p.level, 4);
      expect(p.badges, {
        'first_session': DateTime(2026, 3, 1, 9),
        'streak_3': DateTime(2026, 3, 3, 9),
      });
      expect(p.currentStreak, 3);
      expect(p.bestStreak, 5);
      expect(p.lastActiveDay, DateTime(2026, 3, 3));
      expect(p.totalSessions, 12);
      expect(p.totalFocusSeconds, 18000);
      expect(p.tasksCompleted, 7);
    });

    test('ActiveTimer, running and paused', () async {
      final start = DateTime(2026, 3, 2, 10);
      final running = ActiveTimer(
        taskId: 't1',
        taskTitle: 'Titration lab',
        planId: 'p1',
        subject: 'Lab',
        colorValue: 0xFFB5D0FF,
        startedAt: start,
        plannedSeconds: 1500,
        endsAt: start.add(const Duration(minutes: 25)),
      );
      await env.boxes.meta.put(MetaKeys.activeTimer, running);
      await env.restart();
      final a = env.boxes.meta.get(MetaKeys.activeTimer) as ActiveTimer;
      expect(a.taskTitle, 'Titration lab');
      expect(a.colorValue, 0xFFB5D0FF);
      expect(a.startedAt, start);
      expect(a.endsAt, start.add(const Duration(minutes: 25)));
      expect(a.isPaused, isFalse);
      expect(a.isBreak, isFalse);

      await env.boxes.meta.put(
        MetaKeys.activeTimer,
        running.paused(start.add(const Duration(minutes: 5))),
      );
      await env.restart();
      final b = env.boxes.meta.get(MetaKeys.activeTimer) as ActiveTimer;
      expect(b.pausedRemainingSeconds, 1200);
    });
  });

  group('Task state', () {
    final now = DateTime(2026, 3, 2, 10);

    test('copyWith can clear nullable fields', () {
      final t = Task(id: 't', planId: 'p', title: 'x', deadline: now, completedAt: now);
      expect(t.copyWith(title: 'y').deadline, now);
      expect(t.copyWith(deadline: null).deadline, isNull);
      expect(t.copyWith(completedAt: null).completedAt, isNull);
    });

    test('a normal task is overdue once its deadline passes, unless done', () {
      final t = Task(id: 't', planId: 'p', title: 'x', deadline: now);
      expect(t.isOverdueOn(now.subtract(const Duration(minutes: 1))), isFalse);
      expect(t.isOverdueOn(now.add(const Duration(minutes: 1))), isTrue);
      expect(t.copyWith(done: true).isOverdueOn(now.add(const Duration(days: 1))), isFalse);
    });

    test('a daily task is done only on the day it was completed', () {
      final t = Task(
        id: 't',
        planId: 'p',
        title: 'x',
        repeatsDaily: true,
        done: true,
        completedAt: DateTime(2026, 3, 2, 23, 59),
      );
      expect(t.isDoneOn(DateTime(2026, 3, 2, 8)), isTrue);
      expect(t.isDoneOn(DateTime(2026, 3, 3, 0, 1)), isFalse);
    });
  });

  group('settings', () {
    SettingsNotifier settings() => env.container.read(settingsProvider.notifier);

    test('defaults', () {
      final s = env.container.read(settingsProvider);
      expect(
        (s.themeId, s.focusMinutes, s.breakMinutes, s.remindersEnabled),
        ('peach', 25, 5, true),
      );
    });

    test('lengths are clamped to sane ranges', () async {
      await settings().setFocusMinutes(999);
      await settings().setBreakMinutes(0);
      final s = env.container.read(settingsProvider);
      expect(s.focusMinutes, SettingsNotifier.maxFocusMinutes);
      expect(s.breakMinutes, SettingsNotifier.minBreakMinutes);
    });

    test('theme choice persists and drives themeProvider', () async {
      await settings().setTheme('lavender');
      expect(env.container.read(themeProvider), 'lavender');
      await env.restart();
      expect(env.container.read(themeProvider), 'lavender');
    });

    test('daily reminder times are sorted, de-duplicated and capped', () async {
      await settings().addDailyReminder(1140);
      await settings().addDailyReminder(480);
      await settings().addDailyReminder(480);
      expect(env.container.read(settingsProvider).dailyReminderMinutes, [480, 1140]);

      for (var i = 0; i < 10; i++) {
        await settings().addDailyReminder(600 + i);
      }
      expect(
        env.container.read(settingsProvider).dailyReminderMinutes,
        hasLength(SettingsNotifier.maxDailyReminders),
      );

      await settings().removeDailyReminder(480);
      expect(env.container.read(settingsProvider).dailyReminderMinutes, isNot(contains(480)));
    });
  });

  group('helpers', () {
    test('ids are unique', () {
      final ids = {for (var i = 0; i < 5000; i++) newId()};
      expect(ids.length, 5000);
    });

    test('daysBetween counts calendar days, not 24-hour blocks', () {
      expect(daysBetween(DateTime(2026, 3, 2, 23, 59), DateTime(2026, 3, 3, 0, 1)), 1);
      expect(daysBetween(DateTime(2026, 3, 2, 0, 1), DateTime(2026, 3, 2, 23, 59)), 0);
      expect(daysBetween(DateTime(2026, 3, 5), DateTime(2026, 3, 2)), -3);
      expect(daysBetween(DateTime(2025, 12, 31), DateTime(2026, 1, 1)), 1);
    });

    test('startOfWeek is Monday', () {
      expect(startOfWeek(DateTime(2026, 3, 2, 15)), DateTime(2026, 3, 2));
      expect(startOfWeek(DateTime(2026, 3, 8, 23)), DateTime(2026, 3, 2));
      expect(startOfWeek(DateTime(2026, 3, 1, 9)), DateTime(2026, 2, 23));
    });

    test('formatting', () {
      expect(formatCountdown(1500), '25:00');
      expect(formatCountdown(61), '01:01');
      expect(formatCountdown(5400), '90:00');
      expect(formatCountdown(-4), '00:00');
      expect(formatDuration(0), '0m');
      expect(formatDuration(2400), '40m');
      expect(formatDuration(3600), '1h');
      expect(formatDuration(5100), '1h 25m');
      expect(formatClock(DateTime(2026, 1, 1, 0, 5)), '12:05 AM');
      expect(formatClock(DateTime(2026, 1, 1, 18)), '6:00 PM');
      expect(formatMinuteOfDay(480), '8:00 AM');

      final now = DateTime(2026, 3, 2, 10);
      expect(formatDeadline(DateTime(2026, 3, 2, 18), now), 'Today 6:00 PM');
      expect(formatDeadline(DateTime(2026, 3, 3, 9, 30), now), 'Tomorrow 9:30 AM');
      expect(formatDeadline(DateTime(2026, 3, 5, 18), now), 'Thu 6:00 PM');
      expect(formatDeadline(DateTime(2026, 3, 20, 18), now), '20 Mar');
      expect(formatDeadline(DateTime(2027, 1, 4, 18), now), '4 Jan 2027');
      expect(formatDeadline(DateTime(2026, 3, 1, 18), now), 'Yesterday');
    });
  });
}
