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
  int? _hoverIndex;
  int _previewEpoch = 0;
  final _anchors = <PlayerId, GlobalKey>{};
  Map<PlayerId, Offset> _previewOffsets = {};

  void _hover(PlayerId id, int index) {
    if (_dragged == id && _hoverIndex == index) return;
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
      _previewOffsets = offsets;
    });
  }

  void _endPreview() {
    if (!mounted) return;
    setState(() {
      _dragged = null;
      _hoverIndex = null;
      _previewOffsets = {};
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
  Widget build(BuildContext context) => Theme(
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
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 4,
                                    ),
                                    child:
                                        tileIndex(row, col) <
                                            widget.order.length
                                        ? _tile(tileIndex(row, col))
                                        : const SizedBox.shrink(),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Container(
                            height: 8,
                            decoration: BoxDecoration(
                              color: CourtTokens.wood,
                              border: Border.all(color: CourtSceneTokens.gold),
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
  );

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
          if (!editable || !widget.order.contains(details.data)) return false;
          _hover(details.data, index);
          return true;
        },
        onMove: (details) {
          _edgeScroll(details.offset);
          _hover(details.data, index);
        },
        onLeave: (_) {
          if (_hoverIndex == index) {
            setState(() {
              _hoverIndex = null;
              _previewOffsets = {};
            });
          }
        },
        onAcceptWithDetails: (details) {
          final from = widget.order.indexOf(details.data);
          setState(() {
            _selected = null;
            _previewEpoch++;
            _dragged = null;
            _hoverIndex = null;
            _previewOffsets = {};
          });
          if (from >= 0 && from != index) {
            _move(id: details.data, from: from, to: index);
          }
        },
        builder: (context, candidates, rejected) => DragPreviewSlide(
          key: ValueKey(('bench-preview', id, _previewEpoch)),
          offset: _previewOffsets[id] ?? Offset.zero,
          ghost: _dragged == id,
          originGhost: AvatarView(
            config: profile.avatar,
            size: widget.compactControls ? 64 : 76,
            playerName: profile.player.name,
            showBackdrop: false,
          ),
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
            child: AnimatedContainer(
              duration: CourtTokens.motionDuration(
                MediaQuery.disableAnimationsOf(context),
              ),
              padding: EdgeInsets.all(widget.compactControls ? 4 : 8),
              decoration: BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color:
                      candidates.isNotEmpty || _selected == id || _focused == id
                      ? CourtTokens.red
                      : Colors.transparent,
                  width:
                      candidates.isNotEmpty || _selected == id || _focused == id
                      ? 3
                      : 1,
                ),
              ),
              child: Column(
                children: [
                  InkWell(
                    onTap: editable ? () => _tap(id) : null,
                    child: Column(
                      children: [
                        if (widget.compactControls)
                          _compactPortrait(profile, index, id, editable)
                        else
                          PendingOrderAvatar(
                            pending: widget.pending.contains(id),
                            child: AvatarView(
                              showBackdrop: false,
                              config: profile.avatar,
                              size: 76,
                              label: profile.player.name,
                              playerName: profile.player.name,
                            ),
                          ),
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
                      onDragStarted: () => _hover(id, index),
                      onDragEnd: (_) => _endPreview(),
                      feedback: Material(
                        color: Colors.transparent,
                        child: AvatarView(
                          config: profile.avatar,
                          size: 96,
                          playerName: profile.player.name,
                          showBackdrop: false,
                        ),
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
                              ? () => _move(id: id, from: index, to: index - 1)
                              : null,
                          icon: const Icon(Icons.arrow_upward),
                        ),
                        IconButton(
                          tooltip: context.tr('moveBack', {
                            'position': index + 1,
                          }),
                          onPressed: index < widget.order.length - 1
                              ? () => _move(id: id, from: index, to: index + 1)
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
    );
  }

  Widget _compactPortrait(
    UserProfile profile,
    int index,
    PlayerId id,
    bool editable,
  ) => SizedBox(
    height: 112,
    child: Stack(
      alignment: Alignment.center,
      children: [
        AvatarView(
          showBackdrop: false,
          config: profile.avatar,
          size: 76,
          label: profile.player.name,
          playerName: profile.player.name,
        ),
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
                onDragStarted: () => _hover(id, index),
                onDragEnd: (_) => _endPreview(),
                feedback: Material(
                  color: Colors.transparent,
                  child: AvatarView(
                    config: profile.avatar,
                    size: 96,
                    playerName: profile.player.name,
                    showBackdrop: false,
                  ),
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
