import 'package:flutter/material.dart';

/// One complete look for the app: palette, shadow tones and background.
///
/// Registered on [ThemeData] as an extension, so switching theme animates
/// every colour, shadows included.
@immutable
class ClayTheme extends ThemeExtension<ClayTheme> {
  const ClayTheme({
    required this.id,
    required this.name,
    required this.brightness,
    required this.background,
    required this.surface,
    required this.primary,
    required this.onPrimary,
    required this.secondary,
    required this.ink,
    required this.shadow,
    required this.highlight,
    this.success = const Color(0xFF58C48A),
    this.danger = const Color(0xFFF07C7C),
  });

  /// Stored in settings. Never change an existing id.
  final String id;
  final String name;
  final Brightness brightness;

  /// Page background.
  final Color background;

  /// Default card fill.
  final Color surface;
  final Color primary;
  final Color onPrimary;
  final Color secondary;

  /// Text and icon colour on [background] and [surface].
  final Color ink;

  /// Soft outer shadow under raised shapes.
  final Color shadow;

  /// Light rim on the top-left of raised shapes.
  final Color highlight;
  final Color success;
  final Color danger;

  bool get isDark => brightness == Brightness.dark;
  Color get inkMuted => ink.withValues(alpha: 0.62);

  @override
  ClayTheme copyWith({
    Color? background,
    Color? surface,
    Color? primary,
    Color? onPrimary,
    Color? secondary,
    Color? ink,
    Color? shadow,
    Color? highlight,
    Color? success,
    Color? danger,
  }) => ClayTheme(
    id: id,
    name: name,
    brightness: brightness,
    background: background ?? this.background,
    surface: surface ?? this.surface,
    primary: primary ?? this.primary,
    onPrimary: onPrimary ?? this.onPrimary,
    secondary: secondary ?? this.secondary,
    ink: ink ?? this.ink,
    shadow: shadow ?? this.shadow,
    highlight: highlight ?? this.highlight,
    success: success ?? this.success,
    danger: danger ?? this.danger,
  );

  @override
  ClayTheme lerp(ThemeExtension<ClayTheme>? other, double t) {
    if (other is! ClayTheme) return this;
    final end = t < 0.5 ? this : other;
    return ClayTheme(
      id: end.id,
      name: end.name,
      brightness: end.brightness,
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      primary: Color.lerp(primary, other.primary, t)!,
      onPrimary: Color.lerp(onPrimary, other.onPrimary, t)!,
      secondary: Color.lerp(secondary, other.secondary, t)!,
      ink: Color.lerp(ink, other.ink, t)!,
      shadow: Color.lerp(shadow, other.shadow, t)!,
      highlight: Color.lerp(highlight, other.highlight, t)!,
      success: Color.lerp(success, other.success, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
    );
  }
}

/// The themes a user can pick in Settings. To add one, define it here and
/// append it to [all].
abstract final class ClayThemes {
  static const peach = ClayTheme(
    id: 'peach',
    name: 'Peach',
    brightness: Brightness.light,
    background: Color(0xFFFFEEE2),
    surface: Color(0xFFFFF8F2),
    primary: Color(0xFFFF8A65),
    onPrimary: Color(0xFF4A2317),
    secondary: Color(0xFFFFC857),
    ink: Color(0xFF4A342B),
    shadow: Color(0x66C99774),
    highlight: Color(0xE6FFFFFF),
  );

  static const mint = ClayTheme(
    id: 'mint',
    name: 'Mint',
    brightness: Brightness.light,
    background: Color(0xFFE3F5EC),
    surface: Color(0xFFF3FCF7),
    primary: Color(0xFF47C795),
    onPrimary: Color(0xFF0E3B2A),
    secondary: Color(0xFFFFB86B),
    ink: Color(0xFF23443A),
    shadow: Color(0x6687BFA5),
    highlight: Color(0xE6FFFFFF),
  );

  static const lavender = ClayTheme(
    id: 'lavender',
    name: 'Lavender',
    brightness: Brightness.light,
    background: Color(0xFFEDE8FD),
    surface: Color(0xFFF8F5FF),
    primary: Color(0xFF9A7DF8),
    onPrimary: Color(0xFF231548),
    secondary: Color(0xFFFF9ECF),
    ink: Color(0xFF33285C),
    shadow: Color(0x66A796E0),
    highlight: Color(0xE6FFFFFF),
  );

  static const sky = ClayTheme(
    id: 'sky',
    name: 'Sky',
    brightness: Brightness.light,
    background: Color(0xFFE2F0FF),
    surface: Color(0xFFF3F9FF),
    primary: Color(0xFF5AA5F7),
    onPrimary: Color(0xFF0D2C4E),
    secondary: Color(0xFFFFD166),
    ink: Color(0xFF1F3A5C),
    shadow: Color(0x668DB6E3),
    highlight: Color(0xE6FFFFFF),
  );

