import 'dart:async';

import 'package:clay_timer_notification/clay_timer_notification.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/clock.dart';
import 'core/design/clay_card.dart';
import 'core/design/clay_theme.dart';
import 'core/navigation.dart';
import 'features/focus/providers/timer_notifier.dart';
import 'features/focus/widgets/focus_actions.dart';
import 'features/focus/widgets/mini_bar.dart';
import 'features/home/widgets/home_screen.dart';
import 'features/plans/widgets/plans_screen.dart';
import 'features/progress/providers/progress_provider.dart';
import 'features/progress/widgets/progress_widgets.dart';
import 'features/reminders/reminder_sync.dart';
import 'features/settings/providers/settings_provider.dart';
import 'features/settings/widgets/settings_screen.dart';
import 'features/stats/widgets/stats_screen.dart';

class FocusApp extends ConsumerWidget {
  const FocusApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clay = ClayThemes.byId(ref.watch(themeProvider));
    ref.watch(reminderSyncProvider);

    return MaterialApp(
      title: 'Focus',
      debugShowCheckedModeBanner: false,
      theme: buildClayTheme(clay),
      home: const AppShell(),
    );
  }
}

/// The frame around every screen: tab content on top, then the mini bar and
/// the nav bar, which stay put while pages are pushed inside the content area.
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Closes out a session that finished while the app was not running.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _catchUp();
      _listenForWidgetLaunches();
    });
  }

  StreamSubscription<String>? _widgetLaunches;

  @override
  void dispose() {
    _widgetLaunches?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// A home-screen widget opened the app: show what it asked for.
  Future<void> _listenForWidgetLaunches() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    _widgetLaunches = ClayHomeWidget.launchActions.listen(_onWidgetLaunch);
    try {
      final action = await ClayHomeWidget.takeLaunchAction();
      if (action != null) _onWidgetLaunch(action);
    } catch (_) {
      // No plugin here (tests, other platforms): nothing to do.
    }
  }

  void _onWidgetLaunch(String action) {
    if (!mounted) return;
    if (action == 'focus') startFocusFlow(context, ref);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _catchUp();
  }

  /// Brings clock-dependent state up to date after time passed unobserved.
  void _catchUp() {
    if (!mounted) return;
    ref.read(todayProvider.notifier).refresh();
    ref.read(timerNotifierProvider.notifier).tick();
    // Back from the system page where exact alarms are allowed: re-check,
    // and the resync below reschedules the timer alert as exact.
    ref.invalidate(exactAlarmsAllowedProvider);
    ref.read(reminderSyncProvider).schedule();
  }

  void _onBack() {
    final content = contentNavigatorKey.currentState;
    if (content != null && content.canPop()) {
      content.pop();
    } else if (ref.read(tabIndexProvider) != AppTab.home) {
      ref.read(tabIndexProvider.notifier).go(AppTab.home);
    } else {
      SystemNavigator.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final clay = context.clay;
    ref.listen(rewardBusProvider, (_, event) {
      if (event != null) showRewardToast(context, event);
    });

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: (clay.isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark).copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: clay.background,
      ),
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _onBack();
        },
        child: Scaffold(
          resizeToAvoidBottomInset: false,
          body: SafeArea(
            bottom: false,
            child: Navigator(
              key: contentNavigatorKey,
              onGenerateRoute: (_) => MaterialPageRoute<void>(builder: (_) => const _Tabs()),
            ),
          ),
          bottomNavigationBar: const SafeArea(
            top: false,
            child: Column(mainAxisSize: MainAxisSize.min, children: [MiniBar(), _NavBar()]),
          ),
        ),
      ),
    );
  }
}

class _Tabs extends ConsumerWidget {
  const _Tabs();

  @override
  Widget build(BuildContext context, WidgetRef ref) => ColoredBox(
    color: context.clay.background,
    child: IndexedStack(
      index: ref.watch(tabIndexProvider),
      children: const [HomeScreen(), PlansScreen(), StatsScreen(), SettingsScreen()],
    ),
  );
}

class _NavBar extends ConsumerWidget {
  const _NavBar();

  static const _items = [
    (Icons.home_rounded, 'Home'),
    (Icons.dashboard_customize_rounded, 'Plans'),
    (Icons.insights_rounded, 'Stats'),
    (Icons.palette_rounded, 'Settings'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clay = context.clay;
    final current = ref.watch(tabIndexProvider);

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
      child: ClayCard(
        radius: 30,
        depth: 7,
        padding: const EdgeInsets.all(7),
        child: Row(
          children: [
            for (final (i, (icon, label)) in _items.indexed)
              Expanded(
                flex: i == current ? 3 : 2,
                child: Semantics(
                  selected: i == current,
                  child: ClayPressable(
                    scale: 0.92,
                    onTap: () => ref.read(tabIndexProvider.notifier).go(i),
                    builder: (context, _) => AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOutCubic,
                      height: 46,
                      decoration: BoxDecoration(
                        color: i == current ? clay.primary : Colors.transparent,
                        borderRadius: BorderRadius.circular(23),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            icon,
                            size: 24,
                            color: i == current ? clay.onPrimary : clay.inkMuted,
                            semanticLabel: label,
                          ),
                          if (i == current) ...[
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                label,
                                maxLines: 1,
                                overflow: TextOverflow.fade,
                                softWrap: false,
                                style: ClayText.label.copyWith(color: clay.onPrimary),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
