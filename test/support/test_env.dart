import 'dart:io';

import 'package:focus_app/core/clock.dart';
import 'package:focus_app/core/storage/app_boxes.dart';
import 'package:focus_app/features/focus/providers/timer_notifier.dart';
import 'package:focus_app/features/plans/data/presets.dart';
import 'package:focus_app/features/reminders/reminder_service.dart';
import 'package:focus_app/features/reminders/reminder_sync.dart';
import 'package:hive/hive.dart';
import 'package:riverpod/riverpod.dart';

/// A clock the test moves by hand.
class FakeClock {
  FakeClock(this.now);

  DateTime now;

  DateTime call() => now;

  void advance(Duration by) => now = now.add(by);

  void set(DateTime to) => now = to;
}

/// Records what the app asked the notification system to schedule.
class RecordingReminderService implements ReminderService {
  final List<List<PlannedReminder>> calls = [];

  List<PlannedReminder> get last => calls.isEmpty ? const [] : calls.last;

  @override
  Future<void> init() async {}

  @override
  Future<bool> requestPermission() async => true;

  bool exactAllowed = true;
  int exactRequests = 0;

  @override
  Future<bool> canScheduleExact() async => exactAllowed;

  @override
  Future<void> requestExactAlarms() async => exactRequests++;

  @override
  Future<void> replaceAll(List<PlannedReminder> reminders) async => calls.add(reminders);

  /// Every ongoing-notification update, in order. Null means hidden.
  final List<OngoingTimer?> ongoing = [];

  @override
  Future<void> showOngoing(OngoingTimer? timer) async => ongoing.add(timer);

  /// Every home-widget update, in order.
  final List<HomeWidgetSnapshot> widgets = [];

  @override
  Future<void> updateHomeWidgets(HomeWidgetSnapshot snapshot) async => widgets.add(snapshot);
}

/// Real Hive boxes in a temp folder plus a provider container wired to a
/// fake clock. [restart] closes everything and reopens the same folder, which
/// is what the app sees after being killed and relaunched.
class TestEnv {
  TestEnv._(this._dir, this._seed, this.clock, this.reminders, this.boxes, this.container);

  final Directory _dir;
  final bool _seed;
  final FakeClock clock;
  final RecordingReminderService reminders;
  AppBoxes boxes;
  ProviderContainer container;

  /// A Monday, mid-morning.
  static final defaultNow = DateTime(2026, 3, 2, 10);

  static Future<TestEnv> create({DateTime? now, bool seed = true}) async {
    final dir = await Directory.systemTemp.createTemp('focus_app_test_');
    final clock = FakeClock(now ?? defaultNow);
    final reminders = RecordingReminderService();
    final boxes = await _open(dir, seed: seed);
    return TestEnv._(dir, seed, clock, reminders, boxes, _container(boxes, clock, reminders));
  }

  static Future<AppBoxes> _open(Directory dir, {required bool seed}) async {
    Hive.init(dir.path);
    final boxes = await AppBoxes.open();
    if (seed) await seedPresets(boxes);
    return boxes;
  }

  static ProviderContainer _container(
    AppBoxes boxes,
    FakeClock clock,
    RecordingReminderService reminders,
  ) => ProviderContainer(
    overrides: [
      boxesProvider.overrideWithValue(boxes),
      clockProvider.overrideWithValue(clock.call),
      timerTickerEnabledProvider.overrideWithValue(false),
      reminderServiceProvider.overrideWithValue(reminders),
    ],
  );

  Future<void> restart() async {
    container.dispose();
    await Hive.close();
    boxes = await _open(_dir, seed: _seed);
    container = _container(boxes, clock, reminders);
  }

  Future<void> dispose() async {
    container.dispose();
    await Hive.close();
    if (_dir.existsSync()) await _dir.delete(recursive: true);
  }
}
