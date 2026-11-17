import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focus_app/core/design/clay_card.dart';
import 'package:focus_app/core/design/clay_theme.dart';
import 'package:focus_app/core/design/clay_widgets.dart';

Widget _host(ClayTheme theme, Widget child) => MaterialApp(
  theme: buildClayTheme(theme),
  home: Scaffold(body: Center(child: child)),
);

void main() {
  test('every theme has a unique id and builds a ThemeData carrying it', () {
    final ids = ClayThemes.all.map((t) => t.id).toSet();
    expect(ids.length, ClayThemes.all.length);
    expect(ClayThemes.all.length, greaterThan(2), reason: 'more than just light and dark');

    for (final theme in ClayThemes.all) {
      final data = buildClayTheme(theme);
      expect(data.extension<ClayTheme>()?.id, theme.id);
      expect(data.scaffoldBackgroundColor, theme.background);
      expect(data.brightness, theme.brightness);
    }
    expect(ClayThemes.byId('does-not-exist').id, 'peach');
  });

  test('themes blend into each other and settle on the target', () {
    final mid = ClayThemes.peach.lerp(ClayThemes.midnight, 0.5);
    expect(mid.background, isNot(ClayThemes.peach.background));
    expect(
      ClayThemes.peach.lerp(ClayThemes.midnight, 1).background,
      ClayThemes.midnight.background,
    );
    expect(ClayThemes.peach.lerp(ClayThemes.midnight, 1).id, 'midnight');
  });

  testWidgets('ClayCard gives its child readable text on a pastel fill in a dark theme', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        ClayThemes.midnight,
        const ClayCard(color: Color(0xFFFFD6A5), radius: 24, depth: 6, child: Text('Hello')),
      ),
    );
    final text = tester.widget<RichText>(find.byType(RichText));
    expect(text.text.style?.color, clayInkOnPastel);
  });

  testWidgets('ClayButton shows its label and reports taps', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      _host(ClayThemes.peach, ClayButton(label: 'Start focus', onPressed: () => taps++)),
    );
    expect(find.text('Start focus'), findsOneWidget);

    await tester.tap(find.text('Start focus'));
    // Let the press animation and its release delay finish.
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    expect(taps, 1);
  });

  testWidgets('a disabled ClayButton ignores taps', (tester) async {
    await tester.pumpWidget(
      _host(ClayThemes.mint, const ClayButton(label: 'Nope', onPressed: null)),
    );
    await tester.tap(find.text('Nope'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    expect(find.text('Nope'), findsOneWidget);
  });
}
