import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/semantics.dart';

import '../../design/avatar_view.dart';
import '../../design/drag_preview_slide.dart';
import '../../design/pending_order_avatar.dart';
import '../../l10n/app_strings.dart';
import '../../design/court_theme.dart';
import '../../design/court_scene.dart';
import '../../domain/bench_order.dart';
import '../../domain/models/ids.dart';
import '../../domain/user_profile.dart';

class BenchView extends StatefulWidget {
  const BenchView({
    required this.order,
    required this.profiles,
    this.onMove,
    this.compactControls = false,
    this.actionsBuilder,
    this.revealedNumbers = const {},
    this.incorrect = const {},
    this.pending = const {},
    this.showPositionResult = true,
    super.key,
  });
  final bool compactControls;
  final List<PlayerId> order;
  final Map<PlayerId, UserProfile> profiles;
  final void Function(int from, int to)? onMove;
  final Widget Function(BuildContext context, UserProfile profile, int index)?
  actionsBuilder;
  final Map<PlayerId, int> revealedNumbers;
  final Set<PlayerId> incorrect;
  final Set<PlayerId> pending;
  final bool showPositionResult;
  @override
  State<BenchView> createState() => _BenchViewState();
}

class _BenchViewState extends State<BenchView> {
  final _scroll = ScrollController();
  final _focus = <PlayerId, FocusNode>{};
  PlayerId? _selected, _focused, _dragged;
  int? _hoverIndex, _hoverCell, _previewCell;
  int _previewEpoch = 0;
  bool _settling = false;
  final _anchors = <PlayerId, GlobalKey>{};
  Map<PlayerId, Offset> _previewOffsets = {};
  Map<PlayerId, Offset> _halfOffsets = {};
  Offset? _pointer;

  int _insertion(PlayerId id, int hovered) {
    final rect = reorderCellRect(_anchors[widget.order[hovered]]);
    if (rect == null) return hovered;
    final cells = widget.order
        .map((id) => reorderCellRect(_anchors[id]) ?? Rect.zero)
        .toList();
    final between = _pointer == null
        ? null
        : reorderBetweenRows(
            cells: cells,
            pointer: _pointer!,
            source: widget.order.indexOf(id),
          );
    _hoverCell = between?.cell ?? hovered;
    if (between != null) return between.index;
    final row = widget.order
        .map((id) => reorderCellRect(_anchors[id]))
        .whereType<Rect>()
        .where((r) => (r.top - rect.top).abs() < 1)
        .toList();
    return reorderInsertionIndex(
      reversed: row.length > 1 && row.first.center.dx > row.last.center.dx,
      source: widget.order.indexOf(id),
      hovered: hovered,
      cell: rect,
      pointer: _pointer ?? rect.center,
      count: widget.order.length,
    );
  }

  void _dragUpdate(PlayerId id, DragUpdateDetails details) {
    _pointer = (_pointer ?? details.globalPosition) + details.delta;
    _edgeScroll(_pointer!);
    final nearest = nearestReorderCell(
      widget.order
          .map((id) => reorderCellRect(_anchors[id]) ?? Rect.zero)
          .toList(),
      _pointer!,
    );
    if (nearest != null) _hover(id, _insertion(id, nearest));
  }

  void _hover(PlayerId id, int index) {
    if (_dragged == id && _hoverIndex == index && _previewCell == _hoverCell) {
      return;
    }
    final from = widget.order.indexOf(id);
    if (widget.onMove == null || from < 0) return;
    final preview = insertPlayer(widget.order, from, index);
    final offsets = <PlayerId, Offset>{};
    for (final person in widget.order) {
      final source =
          _anchors[person]?.currentContext?.findRenderObject() as RenderBox?;
      final targetId = widget.order[preview.indexOf(person)];
      final target =
          _anchors[targetId]?.currentContext?.findRenderObject() as RenderBox?;
      if (source?.hasSize == true && target?.hasSize == true) {
        offsets[person] =
            target!.localToGlobal(Offset.zero) -
            source!.localToGlobal(Offset.zero);
      }
    }
    setState(() {
      _dragged = id;
      _hoverIndex = index;
      _previewCell = _hoverCell;
      _previewOffsets = offsets;
      _halfOffsets = halfReorderGap<PlayerId>(
        slots: widget.order,
        preview: preview,
        dragged: id,
        avatarWidth: 76,
        activeIndex: _hoverCell,
        cells: widget.order
            .map((id) => reorderCellRect(_anchors[id]) ?? Rect.zero)
            .toList(),
      );
    });
  }

  void _endPreview() {
    if (!mounted || _settling) return;
    setState(() {
      _dragged = null;
      _hoverIndex = null;
      _previewOffsets = {};
      _halfOffsets = {};
      _pointer = null;
    });
  }

