import 'package:flutter/material.dart';

/// Moves only the illustration. Drop targets stay in their numbered cells,
/// avoiding hover jitter while neighbours make space for a tentative insertion.
class DragPreviewSlide extends StatelessWidget {
  const DragPreviewSlide({
    required this.offset,
    required this.child,
    this.ghost = false,
    this.originGhost,
    super.key,
  });
  final Offset offset;
  final Widget child;
  final bool ghost;
  final Widget? originGhost;

  @override
  Widget build(BuildContext context) => Stack(
    clipBehavior: Clip.none,
    alignment: Alignment.center,
    children: [
      if (ghost && offset != Offset.zero && originGhost != null)
        Positioned.fill(
          child: IgnorePointer(
            child: ExcludeSemantics(
              child: Center(
                child: Opacity(
                  key: const ValueKey('drag-origin-ghost'),
                  opacity: .25,
                  child: originGhost,
                ),
              ),
            ),
          ),
        ),
      TweenAnimationBuilder<Offset>(
        duration:
            ghost ||
                MediaQuery.disableAnimationsOf(context) ||
                MediaQuery.accessibleNavigationOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 360),
        curve: Curves.easeInOutCubic,
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
      ),
    ],
  );
}
