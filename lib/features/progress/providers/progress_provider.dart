import 'package:riverpod/riverpod.dart';

import '../../../core/storage/app_boxes.dart';
import '../data/progress.dart';
import '../data/xp_rules.dart';

/// What the user just earned. The shell listens for these and shows a toast.
class RewardEvent {
  const RewardEvent({
    required this.label,
    required this.xp,
    this.leveledUpTo,
    this.newBadges = const [],
  });

  final String label;
  final int xp;
  final int? leveledUpTo;
  final List<String> newBadges;
}

final rewardBusProvider = NotifierProvider<RewardBus, RewardEvent?>(RewardBus.new);

class RewardBus extends Notifier<RewardEvent?> {
  @override
  RewardEvent? build() => null;

  void emit(RewardEvent event) => state = event;
}

final progressProvider = NotifierProvider<ProgressNotifier, Progress>(ProgressNotifier.new);

class ProgressNotifier extends Notifier<Progress> {
  @override
  Progress build() =>
      ref.watch(boxesProvider).meta.get(MetaKeys.progress) as Progress? ?? const Progress();

  Future<RewardEvent> recordSession({
    required int seconds,
    required int plannedSeconds,
    required bool completedFull,
    required DateTime at,
  }) => _commit(
    'Focus session',
    applySession(
      state,
      seconds: seconds,
      plannedSeconds: plannedSeconds,
      completedFull: completedFull,
      at: at,
    ),
  );

  Future<RewardEvent> recordTaskCompleted({
    required int priority,
    required bool onTime,
    required DateTime at,
  }) => _commit('Task done', applyTaskCompleted(state, priority: priority, onTime: onTime, at: at));

  Future<RewardEvent> _commit(String label, ProgressChange change) async {
    state = change.progress;
    final event = RewardEvent(
      label: label,
      xp: change.xpGained,
      leveledUpTo: change.leveledUpTo,
      newBadges: change.newBadges,
    );
    ref.read(rewardBusProvider.notifier).emit(event);
    await ref.read(boxesProvider).meta.put(MetaKeys.progress, change.progress);
    return event;
  }
}
