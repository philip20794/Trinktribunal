import 'package:flutter/material.dart';

/// Moves only the illustration. Drop targets stay in their numbered cells,
/// avoiding hover jitter while neighbours make space for a tentative insertion.
class DragPreviewSlide extends StatelessWidget {
  const DragPreviewSlide({
    required this.offset,
    required this.child,
    this.ghost = false,
    super.key,
  });
  final Offset offset;
  final Widget child;
  final bool ghost;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<Offset>(
    duration:
        MediaQuery.disableAnimationsOf(context) ||
            MediaQuery.accessibleNavigationOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 240),
    curve: Curves.easeOutCubic,
    tween: Tween(begin: Offset.zero, end: offset),
    child: AnimatedOpacity(
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 120),
      opacity: ghost ? .35 : 1,
      child: child,
    ),
    builder: (context, position, content) => Transform.translate(
      offset: position,
      transformHitTests: false,
      child: content,
    ),
  );
}
