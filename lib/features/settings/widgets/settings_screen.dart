import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/dates.dart';
import '../../../core/design/clay_card.dart';
import '../../../core/design/clay_theme.dart';
import '../../../core/design/clay_widgets.dart';
import '../../reminders/reminder_sync.dart';
import '../providers/settings_provider.dart';

const _leadChoices = {15: '15 min', 60: '1 hour', 180: '3 hours', 1440: '1 day'};

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clay = context.clay;
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);

    return ListView(
      primary: false,
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
      children: [
        const Text('Settings', style: ClayText.display),
        const SectionHeader('Theme'),
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 14,
          crossAxisSpacing: 14,
          childAspectRatio: 0.9,
          children: [
            for (final theme in ClayThemes.all)
              _ThemeSwatch(
                theme: theme,
                selected: theme.id == settings.themeId,
                onTap: () => notifier.setTheme(theme.id),
              ),
          ],
        ),
        const SectionHeader('Timer'),
        ClayCard(
          child: Column(
            children: [
              _Stepper(
                label: 'Focus length',
                hint: 'Used when a plan has no length of its own',
                value: settings.focusMinutes,
                step: 5,
                onChanged: notifier.setFocusMinutes,
              ),
              const SizedBox(height: 16),
              _Stepper(
                label: 'Break length',
                hint: 'Offered after each focus session',
                value: settings.breakMinutes,
                step: 1,
                onChanged: notifier.setBreakMinutes,
              ),
              if (ref.watch(exactAlarmsAllowedProvider).valueOrNull == false) ...[
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('On-time finish alert', style: ClayText.label),
                          SizedBox(height: 2),
                          Muted(
                            'Allow alarms so "session complete" arrives right on time, '
                            'not a few minutes late.',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    ClayButton(
                      label: 'Allow',
                      icon: Icons.alarm_on_rounded,
                      color: clay.surface,
                      onPressed: () => ref.read(reminderServiceProvider).requestExactAlarms(),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SectionHeader('Reminders'),
        ClayCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Study and deadline reminders', style: ClayText.label),
                        SizedBox(height: 2),
                        Muted('Scheduled on this device. They work offline.'),
                      ],
                    ),
                  ),
                  Switch(
                    value: settings.remindersEnabled,
                    activeTrackColor: clay.primary,
                    onChanged: (on) async {
                      await notifier.setRemindersEnabled(on);
                      if (on) await ref.read(reminderServiceProvider).requestPermission();
                    },
                  ),
                ],
              ),
              if (settings.remindersEnabled) ...[
                const SizedBox(height: 16),
                const Muted('Daily study reminders', style: ClayText.label),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    for (final minute in settings.dailyReminderMinutes)
                      ClayCard(
                        radius: 18,
                        depth: 4,
                        padding: const EdgeInsets.fromLTRB(14, 4, 4, 4),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(formatMinuteOfDay(minute), style: ClayText.label),
                            IconButton(
                              tooltip: 'Remove ${formatMinuteOfDay(minute)}',
                              visualDensity: VisualDensity.compact,
                              icon: const Icon(Icons.close_rounded, size: 18),
                              onPressed: () => notifier.removeDailyReminder(minute),
                            ),
                          ],
                        ),
                      ),
                    if (settings.dailyReminderMinutes.length < SettingsNotifier.maxDailyReminders)
                      ClayButton(
                        label: 'Add time',
                        icon: Icons.add_alarm_rounded,
                        color: clay.surface,
                        onPressed: () async {
                          final time = await showTimePicker(
                            context: context,
                            useRootNavigator: true,
                            initialTime: const TimeOfDay(hour: 18, minute: 0),
                            helpText: 'Remind me to study at',
                          );
                          if (time == null) return;
                          await notifier.addDailyReminder(time.hour * 60 + time.minute);
                          await ref.read(reminderServiceProvider).requestPermission();
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 18),
                const Muted('Remind me before a deadline', style: ClayText.label),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final entry in _leadChoices.entries)
                      ClayChip(
                        label: entry.value,
                        selected: settings.deadlineLeadMinutes == entry.key,
                        onTap: () => notifier.setDeadlineLeadMinutes(entry.key),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 22),
        const Center(child: Muted('Everything is stored on this device.')),
      ],
    );
  }
}

/// A small preview of a theme: its background, a card and its accents.
class _ThemeSwatch extends StatelessWidget {
  const _ThemeSwatch({required this.theme, required this.selected, required this.onTap});

  final ClayTheme theme;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      label: '${theme.name} theme',
      child: ClayCard(
        color: theme.background,
        radius: 24,
        depth: selected ? 3 : 7,
        padding: const EdgeInsets.all(10),
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: theme.surface,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(color: theme.shadow, offset: const Offset(2, 3), blurRadius: 6),
                  ],
                ),
                padding: const EdgeInsets.all(8),
                child: Row(
                  children: [
                    _dot(theme.primary),
                    const SizedBox(width: 5),
                    _dot(theme.secondary),
                    const Spacer(),
                    if (selected) Icon(Icons.check_circle_rounded, size: 18, color: theme.primary),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              theme.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: ClayText.label.copyWith(color: theme.ink),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dot(Color color) => Container(
    width: 16,
    height: 16,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );
}

class _Stepper extends StatelessWidget {
  const _Stepper({
    required this.label,
    required this.hint,
    required this.value,
    required this.step,
    required this.onChanged,
  });

  final String label;
  final String hint;
  final int value;
  final int step;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: ClayText.label),
            const SizedBox(height: 2),
            Muted(hint, maxLines: 2),
          ],
        ),
      ),
      const SizedBox(width: 8),
      ClayIconButton(
        size: 38,
        icon: Icons.remove_rounded,
        tooltip: 'Shorter $label',
        onPressed: () => onChanged(value - step),
      ),
      SizedBox(
        width: 62,
        child: Text('$value min', textAlign: TextAlign.center, style: ClayText.label),
      ),
      ClayIconButton(
        size: 38,
        icon: Icons.add_rounded,
        tooltip: 'Longer $label',
        onPressed: () => onChanged(value + step),
      ),
    ],
  );
}
