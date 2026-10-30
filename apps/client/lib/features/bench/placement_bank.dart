import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../design/avatar_view.dart';
import '../../design/drag_preview_slide.dart';
import '../../domain/bench_order.dart';
import '../../design/pending_order_avatar.dart';
import '../../design/court_scene.dart';
import '../../domain/models/ids.dart';
import '../../domain/user_profile.dart';
import '../../l10n/app_strings.dart';

/// Numbered seats with a floating, independently scrollable pool of people.
class PlacementBank extends StatefulWidget {
  const PlacementBank({
    required this.slots,
    required this.unplaced,
    required this.profiles,
    required this.onPlace,
    required this.onRemove,
    this.pending = const {},
    super.key,
  });
  final Set<PlayerId> pending;
  final List<PlayerId?> slots;
  final List<PlayerId> unplaced;
  final Map<PlayerId, UserProfile> profiles;
  final void Function(PlayerId, int)? onPlace;
  final ValueChanged<PlayerId> onRemove;
  static const panelWidth = 56.0, collapsedPanelWidth = 16.0;
  static const minAvatarSize = 48.0, maxAvatarSize = 112.0;
  @override
  State<PlacementBank> createState() => _PlacementBankState();
}

class _PlacementBankState extends State<PlacementBank> {
  final _seatsScroll = ScrollController(), _poolScroll = ScrollController();
  final _surfaceKey = GlobalKey(), _gridKey = GlobalKey();
  PlayerId? _selected, _dragged;
  int? _hoverIndex;
  int _previewEpoch = 0;
  bool _settling = false;
  final _targets = <int, GlobalKey>{};

  List<PlayerId?> get _previewSlots => _dragged != null && _hoverIndex != null
      ? placePlayer(widget.slots, _dragged!, _hoverIndex!)
      : widget.slots;
  void _hover(PlayerId id, int index) {
    if (_dragged == id && _hoverIndex == index) return;
    setState(() {
      _dragged = id;
      _hoverIndex = index;
    });
  }

  Timer? _edgeScroll;
  Offset? _dragPosition;
  bool _dragging = false, _panelOpen = false, _poolHidden = false;

  void _stopDrag() {
    _edgeScroll?.cancel();
    _edgeScroll = null;
    _dragPosition = null;
  }

  void _startDrag(PlayerId id) {
    _stopDrag();
    setState(() {
      _dragging = true;
      _dragged = id;
      final from = widget.slots.indexOf(id);
      _hoverIndex = from < 0 ? null : from;
      _panelOpen = false;
    });
    _edgeScroll = Timer.periodic(
      const Duration(milliseconds: 30),
      (_) => _scrollWhileDragging(),
    );
  }

  void _updateDrag(DragUpdateDetails details) {
    _dragPosition = details.globalPosition;
    final box = _surfaceKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final x = box.globalToLocal(details.globalPosition).dx;
    // A narrow edge opens the drawer; a wider exit threshold prevents flicker.
    final open = x >= box.size.width - (_panelOpen ? 72 : 28);
    if (_panelOpen != open) {
      setState(() {
        _panelOpen = open;
        if (open) _hoverIndex = null;
      });
    }
  }

  void _endDrag(DraggableDetails _) {
    _stopDrag();
    if (!mounted) return;
    if (_settling) return;
    setState(() {
      _dragging = false;
      _dragged = null;
      _hoverIndex = null;
      _panelOpen = false;
    });
  }

