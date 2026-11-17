import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/clock.dart';
import '../../../core/dates.dart';
import '../../../core/design/clay_card.dart';
import '../../../core/design/clay_theme.dart';
import '../../../core/design/clay_widgets.dart';
import '../../focus/widgets/focus_actions.dart';
import '../data/task.dart';
import '../providers/plans_providers.dart';

/// One task row: check circle, title, tags, and a play button that starts a
/// focus session on it.
class TaskTile extends ConsumerWidget {
  const TaskTile({
    super.key,
    required this.task,
    this.color,
    this.planName,
    this.onTap,
    this.trailing,
  });

  final Task task;

  /// Card fill, usually the plan's colour.
  final Color? color;

  /// Shown as a tag when the tile appears outside its plan.
  final String? planName;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clay = context.clay;
    final now = ref.watch(clockProvider)();
    ref.watch(todayProvider);
    final done = task.isDoneOn(now);
    final overdue = task.isOverdueOn(now);

    return Opacity(
      opacity: done ? 0.6 : 1,
      child: ClayCard(
        color: color,
        radius: 24,
        depth: done ? 3 : 6,
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
        onTap: onTap,
        child: Row(
          children: [
            ClayPressable(
              scale: 0.85,
              onTap: () => ref.read(allTasksProvider.notifier).toggleDone(task.id),
              builder: (context, _) => Semantics(
                label: done ? 'Mark as not done' : 'Mark as done',
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: SizedBox.square(
                    dimension: 30,
                    child: ClayCard(
                      inset: !done,
                      color: done ? clay.success : clay.surface,
                      radius: 15,
                      depth: 3,
                      padding: EdgeInsets.zero,
                      child: done
                          ? const Icon(Icons.check_rounded, size: 20, color: Colors.white)
                          : const SizedBox.expand(),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: ClayText.label.copyWith(
                      decoration: done ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      if (task.repeatsDaily)
                        const ClayTag(icon: Icons.repeat_rounded, label: 'Daily')
                      else if (task.deadline != null)
                        ClayTag(
                          icon: overdue ? Icons.error_rounded : Icons.event_rounded,
                          label: overdue
                              ? 'Overdue · ${formatDeadline(task.deadline!, now)}'
                              : formatDeadline(task.deadline!, now),
                          color: overdue ? const Color(0xFFC0392B) : null,
                        ),
                      if (task.priority == TaskPriority.high)
                        const ClayTag(icon: Icons.flag_rounded, label: 'High'),
                      if (task.focusMinutes != null)
                        ClayTag(icon: Icons.timer_rounded, label: '${task.focusMinutes} min'),
                      if (task.subject.isNotEmpty) ClayTag(label: task.subject),
                      if (planName != null) ClayTag(icon: Icons.folder_rounded, label: planName!),
                    ],
                  ),
                ],
              ),
            ),
            if (!done)
              ClayIconButton(
                size: 40,
                color: clay.surface,
                icon: Icons.play_arrow_rounded,
                tooltip: 'Start focus',
                onPressed: () => startFocusOn(context, ref, task),
              ),
            ?trailing,
          ],
        ),
      ),
    );
  }
}
