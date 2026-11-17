import 'dart:async';

import 'package:flutter/services.dart';

/// Colours for the notification, normally taken from the app's clay theme.
class ClayNotificationColors {
  const ClayNotificationColors({
    required this.background,
    required this.surface,
    required this.primary,
    required this.onPrimary,
    required this.ink,
    required this.shadow,
    required this.highlight,
  });

  final Color background;
  final Color surface;
  final Color primary;
  final Color onPrimary;
  final Color ink;
  final Color shadow;
  final Color highlight;

  Map<String, int> toMap() => {
    'background': background.toARGB32(),
    'surface': surface.toARGB32(),
    'primary': primary.toARGB32(),
    'onPrimary': onPrimary.toARGB32(),
    'ink': ink.toARGB32(),
    'shadow': shadow.toARGB32(),
    'highlight': highlight.toARGB32(),
  };
}

/// Buttons on the notification. Taps are delivered through
/// `flutter_local_notifications`' action receiver, so they arrive in its
/// background notification-response callback with these ids.
class ClayNotificationActions {
  const ClayNotificationActions({
    required this.pauseId,
    required this.resumeId,
    required this.stopId,
    this.pauseLabel = 'Pause',
    this.resumeLabel = 'Resume',
    this.stopLabel = 'Stop',
  });

  final String pauseId;
  final String resumeId;
  final String stopId;

  /// Read out by screen readers; the buttons themselves show icons.
  final String pauseLabel;
  final String resumeLabel;
  final String stopLabel;
}

/// A sticky Android notification drawn in the app's clay style: a raised
/// card with a live countdown and round Pause/Resume and Stop buttons.
abstract final class ClayTimerNotification {
  static const _channel = MethodChannel('clay_timer_notification');

  /// Shows or replaces notification [id]. While running (no
  /// [pausedRemainingSeconds]) the system counts down to [endsAt] by itself
  /// and removes the notification when it gets there.
  static Future<void> show({
    required int id,
    required String channelId,
    required String channelName,
    required String channelDescription,
    required String title,
    required String status,
    required DateTime endsAt,
    required ClayNotificationColors colors,
    required ClayNotificationActions actions,
    int? pausedRemainingSeconds,
  }) => _channel.invokeMethod<void>('show', {
    'id': id,
    'channelId': channelId,
    'channelName': channelName,
    'channelDescription': channelDescription,
    'title': title,
    'status': status,
    'endsAtMillis': endsAt.millisecondsSinceEpoch,
    'pausedRemainingSeconds': pausedRemainingSeconds,
    'colors': colors.toMap(),
    'pauseId': actions.pauseId,
    'resumeId': actions.resumeId,
    'stopId': actions.stopId,
    'pauseLabel': actions.pauseLabel,
    'resumeLabel': actions.resumeLabel,
    'stopLabel': actions.stopLabel,
  });

  static Future<void> cancel(int id) => _channel.invokeMethod<void>('cancel', {'id': id});
}

/// The timer as the home-screen widgets show it.
class ClayWidgetTimer {
  const ClayWidgetTimer({
    required this.title,
    required this.endsAt,
    this.pausedRemainingSeconds,
    this.isBreak = false,
  });

  final String title;
  final DateTime endsAt;
  final int? pausedRemainingSeconds;
  final bool isBreak;

  Map<String, Object?> toMap() => {
    'title': title,
    'endsAtMillis': endsAt.millisecondsSinceEpoch,
    'pausedRemainingSeconds': pausedRemainingSeconds,
    'isBreak': isBreak,
  };
}

/// One row of the medium widget's "Up next" list.
class ClayWidgetTask {
  const ClayWidgetTask({
    required this.id,
    required this.title,
    required this.subtitle,
    this.color,
    this.doneDay,
  });

  final String id;
  final String title;

  /// Short detail beside the title, e.g. "45 min".
  final String subtitle;

  /// Plan colour for the dot; null uses the theme's primary.
  final Color? color;

  /// Set to today (yyyymmdd) for a daily task already done today. The widget
  /// hides it until midnight, then shows it again with no help from the app.
  final int? doneDay;

  Map<String, Object?> toMap() => {
    'id': id,
    'title': title,
    'subtitle': subtitle,
    'color': color?.toARGB32() ?? 0,
    'doneDay': doneDay,
  };
}

/// The Android home-screen widgets (2x2 timer, 4x2 timer plus up next).
///
/// They cannot run Dart, so the app sends a snapshot whenever something they
/// show changes; Android keeps it and redraws from it, counting a running
/// timer down by itself.
abstract final class ClayHomeWidget {
  static const _channel = MethodChannel('clay_timer_notification');
  static final StreamController<String> _launchActions = StreamController<String>.broadcast(
    onListen: () => _channel.setMethodCallHandler((call) async {
      if (call.method == 'launchAction' && call.arguments is String) {
        _launchActions.add(call.arguments as String);
      }
    }),
  );

  /// Replaces what every placed widget shows. Widget buttons send
  /// `pauseId` / `resumeId` / `stopId`, and `startPrefix` + task id, to the
  /// notification-response callback, like the notification's buttons.
  static Future<void> update({
    required ClayWidgetTimer? timer,
    required List<ClayWidgetTask> tasks,
    required ClayNotificationColors colors,
    required ClayNotificationActions actions,
    required String startPrefix,
  }) => _channel.invokeMethod<void>('updateWidgets', {
    'snapshot': {
      'timer': timer?.toMap(),
      'tasks': [for (final t in tasks) t.toMap()],
      'colors': colors.toMap(),
      'pauseId': actions.pauseId,
      'resumeId': actions.resumeId,
      'stopId': actions.stopId,
      'startPrefix': startPrefix,
    },
  });

  /// What a widget asked the app to show when it launched it (e.g. "focus"),
  /// or null. Returns it once.
  static Future<String?> takeLaunchAction() => _channel.invokeMethod<String>('takeLaunchAction');

  /// Launch actions for an app that is already running.
  static Stream<String> get launchActions => _launchActions.stream;
}
