import 'dart:math' as math;

import '../../../core/dates.dart';
import 'badges.dart';
import 'progress.dart';

/// The numbers behind XP. Tune them here; nothing else hard-codes them.
abstract final class XpRules {
  static const xpPerFocusMinute = 2;

  /// Bonus for letting a session run to its planned end.
  static const fullSessionBonus = 10;

  /// Sessions planned shorter than this earn no completion bonus, so a string
  /// of one-minute timers is not worth more than real focus time.
  static const minPlannedSecondsForBonus = 10 * 60;

  static const taskBase = 20;
  static const taskPriorityBonus = [0, 5, 10];
  static const taskOnTimeBonus = 5;

  static int sessionXp({
    required int seconds,
    required int plannedSeconds,
    required bool completedFull,
  }) {
    if (seconds < 60) return 0;
    final base = (seconds ~/ 60) * xpPerFocusMinute;
    final bonus = completedFull && plannedSeconds >= minPlannedSecondsForBonus
        ? fullSessionBonus
        : 0;
    return base + bonus;
  }

  static int taskXp({required int priority, required bool onTime}) {
    final p = priority.clamp(0, taskPriorityBonus.length - 1);
    return taskBase + taskPriorityBonus[p] + (onTime ? taskOnTimeBonus : 0);
  }
}

/// Where a given XP total sits on the level curve.
///
/// Level 1 to 2 costs 100 XP and each level after costs 50 more than the one
/// before: 100, 150, 200, ...
class LevelInfo {
  const LevelInfo({required this.level, required this.xpIntoLevel, required this.xpForNextLevel});

  factory LevelInfo.fromXp(int xp) {
    final total = math.max(0, xp);
    var level = 1;
    while (total >= xpToReach(level + 1)) {
      level++;
    }
    return LevelInfo(
      level: level,
      xpIntoLevel: total - xpToReach(level),
      xpForNextLevel: xpToReach(level + 1) - xpToReach(level),
    );
  }

  final int level;
  final int xpIntoLevel;
  final int xpForNextLevel;

  double get fraction => xpForNextLevel == 0 ? 0 : xpIntoLevel / xpForNextLevel;
  int get xpToGo => xpForNextLevel - xpIntoLevel;

  /// Total XP needed to reach [level] from zero.
  static int xpToReach(int level) {
    final n = level - 1;
    return 100 * n + 25 * n * (n - 1);
  }
}

/// The result of applying one rewarded action to [Progress].
class ProgressChange {
  const ProgressChange({
    required this.progress,
    required this.xpGained,
    required this.leveledUpTo,
    required this.newBadges,
  });

  final Progress progress;
  final int xpGained;

  /// The new level, or null if the level did not change.
  final int? leveledUpTo;
  final List<String> newBadges;
}

ProgressChange applySession(
  Progress before, {
  required int seconds,
  required int plannedSeconds,
  required bool completedFull,
  required DateTime at,
}) {
  final xp = XpRules.sessionXp(
    seconds: seconds,
    plannedSeconds: plannedSeconds,
    completedFull: completedFull,
  );
  final after = _touchStreak(
    before.copyWith(
      xp: before.xp + xp,
      totalSessions: before.totalSessions + 1,
      totalFocusSeconds: before.totalFocusSeconds + seconds,
    ),
    at,
  );
  return _settle(before, after, xp, at);
}

ProgressChange applyTaskCompleted(
  Progress before, {
  required int priority,
  required bool onTime,
  required DateTime at,
}) {
  final xp = XpRules.taskXp(priority: priority, onTime: onTime);
  final after = _touchStreak(
    before.copyWith(xp: before.xp + xp, tasksCompleted: before.tasksCompleted + 1),
    at,
  );
  return _settle(before, after, xp, at);
}

/// Counts [at] as an active day: extends the streak if yesterday was active,
/// restarts it after a gap, and leaves it alone for a second action today.
Progress _touchStreak(Progress p, DateTime at) {
  final today = dayOf(at);
  final last = p.lastActiveDay;
  final int streak;
  if (last == null) {
    streak = 1;
  } else {
    final gap = daysBetween(last, today);
    if (gap <= 0) return p;
    streak = gap == 1 ? p.currentStreak + 1 : 1;
  }
  return p.copyWith(
    currentStreak: streak,
    bestStreak: math.max(p.bestStreak, streak),
    lastActiveDay: today,
  );
}

ProgressChange _settle(Progress before, Progress after, int xp, DateTime at) {
  final unlocked = [
    for (final badge in badgeCatalog)
      if (!after.badges.containsKey(badge.id) && badge.isEarned(after)) badge.id,
  ];
  final settled = unlocked.isEmpty
      ? after
      : after.copyWith(badges: {...after.badges, for (final id in unlocked) id: at});
  return ProgressChange(
    progress: settled,
    xpGained: xp,
    leveledUpTo: settled.level > before.level ? settled.level : null,
    newBadges: unlocked,
  );
}
