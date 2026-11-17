import 'package:hive/hive.dart';
import 'package:riverpod/riverpod.dart';

import '../../features/focus/data/active_timer.dart';
import '../../features/focus/data/focus_session.dart';
import '../../features/plans/data/plan.dart';
import '../../features/plans/data/task.dart';
import '../../features/progress/data/progress.dart';
import '../../features/settings/data/app_settings.dart';

/// Keys inside the `meta` box, which holds the app's single-instance records.
abstract final class MetaKeys {
  static const settings = 'settings';
  static const progress = 'progress';
  static const activeTimer = 'activeTimer';
  static const presetsVersion = 'presetsVersion';
}

/// The open Hive boxes. Opened once at startup and handed to the provider
/// tree through [boxesProvider].
class AppBoxes {
  AppBoxes._(this.plans, this.tasks, this.sessions, this.meta);

  final Box<Plan> plans;
  final Box<Task> tasks;
  final Box<FocusSession> sessions;
  final Box<dynamic> meta;

  static void registerAdapters() {
    void add<T>(TypeAdapter<T> adapter) {
      if (!Hive.isAdapterRegistered(adapter.typeId)) Hive.registerAdapter<T>(adapter);
    }

    add(PlanAdapter());
    add(TaskAdapter());
    add(FocusSessionAdapter());
    add(AppSettingsAdapter());
    add(ProgressAdapter());
    add(ActiveTimerAdapter());
  }

  /// Call after `Hive.initFlutter()` (or `Hive.init(path)` in tests).
  static Future<AppBoxes> open() async {
    registerAdapters();
    return AppBoxes._(
      await Hive.openBox<Plan>('plans'),
      await Hive.openBox<Task>('tasks'),
      await Hive.openBox<FocusSession>('sessions'),
      await Hive.openBox<dynamic>('meta'),
    );
  }

  Future<void> close() async {
    await plans.close();
    await tasks.close();
    await sessions.close();
    await meta.close();
  }
}

/// Overridden in `main()` and in tests with the opened boxes.
final boxesProvider = Provider<AppBoxes>(
  (ref) => throw UnimplementedError('boxesProvider must be overridden with opened boxes'),
);
