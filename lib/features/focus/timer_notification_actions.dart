import 'dart:async';
import 'dart:isolate';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:riverpod/riverpod.dart';

import '../../core/storage/app_boxes.dart';
import '../reminders/local_reminder_service.dart';
import '../reminders/reminder_sync.dart';
import '../plans/providers/plans_providers.dart';
import 'providers/timer_notifier.dart';

/// Ids of the buttons on the ongoing timer notification.
abstract final class TimerActions {
  static const pause = 'timer_pause';
  static const resume = 'timer_resume';
  static const stop = 'timer_stop';

  /// Followed by a task id: start focus on that task (home-screen widget).
  static const startPrefix = 'timer_start:';
}

const _portName = 'focus_timer_actions';

/// Runs one notification or widget button against the timer. Stop ends the
/// session the same way the in-app Finish button does, so the time so far is
/// logged. Start uses the task's own focus length, like starting in the app.
Future<void> applyTimerAction(ProviderContainer container, String? actionId) async {
  final timer = container.read(timerNotifierProvider.notifier);
  if (actionId != null && actionId.startsWith(TimerActions.startPrefix)) {
    final taskId = actionId.substring(TimerActions.startPrefix.length);
    final task = container.read(allTasksProvider).where((t) => t.id == taskId).firstOrNull;
    if (task == null) return;
    await timer.start(task: task, plan: container.read(planByIdProvider(task.planId)));
    return;
  }
  switch (actionId) {
    case TimerActions.pause:
      await timer.pause();
    case TimerActions.resume:
      await timer.resume();
    case TimerActions.stop:
      await timer.finish();
  }
}

/// Lets notification buttons reach the running app.
///
/// Button taps arrive in a separate background isolate (see
/// [onTimerNotificationAction]), which cannot touch the app's state. While
/// the app is alive it listens on a named port, and the background isolate
/// forwards each tap here.
class TimerActionPort {
  TimerActionPort._(this._port);

  final ReceivePort _port;

  static TimerActionPort listen(ProviderContainer container) {
    final port = ReceivePort();
    IsolateNameServer.removePortNameMapping(_portName);
    IsolateNameServer.registerPortWithName(port.sendPort, _portName);
    port.listen((message) async {
      if (message is! List || message.length != 2) return;
      final [actionId as String?, reply as SendPort] = message;
      // Acknowledge first: the sender only needs to know someone is here.
      reply.send(true);
      await applyTimerAction(container, actionId);
    });
    return TimerActionPort._(port);
  }

  void close() {
    IsolateNameServer.removePortNameMapping(_portName);
    _port.close();
  }
}

/// Entry point for notification button taps, run by the notifications plugin
/// in a background isolate.
@pragma('vm:entry-point')
Future<void> onTimerNotificationAction(NotificationResponse response) async {
  final actionId = response.actionId;
  if (kDebugMode) debugPrint('Timer notification button: $actionId');
  if (actionId == null) return;
  if (await _forwardToApp(actionId)) return;
  await _applyWithoutApp(actionId);
}

/// Hands the tap to the running app. False when no app answers, which also
/// covers a port left registered by an app that has since been shut down.
Future<bool> _forwardToApp(String actionId) async {
  final app = IsolateNameServer.lookupPortByName(_portName);
  if (app == null) return false;
  final reply = ReceivePort();
  try {
    app.send([actionId, reply.sendPort]);
    return await reply.first.timeout(const Duration(seconds: 1), onTimeout: () => false) == true;
  } finally {
    reply.close();
  }
}

/// The app is not running: open storage here and run the same timer code it
/// would, including logging the session and rescheduling reminders.
Future<void> _applyWithoutApp(String actionId) async {
  IsolateNameServer.removePortNameMapping(_portName);
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  await Hive.initFlutter();
  final boxes = await AppBoxes.open();
  final reminders = LocalReminderService();
  await reminders.init();
  final container = ProviderContainer(
    overrides: [
      boxesProvider.overrideWithValue(boxes),
      reminderServiceProvider.overrideWithValue(reminders),
      timerTickerEnabledProvider.overrideWithValue(false),
    ],
  );
  try {
    final sync = container.read(reminderSyncProvider);
    await applyTimerAction(container, actionId);
    await sync.idle;
  } finally {
    container.dispose();
    await Hive.close();
  }
}
