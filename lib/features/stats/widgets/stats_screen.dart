import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/clock.dart';
import '../../../core/dates.dart';
import '../../../core/design/clay_card.dart';
import '../../../core/design/clay_theme.dart';
import '../../../core/design/clay_widgets.dart';
import '../../progress/providers/progress_provider.dart';
import '../../progress/widgets/progress_widgets.dart';
import '../providers/stats_provider.dart';

class StatsScreen extends ConsumerWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clay = context.clay;
    final stats = ref.watch(statsProvider);
    final progress = ref.watch(progressProvider);
    final today = ref.watch(todayProvider);

    return ListView(
      primary: false,
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
      children: [
        const Text('Stats', style: ClayText.display),
        const SizedBox(height: 16),
        const LevelCard(),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: _StatTile(
                label: 'This week',
                value: formatDuration(stats.weekSeconds),
                detail: '${stats.sessionsThisWeek} sessions',
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: _StatTile(
                label: 'Tasks this week',
                value: '${stats.tasksDoneThisWeek}',
                detail: '${progress.tasksCompleted} all time',
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: _StatTile(
                label: 'Streak',
                value: '${progress.streakOn(today)} d',
                detail: 'Best ${progress.bestStreak} d',
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: _StatTile(
                label: 'Total focus',
                value: formatDuration(stats.totalSeconds),
                detail: '${progress.totalSessions} sessions',
              ),
            ),
          ],
        ),
        const SectionHeader('Last 7 days'),
        ClayCard(child: _WeekChart(days: stats.lastSevenDays)),
        const SectionHeader('Focus by plan'),
        _Breakdown(rows: stats.byPlan, fallback: clay.primary),
        const SectionHeader('Focus by subject'),
        _Breakdown(rows: stats.bySubject, fallback: clay.secondary),
        SectionHeader('Badges', trailing: Muted('${progress.badges.length} earned')),
        const BadgeGrid(),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value, required this.detail});

  final String label;
  final String value;
  final String detail;

  @override
  Widget build(BuildContext context) => ClayCard(
    radius: 26,
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Muted(label, maxLines: 1),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(value, style: ClayText.headline),
        ),
        const SizedBox(height: 2),
        Muted(detail, maxLines: 1),
      ],
    ),
  );
}

/// Seven clay bars, one per day, with today in the primary colour.
class _WeekChart extends StatelessWidget {
  const _WeekChart({required this.days});

  final List<DayTotal> days;

  @override
  Widget build(BuildContext context) {
    final clay = context.clay;
    final peak = days.fold<int>(0, (max, d) => d.seconds > max ? d.seconds : max);
    const chartHeight = 120.0;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (var i = 0; i < days.length; i++)
          Expanded(
            child: Semantics(
              label: '${weekdayShort(days[i].day)}: ${formatDuration(days[i].seconds)}',
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Muted(
                    days[i].seconds == 0 ? '' : formatDuration(days[i].seconds),
                    style: ClayText.caption.copyWith(fontSize: 10),
                    maxLines: 1,
                  ),
                  const SizedBox(height: 4),
                  SizedBox(
                    height: chartHeight,
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: FractionallySizedBox(
                        widthFactor: 0.62,
                        heightFactor: peak == 0 ? 0.06 : (days[i].seconds / peak).clamp(0.06, 1.0),
                        child: ClayCard(
                          color: i == days.length - 1
                              ? clay.primary
                              : Color.alphaBlend(
                                  clay.primary.withValues(alpha: 0.35),
                                  clay.surface,
                                ),
                          radius: 12,
                          depth: 3,
                          padding: EdgeInsets.zero,
                          child: const SizedBox.expand(),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(weekdayShort(days[i].day), style: ClayText.caption.copyWith(fontSize: 11)),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// Ranked list of totals with proportional bars.
class _Breakdown extends StatelessWidget {
  const _Breakdown({required this.rows, required this.fallback});

  final List<NamedTotal> rows;
  final Color fallback;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return const ClayCard(
        child: Muted('Finish a focus session to see this fill in.', style: ClayText.body),
      );
    }
    final peak = rows.first.seconds;
    return ClayCard(
      child: Column(
        children: [
          for (final (i, row) in rows.take(6).indexed) ...[
            if (i > 0) const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: Text(
                    row.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: ClayText.label,
                  ),
                ),
                Muted(formatDuration(row.seconds)),
              ],
            ),
            const SizedBox(height: 6),
            ClayProgressBar(
              value: peak == 0 ? 0 : row.seconds / peak,
              height: 12,
              color: row.colorValue == null ? fallback : Color(row.colorValue!),
            ),
          ],
        ],
      ),
    );
  }
}
