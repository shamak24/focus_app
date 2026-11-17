import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'clay_theme.dart';

/// The app's one building block: a soft, puffy shape.
///
/// A raised card gets two outer shadows (a tinted one below-right, a light
/// one above-left) and two inner edges (a highlight top-left, a shade
/// bottom-right), which together read as moulded clay. With [inset] the
/// edges flip and the outer shadows go, giving a pressed-in well for tracks
/// and text fields.
///
/// * [color] is the fill; defaults to the theme's surface.
/// * [radius] is the corner radius.
/// * [depth] scales every shadow: 0 is flat, 8 is a normal card.
class ClayCard extends StatelessWidget {
  const ClayCard({
    super.key,
    required this.child,
    this.color,
    this.radius = 28,
    this.depth = 8,
    this.padding = const EdgeInsets.all(18),
    this.inset = false,
    this.onTap,
    this.onLongPress,
  });

  final Widget child;
  final Color? color;
  final double radius;
  final double depth;
  final EdgeInsetsGeometry padding;
  final bool inset;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    if (onTap == null && onLongPress == null) return _shape(context, depth);
    return ClayPressable(
      onTap: onTap,
      onLongPress: onLongPress,
      builder: (context, pressed) => _shape(context, pressed ? depth * 0.45 : depth),
    );
  }

  Widget _shape(BuildContext context, double depth) {
    final clay = context.clay;
    final fill = color ?? clay.surface;
    final ink = inkOn(fill, clay);
    final lightFill = ThemeData.estimateBrightnessForColor(fill) == Brightness.light;
    final tinted = fill != clay.surface && fill != clay.background;

    final outerShade = tinted && !clay.isDark
        ? Color.lerp(fill, Colors.black, 0.32)!.withValues(alpha: 0.34)
        : clay.shadow;

    return RepaintBoundary(
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          boxShadow: inset || depth <= 0
              ? null
              : [
                  BoxShadow(
                    color: outerShade,
                    offset: Offset(depth * 0.6, depth),
                    blurRadius: depth * 2.4,
                  ),
                  BoxShadow(
                    color: clay.highlight,
                    offset: Offset(-depth * 0.5, -depth * 0.5),
                    blurRadius: depth * 1.6,
                  ),
                ],
        ),
        child: CustomPaint(
          painter: _ClayPainter(
            color: fill,
            radius: radius,
            depth: depth,
            inset: inset,
            lightEdge: Colors.white.withValues(alpha: lightFill ? 0.62 : 0.10),
            darkEdge: Color.lerp(
              fill,
              Colors.black,
              lightFill ? 0.22 : 0.5,
            )!.withValues(alpha: 0.5),
          ),
          child: Padding(
            padding: padding,
            child: DefaultTextStyle.merge(
              style: TextStyle(color: ink),
              child: IconTheme.merge(
                data: IconThemeData(color: ink),
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ClayPainter extends CustomPainter {
  const _ClayPainter({
    required this.color,
    required this.radius,
    required this.depth,
    required this.inset,
    required this.lightEdge,
    required this.darkEdge,
  });

  final Color color;
  final double radius;
  final double depth;
  final bool inset;
  final Color lightEdge;
  final Color darkEdge;

  @override
  void paint(Canvas canvas, Size size) {
    final shape = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(math.min(radius, size.shortestSide / 2)),
    );
    canvas.drawRRect(shape, Paint()..color = color);
    if (depth <= 0) return;

    canvas.save();
    canvas.clipRRect(shape);
    if (inset) {
      _edge(canvas, shape, Offset(depth * 0.5, depth * 0.6), darkEdge, depth);
      _edge(canvas, shape, Offset(-depth * 0.4, -depth * 0.4), lightEdge, depth * 0.8);
    } else {
      _edge(canvas, shape, Offset(depth * 0.55, depth * 0.55), lightEdge, depth * 0.9);
      _edge(canvas, shape, Offset(-depth * 0.5, -depth * 0.6), darkEdge, depth * 1.1);
    }
    canvas.restore();
  }

  /// Paints a blurred band just inside two edges of [shape]: everything
  /// outside a copy of the shape moved by [shift], clipped to the shape.
  void _edge(Canvas canvas, RRect shape, Offset shift, Color color, double blur) {
    final path = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(shape.outerRect.inflate(blur * 3 + shift.distance))
      ..addRRect(shape.shift(shift));
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, blur),
    );
  }

  @override
  bool shouldRepaint(_ClayPainter old) =>
      old.color != color ||
      old.radius != radius ||
      old.depth != depth ||
      old.inset != inset ||
      old.lightEdge != lightEdge ||
      old.darkEdge != darkEdge;
}

/// Tap handling with the clay "squish": the child scales down while pressed.
/// [builder] also receives the pressed flag so shapes can flatten their
/// shadow at the same time.
class ClayPressable extends StatefulWidget {
  const ClayPressable({
    super.key,
    required this.builder,
    this.onTap,
    this.onLongPress,
    this.scale = 0.96,
  });

  final Widget Function(BuildContext context, bool pressed) builder;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double scale;

  @override
  State<ClayPressable> createState() => _ClayPressableState();
}

class _ClayPressableState extends State<ClayPressable> {
  bool _pressed = false;

  bool get _enabled => widget.onTap != null || widget.onLongPress != null;

  void _set(bool value) {
    if (mounted && _pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: _enabled,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: _enabled ? (_) => _set(true) : null,
        onTapCancel: () => _set(false),
        onTapUp: (_) {
          // Hold the pressed look briefly so a quick tap is still visible.
          Future<void>.delayed(const Duration(milliseconds: 90), () => _set(false));
        },
        onTap: widget.onTap == null
            ? null
            : () {
                HapticFeedback.selectionClick();
                widget.onTap!();
              },
        onLongPress: widget.onLongPress,
        child: AnimatedScale(
          scale: _pressed ? widget.scale : 1,
          duration: const Duration(milliseconds: 110),
          curve: Curves.easeOut,
          child: widget.builder(context, _pressed),
        ),
      ),
    );
  }
}
