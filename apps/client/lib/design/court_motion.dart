import 'package:flutter/material.dart';

import 'court_theme.dart';

enum CourtMotionStyle { file, stamp }

/// Places the previous paper behind the next one, or stamps a verdict.
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
    if (style == CourtMotionStyle.file) {
      return AnimatedSwitcher(
        duration: const Duration(milliseconds: 650),
        switchOutCurve: Curves.easeInOutCubic,
        layoutBuilder: (current, previous) => Stack(
          alignment: Alignment.topCenter,
          children: [?current, ...previous],
        ),
        transitionBuilder: (paper, animation) => AnimatedBuilder(
          animation: animation,
          child: paper,
          builder: (context, content) {
            // The next sheet rests underneath while the old one recedes.
            if (animation.status != AnimationStatus.reverse) return content!;
            final remaining = animation.value;
            return IgnorePointer(
              child: ExcludeSemantics(
                child: Opacity(
                  opacity: remaining,
                  child: FractionalTranslation(
                    translation: Offset(0, -.045 * (1 - remaining)),
                    child: Transform.scale(
                      scale: .94 + .06 * remaining,
                      child: content,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
        child: KeyedSubtree(key: ValueKey(replayKey), child: child),
      );
    }
    return TweenAnimationBuilder<double>(
      key: ValueKey(replayKey),
      duration: CourtTokens.motionDuration(false),
      tween: Tween(begin: 0, end: 1),
      curve: Curves.easeOutCubic,
      child: child,
      builder: (context, value, content) => Transform.rotate(
        angle: (1 - value) * -0.035,
        child: Transform.scale(scale: 1 + (1 - value) * 0.08, child: content),
      ),
    );
  }
}
