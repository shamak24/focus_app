import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/clock.dart';
import '../../../core/dates.dart';
import '../../../core/design/clay_card.dart';
import '../../../core/design/clay_theme.dart';
import '../../../core/design/clay_widgets.dart';
import '../../../core/navigation.dart';
import '../../focus/providers/timer_notifier.dart';
import '../../focus/widgets/focus_actions.dart';
import '../../plans/data/task.dart';
import '../../plans/providers/plans_providers.dart';
import '../../plans/widgets/plan_sheets.dart';
import '../../plans/widgets/task_tile.dart';
import '../../progress/widgets/progress_widgets.dart';
import '../../stats/providers/stats_provider.dart';

/// Tasks sorted into what Home shows.
class HomeBuckets {
  HomeBuckets._(this.today, this.upcoming, this.doneToday);

  /// Open tasks for [now]'s day: overdue first, then due today by time, then
  /// the daily routine, then finished ones.
  factory HomeBuckets.from(List<Task> tasks, DateTime now) {
    final overdue = <Task>[], dueToday = <Task>[], daily = <Task>[];
    final upcoming = <Task>[], done = <Task>[];
    for (final t in tasks) {
      final deadline = t.deadline;
      if (t.isDoneOn(now)) {
        final at = t.completedAt;
        if (t.repeatsDaily || isSameDay(at, now)) done.add(t);
      } else if (t.repeatsDaily) {
        daily.add(t);
      } else if (deadline == null) {
        continue;
      } else if (deadline.isBefore(now)) {
        overdue.add(t);
      } else if (isSameDay(deadline, now)) {
        dueToday.add(t);
      } else if (daysBetween(now, deadline) <= 7) {
        upcoming.add(t);
      }
    }
    int byDeadline(Task a, Task b) => a.deadline!.compareTo(b.deadline!);
    overdue.sort(byDeadline);
    dueToday.sort(byDeadline);
    upcoming.sort(byDeadline);
    daily.sort((a, b) => a.order.compareTo(b.order));
    return HomeBuckets._([...overdue, ...dueToday, ...daily], upcoming, done);
  }

  final List<Task> today;

  /// Due in the next seven days, soonest first.
  final List<Task> upcoming;
  final List<Task> doneToday;
}

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(clockProvider)();
    ref.watch(todayProvider);
    final plans = {for (final p in ref.watch(userPlansProvider)) p.id: p};
    final buckets = HomeBuckets.from(ref.watch(userTasksProvider), now);
    final stats = ref.watch(statsProvider);

    Widget tile(Task task) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TaskTile(
        task: task,
        color: plans[task.planId] == null ? null : Color(plans[task.planId]!.colorValue),
        planName: plans[task.planId]?.name,
        onTap: () => showTaskSheet(context, planId: task.planId, task: task),
      ),
    );

    final greeting = now.hour < 12
        ? 'Good morning'
        : now.hour < 17
        ? 'Good afternoon'
        : 'Good evening';

    return ListView(
      primary: false,
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
      children: [
        Text(greeting, style: ClayText.display),
        const SizedBox(height: 2),
        Muted(
          stats.todaySeconds == 0
              ? 'No focus time yet today'
              : '${formatDuration(stats.todaySeconds)} focused today',
          style: ClayText.body,
        ),
        const SizedBox(height: 16),
        const LevelCard(),
        const SizedBox(height: 16),
        const _FocusCard(),
        const SectionHeader('Today'),
        if (plans.isEmpty)
          ClayCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Set up your first plan', style: ClayText.title),
                const SizedBox(height: 4),
                const Muted(
                  'Pick the exam prep or daily routine starter, or build your own.',
                  style: ClayText.body,
                ),
                const SizedBox(height: 14),
                ClayButton(
                  label: 'Browse plans',
                  icon: Icons.dashboard_customize_rounded,
                  onPressed: () => ref.read(tabIndexProvider.notifier).go(AppTab.plans),
                ),
              ],
            ),
          )
        else if (buckets.today.isEmpty && buckets.doneToday.isEmpty)
          const ClayCard(
            child: Muted('Nothing due today. Enjoy it, or get ahead.', style: ClayText.body),
          )
        else ...[
          ...buckets.today.map(tile),
          ...buckets.doneToday.map(tile),
        ],
        if (buckets.upcoming.isNotEmpty) ...[
          const SectionHeader('Due this week'),
          ...buckets.upcoming.map(tile),
        ],
      ],
    );
  }
}

/// The "start focus" call to action. While a timer runs it shows that
/// session instead.
class _FocusCard extends ConsumerWidget {
  const _FocusCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clay = context.clay;
    final timer = ref.watch(timerNotifierProvider);
    final active = timer.active;

    return ClayCard(
      color: clay.primary,
      radius: 32,
      depth: 9,
      padding: const EdgeInsets.all(20),
      onTap: () => startFocusFlow(context, ref),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  active == null ? 'Start focus' : formatCountdown(timer.remainingSeconds),
                  style: ClayText.headline.copyWith(
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(height: 4),
                Muted(
                  active == null
                      ? 'Pick a task and start the timer'
                      : '${timer.isPaused ? 'Paused' : 'In progress'} · ${active.taskTitle}',
                  style: ClayText.body,
                  maxLines: 2,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          SizedBox.square(
            dimension: 60,
            child: ClayCard(
              radius: 30,
              depth: 5,
              padding: EdgeInsets.zero,
              child: Icon(
                active == null ? Icons.play_arrow_rounded : Icons.open_in_full_rounded,
                size: active == null ? 36 : 26,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
