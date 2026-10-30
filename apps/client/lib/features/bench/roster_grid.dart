import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../design/avatar_view.dart';
import '../../design/drag_preview_slide.dart';
import '../../domain/bench_order.dart';
import '../../design/court_scene.dart';
import '../../domain/models/ids.dart';
import '../../domain/user_profile.dart';
import '../../l10n/app_strings.dart';

/// The same ordered group for both local modes; scrolling and dragging stay distinct.
class RosterGrid extends StatefulWidget {
  const RosterGrid({
    required this.members,
    required this.onMove,
    required this.onEdit,
    required this.onRemove,
    required this.isOwner,
    this.enabled = true,
    super.key,
  });
  final List<UserProfile> members;
  final void Function(int, int) onMove;
  final ValueChanged<UserProfile> onEdit;
  final void Function(UserProfile, int) onRemove;
  final bool Function(PlayerId) isOwner;
  final bool enabled;

  @override
  State<RosterGrid> createState() => _RosterGridState();
}

class _RosterGridState extends State<RosterGrid> {
  PlayerId? _dragged;
  int? _hoverIndex;
  int _previewEpoch = 0;

  List<PlayerId> get _preview {
    final ids = widget.members.map((p) => p.player.id).toList();
    final from = _dragged == null ? -1 : ids.indexOf(_dragged!);
    return from >= 0 && _hoverIndex != null
        ? insertPlayer(ids, from, _hoverIndex!)
        : ids;
  }

  void _hover(PlayerId id, int index) {
    if (_dragged == id && _hoverIndex == index) return;
    setState(() {
      _dragged = id;
      _hoverIndex = index;
    });
  }

  void _clearPreview() {
    if (!mounted) return;
    setState(() {
      _dragged = null;
      _hoverIndex = null;
    });
  }

  @override
  void didUpdateWidget(RosterGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled ||
        !widget.members.any((p) => p.player.id == _dragged)) {
      _dragged = null;
      _hoverIndex = null;
    }
  }

  @override
  Widget build(BuildContext context) => SliverLayoutBuilder(
    builder: (context, area) {
      final width = area.crossAxisExtent;
      const ratio =
          TrinkAvatarRenderer.visibleHeight / TrinkAvatarRenderer.canvasWidth;
      final height = math.max(100.0, area.remainingPaintExtent);
      var columns = 1,
          size = 56.0,
          bestOverflow = double.infinity,
          bestComfort = 0.0;
      var bestRows = widget.members.length + 1;
      for (
        var candidate = 1;
        candidate <=
            math.min(widget.members.length, (width / 76).floor().clamp(1, 5));
        candidate++
      ) {
        final rows = (widget.members.length / candidate).ceil();
        final proposed = math.min(
          128.0,
          math.min(
            width / candidate - 12,
            math.max(56.0, (height / rows - 12) / ratio),
          ),
        );
        final overflow = math.max(0.0, rows * (proposed * ratio + 12) - height);
        final comfort = math.min(proposed, 100.0);
        if (overflow < bestOverflow - .1 ||
            (overflow - bestOverflow).abs() < .1 &&
                (comfort > bestComfort ||
                    (comfort - bestComfort).abs() < .1 && rows < bestRows)) {
          columns = candidate;
          size = proposed;
          bestOverflow = overflow;
          bestComfort = comfort;
          bestRows = rows;
        }
      }
      final preview = _preview;
      final strideX = (width + 4) / columns;
      final strideY = size * ratio + 16;
      return SliverGrid.builder(
        itemCount: widget.members.length,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columns,
          mainAxisExtent: size * ratio + 12,
          crossAxisSpacing: 4,
          mainAxisSpacing: 4,
        ),
        itemBuilder: (context, index) {
          final member = widget.members[index];
          Widget portrait() => AvatarView(
            showBackdrop: false,
            config: member.avatar,
            size: size,
            playerName: member.player.name,
            label: member.player.name,
          );
          return DragTarget<PlayerId>(
            key: ValueKey(member.player.id),
            onWillAcceptWithDetails: (drag) {
              if (!widget.enabled ||
                  !widget.members.any((p) => p.player.id == drag.data)) {
                return false;
              }
              _hover(drag.data, index);
              return true;
            },
            onMove: (drag) => _hover(drag.data, index),
            onLeave: (_) {
              if (_hoverIndex == index) setState(() => _hoverIndex = null);
            },
            onAcceptWithDetails: (drag) {
              final from = widget.members.indexWhere(
                (p) => p.player.id == drag.data,
              );
              setState(() {
                _previewEpoch++;
                _dragged = null;
                _hoverIndex = null;
              });
              if (from >= 0 && from != index) widget.onMove(from, index);
            },
            builder: (context, candidates, _) => Container(
              decoration: BoxDecoration(
                color: CourtSceneTokens.panel.withValues(alpha: .6),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: candidates.isEmpty
                      ? CourtSceneTokens.gold.withValues(alpha: .4)
                      : CourtSceneTokens.gold,
                ),
              ),
              child: Stack(
                clipBehavior: Clip.none,
                fit: StackFit.expand,
                children: [
                  Center(
                    child: DragPreviewSlide(
                      key: ValueKey((
                        'roster-preview',
                        member.player.id,
                        _previewEpoch,
                      )),
                      offset: Offset(
                        (preview.indexOf(member.player.id) % columns -
                                index % columns) *
                            strideX,
                        (preview.indexOf(member.player.id) ~/ columns -
                                index ~/ columns) *
                            strideY,
                      ),
                      ghost: _dragged == member.player.id,
                      child: LongPressDraggable<PlayerId>(
                        key: ValueKey('roster-drag-${member.player.id.value}'),
                        delay: const Duration(milliseconds: 180),
                        data: member.player.id,
                        onDragStarted: () => _hover(member.player.id, index),
                        onDragEnd: (_) => _clearPreview(),
                        maxSimultaneousDrags: widget.enabled ? 1 : 0,
                        feedback: Material(
                          color: Colors.transparent,
                          child: portrait(),
                        ),
                        childWhenDragging: portrait(),
                        child: InkWell(
                          onTap: widget.enabled
                              ? () => widget.onEdit(member)
                              : null,
                          child: portrait(),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 3,
                    left: 3,
                    child: IgnorePointer(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: CourtSceneTokens.panel,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${index + 1}',
                          style: const TextStyle(
                            color: CourtSceneTokens.gold,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 0,
                    right: 0,
                    child: PopupMenuButton<String>(
                      key: ValueKey('roster-menu-${member.player.id.value}'),
                      enabled: widget.enabled,
                      tooltip: context.tr('rosterEditPerson'),
                      icon: const Icon(Icons.more_vert, size: 20),
                      itemBuilder: (_) => [
                        PopupMenuItem(
                          value: 'edit',
                          child: TText('rosterEditPerson'),
                        ),
                        if (!widget.isOwner(member.player.id))
                          PopupMenuItem(
                            value: 'remove',
                            child: TText('rosterRemove'),
                          ),
                      ],
                      onSelected: (action) => action == 'edit'
                          ? widget.onEdit(member)
                          : widget.onRemove(member, index),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}
