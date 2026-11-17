import 'progress.dart';

class BadgeDef {
  const BadgeDef({
    required this.id,
    required this.name,
    required this.description,
    required this.emoji,
    required this.isEarned,
  });

  final String id;
  final String name;
  final String description;
  final String emoji;
  final bool Function(Progress progress) isEarned;
}

bool _firstSession(Progress p) => p.totalSessions >= 1;
bool _firstTask(Progress p) => p.tasksCompleted >= 1;
bool _streak3(Progress p) => p.bestStreak >= 3;
bool _streak7(Progress p) => p.bestStreak >= 7;
bool _streak30(Progress p) => p.bestStreak >= 30;
bool _tasks10(Progress p) => p.tasksCompleted >= 10;
bool _tasks50(Progress p) => p.tasksCompleted >= 50;
bool _focus5h(Progress p) => p.totalFocusSeconds >= 5 * 3600;
bool _focus25h(Progress p) => p.totalFocusSeconds >= 25 * 3600;
bool _level5(Progress p) => p.level >= 5;
bool _level10(Progress p) => p.level >= 10;

/// Every badge in the app, in display order. Add new ones at the end.
const badgeCatalog = <BadgeDef>[
  BadgeDef(
    id: 'first_session',
    name: 'First Focus',
    description: 'Finish your first focus session',
    emoji: '🌱',
    isEarned: _firstSession,
  ),
  BadgeDef(
    id: 'first_task',
    name: 'Ticked Off',
    description: 'Complete your first task',
    emoji: '✅',
    isEarned: _firstTask,
  ),
  BadgeDef(
    id: 'streak_3',
    name: 'Warming Up',
    description: 'Stay active 3 days in a row',
    emoji: '🔥',
    isEarned: _streak3,
  ),
  BadgeDef(
    id: 'streak_7',
    name: 'On a Roll',
    description: 'Keep a 7-day streak',
    emoji: '🏆',
    isEarned: _streak7,
  ),
  BadgeDef(
    id: 'streak_30',
    name: 'Unstoppable',
    description: 'Keep a 30-day streak',
    emoji: '🌟',
    isEarned: _streak30,
  ),
  BadgeDef(
    id: 'tasks_10',
    name: 'Task Tamer',
    description: 'Complete 10 tasks',
    emoji: '📚',
    isEarned: _tasks10,
  ),
  BadgeDef(
    id: 'tasks_50',
    name: 'Graduate',
    description: 'Complete 50 tasks',
    emoji: '🎓',
    isEarned: _tasks50,
  ),
  BadgeDef(
    id: 'focus_5h',
    name: 'Deep Diver',
    description: 'Focus for 5 hours in total',
    emoji: '⏳',
    isEarned: _focus5h,
  ),
  BadgeDef(
    id: 'focus_25h',
    name: 'Big Brain',
    description: 'Focus for 25 hours in total',
    emoji: '🧠',
    isEarned: _focus25h,
  ),
  BadgeDef(
    id: 'level_5',
    name: 'Lift-off',
    description: 'Reach level 5',
    emoji: '🚀',
    isEarned: _level5,
  ),
  BadgeDef(
    id: 'level_10',
    name: 'Royalty',
    description: 'Reach level 10',
    emoji: '👑',
    isEarned: _level10,
  ),
];

BadgeDef? badgeById(String id) {
  for (final badge in badgeCatalog) {
    if (badge.id == id) return badge;
  }
  return null;
}
