import '../../../core/dates.dart';
import '../../../core/storage/app_boxes.dart';
import 'plan.dart';
import 'task.dart';

const examPrepPresetId = 'preset_exam_prep';
const dailyRoutinePresetId = 'preset_daily_routine';

/// Bump when the built-in presets change so existing installs pick them up.
const presetsVersion = 1;

class PlanBundle {
  const PlanBundle(this.plan, this.tasks);

  final Plan plan;
  final List<Task> tasks;
}

Task _examTask(int index, int dayOffset, String title, String subject, int priority) => Task(
  id: '${examPrepPresetId}_${index.toString().padLeft(2, '0')}',
  planId: examPrepPresetId,
  title: title,
  subject: subject,
  priority: priority,
  order: index,
  dayOffset: dayOffset,
);

Task _routineTask(int index, String title, String subject, int priority) => Task(
  id: '${dailyRoutinePresetId}_${index.toString().padLeft(2, '0')}',
  planId: dailyRoutinePresetId,
  title: title,
  subject: subject,
  priority: priority,
  order: index,
  repeatsDaily: true,
);

/// The two starter plans. Exam prep is laid out backwards from an exam date
/// the user picks; the daily routine is a set of blocks that reset each day.
List<PlanBundle> builtInPresets() {
  final epoch = DateTime.fromMillisecondsSinceEpoch(0);
  return [
    PlanBundle(
      Plan(
        id: examPrepPresetId,
        name: 'Exam prep',
        description: 'Two weeks of revision and timed practice, counted back from your exam date.',
        colorValue: 0xFFFFB5A7,
        isPreset: true,
        defaultFocusMinutes: 45,
        createdAt: epoch,
      ),
      [
        _examTask(0, -14, 'Collect the syllabus and past papers', 'Planning', TaskPriority.high),
        _examTask(
          1,
          -13,
          'Turn the syllabus into a topic checklist',
          'Planning',
          TaskPriority.medium,
        ),
        _examTask(2, -12, 'Revise unit 1', 'Revision', TaskPriority.medium),
        _examTask(3, -10, 'Revise unit 2', 'Revision', TaskPriority.medium),
        _examTask(4, -8, 'Revise unit 3', 'Revision', TaskPriority.medium),
        _examTask(5, -6, 'Revise unit 4', 'Revision', TaskPriority.medium),
        _examTask(6, -5, 'Write a one-page summary sheet', 'Revision', TaskPriority.medium),
        _examTask(7, -4, 'Timed past paper 1', 'Practice', TaskPriority.high),
        _examTask(8, -3, 'Go through mistakes from paper 1', 'Practice', TaskPriority.high),
        _examTask(9, -2, 'Timed past paper 2', 'Practice', TaskPriority.high),
        _examTask(10, -1, 'Light review of weak topics, then rest', 'Revision', TaskPriority.low),
      ],
    ),
    PlanBundle(
      Plan(
        id: dailyRoutinePresetId,
        name: 'Daily routine',
        description: 'Study blocks for an ordinary weekday. They reset every morning.',
        colorValue: 0xFFB5D0FF,
        isPreset: true,
        defaultFocusMinutes: 25,
        createdAt: epoch,
      ),
      [
        _routineTask(0, 'Review yesterday\'s notes', 'Review', TaskPriority.medium),
        _routineTask(1, 'Deep study block 1', 'Study', TaskPriority.high),
        _routineTask(2, 'Deep study block 2', 'Study', TaskPriority.high),
        _routineTask(3, 'Practice problems', 'Practice', TaskPriority.medium),
        _routineTask(4, 'Plan tomorrow', 'Planning', TaskPriority.low),
      ],
    ),
  ];
}

/// Writes the built-in presets into Hive on first launch, and again whenever
/// [presetsVersion] changes. User plans are never touched.
Future<void> seedPresets(AppBoxes boxes) async {
  if (boxes.meta.get(MetaKeys.presetsVersion) == presetsVersion) return;

  final stalePlans = [
    for (final p in boxes.plans.values)
      if (p.isPreset) p.id,
  ];
  final staleTasks = [
    for (final t in boxes.tasks.values)
      if (stalePlans.contains(t.planId)) t.id,
  ];
  await boxes.tasks.deleteAll(staleTasks);
  await boxes.plans.deleteAll(stalePlans);

  for (final bundle in builtInPresets()) {
    await boxes.plans.put(bundle.plan.id, bundle.plan);
    await boxes.tasks.putAll({for (final t in bundle.tasks) t.id: t});
  }
  await boxes.meta.put(MetaKeys.presetsVersion, presetsVersion);
}

/// True when copying this preset should ask the user for a date first.
bool presetNeedsDate(List<Task> presetTasks) => presetTasks.any((t) => t.dayOffset != null);

/// Builds the user's own editable copy of a preset.
///
/// Tasks with a [Task.dayOffset] get a 6 PM deadline that many days from
/// [anchor]. If the anchor is so close that a deadline would land in the past,
/// it is moved to the end of today so nothing starts out overdue.
PlanBundle instantiatePreset({
  required Plan preset,
  required List<Task> presetTasks,
  required DateTime anchor,
  required DateTime now,
  required String Function() newId,
}) {
  final planId = newId();
  final endOfToday = DateTime(now.year, now.month, now.day, 23, 59);
  final sorted = [...presetTasks]..sort((a, b) => a.order.compareTo(b.order));

  DateTime? deadlineFor(Task t) {
    final offset = t.dayOffset;
    if (offset == null) return null;
    final day = addDays(dayOf(anchor), offset);
    final due = DateTime(day.year, day.month, day.day, 18);
    return due.isBefore(now) ? endOfToday : due;
  }

  return PlanBundle(preset.copyWith(id: planId, isPreset: false, createdAt: now), [
    for (var i = 0; i < sorted.length; i++)
      Task(
        id: newId(),
        planId: planId,
        title: sorted[i].title,
        subject: sorted[i].subject,
        priority: sorted[i].priority,
        repeatsDaily: sorted[i].repeatsDaily,
        deadline: deadlineFor(sorted[i]),
        order: i,
        focusMinutes: sorted[i].focusMinutes,
      ),
  ]);
}
