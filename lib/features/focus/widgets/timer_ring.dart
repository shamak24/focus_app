import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/design/clay_card.dart';
import '../../../core/design/clay_theme.dart';

/// The big countdown: a pressed-in circular track, a rounded progress arc and
/// a raised centre disc that holds [child].
class TimerRing extends StatelessWidget {
  const TimerRing({
    super.key,
    required this.progress,
    required this.child,
    this.color,
    this.size = 290,
  });

  /// 0 to 1.
  final double progress;
  final Widget child;
  final Color? color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final clay = context.clay;
    final thickness = size * 0.095;
    return SizedBox.square(
      dimension: size,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClayCard(
            inset: true,
            radius: size / 2,
            depth: 7,
            color: Color.alphaBlend(clay.ink.withValues(alpha: 0.06), clay.background),
            padding: EdgeInsets.zero,
            child: const SizedBox.expand(),
          ),
          // Animate between whole-second updates so the arc glides.
          TweenAnimationBuilder<double>(
            tween: Tween(end: progress.clamp(0.0, 1.0)),
            duration: const Duration(milliseconds: 900),
            curve: Curves.linear,
            builder: (context, value, _) => CustomPaint(
              painter: _ArcPainter(
                progress: value,
                color: color ?? clay.primary,
                thickness: thickness,
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.all(thickness * 1.75),
            child: ClayCard(
              radius: size / 2,
              depth: 9,
              padding: EdgeInsets.zero,
              child: Center(child: child),
            ),
          ),
        ],
      ),
    );
  }
}

class _ArcPainter extends CustomPainter {
  const _ArcPainter({required this.progress, required this.color, required this.thickness});

  final double progress;
  final Color color;
  final double thickness;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    final rect = (Offset.zero & size).deflate(thickness * 0.87);
    final sweep = 2 * math.pi * progress;
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = thickness;
    canvas.drawArc(
      rect.shift(Offset(0, thickness * 0.12)),
      -math.pi / 2,
      sweep,
      false,
      stroke
        ..color = Color.lerp(color, Colors.black, 0.35)!.withValues(alpha: 0.28)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, thickness * 0.22),
    );
    canvas.drawArc(
      rect,
      -math.pi / 2,
      sweep,
      false,
      stroke
        ..color = color
        ..maskFilter = null,
    );
    canvas.drawArc(
      rect.deflate(thickness * 0.2),
      -math.pi / 2,
      sweep,
      false,
      stroke
        ..strokeWidth = thickness * 0.18
        ..color = Colors.white.withValues(alpha: 0.35),
    );
  }

  @override
  bool shouldRepaint(_ArcPainter old) =>
      old.progress != progress || old.color != color || old.thickness != thickness;
}
