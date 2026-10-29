import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Finite, deterministic bursts from both bottom corners. No timers or particles
/// survive disposal; reduced-motion devices receive a static celebration.
class CourtCelebration extends StatefulWidget {
  const CourtCelebration({super.key});
  @override
  State<CourtCelebration> createState() => _CourtCelebrationState();
}

class _CourtCelebrationState extends State<CourtCelebration>
    with SingleTickerProviderStateMixin {
  late final _animation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  );
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _animation.stop();
      _animation.value = .35;
    } else if (_animation.value == 0) {
      _animation.forward();
    }
  }

  @override
  void dispose() {
    _animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: RepaintBoundary(
      child: CustomPaint(
        painter: _Confetti(_animation),
        child: const SizedBox.expand(),
      ),
    ),
  );
}

class _Confetti extends CustomPainter {
  _Confetti(this.animation) : super(repaint: animation);
  final Animation<double> animation;
  static const colors = [
    Color(0xFFFFC857),
    Color(0xFFEF6461),
    Color(0xFF56C9B8),
    Color(0xFFBB86FC),
    Color(0xFFF9F4DF),
  ];
  @override
  void paint(Canvas canvas, Size size) {
    final t = animation.value;
    if (t <= 0 || t >= 1) return;
    final random = math.Random(71);
    for (final side in [-1, 1]) {
      for (var i = 0; i < 45; i++) {
        final speed = .45 + random.nextDouble() * .75;
        final vx = 50 + random.nextDouble() * size.width * .85;
        final vy = size.height * (.8 + random.nextDouble() * .65);
        final x = (side == 1 ? 0 : size.width) + side * vx * t * speed;
        final y = size.height - vy * t * speed + size.height * t * t * .85;
        canvas.save();
        canvas.translate(x, y);
        canvas.rotate(i + t * 8);
        canvas.drawRect(
          const Rect.fromLTWH(-3, -5, 6, 10),
          Paint()
            ..color = colors[i % colors.length].withValues(
              alpha: (1 - t).clamp(0, 1),
            ),
        );
        canvas.restore();
      }
    }
  }

  @override
  bool shouldRepaint(_Confetti oldDelegate) =>
      oldDelegate.animation != animation;
}
