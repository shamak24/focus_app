import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/clock.dart';
import '../../../core/dates.dart';
import '../../../core/design/clay_theme.dart';
import '../../../core/design/clay_widgets.dart';
import '../../plans/providers/plans_providers.dart';
import '../../settings/providers/settings_provider.dart';
import '../providers/timer_notifier.dart';
import 'focus_actions.dart';
import 'timer_ring.dart';

/// Full-screen timer: the active task, the ring, and pause / finish controls.
/// When a timer ends it turns into a short summary with the next step.
class FocusScreen extends ConsumerWidget {
  const FocusScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timer = ref.watch(timerNotifierProvider);
    final active = timer.active;

    void close() {
      ref.read(timerNotifierProvider.notifier).clearFinished();
      Navigator.of(context).pop();
    }

    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) ref.read(timerNotifierProvider.notifier).clearFinished();
      },
      child: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 10, 22, 22),
            child: Column(
              children: [
                Row(
                  children: [
                    ClayIconButton(
                      icon: Icons.keyboard_arrow_down_rounded,
                      tooltip: 'Minimise',
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    const Spacer(),
                    if (active != null)
                      ClayTag(
                        icon: active.isBreak ? Icons.coffee_rounded : Icons.bolt_rounded,
                        label: timer.isPaused ? 'Paused' : (active.isBreak ? 'Break' : 'Focus'),
                      ),
                  ],
                ),
                Expanded(
                  child: active != null
                      ? _Running(timer: timer)
                      : timer.lastFinished != null
                      ? _Finished(finished: timer.lastFinished!, onClose: close)
                      : const _Idle(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Running extends ConsumerWidget {
  const _Running({required this.timer});

  final TimerState timer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = timer.active!;
    final notifier = ref.read(timerNotifierProvider.notifier);
    final accent = active.colorValue == 0 ? null : Color(active.colorValue);

    final title = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          active.taskTitle,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: ClayText.headline,
        ),
        if (active.subject.isNotEmpty) ...[
          const SizedBox(height: 6),
          Muted(active.subject, style: ClayText.body),
        ],
      ],
    );

    Widget ring(double size) => TimerRing(
      size: size,
      progress: timer.progress,
      color: accent,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            formatCountdown(timer.remainingSeconds),
            style: ClayText.display.copyWith(
              fontSize: size * 0.19,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          Muted('of ${active.plannedSeconds ~/ 60} min'),
        ],
      ),
    );

    final controls = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: ClayButton(
                large: true,
                expand: true,
                icon: timer.isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                label: timer.isPaused ? 'Resume' : 'Pause',
                onPressed: timer.isPaused ? notifier.resume : notifier.pause,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: ClayButton(
                large: true,
                expand: true,
                color: context.clay.surface,
                icon: Icons.check_rounded,
                label: active.isBreak ? 'End break' : 'Finish',
                onPressed: notifier.finish,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        if (!active.isBreak)
          TextButton(
            onPressed: () async {
              final ok = await confirmClay(
                context,
                title: 'Discard this session?',
                message: 'The time so far will not be logged and earns no XP.',
                confirmLabel: 'Discard',
              );
              if (ok) await notifier.discard();
            },
            child: const Muted('Discard session', style: ClayText.label),
          ),
      ],
    );

    return LayoutBuilder(
      builder: (context, box) {
        // Landscape: there is far too little height to stack everything, so
        // the ring takes the full height on the left and the rest sits beside
        // it.
        if (box.maxWidth > box.maxHeight * 1.2) {
          final size = (box.maxHeight - 8).clamp(120.0, box.maxWidth * 0.45);
          return Row(
            children: [
              Expanded(child: Center(child: ring(size))),
              const SizedBox(width: 24),
              Expanded(
                child: Center(
                  // Scrolls rather than overflowing if text is scaled up.
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [title, const SizedBox(height: 20), controls],
                    ),
                  ),
                ),
              ),
            ],
          );
        }
        final size = (box.maxHeight * 0.52).clamp(180.0, 300.0);
        return Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [title, ring(size), controls],
        );
      },
    );
  }
}

class _Finished extends ConsumerWidget {
  const _Finished({required this.finished, required this.onClose});

  final FinishedTimer finished;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clay = context.clay;
    final notifier = ref.read(timerNotifierProvider.notifier);
    final breakMinutes = ref.watch(settingsProvider.select((s) => s.breakMinutes));
    final now = ref.watch(clockProvider)();
    final task = finished.isBreak
        ? null
        : ref
              .watch(userTasksProvider)
              .where((t) => t.id == finished.taskId && !t.isDoneOn(now))
              .firstOrNull;

    final String emoji, title, detail;
    if (finished.isBreak) {
      (emoji, title, detail) = ('☕', 'Break over', 'Ready when you are.');
    } else if (!finished.logged) {
      (emoji, title, detail) = ('👋', 'Session dropped', 'Under a minute is not logged.');
    } else {
      (emoji, title, detail) = (
        finished.completedFull ? '🎉' : '👍',
        finished.completedFull ? 'Session complete' : 'Session logged',
        '${formatDuration(finished.seconds)} on "${finished.taskTitle}"',
      );
    }

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(emoji, textAlign: TextAlign.center, style: const TextStyle(fontSize: 64)),
            const SizedBox(height: 12),
            Text(title, textAlign: TextAlign.center, style: ClayText.display),
            const SizedBox(height: 8),
            Muted(detail, style: ClayText.body, textAlign: TextAlign.center),
            if (finished.reward != null && finished.reward!.xp > 0) ...[
              const SizedBox(height: 16),
              Center(
                child: ClayTag(
                  icon: Icons.auto_awesome_rounded,
                  label: '+${finished.reward!.xp} XP',
                  color: clay.primary,
                ),
              ),
            ],
            const SizedBox(height: 32),
            if (finished.isBreak)
              ClayButton(
                large: true,
                icon: Icons.play_arrow_rounded,
                label: 'Pick the next task',
                onPressed: () => startFocusFlow(context, ref, openScreen: false),
              )
            else
              ClayButton(
                large: true,
                icon: Icons.coffee_rounded,
                label: 'Take a $breakMinutes min break',
                onPressed: notifier.startBreak,
              ),
            if (task != null) ...[
              const SizedBox(height: 12),
              ClayButton(
                large: true,
                color: clay.surface,
                icon: Icons.task_alt_rounded,
                label: 'Mark task done',
                onPressed: () => ref.read(allTasksProvider.notifier).toggleDone(task.id),
              ),
            ],
            const SizedBox(height: 12),
            ClayButton(large: true, color: clay.surface, label: 'Done', onPressed: onClose),
          ],
        ),
      ),
    );
  }
}

class _Idle extends ConsumerWidget {
  const _Idle();

  @override
  Widget build(BuildContext context, WidgetRef ref) => Column(
    mainAxisAlignment: MainAxisAlignment.center,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Text('No session running', textAlign: TextAlign.center, style: ClayText.headline),
      const SizedBox(height: 8),
      const Muted('Pick a task to start one.', style: ClayText.body, textAlign: TextAlign.center),
      const SizedBox(height: 28),
      ClayButton(
        large: true,
        icon: Icons.play_arrow_rounded,
        label: 'Start focus',
        onPressed: () => startFocusFlow(context, ref, openScreen: false),
      ),
    ],
  );
}
