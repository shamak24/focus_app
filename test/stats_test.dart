import 'package:flutter_test/flutter_test.dart';
import 'package:focus_app/features/focus/data/focus_session.dart';
import 'package:focus_app/features/focus/providers/timer_notifier.dart';
import 'package:focus_app/features/plans/data/plan.dart';
import 'package:focus_app/features/plans/data/task.dart';
import 'package:focus_app/features/plans/providers/plans_providers.dart';
import 'package:focus_app/features/stats/providers/stats_provider.dart';

import 'support/test_env.dart';

void main() {
  // Wednesday 4 March 2026; the week began Monday 2 March.
  final now = DateTime(2026, 3, 4, 15);
  var n = 0;

  FocusSession session(DateTime at, int minutes, {String plan = 'p1', String subject = ''}) =>
      FocusSession(
        id: 's${n++}',
        taskId: 't',
        startedAt: at,
        durationSeconds: minutes * 60,
        planId: plan,
        subject: subject,
      );

  final plans = [
    Plan(id: 'p1', name: 'Maths', colorValue: 0xFF000001, createdAt: now),
    Plan(id: 'p2', name: 'Physics', colorValue: 0xFF000002, createdAt: now),
  ];

  test('empty data gives zeros and a full seven-day window', () {
    final s = computeStats(sessions: const [], tasks: const [], plans: const [], now: now);
    expect((s.todaySeconds, s.weekSeconds, s.totalSeconds, s.sessionsThisWeek), (0, 0, 0, 0));
    expect(s.lastSevenDays, hasLength(7));
    expect(s.lastSevenDays.first.day, DateTime(2026, 2, 26));
    expect(s.lastSevenDays.last.day, DateTime(2026, 3, 4));
    expect(s.byPlan, isEmpty);
    expect(s.bySubject, isEmpty);
  });

  test('splits focus time into today, this week and all time', () {
    final s = computeStats(
      sessions: [
        session(DateTime(2026, 3, 4, 9), 25),
        session(DateTime(2026, 3, 4, 0, 0), 5),
        session(DateTime(2026, 3, 2, 0, 0), 30),
        session(DateTime(2026, 3, 1, 23, 59), 40),
        session(DateTime(2026, 1, 10, 9), 60),
      ],
      tasks: const [],
      plans: plans,
      now: now,
    );
    expect(s.todaySeconds, 30 * 60);
    expect(s.weekSeconds, 60 * 60, reason: 'Sunday night belongs to last week');
    expect(s.sessionsThisWeek, 3);
    expect(s.totalSeconds, 160 * 60);
  });

  test('the seven-day chart buckets by calendar day', () {
    final s = computeStats(
      sessions: [
        session(DateTime(2026, 3, 4, 9), 25),
        session(DateTime(2026, 3, 4, 21), 25),
        session(DateTime(2026, 3, 1, 23, 59), 40),
        session(DateTime(2026, 2, 26, 0, 0), 10),
        session(DateTime(2026, 2, 25, 23, 59), 99),
      ],
      tasks: const [],
      plans: plans,
      now: now,
    );
    expect([for (final d in s.lastSevenDays) d.seconds ~/ 60], [10, 0, 0, 40, 0, 0, 50]);
  });

  test('ranks plans and subjects, and labels missing ones', () {
    final s = computeStats(
      sessions: [
        session(now, 20, plan: 'p1', subject: 'Algebra'),
        session(now, 50, plan: 'p2', subject: 'Optics'),
        session(now, 15, plan: 'p1', subject: 'Algebra'),
        session(now, 10, plan: 'gone', subject: '  '),
      ],
      tasks: const [],
      plans: plans,
      now: now,
    );
    expect(
      [for (final r in s.byPlan) (r.label, r.seconds ~/ 60)],
      [('Physics', 50), ('Maths', 35), ('Deleted plan', 10)],
    );
    expect(s.byPlan.first.colorValue, 0xFF000002);
    expect(s.byPlan.last.colorValue, isNull);
    expect(
      [for (final r in s.bySubject) (r.label, r.seconds ~/ 60)],
      [('Optics', 50), ('Algebra', 35), ('No subject', 10)],
    );
  });

  test('counts tasks completed since Monday', () {
    Task done(String id, DateTime at) =>
        Task(id: id, planId: 'p1', title: id, done: true, completedAt: at);
    final s = computeStats(
      sessions: const [],
      tasks: [
        done('a', DateTime(2026, 3, 2, 0, 0)),
        done('b', DateTime(2026, 3, 4, 14)),
        done('c', DateTime(2026, 3, 1, 22)),
        const Task(id: 'd', planId: 'p1', title: 'open'),
      ],
      plans: plans,
      now: now,
    );
    expect(s.tasksDoneThisWeek, 2);
  });

  test('statsProvider reflects a session logged through the timer', () async {
    final env = await TestEnv.create(now: now);
    try {
      final plan = await env.container
          .read(plansProvider.notifier)
          .create(name: 'History', colorValue: 7, defaultFocusMinutes: 25);
      final task = await env.container
          .read(allTasksProvider.notifier)
          .add(planId: plan.id, title: 'Essay', subject: 'WW2');

      expect(env.container.read(statsProvider).totalSeconds, 0);

      final timer = env.container.read(timerNotifierProvider.notifier);
      await timer.start(task: task, plan: plan);
      env.clock.advance(const Duration(minutes: 25));
      await timer.tick();

      final s = env.container.read(statsProvider);
      expect(s.todaySeconds, 1500);
      expect(s.byPlan.single.label, 'History');
      expect(s.byPlan.single.colorValue, 7);
      expect(s.bySubject.single.label, 'WW2');
    } finally {
      await env.dispose();
    }
  });
}
