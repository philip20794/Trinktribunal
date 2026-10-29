import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'court_theme.dart';

enum CourtMotionStyle { file, stamp }

/// A brief paper turn without vertical translation, or a decorative verdict stamp.
class CourtMotion extends StatelessWidget {
  const CourtMotion({
    required this.child,
    required this.style,
    this.replayKey,
    super.key,
  });
  final Widget child;
  final CourtMotionStyle style;
  final Object? replayKey;

  @override
  Widget build(BuildContext context) {
    final reduced =
        MediaQuery.disableAnimationsOf(context) ||
        MediaQuery.accessibleNavigationOf(context);
    if (reduced) return child;
    return TweenAnimationBuilder<double>(
      key: ValueKey(replayKey),
      duration: style == CourtMotionStyle.file
          ? const Duration(milliseconds: 220)
          : CourtTokens.motionDuration(false),
      tween: Tween(begin: 0, end: 1),
      curve: Curves.easeOutCubic,
      child: child,
      builder: (context, value, content) => style == CourtMotionStyle.file
          ? Transform(
              alignment: Alignment.centerRight,
              transform: Matrix4.identity()
                ..setEntry(3, 2, .001)
                ..rotateY((1 - value) * -math.pi / 2),
              child: content,
            )
          : Transform.rotate(
              angle: (1 - value) * -0.035,
              child: Transform.scale(
                scale: 1 + (1 - value) * 0.08,
                child: content,
              ),
            ),
    );
  }
}
