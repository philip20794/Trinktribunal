import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import 'court_scene.dart';

const reorderMotionDuration = Duration(milliseconds: 240);
bool _reducedMotion(BuildContext context) =>
    MediaQuery.disableAnimationsOf(context) ||
    MediaQuery.accessibleNavigationOf(context);

/// Move the complete portrait unit while its drop hit area remains stable.
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
/// Move neighbours in the active row together to avoid collisions.
Map<T, Offset> halfReorderGap<T>({
  required List<T?> slots,
  required List<T?> preview,
  required T dragged,
  required List<Rect> cells,
  required double avatarWidth,
  int? activeIndex,
}) {
  final index = preview.indexOf(dragged);
  if (index < 0 || slots.indexOf(dragged) == index) return {};
  final activeRow =
      cells[(activeIndex ?? index).clamp(0, cells.length - 1)].top;
  final before = preview.take(index).whereType<T>().toList();
  final after = preview.skip(index + 1).whereType<T>().toList();
  final left = before.isEmpty ? -1 : slots.indexOf(before.last);
  final right = after.isEmpty ? -1 : slots.indexOf(after.first);
  final row = List.generate(cells.length, (i) => i)
      .where((i) => !cells[i].isEmpty && (cells[i].top - activeRow).abs() < 1)
      .toList();
  final direction =
      row.length > 1 && cells[row.first].center.dx > cells[row.last].center.dx
      ? -1.0
      : 1.0;
  final result = <T, Offset>{};
  for (var i = 0; i < slots.length; i++) {
    final id = slots[i];
    if (id == null || id == dragged || cells[i].isEmpty) continue;
    if ((cells[i].top - activeRow).abs() >= 1) {
      result[id] = Offset.zero;
      continue;
    }
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

/// Badges belong to the portrait, not its stationary drop target.
class ReorderAvatarUnit extends StatelessWidget {
  const ReorderAvatarUnit({
    required this.size,
    required this.child,
    this.number,
    this.menu,
    super.key,
  });
  final double size;
  final Widget child;
  final int? number;
  final Widget? menu;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: size,
    child: Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        if (number != null)
          Positioned(
            top: 0,
            left: 8,
            child: IgnorePointer(
              child: Container(
                key: const ValueKey('avatar-number'),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: CourtSceneTokens.panel,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$number',
                  style: const TextStyle(
                    fontSize: 12,
                    color: CourtSceneTokens.gold,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        if (menu != null) Positioned(top: -8, right: -8, child: menu!),
      ],
    ),
  );
}

/// Row gaps are insertion boundaries, rather than the nearest column's center.
({int cell, int index})? reorderBetweenRows({
  required List<Rect> cells,
  required Offset pointer,
  required int source,
}) {
  final rows = <double, List<int>>{};
  for (var i = 0; i < cells.length; i++) {
    if (!cells[i].isEmpty) rows.putIfAbsent(cells[i].top, () => []).add(i);
  }
  final tops = rows.keys.toList()..sort();
  for (var row = 0; row < tops.length - 1; row++) {
    final current = rows[tops[row]]!;
    final bottom = current
        .map((i) => cells[i].bottom)
        .reduce((a, b) => a > b ? a : b);
    final nextTop = tops[row + 1];
    if (pointer.dy < bottom - 8 || pointer.dy > nextTop + 8) continue;
    final next = rows[nextTop]!;
    final boundary = next.reduce((a, b) => a < b ? a : b);
    return (
      cell: boundary,
      index: (boundary - (source >= 0 && source < boundary ? 1 : 0)).clamp(
        0,
        cells.length - 1,
      ),
    );
  }
  return null;
}

int? nearestReorderCell(List<Rect> cells, Offset pointer) {
  int? nearest;
  var best = double.infinity;
  for (var i = 0; i < cells.length; i++) {
    final rect = cells[i];
    if (rect.isEmpty) continue;
    final dx = pointer.dx - pointer.dx.clamp(rect.left, rect.right);
    final dy = pointer.dy - pointer.dy.clamp(rect.top, rect.bottom);
    final distance = dx * dx + dy * dy;
    if (distance < best) {
      best = distance;
      nearest = i;
    }
  }
  return nearest;
}
