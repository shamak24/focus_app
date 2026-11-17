import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/clock.dart';
import '../../../core/design/clay_card.dart';
import '../../../core/design/clay_theme.dart';
import '../../../core/design/clay_widgets.dart';
import '../data/badges.dart';
import '../data/xp_rules.dart';
import '../providers/progress_provider.dart';

/// Level, XP bar and streak in one card. Shown on Home and Stats.
class LevelCard extends ConsumerWidget {
  const LevelCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clay = context.clay;
    final progress = ref.watch(progressProvider);
    final today = ref.watch(todayProvider);
    final level = LevelInfo.fromXp(progress.xp);
    final streak = progress.streakOn(today);

    return ClayCard(
      child: Row(
        children: [
          SizedBox.square(
            dimension: 58,
            child: ClayCard(
              color: clay.secondary,
              radius: 22,
              depth: 5,
              padding: EdgeInsets.zero,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('LVL', style: ClayText.caption.copyWith(fontSize: 10, height: 1)),
                    Text('${level.level}', style: ClayText.headline.copyWith(height: 1.05)),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text('${progress.xp} XP', style: ClayText.title)),
                    ClayTag(
                      icon: Icons.local_fire_department_rounded,
                      label: streak == 1 ? '1 day' : '$streak days',
                      color: streak > 0 ? clay.primary : null,
                    ),
                  ],
                ),
                const SizedBox(height: 9),
                ClayProgressBar(value: level.fraction, height: 14),
                const SizedBox(height: 7),
                Muted('${level.xpToGo} XP to level ${level.level + 1}'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// All badges, earned ones in colour and the rest greyed with their goal.
class BadgeGrid extends ConsumerWidget {
  const BadgeGrid({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clay = context.clay;
    final earned = ref.watch(progressProvider.select((p) => p.badges));
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 14,
      crossAxisSpacing: 14,
      childAspectRatio: 0.76,
      children: [
        for (final badge in badgeCatalog)
          Tooltip(
            message: badge.description,
            triggerMode: TooltipTriggerMode.tap,
            child: Opacity(
              opacity: earned.containsKey(badge.id) ? 1 : 0.45,
              child: ClayCard(
                radius: 24,
                depth: earned.containsKey(badge.id) ? 6 : 3,
                color: earned.containsKey(badge.id) ? clay.secondary : null,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      earned.containsKey(badge.id) ? badge.emoji : '🔒',
                      style: const TextStyle(fontSize: 28),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      badge.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: ClayText.caption,
                    ),
                    const SizedBox(height: 2),
                    Muted(
                      badge.description,
                      maxLines: 2,
                      textAlign: TextAlign.center,
                      style: ClayText.caption.copyWith(fontSize: 10.5),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// One quiet toast per reward: XP, plus a line for a new level or badge.
void showRewardToast(BuildContext context, RewardEvent event) {
  if (event.xp <= 0 && event.newBadges.isEmpty && event.leveledUpTo == null) return;
  final clay = context.clay;
  final extras = [
    if (event.leveledUpTo != null) 'Level ${event.leveledUpTo} reached',
    for (final id in event.newBadges)
      if (badgeById(id) case final badge?) 'New badge: ${badge.name} ${badge.emoji}',
  ];
  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      duration: Duration(milliseconds: extras.isEmpty ? 1800 : 3200),
      padding: EdgeInsets.zero,
      margin: const EdgeInsets.fromLTRB(18, 0, 18, 10),
      content: ClayCard(
        color: clay.secondary,
        radius: 22,
        depth: 5,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            const Icon(Icons.auto_awesome_rounded, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('+${event.xp} XP · ${event.label}', style: ClayText.label),
                  for (final line in extras) Text(line, style: ClayText.caption),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
