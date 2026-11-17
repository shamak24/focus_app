import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Navigator for pages shown inside the shell, above the nav and mini bars.
/// Full-screen routes (the focus timer, sheets, dialogs) use the root one.
final contentNavigatorKey = GlobalKey<NavigatorState>();

abstract final class AppTab {
  static const home = 0;
  static const plans = 1;
  static const stats = 2;
  static const settings = 3;
}

final tabIndexProvider = NotifierProvider<TabIndexNotifier, int>(TabIndexNotifier.new);

class TabIndexNotifier extends Notifier<int> {
  @override
  int build() => AppTab.home;

  /// Switches tab, closing any page pushed on top of the tabs first.
  void go(int index) {
    contentNavigatorKey.currentState?.popUntil((route) => route.isFirst);
    state = index;
  }
}
