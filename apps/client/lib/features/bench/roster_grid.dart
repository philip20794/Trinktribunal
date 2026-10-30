import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../design/avatar_view.dart';
import '../../design/seat_hint.dart';
import '../../design/drag_preview_slide.dart';
import '../../domain/bench_order.dart';
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
  int? _hoverIndex, _hoverCell, _previewCell;
  int _previewEpoch = 0;
  bool _settling = false;
  final _targets = <PlayerId, GlobalKey>{};

  List<PlayerId> get _preview {
    final ids = widget.members.map((p) => p.player.id).toList();
    final from = _dragged == null ? -1 : ids.indexOf(_dragged!);
    return from >= 0 && _hoverIndex != null
        ? insertPlayer(ids, from, _hoverIndex!)
        : ids;
  }

  void _hover(PlayerId id, int index) {
    if (_dragged == id && _hoverIndex == index && _previewCell == _hoverCell) {
      return;
    }
    setState(() {
      _dragged = id;
      _hoverIndex = index;
      _previewCell = _hoverCell;
    });
  }

  Offset? _pointer;
  int _insertion(PlayerId id, int hovered) {
    final rect = reorderCellRect(_targets[widget.members[hovered].player.id]);
    if (rect == null) return hovered;
    final cells = widget.members
        .map((p) => reorderCellRect(_targets[p.player.id]) ?? Rect.zero)
        .toList();
    final between = _pointer == null
        ? null
        : reorderBetweenRows(
            cells: cells,
            pointer: _pointer!,
            source: widget.members.indexWhere((p) => p.player.id == id),
          );
    _hoverCell = between?.cell ?? hovered;
    if (between != null) return between.index;
    return reorderInsertionIndex(
      source: widget.members.indexWhere((p) => p.player.id == id),
      hovered: hovered,
      cell: rect,
      pointer: _pointer ?? rect.center,
      count: widget.members.length,
    );
  }

  void _dragUpdate(PlayerId id, DragUpdateDetails details) {
    _pointer = (_pointer ?? details.globalPosition) + details.delta;
    for (var i = 0; i < widget.members.length; i++) {
      if (reorderCellRect(_targets[widget.members[i].player.id])
              ?.contains(_pointer!) ==
          true) {
        _hover(id, _insertion(id, i));
        break;
      }
    }
  }

  void _clearPreview() {
    if (!mounted || _settling) return;
    setState(() {
      _dragged = null;
      _hoverIndex = null;
      _pointer = null;
    });
  }

  @override
  void didUpdateWidget(RosterGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled ||
        !widget.members.any((p) => p.player.id == _dragged)) {
      _dragged = null;
      _hoverIndex = null;
      _pointer = null;
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
      final strideX = width / columns;
      final strideY = size * ratio + 16;
      final halfGap = _dragged == null
          ? <PlayerId, Offset>{}
          : halfReorderGap<PlayerId>(
              slots: widget.members.map((p) => p.player.id).toList(),
              preview: preview,
              dragged: _dragged!,
              avatarWidth: size,
              activeIndex: _hoverCell,
              cells: List.generate(
                widget.members.length,
                (i) => Rect.fromLTWH(
                  i % columns * strideX,
                  i ~/ columns * strideY,
                  strideX - 4,
                  strideY - 4,
                ),
              ),
            );

      return SliverGrid.builder(
        itemCount: widget.members.length,
        findChildIndexCallback: (key) {
          if (key is! ValueKey<PlayerId>) return null;
          final index = widget.members.indexWhere(
            (p) => p.player.id == key.value,
          );
          return index < 0 ? null : index;
        },
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columns,
          mainAxisExtent: strideY,
          crossAxisSpacing: 0,
          mainAxisSpacing: 0,
        ),
        itemBuilder: (context, index) {
          final member = widget.members[index];
          final id = member.player.id;
          return DragTarget<PlayerId>(
            key: ValueKey(id),
            onWillAcceptWithDetails: (drag) {
              if (_settling ||
                  !widget.enabled ||
                  !widget.members.any((p) => p.player.id == drag.data)) {
                return false;
              }
              _hover(drag.data, _insertion(drag.data, index));
              return true;
            },
            onMove: (drag) => _hover(drag.data, _insertion(drag.data, index)),
            onAcceptWithDetails: (drag) async {
              final destination = _hoverIndex ?? _insertion(drag.data, index);
              final from = widget.members.indexWhere(
                (p) => p.player.id == drag.data,
              );
              if (from < 0 || !widget.enabled || _settling) return;
              final original = widget.members.map((p) => p.player.id).toList();
              final moving = widget.members[from];
              setState(() => _settling = true);
              await landReorderAvatar(
                context: context,
                target: _targets[widget.members[destination].player.id]!,
                from: drag.offset,
                size: Size(size, size * ratio),
                child: _unit(moving, destination, size),
              );
              if (mounted) {
                if (widget.enabled &&
                    sameReorderOrder(
                      original,
                      widget.members.map((p) => p.player.id),
                    ) &&
                    from != destination) {
                  widget.onMove(from, destination);
                }
                _previewEpoch++;
                _settling = false;
                _clearPreview();
              }
            },
            builder: (context, candidates, _) => Listener(
              onPointerDown: (event) => _pointer = event.position,
              child: SizedBox.expand(
                key: _targets.putIfAbsent(id, GlobalKey.new),
                child: Stack(
                  children: [
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: SeatHint(number: index + 1),
                    ),
                    Center(
                      child: DragPreviewSlide(
                        key: ValueKey(('roster-preview', id)),
                        resetToken: _previewEpoch,
                        offset: !_settling && _dragged != id
                            ? (halfGap[id] ?? Offset.zero)
                            : Offset(
                                (preview.indexOf(id) % columns -
                                        index % columns) *
                                    strideX,
                                (preview.indexOf(id) ~/ columns -
                                        index ~/ columns) *
                                    strideY,
                              ),
                        ghost: _dragged == id,
                        child: LongPressDraggable<PlayerId>(
                          key: ValueKey('roster-drag-${id.value}'),
                          delay: const Duration(milliseconds: 180),
                          data: id,
                          onDragStarted: () {
                            _hoverCell = index;
                            _hover(id, index);
                          },
                          onDragUpdate: (details) => _dragUpdate(id, details),
                          onDragEnd: (_) => _clearPreview(),
                          maxSimultaneousDrags: widget.enabled && !_settling
                              ? 1
                              : 0,
                          feedback: LiftedDragAvatar(
                            child: _unit(member, index, size),
                          ),
                          childWhenDragging: _unit(member, index, size),
                          child: _unit(member, index, size),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    },
  );
  Widget _unit(UserProfile member, int index, double size) => ReorderAvatarUnit(
    size: size,
    menu: PopupMenuButton<String>(
      key: ValueKey('roster-menu-${member.player.id.value}'),
      enabled: widget.enabled,
      tooltip: context.tr('rosterEditPerson'),
      icon: const Icon(Icons.more_vert, size: 20),
      itemBuilder: (_) => [
        PopupMenuItem(value: 'edit', child: TText('rosterEditPerson')),
        if (!widget.isOwner(member.player.id))
          PopupMenuItem(value: 'remove', child: TText('rosterRemove')),
      ],
      onSelected: (action) => action == 'edit'
          ? widget.onEdit(member)
          : widget.onRemove(member, index),
    ),
    child: InkWell(
      onTap: widget.enabled ? () => widget.onEdit(member) : null,
      child: AvatarView(
        showBackdrop: false,
        config: member.avatar,
        size: size,
        playerName: member.player.name,
        label: member.player.name,
      ),
    ),
  );
}