  void _scrollWhileDragging() {
    final position = _dragPosition;
    if (position == null) return;
    final controller = _panelOpen ? _poolScroll : _seatsScroll;
    final target = _panelOpen ? _surfaceKey : _gridKey;
    final box = target.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !controller.hasClients) return;
    final local = box.globalToLocal(position);
    final delta = local.dy < 48
        ? -10.0
        : local.dy > box.size.height - 48
        ? 10.0
        : 0.0;
    if (delta == 0) return;
    controller.jumpTo(
      (controller.offset + delta).clamp(
        controller.position.minScrollExtent,
        controller.position.maxScrollExtent,
      ),
    );
  }

  @override
  void didUpdateWidget(PlacementBank oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.profiles.containsKey(_selected)) _selected = null;
    if (widget.onPlace == null) {
      _stopDrag();
      _dragging = false;
      _dragged = null;
      _hoverIndex = null;
      _panelOpen = false;
      _selected = null;
    }
  }

  @override
  void dispose() {
    _stopDrag();
    _seatsScroll.dispose();
    _poolScroll.dispose();
    super.dispose();
  }

  Widget _portrait(PlayerId id, double size) => PendingOrderAvatar(
    pending: widget.pending.contains(id),
    child: AvatarView(
      showBackdrop: false,
      config: widget.profiles[id]!.avatar,
      size: size,
      label: widget.profiles[id]!.player.name,
      playerName: widget.profiles[id]!.player.name,
    ),
  );
  Widget _name(PlayerId id) => Tooltip(
    message: widget.profiles[id]!.player.name,
    child: Text(
      widget.profiles[id]!.player.name,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.center,
      style: const TextStyle(
        fontSize: 12,
        height: 1.2,
        fontWeight: FontWeight.w600,
        color: CourtSceneTokens.cream,
      ),
    ),
  );
  Widget _poolPerson(PlayerId id) => Semantics(
    selected: _selected == id,
    child: InkWell(
      onTap: widget.onPlace == null
          ? null
          : () => setState(() => _selected = id),
      child: Container(
        width: PlacementBank.panelWidth,
        padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 5),
        decoration: BoxDecoration(
          color: _selected == id
              ? CourtSceneTokens.gold.withValues(alpha: .25)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            AvatarHeadView(
              config: widget.profiles[id]!.avatar,
              size: 38,
              label: widget.profiles[id]!.player.name,
            ),
            const SizedBox(height: 3),
            _name(id),
          ],
        ),
      ),
    ),
  );
  Widget _person(PlayerId id, double size, {bool pool = false}) {
    final child = pool ? _poolPerson(id) : _portrait(id, size);
    final feedback = LiftedDragAvatar(
      child: Transform.translate(
        offset: Offset(-size / 2, -size * .65),
        child: _portrait(id, size),
      ),
    );
    // A short hold distinguishes dragging a person from scrolling the pool.
    if (pool) {
      return LongPressDraggable<PlayerId>(
        key: ValueKey('unplaced-${id.value}'),
        data: id,
        delay: const Duration(milliseconds: 180),
        maxSimultaneousDrags: widget.onPlace == null || _settling ? 0 : 1,
        dragAnchorStrategy: pointerDragAnchorStrategy,
        onDragStarted: () => _startDrag(id),
        onDragUpdate: _updateDrag,
        onDragEnd: _endDrag,
        feedback: feedback,
        childWhenDragging: Opacity(opacity: .25, child: child),
        child: child,
      );
    }
    return Draggable<PlayerId>(
      data: id,
      maxSimultaneousDrags: widget.onPlace == null || _settling ? 0 : 1,
      dragAnchorStrategy: pointerDragAnchorStrategy,
      onDragStarted: () => _startDrag(id),
      onDragUpdate: _updateDrag,
      onDragEnd: _endDrag,
      feedback: feedback,
      childWhenDragging: child,
      child: InkWell(
        onTap: widget.onPlace == null
            ? null
            : () => setState(() => _selected = id),
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, bounds) {
      final height = bounds.hasBoundedHeight
          ? bounds.maxHeight
          : MediaQuery.sizeOf(context).height * .65;
      final width = bounds.maxWidth;
      const chrome = 12.0;
      const ratio =
          TrinkAvatarRenderer.visibleHeight / TrinkAvatarRenderer.canvasWidth;
      final minCell = math.max(
        64.0,
        MediaQuery.textScalerOf(context).scale(12) * 5,
      );
      final maxColumns = math.min(
        math.max(1, widget.slots.length),
        (width / minCell).floor().clamp(1, 5),
      );
      var columns = 1, bestRows = widget.slots.length + 1;
      var avatarSize = PlacementBank.minAvatarSize;
      var bestOverflow = double.infinity, bestComfort = 0.0;
      for (var candidate = 1; candidate <= maxColumns; candidate++) {
        final rows = math.max(1, (widget.slots.length / candidate).ceil());
        final size = math
            .min(
              math.min(PlacementBank.maxAvatarSize, width / candidate - 16),
              math.max(
                PlacementBank.minAvatarSize,
                (height / rows - chrome) / ratio,
              ),
            )
            .clamp(0.0, PlacementBank.maxAvatarSize);
        final overflow = math.max(0.0, rows * (size * ratio + chrome) - height);
        final comfort = math.min(size, 88.0);
        if (overflow < bestOverflow - .01 ||
            ((overflow - bestOverflow).abs() < .01 &&
                (comfort > bestComfort + .01 ||
                    ((comfort - bestComfort).abs() < .01 &&
                        (rows < bestRows ||
                            rows == bestRows && size > avatarSize))))) {
          columns = candidate;
          avatarSize = size;
          bestOverflow = overflow;
          bestComfort = comfort;
          bestRows = rows;
        }
      }
      final unplaced = List<PlayerId>.of(widget.unplaced)
        ..sort((a, b) {
          final result = widget.profiles[a]!.player.name
              .toLowerCase()
              .compareTo(widget.profiles[b]!.player.name.toLowerCase());
          return result == 0 ? a.value.compareTo(b.value) : result;
        });
      final collapsed =
          (_dragging || unplaced.isEmpty || _poolHidden) && !_panelOpen;
      final duration = MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 180);
      return SizedBox(
        key: _surfaceKey,
        height: height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fill(
              child: Scrollbar(
                controller: _seatsScroll,
                child: GridView.builder(
                  key: _gridKey,
                  controller: _seatsScroll,
                  padding: EdgeInsets.zero,
                  itemCount: widget.slots.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    mainAxisExtent: avatarSize * ratio + chrome,
                    crossAxisSpacing: 4,
                  ),
                  itemBuilder: (context, index) => _seat(
                    context,
                    index,
                    avatarSize,
                    columns,
                    (width + 4) / columns,
                    avatarSize * ratio + chrome,
                  ),
                ),
              ),
            ),
            Positioned(
              right: 0,
              top: 4,
              bottom: 4,
              child: DragTarget<PlayerId>(
                key: const ValueKey('unplaced-return-target'),
                onWillAcceptWithDetails: (details) =>
                    widget.onPlace != null &&
                    widget.profiles.containsKey(details.data),
                onAcceptWithDetails: (details) {
                  widget.onRemove(details.data);
                  setState(() => _selected = null);
                },
                builder: (context, candidates, rejected) => AnimatedOpacity(
                  key: const ValueKey('placement-pool-opacity'),
                  duration: duration,
                  opacity: collapsed ? .2 : 1,
                  child: AnimatedContainer(
                    key: const ValueKey('placement-pool-panel'),
                    duration: duration,
                    curve: Curves.easeOutCubic,
                    width: collapsed
                        ? PlacementBank.collapsedPanelWidth
                        : PlacementBank.panelWidth,
                    decoration: BoxDecoration(
                      color: CourtSceneTokens.panel,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: candidates.isNotEmpty || _selected != null
                            ? CourtSceneTokens.gold
                            : CourtSceneTokens.gold.withValues(alpha: .45),
                      ),
                      boxShadow: const [
                        BoxShadow(color: Colors.black38, blurRadius: 10),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: OverflowBox(
                        alignment: Alignment.topRight,
                        minWidth: PlacementBank.panelWidth - 2,
                        maxWidth: PlacementBank.panelWidth - 2,
                        child: InkWell(
                          onTap: _selected != null && widget.onPlace != null
                              ? () {
                                  widget.onRemove(_selected!);
                                  setState(() => _selected = null);
                                }
                              : null,
                          child: Column(
                            children: [
                              const SizedBox(
                                height: 24,
                                child: Icon(
                                  Icons.people_outline,
                                  size: 18,
                                  color: CourtSceneTokens.gold,
                                ),
                              ),
                              Expanded(
                                child: Scrollbar(
                                  controller: _poolScroll,
                                  thumbVisibility: true,
                                  child: ListView(
                                    key: const ValueKey('placement-pool-list'),
                                    controller: _poolScroll,
                                    padding: EdgeInsets.zero,
                                    children: [
                                      for (final id in unplaced)
                                        _person(id, avatarSize, pool: true),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 4,
              right: 0,
              child: Semantics(
                button: true,
                label: context.tr('placementPoolToggle'),
                child: GestureDetector(
                  key: const ValueKey('placement-pool-toggle'),
                  behavior: HitTestBehavior.opaque,
                  onTap: () => setState(() => _poolHidden = !_poolHidden),
                  child: SizedBox(
                    width: collapsed
                        ? PlacementBank.collapsedPanelWidth
                        : PlacementBank.panelWidth,
                    height: 24,
                    child: Icon(
                      collapsed ? Icons.chevron_left : Icons.chevron_right,
                      color: CourtSceneTokens.gold,
                      size: 20,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
  Widget _seatPerson(
    int index,
    double size,
    int columns,
    double strideX,
    double strideY,
  ) {
    final preview = _previewSlots;
    var id = widget.slots[index];
    var ghost = false;
    if (id == null &&
        _dragged != null &&
        !widget.slots.contains(_dragged) &&
        _hoverIndex != null) {
      final vacant = widget.slots.indexOf(null, _hoverIndex!);
      final ghostSource = vacant >= 0 ? vacant : widget.slots.lastIndexOf(null);
      if (index == ghostSource) {
        id = _dragged;
        ghost = true;
      }
    }
    if (id == null) {
      return const Icon(Icons.person_outline, color: CourtSceneTokens.gold);
    }
    final target = preview.indexOf(id);
    if (target < 0) return const SizedBox.shrink();
    return DragPreviewSlide(
      key: ValueKey(('seat-preview', id, _previewEpoch)),
      offset: Offset(
        (target % columns - index % columns) * strideX,
        (target ~/ columns - index ~/ columns) * strideY,
      ),
      ghost: ghost || id == _dragged,
      child: ghost
          ? IgnorePointer(child: _portrait(id, size))
          : _person(id, size),
    );
  }

  Widget _seat(
    BuildContext context,
    int index,
    double avatarSize,
    int columns,
    double strideX,
    double strideY,
  ) => DragTarget<PlayerId>(
    key: ValueKey('order-seat-$index'),
    onWillAcceptWithDetails: (details) {
      if (_settling ||
          widget.onPlace == null ||
          !widget.profiles.containsKey(details.data)) {
        return false;
      }
      _hover(details.data, index);
      return true;
    },
    onMove: (details) => _hover(details.data, index),
    onLeave: (_) {
      if (!_settling && _hoverIndex == index) {
        setState(() => _hoverIndex = null);
      }
    },
    onAcceptWithDetails: (details) async {
      if (_settling ||
          widget.onPlace == null ||
          !widget.profiles.containsKey(details.data)) {
        return;
      }
      final original = List<PlayerId?>.of(widget.slots);
      setState(() => _settling = true);
      await landReorderAvatar(
        context: context,
        target: _targets[index]!,
        inset: const Offset(0, -4),
        from: details.offset + Offset(-avatarSize / 2, -avatarSize * .65),
        size: Size(
          avatarSize,
          avatarSize *
              TrinkAvatarRenderer.visibleHeight /
              TrinkAvatarRenderer.canvasWidth,
        ),
        child: _portrait(details.data, avatarSize),
      );
      if (mounted) {
        if (widget.onPlace != null &&
            sameReorderOrder(original, widget.slots) &&
            original.indexOf(details.data) != index) {
          widget.onPlace!(details.data, index);
        }
        _previewEpoch++;
        _selected = null;
        _settling = false;
        _endDrag(
          DraggableDetails(
            wasAccepted: true,
            velocity: Velocity.zero,
            offset: details.offset,
          ),
        );
      }
    },
    builder: (context, candidates, rejected) => InkWell(
      onTap: _selected == null || widget.onPlace == null
          ? null
          : () {
              widget.onPlace!(_selected!, index);
              setState(() => _selected = null);
            },
      child: Container(
        key: _targets.putIfAbsent(index, GlobalKey.new),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: CourtSceneTokens.panel.withValues(alpha: .45),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: candidates.isNotEmpty
                ? CourtSceneTokens.gold
                : CourtSceneTokens.gold.withValues(alpha: .35),
          ),
        ),
        child: Stack(
          clipBehavior: Clip.none,
          fit: StackFit.expand,
          children: [
            Center(
              child: _seatPerson(index, avatarSize, columns, strideX, strideY),
            ),
            Positioned(
              top: 4,
              left: 4,
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
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: CourtSceneTokens.gold,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
