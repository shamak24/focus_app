import 'package:clay_timer_notification/clay_timer_notification.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart' show Color;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../core/design/clay_theme.dart';
import '../focus/timer_notification_actions.dart';
import 'reminder_planner.dart';
import 'reminder_service.dart';

/// [ReminderService] backed by `flutter_local_notifications`.
///
/// Everything is scheduled on the device, so reminders fire with no network.
/// Every call is wrapped: on a platform or in a state where notifications
/// are unavailable the app carries on without them.
class LocalReminderService implements ReminderService {
  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'focus_reminders',
      'Reminders',
      channelDescription: 'Session finished alerts, study reminders and deadline reminders',
      importance: Importance.high,
      priority: Priority.high,
    ),
    iOS: DarwinNotificationDetails(),
  );

  @override
  Future<void> init() async {
    if (_ready) return;
    try {
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('ic_stat_focus'),
          iOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
        ),
        // Pause / Resume / Stop on the timer notification. They work without
        // opening the app, so they arrive in a background isolate.
        onDidReceiveBackgroundNotificationResponse: onTimerNotificationAction,
      );
      _ready = true;
    } catch (e) {
      debugPrint('Reminders unavailable: $e');
    }
  }

  @override
  Future<bool> requestPermission() async {
    if (!_ready) return false;
    try {
      final android = _plugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (android != null) return await android.requestNotificationsPermission() ?? false;
      final ios = _plugin
          .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
      if (ios != null) {
        return await ios.requestPermissions(alert: true, badge: true, sound: true) ?? false;
      }
    } catch (e) {
      debugPrint('Notification permission request failed: $e');
    }
    return false;
  }

  AndroidFlutterLocalNotificationsPlugin? get _android =>
      _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

  @override
  Future<bool> canScheduleExact() async {
    if (!_ready) return false;
    try {
      final android = _android;
      if (android == null) return true; // Only Android restricts this.
      return await android.canScheduleExactNotifications() ?? false;
    } catch (e) {
      debugPrint('Could not check exact alarm permission: $e');
      return false;
    }
  }

  @override
  Future<void> requestExactAlarms() async {
    if (!_ready) return;
    try {
      await _android?.requestExactAlarmsPermission();
    } catch (e) {
      debugPrint('Exact alarm permission request failed: $e');
    }
  }

  @override
  Future<void> replaceAll(List<PlannedReminder> reminders) async {
    if (!_ready) return;
    // Cancel only what was scheduled. cancelAll() would also remove the
    // ongoing timer notification, which is shown, not scheduled.
    for (final pending in await _plugin.pendingNotificationRequests()) {
      await _plugin.cancel(id: pending.id);
    }
    for (final reminder in reminders) {
      await _schedule(reminder, exact: reminder.exact);
    }
  }

  @override
  Future<void> showOngoing(OngoingTimer? timer) async {
    // Android only: iOS has no countdown notification (that would be a Live
    // Activity), and a plain banner there would just be noise.
    if (!_ready || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      if (timer == null) {
        await _plugin.cancel(id: ReminderIds.ongoingTimer);
        return;
      }
      final paused = timer.pausedRemainingSeconds;
      final remainingMs = timer.endsAt.difference(DateTime.now()).inMilliseconds;
      if (paused == null && remainingMs <= 0) {
        await _plugin.cancel(id: ReminderIds.ongoingTimer);
        return;
      }
      final subtitle = timer.subtitle.isEmpty ? '' : ' · ${timer.subtitle}';
      final status = paused != null
          ? 'Paused · ${_mmss(paused)} left$subtitle'
          : '${timer.isBreak ? 'On a break' : 'Focusing'}$subtitle';
      try {
        await _showClay(timer, status);
        return;
      } catch (e) {
        debugPrint('Clay timer notification failed, using the plain one: $e');
      }
      await _plugin.show(
        id: ReminderIds.ongoingTimer,
        title: timer.title,
        body: status,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            _timerChannelId,
            _timerChannelName,
            channelDescription: _timerChannelDescription,
            // Low importance: sits in the status bar and shade without sound,
            // vibration or a heads-up popup.
            importance: Importance.low,
            priority: Priority.low,
            ongoing: true,
            autoCancel: false,
            onlyAlertOnce: true,
            silent: true,
            category: AndroidNotificationCategory.stopwatch,
            visibility: NotificationVisibility.public,
            // While running, the system draws a live countdown to endsAt, so
            // the app needs to send nothing per second, even when suspended.
            showWhen: paused == null,
            usesChronometer: paused == null,
            chronometerCountDown: paused == null,
            when: paused == null ? timer.endsAt.millisecondsSinceEpoch : null,
            // Removes itself at the end in case the app is not running to do
            // it; the "session finished" reminder takes over from there.
            timeoutAfter: paused == null ? remainingMs : null,
            actions: [
              paused == null
                  ? const AndroidNotificationAction(
                      TimerActions.pause,
                      'Pause',
                      cancelNotification: false,
                    )
                  : const AndroidNotificationAction(
                      TimerActions.resume,
                      'Resume',
                      cancelNotification: false,
                    ),
              const AndroidNotificationAction(TimerActions.stop, 'Stop'),
            ],
          ),
        ),
      );
    } catch (e) {
      debugPrint('Could not update timer notification: $e');
    }
  }

  static const _timerChannelId = 'focus_timer';
  static const _timerChannelName = 'Running timer';
  static const _timerChannelDescription = 'Shows the countdown while a focus session or break runs';

  @override
  Future<void> updateHomeWidgets(HomeWidgetSnapshot snapshot) async {
    if (defaultTargetPlatform != TargetPlatform.android || kIsWeb) return;
    final timer = snapshot.timer;
    try {
      await ClayHomeWidget.update(
        timer: timer == null
            ? null
            : ClayWidgetTimer(
                title: timer.title,
                endsAt: timer.endsAt,
                pausedRemainingSeconds: timer.pausedRemainingSeconds,
                isBreak: timer.isBreak,
              ),
        tasks: [
          for (final t in snapshot.tasks)
            ClayWidgetTask(
              id: t.id,
              title: t.title,
              subtitle: t.subtitle,
              color: t.colorValue == 0 ? null : Color(t.colorValue),
              doneDay: t.doneDay,
            ),
        ],
        colors: _colorsFor(snapshot.themeId),
        actions: _timerButtons,
        startPrefix: TimerActions.startPrefix,
      );
    } catch (e) {
      debugPrint('Could not update home widgets: $e');
    }
  }

  static const _timerButtons = ClayNotificationActions(
    pauseId: TimerActions.pause,
    resumeId: TimerActions.resume,
    stopId: TimerActions.stop,
  );

  static ClayNotificationColors _colorsFor(String themeId) {
    final clay = ClayThemes.byId(themeId);
    return ClayNotificationColors(
      background: clay.background,
      surface: clay.surface,
      primary: clay.primary,
      onPrimary: clay.onPrimary,
      ink: clay.ink,
      shadow: clay.shadow,
      highlight: clay.highlight,
    );
  }

  /// The timer drawn in the app's clay style, in the current theme's colours.
  Future<void> _showClay(OngoingTimer timer, String status) {
    return ClayTimerNotification.show(
      id: ReminderIds.ongoingTimer,
      channelId: _timerChannelId,
      channelName: _timerChannelName,
      channelDescription: _timerChannelDescription,
      title: timer.title,
      status: status,
      endsAt: timer.endsAt,
      pausedRemainingSeconds: timer.pausedRemainingSeconds,
      colors: _colorsFor(timer.themeId),
      actions: _timerButtons,
    );
  }

  static String _mmss(int seconds) {
    final m = seconds ~/ 60;
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Future<void> _schedule(PlannedReminder reminder, {required bool exact}) async {
    final daily = reminder.dailyMinuteOfDay;
    final when = daily != null ? _nextTimeOfDay(daily) : reminder.at!;
    if (!when.isAfter(DateTime.now())) return;
    try {
      await _plugin.zonedSchedule(
        id: reminder.id,
        title: reminder.title,
        body: reminder.body,
        // The instant is expressed in UTC, which avoids shipping the time
        // zone database. A daily reminder therefore repeats at a fixed UTC
        // time: correct wherever the clocks do not change, and corrected at
        // the next launch (when everything is rescheduled) where they do.
        scheduledDate: tz.TZDateTime.from(when, tz.UTC),
        notificationDetails: _details,
        androidScheduleMode: exact
            ? AndroidScheduleMode.exactAllowWhileIdle
            : AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: daily != null ? DateTimeComponents.time : null,
      );
    } catch (e) {
      // Exact alarms can be refused by the OS; an inexact one is better
      // than none.
      if (exact) return _schedule(reminder, exact: false);
      debugPrint('Could not schedule reminder ${reminder.id}: $e');
    }
  }

  DateTime _nextTimeOfDay(int minuteOfDay) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day, minuteOfDay ~/ 60, minuteOfDay % 60);
    return today.isAfter(now)
        ? today
        : DateTime(now.year, now.month, now.day + 1, minuteOfDay ~/ 60, minuteOfDay % 60);
  }
}
