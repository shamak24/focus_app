import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'app.dart';
import 'core/storage/app_boxes.dart';
import 'features/focus/timer_notification_actions.dart';
import 'features/plans/data/presets.dart';
import 'features/reminders/local_reminder_service.dart';
import 'features/reminders/reminder_sync.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Hive.initFlutter();
  final boxes = await AppBoxes.open();
  await seedPresets(boxes);

  final reminders = LocalReminderService();
  await reminders.init();

  final container = ProviderContainer(
    overrides: [
      boxesProvider.overrideWithValue(boxes),
      reminderServiceProvider.overrideWithValue(reminders),
    ],
  );
  TimerActionPort.listen(container);

  runApp(UncontrolledProviderScope(container: container, child: const FocusApp()));
}
