import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/clock.dart';
import '../../../core/dates.dart';
import '../../../core/design/clay_card.dart';
import '../../../core/design/clay_theme.dart';
import '../../../core/design/clay_widgets.dart';
import '../data/plan.dart';
import '../data/plan_palette.dart';
import '../data/task.dart';
import '../providers/plans_providers.dart';
import '../../settings/providers/settings_provider.dart';

const _focusChoices = [15, 25, 30, 45, 50, 60];

/// Quick picks for a task's own focus length.
const _taskFocusChoices = [15, 25, 30, 45, 60, 90];
const _minTaskMinutes = 5;
const _maxTaskMinutes = 180;

/// Create a plan ([plan] null) or edit one. Returns the saved plan, or null
/// if the sheet was dismissed or the plan was deleted.
Future<Plan?> showPlanSheet(BuildContext context, {Plan? plan}) =>
    showClaySheet<Plan>(context, builder: (_) => _PlanForm(plan: plan));

class _PlanForm extends ConsumerStatefulWidget {
  const _PlanForm({this.plan});

  final Plan? plan;

  @override
  ConsumerState<_PlanForm> createState() => _PlanFormState();
}

class _PlanFormState extends ConsumerState<_PlanForm> {
  late final _name = TextEditingController(text: widget.plan?.name ?? '');
  late int _color = widget.plan?.colorValue ?? planPalette[3];
  late int _minutes = widget.plan?.defaultFocusMinutes ?? 25;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    final notifier = ref.read(plansProvider.notifier);
    final existing = widget.plan;
    final Plan saved;
    if (existing == null) {
      saved = await notifier.create(name: name, colorValue: _color, defaultFocusMinutes: _minutes);
    } else {
      saved = existing.copyWith(name: name, colorValue: _color, defaultFocusMinutes: _minutes);
      await notifier.save(saved);
    }
    if (mounted) Navigator.of(context).pop(saved);
  }

  Future<void> _delete() async {
    final plan = widget.plan!;
    final ok = await confirmClay(
      context,
      title: 'Delete "${plan.name}"?',
      message: 'Its tasks are deleted too. Focus time you already logged stays in your stats.',
      confirmLabel: 'Delete',
    );
    if (!ok) return;
    await ref.read(plansProvider.notifier).delete(plan.id);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.plan != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(editing ? 'Edit plan' : 'New plan', style: ClayText.headline),
        const SizedBox(height: 16),
        ClayTextField(
          controller: _name,
          hint: 'Plan name, e.g. Physics',
          autofocus: !editing,
          maxLength: 40,
          textInputAction: TextInputAction.done,
        ),
        const SizedBox(height: 18),
        const Muted('Colour', style: ClayText.label),
        const SizedBox(height: 10),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final value in planPalette)
              ClayPressable(
                scale: 0.88,
                onTap: () => setState(() => _color = value),
                builder: (context, _) => SizedBox.square(
                  dimension: 44,
                  child: ClayCard(
                    color: Color(value),
                    radius: 22,
                    depth: _color == value ? 2 : 5,
                    padding: EdgeInsets.zero,
                    child: _color == value
                        ? const Icon(Icons.check_rounded, size: 22)
                        : const SizedBox.expand(),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 18),
        const Muted('Default focus length', style: ClayText.label),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final m in {..._focusChoices, _minutes}.toList()..sort())
              ClayChip(
                label: '$m min',
                selected: _minutes == m,
                onTap: () => setState(() => _minutes = m),
              ),
          ],
        ),
        const SizedBox(height: 24),
        ClayButton(label: editing ? 'Save plan' : 'Create plan', large: true, onPressed: _save),
        if (editing) ...[
          const SizedBox(height: 4),
          TextButton(
            onPressed: _delete,
            child: Text('Delete plan', style: TextStyle(color: context.clay.danger)),
          ),
        ],
      ],
    );
  }
}

/// Add a task to [planId] ([task] null) or edit an existing one.
Future<void> showTaskSheet(BuildContext context, {required String planId, Task? task}) =>
    showClaySheet<void>(
      context,
      builder: (_) => _TaskForm(planId: planId, task: task),
    );

class _TaskForm extends ConsumerStatefulWidget {
  const _TaskForm({required this.planId, this.task});

  final String planId;
  final Task? task;

  @override
  ConsumerState<_TaskForm> createState() => _TaskFormState();
}

class _TaskFormState extends ConsumerState<_TaskForm> {
  late final _title = TextEditingController(text: widget.task?.title ?? '');
  late final _subject = TextEditingController(text: widget.task?.subject ?? '');
  late int _priority = widget.task?.priority ?? TaskPriority.medium;
  late bool _daily = widget.task?.repeatsDaily ?? false;
  late DateTime? _deadline = widget.task?.deadline;

  /// Null means "use the plan's default".
  late int? _focusMinutes = widget.task?.focusMinutes;

  @override
  void dispose() {
    _title.dispose();
    _subject.dispose();
    super.dispose();
  }

