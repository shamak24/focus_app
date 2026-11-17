import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focus_app/app.dart';
import 'package:focus_app/core/design/clay_theme.dart';
import 'package:focus_app/core/navigation.dart';
import 'package:focus_app/features/focus/data/active_timer.dart';
import 'package:focus_app/features/focus/providers/timer_notifier.dart';
import 'package:focus_app/features/focus/widgets/focus_screen.dart';
import 'package:focus_app/features/plans/providers/plans_providers.dart';

import 'support/test_env.dart';

/// Real phone sizes in logical pixels, with the system bars they reserve.
/// Landscape phones are the tight case: barely 350 px of height.
const _phones = <String, (Size, EdgeInsets)>{
  'small portrait': (Size(360, 640), EdgeInsets.only(top: 24, bottom: 48)),
  'tall portrait': (Size(412, 915), EdgeInsets.only(top: 24, bottom: 24)),
  'small landscape': (Size(640, 360), EdgeInsets.only(left: 48, top: 24)),
  'tall landscape': (Size(915, 412), EdgeInsets.only(left: 32, right: 32, top: 24)),
  'iPhone landscape': (Size(844, 390), EdgeInsets.only(left: 47, right: 47, bottom: 21)),
};

class _FixedTimer extends TimerNotifier {
  _FixedTimer(this._state);

  final TimerState _state;

  @override
  TimerState build() => _state;
}

TimerState _running({bool paused = false, bool isBreak = false, String title = 'Essay'}) {
  final start = DateTime(2026, 3, 2, 10);
  final timer = ActiveTimer(
    taskId: 't',
    taskTitle: title,
    subject: isBreak ? '' : 'Algebra',
    startedAt: start,
    plannedSeconds: 25 * 60,
    endsAt: start.add(const Duration(minutes: 25)),
    pausedRemainingSeconds: paused ? 18 * 60 : null,
    isBreak: isBreak,
  );
  return TimerState(active: timer, remainingSeconds: 18 * 60 + 42);
}

Future<void> _pumpAt(WidgetTester tester, (Size, EdgeInsets) phone, TimerState state) async {
  final (size, padding) = phone;
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  tester.view.padding = FakeViewPadding(
    left: padding.left,
    top: padding.top,
    right: padding.right,
    bottom: padding.bottom,
  );
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [timerNotifierProvider.overrideWith(() => _FixedTimer(state))],
      child: MaterialApp(theme: buildClayTheme(ClayThemes.peach), home: const FocusScreen()),
    ),
  );
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  for (final MapEntry(key: name, value: phone) in _phones.entries) {
    group('timer screen on a $name phone', () {
      testWidgets('running focus session fits without overflow', (tester) async {
        await _pumpAt(tester, phone, _running());
        expect(tester.takeException(), isNull);
        expect(find.text('18:42'), findsOneWidget);
        expect(find.text('Pause'), findsOneWidget);
        expect(find.text('Finish'), findsOneWidget);
        expect(find.text('Discard session'), findsOneWidget);
      });

      testWidgets('paused session with a long title fits without overflow', (tester) async {
        await _pumpAt(
          tester,
          phone,
          _running(paused: true, title: 'Revise every chapter of organic chemistry for the exam'),
        );
        expect(tester.takeException(), isNull);
        expect(find.text('Resume'), findsOneWidget);
      });

      testWidgets('break fits without overflow', (tester) async {
        await _pumpAt(tester, phone, _running(isBreak: true, title: 'Break'));
        expect(tester.takeException(), isNull);
        expect(find.text('End break'), findsOneWidget);
      });
    });
  }

  for (final MapEntry(key: name, value: phone) in _phones.entries) {
    testWidgets('every tab fits on a $name phone, with a timer running', (tester) async {
      final env = (await tester.runAsync(() => TestEnv.create()))!;
      addTearDown(() => tester.runAsync(env.dispose));
      await tester.runAsync(() async {
        final plan = await env.container
            .read(plansProvider.notifier)
            .create(name: 'Maths', colorValue: 0xFFFFD6A5, defaultFocusMinutes: 25);
        final task = await env.container
            .read(allTasksProvider.notifier)
            .add(planId: plan.id, title: 'Essay', subject: 'Algebra');
        // A running timer also shows the mini bar above the nav bar.
        await env.container.read(timerNotifierProvider.notifier).start(task: task, plan: plan);
      });

      final (size, padding) = phone;
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;
      tester.view.padding = FakeViewPadding(
        left: padding.left,
        top: padding.top,
        right: padding.right,
        bottom: padding.bottom,
      );
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        UncontrolledProviderScope(container: env.container, child: const FocusApp()),
      );
      for (final tab in [AppTab.home, AppTab.plans, AppTab.stats, AppTab.settings]) {
        env.container.read(tabIndexProvider.notifier).go(tab);
        await tester.pump(const Duration(seconds: 1));
        expect(tester.takeException(), isNull, reason: 'tab $tab');
      }
    });
  }
}