  @override
  void didUpdateWidget(BenchView oldWidget) {
    super.didUpdateWidget(oldWidget);
    _anchors.removeWhere((id, _) => !widget.order.contains(id));
    if (!widget.order.contains(_selected)) _selected = null;
    if (widget.onMove == null || !widget.order.contains(_dragged)) {
      _dragged = null;
      _hoverIndex = null;
      _previewOffsets = {};
      _halfOffsets = {};
      _pointer = null;
    }
    for (final id
        in _focus.keys.where((id) => !widget.order.contains(id)).toList()) {
      _focus.remove(id)!.dispose();
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    for (final node in _focus.values) {
      node.dispose();
    }
    super.dispose();
  }

  void _tap(PlayerId id) {
    if (widget.onMove == null) return;
    if (_selected == null) {
      setState(() => _selected = id);
      return;
    }
    final from = widget.order.indexOf(_selected!);
    final to = widget.order.indexOf(id);
    setState(() => _selected = null);
    if (from >= 0 && from != to) {
      _move(id: widget.order[from], from: from, to: to);
    }
  }

  void _move({required PlayerId id, required int from, required int to}) {
    widget.onMove?.call(from, to);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus[id]?.requestFocus();
    });
  }

  void _edgeScroll(Offset global) {
    if (!_scroll.hasClients) return;
    final box = context.findRenderObject() as RenderBox;
    final y = box.globalToLocal(global).dy;
    final step = y < 48
        ? -24.0
        : y > box.size.height - 48
        ? 24.0
        : 0.0;
    if (step != 0) {
      _scroll.jumpTo(
        (_scroll.offset + step).clamp(0, _scroll.position.maxScrollExtent),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Listener(
    onPointerDown: (event) => _pointer = event.position,
    child: DragTarget<PlayerId>(
      onMove: (details) => _edgeScroll(details.offset),
      onWillAcceptWithDetails: (details) =>
          !_settling &&
          widget.onMove != null &&
          widget.order.contains(details.data),
      onAcceptWithDetails: (details) => _acceptDrop(details, _hoverIndex ?? 0),
      builder: (context, candidates, rejected) => Theme(
        data: courtPaperTheme(),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final columns = widget.compactControls
                ? (constraints.maxWidth >= 480 &&
                          MediaQuery.textScalerOf(context).scale(16) <= 24
                      ? 3
                      : 2)
                : CourtTokens.bankColumns(
                    constraints.maxWidth,
                    MediaQuery.textScalerOf(context).scale(16) / 16,
                  );
            final rows = (widget.order.length + columns - 1) ~/ columns;
            int tileIndex(int row, int col) => widget.compactControls
                ? row * columns + col
                : snakeIndex(row, col, columns);
            return ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: widget.compactControls
                    ? 0
                    : MediaQuery.sizeOf(context).height * .62,
                maxHeight: MediaQuery.sizeOf(context).height * .62,
              ),
              child: Scrollbar(
                controller: _scroll,
                thumbVisibility: true,
                child: SingleChildScrollView(
                  controller: _scroll,
                  child: Column(
                    children: [
                      for (var row = 0; row < rows; row++)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Semantics(
                                excludeSemantics: true,
                                label: context.tr('benchRowDirection', {
                                  'from': row * columns + 1,
                                  'to': (row * columns + columns).clamp(
                                    1,
                                    widget.order.length,
                                  ),
                                }),
                                child: ColoredBox(
                                  color: CourtTokens.wood,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 4,
                                    ),
                                    child: Text(
                                      [
                                        for (var col = 0; col < columns; col++)
                                          if (tileIndex(row, col) <
                                              widget.order.length)
                                            '${tileIndex(row, col) + 1}',
                                      ].join(
                                        widget.compactControls || row.isEven
                                            ? ' → '
                                            : ' ← ',
                                      ),
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        color: CourtSceneTokens.cream,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  for (var col = 0; col < columns; col++)
                                    Expanded(
                                      child:
                                          tileIndex(row, col) <
                                              widget.order.length
                                          ? _tile(tileIndex(row, col))
                                          : const SizedBox.shrink(),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Container(
                                height: 8,
                                decoration: BoxDecoration(
                                  color: CourtTokens.wood,
                                  border: Border.all(
                                    color: CourtSceneTokens.gold,
                                  ),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    ),
  );

  Future<void> _acceptDrop(
    DragTargetDetails<PlayerId> details,
    int index,
  ) async {
    final from = widget.order.indexOf(details.data);
    if (from < 0 || widget.onMove == null || _settling) return;
    final destination = _hoverIndex ?? _insertion(details.data, index);
    final moving = widget.profiles[details.data]!;
    final original = List<PlayerId>.of(widget.order);
    setState(() => _settling = true);
    const size = 76.0;
    await landReorderAvatar(
      context: context,
      target: _anchors[widget.order[destination]]!,
      from: details.offset,
      size: Size(
        size,
        size *
            TrinkAvatarRenderer.visibleHeight /
            TrinkAvatarRenderer.canvasWidth,
      ),
      child: _avatarUnit(
        moving,
        destination,
        withHandle: widget.compactControls,
      ),
      alignment: Alignment.topCenter,
      inset: Offset(
        0,
        widget.compactControls
            ? 4 +
                  (112 -
                          size *
                              TrinkAvatarRenderer.visibleHeight /
                              TrinkAvatarRenderer.canvasWidth) /
                      2
            : 8,
      ),
    );
    if (mounted) {
      if (widget.onMove != null &&
          sameReorderOrder(original, widget.order) &&
          from >= 0 &&
          from != destination) {
        _move(id: details.data, from: from, to: destination);
      }
      _previewEpoch++;
      _selected = null;
      _settling = false;
      _endPreview();
    }
  }

  Widget _tile(int index) {
    final id = widget.order[index];
    final profile = widget.profiles[id]!;
    final editable = widget.onMove != null;
    return Semantics(
      key: _anchors.putIfAbsent(id, GlobalKey.new),
      sortKey: OrdinalSortKey(index.toDouble()),
      child: DragTarget<PlayerId>(
        key: ValueKey(id),
        onWillAcceptWithDetails: (details) {
          if (_settling || !editable || !widget.order.contains(details.data)) {
            return false;
          }
          _hover(details.data, _insertion(details.data, index));
          return true;
        },
        onMove: (details) {
          _edgeScroll(details.offset);
          _hover(details.data, _insertion(details.data, index));
        },
        onAcceptWithDetails: (details) => _acceptDrop(details, index),
        builder: (context, candidates, rejected) => DragPreviewSlide(
          key: ValueKey(('bench-preview', id, _previewEpoch)),
          offset:
              (_settling || id == _dragged
                  ? _previewOffsets[id]
                  : _halfOffsets[id]) ??
              Offset.zero,
          ghost: _dragged == id,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Focus(
              focusNode: editable
                  ? _focus.putIfAbsent(
                      id,
                      () => FocusNode(debugLabel: 'bench-${id.value}'),
                    )
                  : null,
              canRequestFocus: editable,
              onFocusChange: (focused) {
                if (mounted) {
                  setState(() {
                    if (focused) {
                      _focused = id;
                    } else if (_focused == id) {
                      _focused = null;
                    }
                  });
                }
              },
              onKeyEvent: (node, event) {
                if (!editable ||
                    event is! KeyDownEvent ||
                    !HardwareKeyboard.instance.isAltPressed) {
                  return KeyEventResult.ignored;
                }
                final delta =
                    event.logicalKey ==
                        (widget.compactControls
                            ? LogicalKeyboardKey.arrowLeft
                            : LogicalKeyboardKey.arrowUp)
                    ? -1
                    : event.logicalKey ==
                          (widget.compactControls
                              ? LogicalKeyboardKey.arrowRight
                              : LogicalKeyboardKey.arrowDown)
                    ? 1
                    : 0;
                if (delta == 0 ||
                    index + delta < 0 ||
                    index + delta >= widget.order.length) {
                  return KeyEventResult.ignored;
                }
                _move(id: id, from: index, to: index + delta);
                return KeyEventResult.handled;
              },
              child: Padding(
                padding: EdgeInsets.all(widget.compactControls ? 4 : 8),
                child: Column(
                  children: [
                    InkWell(
                      onTap: editable ? () => _tap(id) : null,
                      child: Column(
                        children: [
                          if (widget.compactControls)
                            _compactPortrait(profile, index, id, editable)
                          else
                            _avatarUnit(profile, index),
                        ],
                      ),
                    ),
                    if (widget.revealedNumbers.containsKey(id))
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Semantics(
                          label: context.tr(
                            widget.showPositionResult
                                ? widget.incorrect.contains(id)
                                      ? 'wrongPosition'
                                      : 'rightPosition'
                                : 'revealedNumber',
                            {'number': widget.revealedNumbers[id]},
                          ),
                          child: ExcludeSemantics(
                            child: Wrap(
                              alignment: WrapAlignment.center,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 6,
                              children: [
                                Text(
                                  '${widget.revealedNumbers[id]}',
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w700,
                                    color: CourtSceneTokens.cream,
                                  ),
                                ),
                                if (widget.showPositionResult)
                                  Icon(
                                    widget.incorrect.contains(id)
                                        ? Icons.cancel
                                        : Icons.check_circle,
                                    size: 22,
                                    color: widget.incorrect.contains(id)
                                        ? const Color(0xFFFFA69D)
                                        : const Color(0xFFA8DBA8),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    if (widget.actionsBuilder != null)
                      widget.actionsBuilder!(context, profile, index),
                    if (editable && !widget.compactControls) ...[
                      LongPressDraggable<PlayerId>(
                        data: id,
                        maxSimultaneousDrags: _settling ? 0 : 1,
                        onDragStarted: () {
                          _hoverCell = index;
                          _hover(id, index);
                        },
                        onDragUpdate: (details) => _dragUpdate(id, details),
                        onDragEnd: (_) => _endPreview(),
                        feedback: LiftedDragAvatar(
                          child: _avatarUnit(profile, index),
                        ),
                        child: const Padding(
                          padding: EdgeInsets.all(12),
                          child: Icon(Icons.drag_indicator),
                        ),
                      ),
                      Wrap(
                        alignment: WrapAlignment.center,
                        children: [
                          IconButton(
                            tooltip: context.tr('moveForward', {
                              'position': index + 1,
                            }),
                            onPressed: index > 0
                                ? () =>
                                      _move(id: id, from: index, to: index - 1)
                                : null,
                            icon: const Icon(Icons.arrow_upward),
                          ),
                          IconButton(
                            tooltip: context.tr('moveBack', {
                              'position': index + 1,
                            }),
                            onPressed: index < widget.order.length - 1
                                ? () =>
                                      _move(id: id, from: index, to: index + 1)
                                : null,
                            icon: const Icon(Icons.arrow_downward),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _avatarUnit(
    UserProfile profile,
    int index, {
    bool withHandle = false,
  }) => ReorderAvatarUnit(
    size: 76,
    number: index + 1,
    menu: withHandle
        ? const SizedBox.square(
            dimension: 48,
            child: Icon(Icons.drag_indicator, size: 18),
          )
        : null,
    child: PendingOrderAvatar(
      pending: widget.pending.contains(profile.player.id),
      child: AvatarView(
        showBackdrop: false,
        config: profile.avatar,
        size: 76,
        label: profile.player.name,
        playerName: profile.player.name,
      ),
    ),
  );

  Widget _compactPortrait(
    UserProfile profile,
    int index,
    PlayerId id,
    bool editable,
  ) => SizedBox(
    width: 76,
    height: 112,
    child: Stack(
      alignment: Alignment.center,
      children: [
        _avatarUnit(profile, index),
        if (editable) ...[
          Positioned(
            top: 0,
            right: 0,
            child: Tooltip(
              message: context.tr('roomDragPlayer', {
                'name': profile.player.name,
              }),
              child: LongPressDraggable<PlayerId>(
                key: ValueKey('compact-drag-${id.value}'),
                data: id,
                maxSimultaneousDrags: _settling ? 0 : 1,
                onDragStarted: () {
                  _hoverCell = index;
                  _hover(id, index);
                },
                onDragUpdate: (details) => _dragUpdate(id, details),
                onDragEnd: (_) => _endPreview(),
                feedback: LiftedDragAvatar(
                  child: _avatarUnit(profile, index, withHandle: true),
                ),
                child: SizedBox.square(
                  dimension: 48,
                  child: Center(
                    child: DecoratedBox(
                      decoration: const BoxDecoration(
                        color: CourtTokens.file,
                        shape: BoxShape.circle,
                      ),
                      child: const Padding(
                        padding: EdgeInsets.all(4),
                        child: Icon(Icons.drag_indicator, size: 18),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(bottom: 0, left: 0, child: _floatingMove(id, index, -1)),
          Positioned(bottom: 0, right: 0, child: _floatingMove(id, index, 1)),
        ],
      ],
    ),
  );
  Widget _floatingMove(PlayerId id, int index, int delta) => IconButton(
    key: ValueKey('compact-move-${delta < 0 ? 'left' : 'right'}-${id.value}'),
    tooltip: context.tr(delta < 0 ? 'roomMoveLeft' : 'roomMoveRight', {
      'position': index + 1,
    }),
    onPressed: index + delta >= 0 && index + delta < widget.order.length
        ? () => _move(id: id, from: index, to: index + delta)
        : null,
    icon: DecoratedBox(
      decoration: const BoxDecoration(
        color: CourtTokens.file,
        shape: BoxShape.circle,
      ),
      child: Padding(
        padding: const EdgeInsets.all(3),
        child: Icon(delta < 0 ? Icons.arrow_left : Icons.arrow_right, size: 22),
      ),
    ),
  );
}
