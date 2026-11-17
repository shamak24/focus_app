import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/dates.dart';
import '../../../core/design/clay_card.dart';
import '../../../core/design/clay_theme.dart';
import '../../../core/design/clay_widgets.dart';
import '../providers/timer_notifier.dart';
import 'focus_actions.dart';

/// The mini player: sits above the nav bar on every screen while a timer is
/// active. Shows the task and countdown with pause and stop; tapping it opens
/// the full timer.
class MiniBar extends ConsumerWidget {
  const MiniBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timer = ref.watch(timerNotifierProvider);
    final active = timer.active;
    final notifier = ref.read(timerNotifierProvider.notifier);
    final clay = context.clay;

    return AnimatedSize(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      alignment: Alignment.bottomCenter,
      child: active == null
          ? const SizedBox(width: double.infinity)
          : Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
              child: ClayCard(
                color: active.colorValue == 0 ? clay.secondary : Color(active.colorValue),
                radius: 26,
                depth: 6,
                padding: const EdgeInsets.fromLTRB(16, 10, 10, 10),
                onTap: () => openFocusScreen(context),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            active.taskTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: ClayText.label,
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Text(
                                formatCountdown(timer.remainingSeconds),
                                style: ClayText.title.copyWith(
                                  fontFeatures: const [FontFeature.tabularFigures()],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Muted(
                                timer.isPaused ? 'Paused' : (active.isBreak ? 'Break' : 'Focusing'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    ClayIconButton(
                      size: 42,
                      color: clay.surface,
                      icon: timer.isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                      tooltip: timer.isPaused ? 'Resume' : 'Pause',
                      onPressed: timer.isPaused ? notifier.resume : notifier.pause,
                    ),
                    const SizedBox(width: 8),
                    ClayIconButton(
                      size: 42,
                      color: clay.surface,
                      icon: Icons.stop_rounded,
                      tooltip: 'Stop and log',
                      onPressed: () async {
                        await notifier.finish();
                        // The reward toast covers it; no summary screen needed.
                        notifier.clearFinished();
                      },
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
