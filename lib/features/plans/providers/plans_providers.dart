import 'package:riverpod/riverpod.dart';

import '../../../core/clock.dart';
import '../../../core/ids.dart';
import '../../../core/storage/app_boxes.dart';
import '../../progress/providers/progress_provider.dart';
import '../data/plan.dart';
import '../data/presets.dart';
import '../data/task.dart';

/// Every plan in storage, presets included.
final plansProvider = NotifierProvider<PlansNotifier, List<Plan>>(PlansNotifier.new);

/// Plans the user owns, newest first.
final userPlansProvider = Provider<List<Plan>>((ref) {
  final plans = ref.watch(plansProvider).where((p) => !p.isPreset).toList()
    ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  return plans;
});

/// The built-in starter plans.
final presetPlansProvider = Provider<List<Plan>>(
  (ref) => ref.watch(plansProvider).where((p) => p.isPreset).toList(),
);

final planByIdProvider = Provider.family<Plan?, String>((ref, id) {
  for (final plan in ref.watch(plansProvider)) {
    if (plan.id == id) return plan;
  }
  return null;
});

class PlansNotifier extends Notifier<List<Plan>> {
  AppBoxes get _boxes => ref.read(boxesProvider);

  @override
  List<Plan> build() => ref.watch(boxesProvider).plans.values.toList();

  Future<Plan> create({
    required String name,
    required int colorValue,
    required int defaultFocusMinutes,
  }) async {
    final plan = Plan(
      id: newId(),
      name: name.trim(),
      colorValue: colorValue,
      defaultFocusMinutes: defaultFocusMinutes,
      createdAt: ref.read(clockProvider)(),
    );
    state = [...state, plan];
    await _boxes.plans.put(plan.id, plan);
    return plan;
  }

  Future<void> save(Plan plan) async {
    state = [
      for (final p in state)
        if (p.id == plan.id) plan else p,
    ];
    await _boxes.plans.put(plan.id, plan);
  }

  /// Deletes a plan and its tasks. Logged focus sessions are kept so past
  /// stats and XP stay intact.
  Future<void> delete(String id) async {
    state = state.where((p) => p.id != id).toList();
    await ref.read(allTasksProvider.notifier).deleteForPlan(id);
    await _boxes.plans.delete(id);
  }

  /// Copies a preset into the user's plans and returns the editable copy.
  Future<Plan> usePreset(String presetId, {DateTime? anchor}) async {
    final preset = state.firstWhere((p) => p.id == presetId && p.isPreset);
    final now = ref.read(clockProvider)();
    final bundle = instantiatePreset(
      preset: preset,
      presetTasks: ref.read(tasksProvider(presetId)),
      anchor: anchor ?? now,
      now: now,
      newId: newId,
    );
    state = [...state, bundle.plan];
    await _boxes.plans.put(bundle.plan.id, bundle.plan);
    await ref.read(allTasksProvider.notifier).insertAll(bundle.tasks);
    return bundle.plan;
  }
}

/// Every task in storage. Screens normally read [tasksProvider] or
/// [userTasksProvider] instead.
final allTasksProvider = NotifierProvider<TasksNotifier, List<Task>>(TasksNotifier.new);

/// Tasks of one plan, in the plan's own order.
final tasksProvider = Provider.family<List<Task>, String>(
  (ref, planId) => _tasksOfPlan(ref.watch(allTasksProvider), planId),
);

List<Task> _tasksOfPlan(List<Task> all, String planId) =>
    all.where((t) => t.planId == planId).toList()..sort((a, b) => a.order.compareTo(b.order));

/// The order tasks are offered in when choosing what to focus on: nearest
/// deadline first, then tasks with no deadline by priority.
int compareUpNext(Task a, Task b) {
  final ad = a.deadline, bd = b.deadline;
  if (ad != null && bd != null) return ad.compareTo(bd);
  if (ad != null) return -1;
  if (bd != null) return 1;
  return b.priority.compareTo(a.priority);
}

