import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

const reorderMotionDuration = Duration(milliseconds: 210);
bool _reducedMotion(BuildContext context) =>
    MediaQuery.disableAnimationsOf(context) ||
    MediaQuery.accessibleNavigationOf(context);

/// Only the artwork moves; the numbered hit targets remain stable.
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
    duration: ghost || _reducedMotion(context)
        ? Duration.zero
        : reorderMotionDuration,
    curve: Curves.easeOutCubic,
    tween: Tween(begin: Offset.zero, end: offset),
    child: IgnorePointer(
      ignoring: ghost,
      child: ExcludeSemantics(
        excluding: ghost,
        child: Opacity(opacity: ghost ? 0 : 1, child: child),
      ),
    ),
    builder: (context, position, content) => Transform.translate(
      offset: position,
      transformHitTests: false,
      child: content,
    ),
  );
}

/// A finger-attached avatar, without a rectangular material surface.
class LiftedDragAvatar extends StatelessWidget {
  const LiftedDragAvatar({required this.child, this.lift = 1, super.key});
  final Widget child;
  final double lift;
  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: Transform.scale(
      scale: 1 + .055 * lift,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(32),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: .16 * lift),
              blurRadius: 18 * lift,
              spreadRadius: -8 * lift,
              offset: Offset(0, 8 * lift),
            ),
          ],
        ),
        child: child,
      ),
    ),
  );
}

/// Takes over Flutter's feedback on release and settles it into the live gap.
/// Persistence remains the caller's single validated drop callback.
Future<void> landReorderAvatar({
  required BuildContext context,
  required GlobalKey target,
  required Offset from,
  required Size size,
  required Widget child,
  Alignment alignment = Alignment.center,
  Offset inset = Offset.zero,
}) async {
  if (_reducedMotion(context)) return;
  final targetBox = target.currentContext?.findRenderObject();
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  final overlayBox = overlay?.context.findRenderObject();
  if (targetBox is! RenderBox ||
      !targetBox.hasSize ||
      overlay == null ||
      overlayBox is! RenderBox) {
    return;
  }
  final end = targetBox.localToGlobal(
    inset +
        alignment.alongOffset(
          Offset(
            targetBox.size.width - size.width,
            targetBox.size.height - size.height,
          ),
        ),
  );
  final startRect = overlayBox.globalToLocal(from) & size;
  final endRect = overlayBox.globalToLocal(end) & size;
  final done = Completer<void>();
  final entry = OverlayEntry(
    builder: (context) => IgnorePointer(
      child: ExcludeSemantics(
        child: TweenAnimationBuilder<double>(
          key: const ValueKey('reorder-landing'),
          duration: reorderMotionDuration,
          curve: Curves.easeOutCubic,
          tween: Tween(begin: 0, end: 1),
          onEnd: () {
            if (!done.isCompleted) done.complete();
          },
          builder: (context, value, _) {
            final rect = Rect.lerp(startRect, endRect, value)!;
            return Stack(
              children: [
                Positioned.fromRect(
                  rect: rect,
                  child: LiftedDragAvatar(lift: 1 - value, child: child),
                ),
              ],
            );
          },
        ),
      ),
    ),
  );
  overlay.insert(entry);
  try {
    await done.future;
  } finally {
    entry.remove();
    entry.dispose();
  }
}

/// Reject a pending drop if a remote update changed the committed seats.
bool sameReorderOrder<T>(Iterable<T> before, Iterable<T> after) =>
    listEquals(before.toList(), after.toList());
