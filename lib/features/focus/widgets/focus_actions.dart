import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/clock.dart';
import '../../../core/design/clay_card.dart';
import '../../../core/design/clay_theme.dart';
import '../../../core/design/clay_widgets.dart';
import '../../../core/navigation.dart';
import '../../plans/data/task.dart';
import '../../plans/providers/plans_providers.dart';
import '../../reminders/reminder_sync.dart';
import '../../settings/providers/settings_provider.dart';
import '../providers/timer_notifier.dart';
import 'focus_screen.dart';

/// Opens the full-screen timer over everything else.
void openFocusScreen(BuildContext context) {
  Navigator.of(context, rootNavigator: true).push(
    PageRouteBuilder<void>(
      settings: const RouteSettings(name: 'focus'),
      transitionDuration: const Duration(milliseconds: 320),
      reverseTransitionDuration: const Duration(milliseconds: 240),
      pageBuilder: (_, _, _) => const FocusScreen(),
      transitionsBuilder: (_, animation, _, child) => SlideTransition(
        position: Tween(
          begin: const Offset(0, 1),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
        child: child,
      ),
    ),
  );
}

/// Starts a focus session on [task] and shows the timer.
Future<void> startFocusOn(
  BuildContext context,
  WidgetRef ref,
  Task task, {
  bool openScreen = true,
}) async {
  // Ask for notification permission the first time it matters, so the
  // "session complete" alert can reach the user outside the app.
  unawaited(ref.read(reminderServiceProvider).requestPermission());
  await ref
      .read(timerNotifierProvider.notifier)
      .start(task: task, plan: ref.read(planByIdProvider(task.planId)));
  if (openScreen && context.mounted) openFocusScreen(context);
}

/// "Start focus": show the running timer if there is one, otherwise let the
/// user pick a task. Pass `openScreen: false` when already on the timer.
Future<void> startFocusFlow(BuildContext context, WidgetRef ref, {bool openScreen = true}) async {
  if (!ref.read(timerNotifierProvider).isIdle) {
    if (openScreen) openFocusScreen(context);
    return;
  }
  final task = await showClaySheet<Task>(context, builder: (_) => const _TaskPicker());
  if (task != null && context.mounted) {
    await startFocusOn(context, ref, task, openScreen: openScreen);
  }
}

class _TaskPicker extends ConsumerWidget {
  const _TaskPicker();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(clockProvider)();
    ref.watch(todayProvider);
    final plans = {for (final p in ref.watch(userPlansProvider)) p.id: p};
    final defaultMinutes = ref.watch(settingsProvider.select((s) => s.focusMinutes));
    final open = ref.watch(userTasksProvider).where((t) => !t.isDoneOn(now)).toList()
      ..sort(compareUpNext);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('What are you focusing on?', style: ClayText.headline),
        const SizedBox(height: 14),
        if (open.isEmpty) ...[
          const Muted('No open tasks yet. Add a plan and a task first.', style: ClayText.body),
          const SizedBox(height: 16),
          ClayButton(
            label: 'Go to plans',
            icon: Icons.dashboard_customize_rounded,
            expand: true,
            onPressed: () {
              Navigator.of(context).pop();
              ref.read(tabIndexProvider.notifier).go(AppTab.plans);
            },
          ),
        ] else
          for (final task in open.take(30))
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: ClayCard(
                color: plans[task.planId] == null ? null : Color(plans[task.planId]!.colorValue),
                radius: 22,
                depth: 5,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                onTap: () => Navigator.of(context).pop(task),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            task.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: ClayText.label,
                          ),
                          const SizedBox(height: 2),
                          Muted(
                            '${plans[task.planId]?.name ?? ''} · '
                            '${task.focusMinutes ?? plans[task.planId]?.defaultFocusMinutes ?? defaultMinutes} min',
                            maxLines: 1,
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.play_arrow_rounded, size: 28),
                  ],
                ),
              ),
            ),
      ],
    );
  }
}