/// Tasks from the user's own plans (preset templates excluded).
final userTasksProvider = Provider<List<Task>>((ref) {
  final presetIds = {for (final p in ref.watch(presetPlansProvider)) p.id};
  return ref.watch(allTasksProvider).where((t) => !presetIds.contains(t.planId)).toList();
});

class TasksNotifier extends Notifier<List<Task>> {
  AppBoxes get _boxes => ref.read(boxesProvider);

  @override
  List<Task> build() => ref.watch(boxesProvider).tasks.values.toList();

  Future<Task> add({
    required String planId,
    required String title,
    DateTime? deadline,
    int priority = TaskPriority.medium,
    String subject = '',
    bool repeatsDaily = false,
    int? focusMinutes,
  }) async {
    final siblings = state.where((t) => t.planId == planId);
    final nextOrder = siblings.fold<int>(-1, (max, t) => t.order > max ? t.order : max) + 1;
    final task = Task(
      id: newId(),
      planId: planId,
      title: title.trim(),
      deadline: repeatsDaily ? null : deadline,
      priority: priority,
      subject: subject.trim(),
      repeatsDaily: repeatsDaily,
      order: nextOrder,
      focusMinutes: focusMinutes,
    );
    state = [...state, task];
    await _boxes.tasks.put(task.id, task);
    return task;
  }

  Future<void> save(Task task) async {
    state = [
      for (final t in state)
        if (t.id == task.id) task else t,
    ];
    await _boxes.tasks.put(task.id, task);
  }

  Future<void> insertAll(List<Task> tasks) async {
    state = [...state, ...tasks];
    await _boxes.tasks.putAll({for (final t in tasks) t.id: t});
  }

  Future<void> delete(String id) async {
    state = state.where((t) => t.id != id).toList();
    await _boxes.tasks.delete(id);
  }

  Future<void> deleteForPlan(String planId) async {
    final ids = [
      for (final t in state)
        if (t.planId == planId) t.id,
    ];
    state = state.where((t) => t.planId != planId).toList();
    await _boxes.tasks.deleteAll(ids);
  }

  /// Moves a task within its plan. Indexes follow `ReorderableListView`:
  /// [newIndex] is the slot before the item is removed from [oldIndex].
  Future<void> reorder(String planId, int oldIndex, int newIndex) async {
    // Built from state, not tasksProvider: that provider depends on this
    // notifier, and reading it from here is a circular dependency.
    final ordered = _tasksOfPlan(state, planId);
    if (oldIndex < 0 || oldIndex >= ordered.length) return;
    var target = newIndex > oldIndex ? newIndex - 1 : newIndex;
    target = target.clamp(0, ordered.length - 1);
    if (target == oldIndex) return;
    ordered.insert(target, ordered.removeAt(oldIndex));

    final changed = <String, Task>{
      for (var i = 0; i < ordered.length; i++)
        if (ordered[i].order != i) ordered[i].id: ordered[i].copyWith(order: i),
    };
    state = [for (final t in state) changed[t.id] ?? t];
    await _boxes.tasks.putAll(changed);
  }

  /// Checks or unchecks a task. Returns the reward when checking it earned
  /// XP, which happens once per task (once per day for daily tasks).
  Future<RewardEvent?> toggleDone(String id) async {
    final index = state.indexWhere((t) => t.id == id);
    if (index < 0) return null;
    final task = state[index];
    final now = ref.read(clockProvider)();

    if (task.isDoneOn(now)) {
      await save(task.copyWith(done: false, completedAt: null));
      return null;
    }

    final earns = task.canEarnXpOn(now);
    await save(task.copyWith(done: true, completedAt: now, lastXpAt: earns ? now : task.lastXpAt));
    if (!earns) return null;

    final deadline = task.deadline;
    return ref
        .read(progressProvider.notifier)
        .recordTaskCompleted(
          priority: task.priority,
          onTime: deadline == null || !now.isAfter(deadline),
          at: now,
        );
  }
}