  static const midnight = ClayTheme(
    id: 'midnight',
    name: 'Midnight',
    brightness: Brightness.dark,
    background: Color(0xFF1B1D2E),
    surface: Color(0xFF292C44),
    primary: Color(0xFF8EA2FF),
    onPrimary: Color(0xFF141A3D),
    secondary: Color(0xFFFFB4A2),
    ink: Color(0xFFEEF0FF),
    shadow: Color(0x99090A12),
    highlight: Color(0x14FFFFFF),
  );

  static const cocoa = ClayTheme(
    id: 'cocoa',
    name: 'Cocoa',
    brightness: Brightness.dark,
    background: Color(0xFF2A1F1B),
    surface: Color(0xFF3B2D27),
    primary: Color(0xFFFFAB76),
    onPrimary: Color(0xFF3F1F0C),
    secondary: Color(0xFFF6D186),
    ink: Color(0xFFFFF1E6),
    shadow: Color(0x99120C09),
    highlight: Color(0x14FFFFFF),
  );

  static const all = <ClayTheme>[peach, mint, lavender, sky, midnight, cocoa];

  static ClayTheme byId(String id) {
    for (final theme in all) {
      if (theme.id == id) return theme;
    }
    return peach;
  }
}

/// Type scale. The styles carry no colour on purpose: text picks its colour
/// up from the surface it sits on (see `ClayCard`), so the same widget reads
/// correctly on a pastel card in a dark theme.
abstract final class ClayText {
  static const display = TextStyle(
    fontSize: 34,
    fontWeight: FontWeight.w900,
    height: 1.1,
    letterSpacing: -0.5,
  );
  static const headline = TextStyle(fontSize: 24, fontWeight: FontWeight.w900, height: 1.15);
  static const title = TextStyle(fontSize: 18, fontWeight: FontWeight.w800, height: 1.2);
  static const body = TextStyle(fontSize: 15, fontWeight: FontWeight.w600, height: 1.35);
  static const label = TextStyle(fontSize: 14, fontWeight: FontWeight.w800, height: 1.2);
  static const caption = TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, height: 1.25);
}

/// Dark ink used on pastel fills in every theme.
const clayInkOnPastel = Color(0xFF3A2F3D);

extension ClayContext on BuildContext {
  ClayTheme get clay => Theme.of(this).extension<ClayTheme>() ?? ClayThemes.peach;

  /// Text colour of the surface this widget sits on.
  Color get ink => DefaultTextStyle.of(this).style.color ?? clay.ink;

  Color get inkMuted => ink.withValues(alpha: 0.62);
}

/// Readable text colour for an arbitrary fill.
Color inkOn(Color fill, ClayTheme clay) {
  if (fill == clay.surface || fill == clay.background) return clay.ink;
  if (fill == clay.primary) return clay.onPrimary;
  return ThemeData.estimateBrightnessForColor(fill) == Brightness.light
      ? clayInkOnPastel
      : Colors.white;
}

ThemeData buildClayTheme(ClayTheme clay) {
  final scheme = ColorScheme.fromSeed(seedColor: clay.primary, brightness: clay.brightness)
      .copyWith(
        primary: clay.primary,
        onPrimary: clay.onPrimary,
        secondary: clay.secondary,
        onSecondary: clayInkOnPastel,
        surface: clay.surface,
        onSurface: clay.ink,
        error: clay.danger,
      );
  final base = ThemeData(
    useMaterial3: true,
    brightness: clay.brightness,
    colorScheme: scheme,
    fontFamily: 'Nunito',
    scaffoldBackgroundColor: clay.background,
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
    extensions: [clay],
  );
  final rounded = RoundedRectangleBorder(borderRadius: BorderRadius.circular(28));
  return base.copyWith(
    textTheme: base.textTheme.apply(bodyColor: clay.ink, displayColor: clay.ink),
    iconTheme: IconThemeData(color: clay.ink),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: clay.background,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: clay.surface,
      surfaceTintColor: Colors.transparent,
      shape: rounded,
      titleTextStyle: ClayText.title.copyWith(color: clay.ink, fontFamily: 'Nunito'),
      contentTextStyle: ClayText.body.copyWith(color: clay.inkMuted, fontFamily: 'Nunito'),
    ),
    datePickerTheme: DatePickerThemeData(backgroundColor: clay.surface, shape: rounded),
    timePickerTheme: TimePickerThemeData(backgroundColor: clay.surface, shape: rounded),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: clay.ink,
        textStyle: ClayText.label.copyWith(fontFamily: 'Nunito'),
      ),
    ),
    snackBarTheme: const SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: Colors.transparent,
      elevation: 0,
    ),
  );
}
