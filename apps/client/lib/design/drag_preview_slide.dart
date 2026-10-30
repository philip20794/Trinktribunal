import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

const reorderMotionDuration = Duration(milliseconds: 240);
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
    curve: Curves.easeInOutCubic,
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
          duration: reorderMotionDuration * 2,
          curve: Curves.linear,
          tween: Tween(begin: 0, end: 1),
          onEnd: () {
            if (!done.isCompleted) done.complete();
          },
          builder: (context, value, _) {
            // First open the full slot, then settle the lifted avatar into it.
            final progress = Curves.easeInOutCubic.transform(
              ((value - .5) * 2).clamp(0.0, 1.0),
            );
            final rect = Rect.lerp(startRect, endRect, progress)!;
            return Stack(
              children: [
                Positioned.fromRect(
                  rect: rect,
                  child: LiftedDragAvatar(lift: 1 - progress, child: child),
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

/// Hit-test insertion boundaries against stationary cells, never moving artwork.
int reorderInsertionIndex({
  required int source,
  required int hovered,
  required Rect cell,
  required Offset pointer,
  required int count,
  bool reversed = false,
}) {
  if (source == hovered) return hovered;
  final delta = (pointer.dx - cell.center.dx) * (reversed ? -1 : 1);
  final after =
      delta > .5 ||
      ((pointer.dx - cell.center.dx).abs() < .5 &&
          source >= 0 &&
          source < hovered);
  final boundary = hovered + (after ? 1 : 0);
  return (boundary - (source >= 0 && source < boundary ? 1 : 0)).clamp(
    0,
    count - 1,
  );
}

/// A half-avatar-width gap: the two sides move by a quarter width each.
/// Move the rest of each affected row with its neighbour to avoid collisions.
Map<T, Offset> halfReorderGap<T>({
  required List<T?> slots,
  required List<T?> preview,
  required T dragged,
  required List<Rect> cells,
  required double avatarWidth,
}) {
  final index = preview.indexOf(dragged);
  if (index < 0 || slots.indexOf(dragged) == index) return {};
  final before = preview.take(index).whereType<T>().toList();
  final after = preview.skip(index + 1).whereType<T>().toList();
  final left = before.isEmpty ? -1 : slots.indexOf(before.last);
  final right = after.isEmpty ? -1 : slots.indexOf(after.first);
  final direction =
      left >= 0 &&
          right >= 0 &&
          (cells[left].top - cells[right].top).abs() < 1 &&
          cells[left].center.dx > cells[right].center.dx
      ? -1.0
      : 1.0;
  final result = <T, Offset>{};
  for (var i = 0; i < slots.length; i++) {
    final id = slots[i];
    if (id == null || id == dragged || cells[i].isEmpty) continue;
    final center = cells[i].center;
    var dx = 0.0;
    if (left >= 0 &&
        (cells[i].top - cells[left].top).abs() < 1 &&
        (center.dx - cells[left].center.dx) * direction <= 0) {
      dx = -avatarWidth * .25 * direction;
    }
    if (right >= 0 &&
        (cells[i].top - cells[right].top).abs() < 1 &&
        (center.dx - cells[right].center.dx) * direction >= 0) {
      dx = avatarWidth * .25 * direction;
    }
    result[id] = Offset(dx, 0);
  }
  return result;
}

Rect? reorderCellRect(GlobalKey? key) {
  final box = key?.currentContext?.findRenderObject();
  return box is RenderBox && box.hasSize
      ? box.localToGlobal(Offset.zero) & box.size
      : null;
}
