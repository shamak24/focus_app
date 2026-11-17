import 'package:hive/hive.dart';

import '../../../core/dates.dart';
import '../../../core/storage/hive_fields.dart';
import 'xp_rules.dart';

/// Everything the gamification layer remembers about the user.
class Progress {
  const Progress({
    this.xp = 0,
    this.badges = const {},
    this.currentStreak = 0,
    this.bestStreak = 0,
    this.lastActiveDay,
    this.totalSessions = 0,
    this.totalFocusSeconds = 0,
    this.tasksCompleted = 0,
  });

  final int xp;

  /// Badge id to the moment it was unlocked.
  final Map<String, DateTime> badges;

  /// Streak as of [lastActiveDay]. Use [streakOn] for display, which also
  /// accounts for days missed since then.
  final int currentStreak;
  final int bestStreak;
  final DateTime? lastActiveDay;
  final int totalSessions;
  final int totalFocusSeconds;
  final int tasksCompleted;

  /// Derived from [xp], so the two can never disagree.
  int get level => LevelInfo.fromXp(xp).level;

  /// The streak the user should see on [today]: still alive if they were
  /// active today or yesterday, otherwise broken.
  int streakOn(DateTime today) {
    final last = lastActiveDay;
    if (last == null) return 0;
    return daysBetween(last, today) <= 1 ? currentStreak : 0;
  }

  bool isActiveOn(DateTime today) => isSameDay(lastActiveDay, today);

  Progress copyWith({
    int? xp,
    Map<String, DateTime>? badges,
    int? currentStreak,
    int? bestStreak,
    DateTime? lastActiveDay,
    int? totalSessions,
    int? totalFocusSeconds,
    int? tasksCompleted,
  }) => Progress(
    xp: xp ?? this.xp,
    badges: badges ?? this.badges,
    currentStreak: currentStreak ?? this.currentStreak,
    bestStreak: bestStreak ?? this.bestStreak,
    lastActiveDay: lastActiveDay ?? this.lastActiveDay,
    totalSessions: totalSessions ?? this.totalSessions,
    totalFocusSeconds: totalFocusSeconds ?? this.totalFocusSeconds,
    tasksCompleted: tasksCompleted ?? this.tasksCompleted,
  );
}

class ProgressAdapter extends TypeAdapter<Progress> {
  @override
  final int typeId = 5;

  @override
  Progress read(BinaryReader reader) {
    final f = readFields(reader);
    final rawBadges = (f[2] as Map?) ?? const {};
    return Progress(
      xp: f[0] as int? ?? 0,
      // f[1] is the level, written for readability only. It is always
      // recomputed from xp.
      badges: {
        for (final e in rawBadges.entries)
          e.key as String: DateTime.fromMillisecondsSinceEpoch(e.value as int),
      },
      currentStreak: f[3] as int? ?? 0,
      bestStreak: f[4] as int? ?? 0,
      lastActiveDay: f[5] as DateTime?,
      totalSessions: f[6] as int? ?? 0,
      totalFocusSeconds: f[7] as int? ?? 0,
      tasksCompleted: f[8] as int? ?? 0,
    );
  }

  @override
  void write(BinaryWriter writer, Progress obj) => writeFields(writer, [
    obj.xp,
    obj.level,
    {for (final e in obj.badges.entries) e.key: e.value.millisecondsSinceEpoch},
    obj.currentStreak,
    obj.bestStreak,
    obj.lastActiveDay,
    obj.totalSessions,
    obj.totalFocusSeconds,
    obj.tasksCompleted,
  ]);
}
