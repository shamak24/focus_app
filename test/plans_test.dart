import 'package:flutter_test/flutter_test.dart';
import 'package:focus_app/features/plans/data/presets.dart';
import 'package:focus_app/features/plans/data/task.dart';
import 'package:focus_app/features/plans/providers/plans_providers.dart';
import 'package:focus_app/features/progress/providers/progress_provider.dart';

import 'support/test_env.dart';

void main() {
  late TestEnv env;

  PlansNotifier plans() => env.container.read(plansProvider.notifier);
  TasksNotifier tasks() => env.container.read(allTasksProvider.notifier);
  List<String> titles(String planId) =>
      env.container.read(tasksProvider(planId)).map((t) => t.title).toList();

  setUp(() async => env = await TestEnv.create());
  tearDown(() => env.dispose());

  group('preset seeding', () {
    test('first launch creates the two presets and no user plans', () {
      final presets = env.container.read(presetPlansProvider);
      expect(presets.map((p) => p.id), unorderedEquals([examPrepPresetId, dailyRoutinePresetId]));
      expect(env.container.read(userPlansProvider), isEmpty);
      expect(env.container.read(tasksProvider(examPrepPresetId)), hasLength(11));
      expect(env.container.read(tasksProvider(dailyRoutinePresetId)), hasLength(5));
      expect(env.container.read(userTasksProvider), isEmpty);
    });

    test('later launches do not duplicate them', () async {
      await env.restart();
      await env.restart();
      expect(env.boxes.plans.length, 2);
      expect(env.boxes.tasks.length, 16);
    });

    test('built-in preset task ids are unique', () {
      final ids = [for (final b in builtInPresets()) ...b.tasks.map((t) => t.id)];
      expect(ids.toSet().length, ids.length);
    });
  });

  group('using a preset', () {
    test('exam prep is copied with deadlines counted back from the exam date', () async {
      final exam = DateTime(2026, 4, 1);
      final plan = await plans().usePreset(examPrepPresetId, anchor: exam);

      expect(plan.isPreset, isFalse);
      expect(plan.id, isNot(examPrepPresetId));
      expect(plan.name, 'Exam prep');
      expect(plan.defaultFocusMinutes, 45);

      final copied = env.container.read(tasksProvider(plan.id));
      expect(copied, hasLength(11));
      expect(copied.first.title, 'Collect the syllabus and past papers');
      expect(copied.first.deadline, DateTime(2026, 3, 18, 18));
      expect(copied.last.deadline, DateTime(2026, 3, 31, 18));
      expect(copied.every((t) => !t.done && t.dayOffset == null), isTrue);
      expect([for (final t in copied) t.order], [for (var i = 0; i < 11; i++) i]);
    });

    test('an exam that is too close never produces overdue tasks', () async {
      final plan = await plans().usePreset(examPrepPresetId, anchor: DateTime(2026, 3, 5));
      final copied = env.container.read(tasksProvider(plan.id));
      expect(copied.any((t) => t.isOverdueOn(env.clock.now)), isFalse);
      expect(copied.first.deadline, DateTime(2026, 3, 2, 23, 59));
      expect(copied.last.deadline, DateTime(2026, 3, 4, 18));
    });

    test('the daily routine is copied as repeating tasks without deadlines', () async {
      final plan = await plans().usePreset(dailyRoutinePresetId);
      final copied = env.container.read(tasksProvider(plan.id));
      expect(copied, hasLength(5));
      expect(copied.every((t) => t.repeatsDaily && t.deadline == null), isTrue);
    });

    test('the copy is independent: editing it leaves the preset alone', () async {
      final plan = await plans().usePreset(dailyRoutinePresetId);
      await plans().save(plan.copyWith(name: 'My weekdays'));
      final first = env.container.read(tasksProvider(plan.id)).first;
      await tasks().save(first.copyWith(title: 'Changed'));
      await tasks().delete(env.container.read(tasksProvider(plan.id)).last.id);

      expect(env.container.read(planByIdProvider(dailyRoutinePresetId))!.name, 'Daily routine');
      expect(titles(dailyRoutinePresetId).first, 'Review yesterday\'s notes');
      expect(env.container.read(tasksProvider(dailyRoutinePresetId)), hasLength(5));
      expect(env.container.read(presetPlansProvider), hasLength(2));
    });

    test('a preset can be used more than once', () async {
      final a = await plans().usePreset(dailyRoutinePresetId);
      final b = await plans().usePreset(dailyRoutinePresetId);
      expect(a.id, isNot(b.id));
      expect(env.container.read(userPlansProvider), hasLength(2));
      expect(env.container.read(userTasksProvider), hasLength(10));
    });

    test('presetNeedsDate is true only for date-based presets', () {
      expect(presetNeedsDate(env.container.read(tasksProvider(examPrepPresetId))), isTrue);
      expect(presetNeedsDate(env.container.read(tasksProvider(dailyRoutinePresetId))), isFalse);
    });
  });

  group('custom plans', () {
    test('create, edit and reload from disk', () async {
      final plan = await plans().create(
        name: '  Physics  ',
        colorValue: 0xFFBFE8C5,
        defaultFocusMinutes: 30,
      );
      expect(plan.name, 'Physics');
      await tasks().add(
        planId: plan.id,
        title: 'Read chapter 4',
        subject: 'Optics',
        priority: TaskPriority.high,
        deadline: DateTime(2026, 3, 6, 18),
      );
      await plans().save(plan.copyWith(name: 'Physics II', defaultFocusMinutes: 50));

      await env.restart();

      final reloaded = env.container.read(userPlansProvider).single;
      expect(reloaded.name, 'Physics II');
      expect(reloaded.colorValue, 0xFFBFE8C5);
      expect(reloaded.defaultFocusMinutes, 50);
      final task = env.container.read(tasksProvider(reloaded.id)).single;
      expect(task.title, 'Read chapter 4');
      expect(task.subject, 'Optics');
      expect(task.priority, TaskPriority.high);
      expect(task.deadline, DateTime(2026, 3, 6, 18));
    });

    test('newest plan is listed first', () async {
      await plans().create(name: 'Old', colorValue: 1, defaultFocusMinutes: 25);
      env.clock.advance(const Duration(minutes: 1));
      await plans().create(name: 'New', colorValue: 1, defaultFocusMinutes: 25);
      expect(env.container.read(userPlansProvider).map((p) => p.name), ['New', 'Old']);
    });

    test('deleting a plan deletes its tasks and nothing else', () async {
      final keep = await plans().create(name: 'Keep', colorValue: 1, defaultFocusMinutes: 25);
      final drop = await plans().create(name: 'Drop', colorValue: 1, defaultFocusMinutes: 25);
      await tasks().add(planId: keep.id, title: 'stay');
      await tasks().add(planId: drop.id, title: 'go 1');
      await tasks().add(planId: drop.id, title: 'go 2');

      await plans().delete(drop.id);

      expect(env.container.read(userPlansProvider).map((p) => p.name), ['Keep']);
      expect(env.container.read(userTasksProvider).map((t) => t.title), ['stay']);
      expect(env.boxes.tasks.values.where((t) => t.planId == drop.id), isEmpty);
      expect(env.container.read(presetPlansProvider), hasLength(2));
    });

    test('new tasks go to the end; daily tasks never keep a deadline', () async {
      final plan = await plans().create(name: 'P', colorValue: 1, defaultFocusMinutes: 25);
      await tasks().add(planId: plan.id, title: 'a');
      await tasks().add(planId: plan.id, title: 'b');
      final daily = await tasks().add(
        planId: plan.id,
        title: 'c',
        repeatsDaily: true,
        deadline: DateTime(2026, 3, 9),
      );
      expect(titles(plan.id), ['a', 'b', 'c']);
      expect(daily.deadline, isNull);
    });
  });

  group('reordering', () {
    late String planId;

    setUp(() async {
      planId = (await plans().create(name: 'P', colorValue: 1, defaultFocusMinutes: 25)).id;
      for (final t in ['a', 'b', 'c', 'd']) {
        await tasks().add(planId: planId, title: t);
      }
    });

    test('moving down uses ReorderableListView indexes', () async {
      await tasks().reorder(planId, 0, 3);
      expect(titles(planId), ['b', 'c', 'a', 'd']);
    });

    test('moving to the very end', () async {
      await tasks().reorder(planId, 0, 4);
      expect(titles(planId), ['b', 'c', 'd', 'a']);
    });

    test('moving up', () async {
      await tasks().reorder(planId, 3, 1);
      expect(titles(planId), ['a', 'd', 'b', 'c']);
    });

    test('dropping in place or out of range changes nothing', () async {
      await tasks().reorder(planId, 1, 1);
      await tasks().reorder(planId, 1, 2);
      await tasks().reorder(planId, 9, 0);
      expect(titles(planId), ['a', 'b', 'c', 'd']);
    });

    test('the new order survives a restart', () async {
      await tasks().reorder(planId, 2, 0);
      await env.restart();
      expect(titles(planId), ['c', 'a', 'b', 'd']);
    });
  });

  group('completing tasks', () {
    late String planId;

    setUp(() async {
      planId = (await plans().create(name: 'P', colorValue: 1, defaultFocusMinutes: 25)).id;
    });

    test('checking a task awards XP with on-time and priority bonuses', () async {
      final task = await tasks().add(
        planId: planId,
        title: 'Essay',
        priority: TaskPriority.high,
        deadline: env.clock.now.add(const Duration(days: 1)),
      );
      final reward = await tasks().toggleDone(task.id);

      expect(reward?.xp, 35);
      final saved = env.container.read(tasksProvider(planId)).single;
      expect(saved.done, isTrue);
      expect(saved.completedAt, env.clock.now);
      expect(env.container.read(progressProvider).tasksCompleted, 1);
      expect(env.container.read(rewardBusProvider)?.xp, 35);
    });

    test('a late task misses the on-time bonus', () async {
      final task = await tasks().add(
        planId: planId,
        title: 'Late',
        priority: TaskPriority.low,
        deadline: env.clock.now.subtract(const Duration(hours: 1)),
      );
      expect((await tasks().toggleDone(task.id))?.xp, 20);
    });

    test('unchecking and rechecking cannot farm XP', () async {
      final task = await tasks().add(planId: planId, title: 'Once');
      await tasks().toggleDone(task.id);
      final xp = env.container.read(progressProvider).xp;

      expect(await tasks().toggleDone(task.id), isNull);
      expect(env.container.read(tasksProvider(planId)).single.done, isFalse);
      expect(await tasks().toggleDone(task.id), isNull);
      expect(env.container.read(tasksProvider(planId)).single.done, isTrue);

      expect(env.container.read(progressProvider).xp, xp);
      expect(env.container.read(progressProvider).tasksCompleted, 1);
    });

    test('a daily task reopens the next morning and pays once per day', () async {
      final task = await tasks().add(planId: planId, title: 'Review', repeatsDaily: true);

      expect((await tasks().toggleDone(task.id))?.xp, isNotNull);
      Task current() => env.container.read(tasksProvider(planId)).single;
      expect(current().isDoneOn(env.clock.now), isTrue);

      await tasks().toggleDone(task.id);
      expect(await tasks().toggleDone(task.id), isNull, reason: 'second time the same day');

      env.clock.advance(const Duration(days: 1));
      expect(current().isDoneOn(env.clock.now), isFalse);
      expect((await tasks().toggleDone(task.id))?.xp, isNotNull);
      expect(env.container.read(progressProvider).tasksCompleted, 2);
      expect(env.container.read(progressProvider).currentStreak, 2);
    });

    test('toggling an unknown id is ignored', () async {
      expect(await tasks().toggleDone('missing'), isNull);
    });
  });
}
