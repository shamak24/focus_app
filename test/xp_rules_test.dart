import 'package:flutter_test/flutter_test.dart';
import 'package:focus_app/features/plans/data/task.dart';
import 'package:focus_app/features/progress/data/badges.dart';
import 'package:focus_app/features/progress/data/progress.dart';
import 'package:focus_app/features/progress/data/xp_rules.dart';

void main() {
  final day1 = DateTime(2026, 3, 2, 10);

  Progress session(Progress p, DateTime at, {int minutes = 25}) => applySession(
    p,
    seconds: minutes * 60,
    plannedSeconds: minutes * 60,
    completedFull: true,
    at: at,
  ).progress;

  group('session XP', () {
    test('pays per focused minute plus a bonus for a full session', () {
      expect(XpRules.sessionXp(seconds: 25 * 60, plannedSeconds: 25 * 60, completedFull: true), 60);
    });

    test('an early finish earns the minutes but no bonus', () {
      expect(
        XpRules.sessionXp(seconds: 10 * 60, plannedSeconds: 25 * 60, completedFull: false),
        20,
      );
    });

    test('partial minutes round down and under a minute earns nothing', () {
      expect(XpRules.sessionXp(seconds: 119, plannedSeconds: 1500, completedFull: false), 2);
      expect(XpRules.sessionXp(seconds: 59, plannedSeconds: 1500, completedFull: false), 0);
    });

    test('very short timers get no completion bonus', () {
      expect(XpRules.sessionXp(seconds: 5 * 60, plannedSeconds: 5 * 60, completedFull: true), 10);
    });
  });

  group('task XP', () {
    test('adds priority and on-time bonuses to the base', () {
      expect(XpRules.taskXp(priority: TaskPriority.low, onTime: false), 20);
      expect(XpRules.taskXp(priority: TaskPriority.medium, onTime: true), 30);
      expect(XpRules.taskXp(priority: TaskPriority.high, onTime: true), 35);
    });

    test('tolerates an out-of-range priority', () {
      expect(XpRules.taskXp(priority: 99, onTime: false), 30);
      expect(XpRules.taskXp(priority: -1, onTime: false), 20);
    });
  });

  group('levels', () {
    test('thresholds grow by 50 XP per level', () {
      expect(LevelInfo.xpToReach(1), 0);
      expect(LevelInfo.xpToReach(2), 100);
      expect(LevelInfo.xpToReach(3), 250);
      expect(LevelInfo.xpToReach(4), 450);
    });

    test('fromXp reports level and progress inside it', () {
      final zero = LevelInfo.fromXp(0);
      expect((zero.level, zero.xpIntoLevel, zero.xpForNextLevel), (1, 0, 100));

      expect(LevelInfo.fromXp(99).level, 1);
      expect(LevelInfo.fromXp(100).level, 2);

      final mid = LevelInfo.fromXp(300);
      expect((mid.level, mid.xpIntoLevel, mid.xpForNextLevel, mid.xpToGo), (3, 50, 200, 150));
      expect(mid.fraction, closeTo(0.25, 1e-9));
    });

    test('negative XP is treated as zero', () {
      expect(LevelInfo.fromXp(-50).level, 1);
    });

    test('a reward that crosses a threshold reports the new level', () {
      final change = applySession(
        const Progress(xp: 90),
        seconds: 1500,
        plannedSeconds: 1500,
        completedFull: true,
        at: day1,
      );
      expect(change.xpGained, 60);
      expect(change.progress.xp, 150);
      expect(change.leveledUpTo, 2);
    });

    test('no level change reports null', () {
      final change = applyTaskCompleted(const Progress(), priority: 0, onTime: false, at: day1);
      expect(change.leveledUpTo, isNull);
    });
  });

  group('streaks', () {
    test('first activity starts a streak of one', () {
      final p = session(const Progress(), day1);
      expect(p.currentStreak, 1);
      expect(p.bestStreak, 1);
      expect(p.lastActiveDay, DateTime(2026, 3, 2));
    });

    test('a second action the same day does not extend it', () {
      var p = session(const Progress(), day1);
      p = session(p, day1.add(const Duration(hours: 5)));
      expect(p.currentStreak, 1);
      expect(p.totalSessions, 2);
    });

    test('consecutive days extend it, including across midnight', () {
      var p = session(const Progress(), DateTime(2026, 3, 2, 23, 50));
      p = session(p, DateTime(2026, 3, 3, 0, 10));
      p = session(p, DateTime(2026, 3, 4, 18));
      expect(p.currentStreak, 3);
      expect(p.bestStreak, 3);
    });

    test('a missed day restarts the streak but keeps the best', () {
      var p = const Progress();
      for (var d = 2; d <= 5; d++) {
        p = session(p, DateTime(2026, 3, d, 9));
      }
      expect(p.currentStreak, 4);
      p = session(p, DateTime(2026, 3, 8, 9));
      expect(p.currentStreak, 1);
      expect(p.bestStreak, 4);
    });

    test('finishing a task also counts as an active day', () {
      var p = session(const Progress(), day1);
      p = applyTaskCompleted(
        p,
        priority: 1,
        onTime: true,
        at: day1.add(const Duration(days: 1)),
      ).progress;
      expect(p.currentStreak, 2);
    });

    test('streakOn shows 0 once a full day has been missed', () {
      final p = session(session(const Progress(), day1), day1.add(const Duration(days: 1)));
      expect(p.streakOn(DateTime(2026, 3, 3, 22)), 2);
      expect(p.streakOn(DateTime(2026, 3, 4, 8)), 2, reason: 'still time to keep it today');
      expect(p.streakOn(DateTime(2026, 3, 5, 8)), 0);
      expect(const Progress().streakOn(day1), 0);
    });

    test('streaks survive a month boundary', () {
      var p = session(const Progress(), DateTime(2026, 2, 28, 20));
      p = session(p, DateTime(2026, 3, 1, 7));
      expect(p.currentStreak, 2);
    });
  });

  group('badges', () {
    test('catalog ids are unique', () {
      final ids = badgeCatalog.map((b) => b.id).toList();
      expect(ids.toSet().length, ids.length);
      expect(badgeById('streak_7')?.name, 'On a Roll');
      expect(badgeById('nope'), isNull);
    });

    test('first session unlocks First Focus exactly once', () {
      final first = applySession(
        const Progress(),
        seconds: 1500,
        plannedSeconds: 1500,
        completedFull: true,
        at: day1,
      );
      expect(first.newBadges, ['first_session']);
      expect(first.progress.badges['first_session'], day1);

      final second = applySession(
        first.progress,
        seconds: 1500,
        plannedSeconds: 1500,
        completedFull: true,
        at: day1,
      );
      expect(second.newBadges, isEmpty);
      expect(second.progress.badges.length, 1);
    });

    test('a 7-day streak unlocks the streak badges on the right days', () {
      var p = const Progress();
      final unlockedOn = <String, int>{};
      for (var i = 0; i < 7; i++) {
        final change = applySession(
          p,
          seconds: 600,
          plannedSeconds: 600,
          completedFull: true,
          at: day1.add(Duration(days: i)),
        );
        for (final id in change.newBadges) {
          unlockedOn[id] = i + 1;
        }
        p = change.progress;
      }
      expect(unlockedOn['streak_3'], 3);
      expect(unlockedOn['streak_7'], 7);
      expect(p.badges.containsKey('streak_30'), isFalse);
    });

    test('the tenth task unlocks Task Tamer', () {
      var p = const Progress();
      List<String> last = const [];
      for (var i = 0; i < 10; i++) {
        final change = applyTaskCompleted(p, priority: 0, onTime: true, at: day1);
        last = change.newBadges;
        p = change.progress;
      }
      expect(p.tasksCompleted, 10);
      expect(last, contains('tasks_10'));
    });

    test('focus-time and level badges unlock from totals', () {
      final change = applySession(
        const Progress(totalFocusSeconds: 5 * 3600 - 600, xp: 990, totalSessions: 9),
        seconds: 600,
        plannedSeconds: 600,
        completedFull: true,
        at: day1,
      );
      expect(change.newBadges, containsAll(['focus_5h', 'level_5']));
    });
  });
}
