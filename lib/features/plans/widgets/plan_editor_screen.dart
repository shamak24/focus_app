import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/clock.dart';
import '../../../core/design/clay_theme.dart';
import '../../../core/design/clay_widgets.dart';
import '../providers/plans_providers.dart';
import 'plan_sheets.dart';
import 'task_tile.dart';

/// One plan: its tasks in order, with add, edit, reorder and check-off.
class PlanEditorScreen extends ConsumerWidget {
  const PlanEditorScreen({super.key, required this.planId});

  final String planId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clay = context.clay;
    final plan = ref.watch(planByIdProvider(planId));
    final tasks = ref.watch(tasksProvider(planId));
    final now = ref.watch(clockProvider)();
    ref.watch(todayProvider);

    if (plan == null) {
      // The plan was just deleted; the route is about to be popped.
      return ColoredBox(color: clay.background);
    }
    final color = Color(plan.colorValue);
    final done = tasks.where((t) => t.isDoneOn(now)).length;

    return ColoredBox(
      color: clay.background,
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 6),
              child: Row(
                children: [
                  ClayIconButton(
                    icon: Icons.arrow_back_rounded,
                    tooltip: 'Back',
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          plan.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: ClayText.headline,
                        ),
                        Muted(
                          '$done of ${tasks.length} done · ${plan.defaultFocusMinutes} min focus',
                        ),
                      ],
                    ),
                  ),
                  ClayIconButton(
                    icon: Icons.tune_rounded,
                    tooltip: 'Edit plan',
                    onPressed: () async {
                      await showPlanSheet(context, plan: plan);
                      if (context.mounted && ref.read(planByIdProvider(planId)) == null) {
                        Navigator.of(context).maybePop();
                      }
                    },
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
              child: ClayProgressBar(value: tasks.isEmpty ? 0 : done / tasks.length, color: color),
            ),
            Expanded(
              child: tasks.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: Muted(
                          'No tasks yet.\nAdd the first one below.',
                          style: ClayText.body,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  : ReorderableListView.builder(
                      padding: const EdgeInsets.fromLTRB(18, 12, 18, 16),
                      buildDefaultDragHandles: false,
                      itemCount: tasks.length,
                      proxyDecorator: (child, _, _) =>
                          Material(type: MaterialType.transparency, child: child),
                      onReorder: (from, to) =>
                          ref.read(allTasksProvider.notifier).reorder(planId, from, to),
                      itemBuilder: (context, index) {
                        final task = tasks[index];
                        return Padding(
                          key: ValueKey(task.id),
                          padding: const EdgeInsets.only(bottom: 12),
                          child: TaskTile(
                            task: task,
                            color: color,
                            onTap: () => showTaskSheet(context, planId: planId, task: task),
                            trailing: ReorderableDragStartListener(
                              index: index,
                              child: const Padding(
                                padding: EdgeInsets.fromLTRB(8, 10, 4, 10),
                                child: Icon(Icons.drag_indicator_rounded, size: 22),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 4, 18, 14),
              child: ClayButton(
                label: 'Add task',
                icon: Icons.add_rounded,
                large: true,
                expand: true,
                onPressed: () => showTaskSheet(context, planId: planId),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
