import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/clock.dart';
import '../../../core/dates.dart';
import '../../../core/design/clay_card.dart';
import '../../../core/design/clay_theme.dart';
import '../../../core/design/clay_widgets.dart';
import '../../../core/navigation.dart';
import '../data/plan.dart';
import '../data/presets.dart';
import '../providers/plans_providers.dart';
import 'plan_editor_screen.dart';
import 'plan_sheets.dart';

void openPlanEditor(String planId) {
  contentNavigatorKey.currentState?.push(
    MaterialPageRoute<void>(builder: (_) => PlanEditorScreen(planId: planId)),
  );
}

/// The user's plans, a create button, and the two starter presets.
class PlansScreen extends ConsumerWidget {
  const PlansScreen({super.key});

  Future<void> _create(BuildContext context) async {
    final plan = await showPlanSheet(context);
    if (plan != null) openPlanEditor(plan.id);
  }

  Future<void> _usePreset(BuildContext context, WidgetRef ref, Plan preset) async {
    final now = ref.read(clockProvider)();
    DateTime? anchor;
    if (presetNeedsDate(ref.read(tasksProvider(preset.id)))) {
      anchor = await showDatePicker(
        context: context,
        useRootNavigator: true,
        initialDate: addDays(now, 14),
        firstDate: dayOf(now),
        lastDate: addDays(now, 365),
        helpText: 'When is the exam?',
      );
      if (anchor == null) return;
    }
    final copy = await ref.read(plansProvider.notifier).usePreset(preset.id, anchor: anchor);
    openPlanEditor(copy.id);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plans = ref.watch(userPlansProvider);
    final presets = ref.watch(presetPlansProvider);

    return ListView(
      primary: false,
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
      children: [
        Row(
          children: [
            const Expanded(child: Text('Plans', style: ClayText.display)),
            ClayButton(
              label: 'New plan',
              icon: Icons.add_rounded,
              onPressed: () => _create(context),
            ),
          ],
        ),
        const SectionHeader('Your plans'),
        if (plans.isEmpty)
          const ClayCard(
            child: Muted(
              'Nothing here yet. Start from one of the plans below, or make your own.',
              style: ClayText.body,
            ),
          )
        else
          for (final plan in plans)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: _PlanCard(plan: plan),
            ),
        const SectionHeader('Starter plans'),
        for (final preset in presets)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: ClayCard(
              child: Row(
                children: [
                  SizedBox.square(
                    dimension: 52,
                    child: ClayCard(
                      color: Color(preset.colorValue),
                      radius: 20,
                      depth: 4,
                      padding: EdgeInsets.zero,
                      child: Icon(
                        preset.id == examPrepPresetId
                            ? Icons.school_rounded
                            : Icons.wb_sunny_rounded,
                        size: 26,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(preset.name, style: ClayText.title),
                        const SizedBox(height: 3),
                        Muted(preset.description, maxLines: 3),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  ClayButton(label: 'Use', onPressed: () => _usePreset(context, ref, preset)),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _PlanCard extends ConsumerWidget {
  const _PlanCard({required this.plan});

  final Plan plan;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(clockProvider)();
    ref.watch(todayProvider);
    final tasks = ref.watch(tasksProvider(plan.id));
    final done = tasks.where((t) => t.isDoneOn(now)).length;
    final color = Color(plan.colorValue);

    return ClayCard(
      color: color,
      onTap: () => openPlanEditor(plan.id),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  plan.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: ClayText.title,
                ),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
          const SizedBox(height: 4),
          Muted(
            tasks.isEmpty
                ? 'No tasks yet · ${plan.defaultFocusMinutes} min focus'
                : '$done of ${tasks.length} done · ${plan.defaultFocusMinutes} min focus',
          ),
          const SizedBox(height: 12),
          ClayProgressBar(
            value: tasks.isEmpty ? 0 : done / tasks.length,
            color: Color.lerp(color, Colors.black, 0.28),
            height: 12,
          ),
        ],
      ),
    );
  }
}