  Future<void> _pickDeadline() async {
    final now = ref.read(clockProvider)();
    final current = _deadline;
    final date = await showDatePicker(
      context: context,
      useRootNavigator: true,
      initialDate: current != null && current.isAfter(now) ? current : now,
      firstDate: dayOf(now),
      lastDate: addDays(current != null && current.isAfter(now) ? current : now, 730),
      helpText: 'Due date',
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      useRootNavigator: true,
      initialTime: current == null
          ? const TimeOfDay(hour: 18, minute: 0)
          : TimeOfDay.fromDateTime(current),
      helpText: 'Due time',
    );
    if (!mounted) return;
    setState(() {
      _deadline = DateTime(date.year, date.month, date.day, time?.hour ?? 18, time?.minute ?? 0);
    });
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    if (title.isEmpty) return;
    final notifier = ref.read(allTasksProvider.notifier);
    final existing = widget.task;
    if (existing == null) {
      await notifier.add(
        planId: widget.planId,
        title: title,
        subject: _subject.text,
        priority: _priority,
        repeatsDaily: _daily,
        deadline: _deadline,
        focusMinutes: _focusMinutes,
      );
    } else {
      await notifier.save(
        existing.copyWith(
          title: title,
          subject: _subject.text.trim(),
          priority: _priority,
          repeatsDaily: _daily,
          deadline: _daily ? null : _deadline,
          focusMinutes: _focusMinutes,
        ),
      );
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final clay = context.clay;
    final editing = widget.task != null;
    final now = ref.watch(clockProvider)();
    final int planMinutes =
        ref.watch(planByIdProvider(widget.planId))?.defaultFocusMinutes ??
        ref.watch(settingsProvider.select((s) => s.focusMinutes));
    final int shownMinutes = _focusMinutes ?? planMinutes;

    void step(int by) => setState(() {
      _focusMinutes = (shownMinutes + by).clamp(_minTaskMinutes, _maxTaskMinutes);
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(editing ? 'Edit task' : 'New task', style: ClayText.headline),
        const SizedBox(height: 16),
        ClayTextField(
          controller: _title,
          hint: 'What needs doing?',
          autofocus: !editing,
          maxLength: 80,
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: 12),
        ClayTextField(
          controller: _subject,
          hint: 'Subject (optional), e.g. Calculus',
          maxLength: 30,
          textInputAction: TextInputAction.done,
        ),
        const SizedBox(height: 18),
        const Muted('Priority', style: ClayText.label),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          children: [
            for (final p in const [TaskPriority.low, TaskPriority.medium, TaskPriority.high])
              ClayChip(
                label: TaskPriority.label(p),
                selected: _priority == p,
                onTap: () => setState(() => _priority = p),
              ),
          ],
        ),
        const SizedBox(height: 18),
        const Muted('Focus length', style: ClayText.label),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            ClayChip(
              label: 'Plan default · $planMinutes min',
              selected: _focusMinutes == null,
              onTap: () => setState(() => _focusMinutes = null),
            ),
            for (final m in {..._taskFocusChoices, ?_focusMinutes}.toList()..sort())
              ClayChip(
                label: '$m min',
                selected: _focusMinutes == m,
                onTap: () => setState(() => _focusMinutes = m),
              ),
          ],
        ),
        const SizedBox(height: 12),
        ClayCard(
          radius: 22,
          depth: 5,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            children: [
              ClayIconButton(
                icon: Icons.remove_rounded,
                tooltip: '5 minutes shorter',
                size: 40,
                onPressed: shownMinutes > _minTaskMinutes ? () => step(-5) : null,
              ),
              Expanded(
                child: Column(
                  children: [
                    Text('$shownMinutes min', style: ClayText.headline),
                    Muted(
                      _focusMinutes == null ? "Using the plan's default" : 'Just for this task',
                    ),
                  ],
                ),
              ),
              ClayIconButton(
                icon: Icons.add_rounded,
                tooltip: '5 minutes longer',
                size: 40,
                onPressed: shownMinutes < _maxTaskMinutes ? () => step(5) : null,
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        ClayCard(
          radius: 22,
          depth: 5,
          padding: const EdgeInsets.fromLTRB(16, 6, 8, 6),
          child: Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Repeat every day', style: ClayText.label),
                    Muted('Resets each morning. No deadline.'),
                  ],
                ),
              ),
              Switch(
                value: _daily,
                activeTrackColor: clay.primary,
                onChanged: (v) => setState(() => _daily = v),
              ),
            ],
          ),
        ),
        if (!_daily) ...[
          const SizedBox(height: 12),
          ClayCard(
            radius: 22,
            depth: 5,
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
            onTap: _pickDeadline,
            child: Row(
              children: [
                const Icon(Icons.event_rounded, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _deadline == null ? 'Add a deadline' : 'Due ${formatDeadline(_deadline!, now)}',
                    style: ClayText.label,
                  ),
                ),
                if (_deadline != null)
                  IconButton(
                    tooltip: 'Remove deadline',
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () => setState(() => _deadline = null),
                  ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 24),
        ClayButton(label: editing ? 'Save task' : 'Add task', large: true, onPressed: _save),
        if (editing) ...[
          const SizedBox(height: 4),
          TextButton(
            onPressed: () async {
              await ref.read(allTasksProvider.notifier).delete(widget.task!.id);
              if (context.mounted) Navigator.of(context).pop();
            },
            child: Text('Delete task', style: TextStyle(color: clay.danger)),
          ),
        ],
      ],
    );
  }
}
