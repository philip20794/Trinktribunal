import 'package:flutter/material.dart';

import 'court_theme.dart';

enum CourtMotionStyle { file, stamp }

/// A short decoration only: content and controls are available on the first frame.
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
      duration: CourtTokens.motionDuration(false),
      tween: Tween(begin: 0, end: 1),
      curve: Curves.easeOutCubic,
      child: child,
      builder: (context, value, content) => style == CourtMotionStyle.file
          ? Transform.translate(
              offset: Offset(0, (1 - value) * 8),
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
