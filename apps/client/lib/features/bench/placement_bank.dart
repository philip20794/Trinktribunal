import 'dart:async';

import 'package:flutter/material.dart';

import '../../design/avatar_view.dart';
import '../../design/court_scene.dart';
import '../../domain/models/ids.dart';
import '../../domain/user_profile.dart';
import '../../l10n/app_strings.dart';

/// Each case begins with empty numbered seats and a separate pool of people.
class PlacementBank extends StatefulWidget {
  const PlacementBank({
    required this.slots,
    required this.unplaced,
    required this.profiles,
    required this.onPlace,
    required this.onRemove,
    super.key,
  });
  final List<PlayerId?> slots;
  final List<PlayerId> unplaced;
  final Map<PlayerId, UserProfile> profiles;
  final void Function(PlayerId, int)? onPlace;
  final ValueChanged<PlayerId> onRemove;
  @override
  State<PlacementBank> createState() => _PlacementBankState();
}

class _PlacementBankState extends State<PlacementBank> {
  PlayerId? _selected;
  Timer? _edgeScroll;
  Offset? _dragPosition;

  void _stopDrag() {
    _edgeScroll?.cancel();
    _edgeScroll = null;
    _dragPosition = null;
  }

  void _scrollWhileDragging() {
    final scroll = Scrollable.maybeOf(context);
    final position = _dragPosition;
    if (scroll == null ||
        position == null ||
        !scroll.position.hasContentDimensions) {
      return;
    }
    final box = scroll.context.findRenderObject() as RenderBox;
    final y = box.globalToLocal(position).dy;
    final delta = y < 56
        ? -12.0
        : y > box.size.height - 56
        ? 12.0
        : 0.0;
    if (delta == 0) return;
    scroll.position.jumpTo(
      (scroll.position.pixels + delta).clamp(
        scroll.position.minScrollExtent,
        scroll.position.maxScrollExtent,
      ),
    );
  }

  @override
  void didUpdateWidget(PlacementBank oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.profiles.containsKey(_selected)) _selected = null;
    if (widget.onPlace == null) _stopDrag();
  }

  @override
  void dispose() {
    _stopDrag();
    super.dispose();
  }

  Widget _portrait(PlayerId id) => AvatarView(
    config: widget.profiles[id]!.avatar,
    size: 82,
    label: widget.profiles[id]!.player.name,
    playerName: widget.profiles[id]!.player.name,
  );
  Widget _person(PlayerId id) => Draggable<PlayerId>(
    data: id,
    maxSimultaneousDrags: widget.onPlace == null ? 0 : 1,
    onDragStarted: () {
      _stopDrag();
      _edgeScroll = Timer.periodic(
        const Duration(milliseconds: 30),
        (_) => _scrollWhileDragging(),
      );
    },
    onDragUpdate: (details) => _dragPosition = details.globalPosition,
    onDragEnd: (_) => _stopDrag(),
    feedback: Material(color: Colors.transparent, child: _portrait(id)),
    childWhenDragging: Opacity(opacity: .3, child: _portrait(id)),
    child: InkWell(
      onTap: widget.onPlace == null
          ? null
          : () => setState(() => _selected = id),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(
            color: _selected == id ? CourtSceneTokens.gold : Colors.transparent,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: _portrait(id),
      ),
    ),
  );
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const TText('placePlayersHelp'),
      const SizedBox(height: 12),
      LayoutBuilder(
        builder: (context, bounds) => GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: widget.slots.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: bounds.maxWidth < 450 ? 3 : 5,
            mainAxisExtent: MediaQuery.textScalerOf(context).scale(16) > 24
                ? 210
                : 190,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
          ),
          itemBuilder: (context, index) => DragTarget<PlayerId>(
            key: ValueKey('order-seat-$index'),
            onWillAcceptWithDetails: (details) =>
                widget.onPlace != null &&
                widget.profiles.containsKey(details.data),
            onAcceptWithDetails: (details) {
              widget.onPlace?.call(details.data, index);
              setState(() => _selected = null);
            },
            builder: (context, candidates, rejected) => InkWell(
              onTap: _selected == null || widget.onPlace == null
                  ? null
                  : () {
                      widget.onPlace!(_selected!, index);
                      setState(() => _selected = null);
                    },
              child: Container(
                decoration: BoxDecoration(
                  color: widget.slots[index] == null
                      ? CourtSceneTokens.panel.withValues(alpha: .55)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: candidates.isNotEmpty
                        ? CourtSceneTokens.gold
                        : widget.slots[index] == null
                        ? CourtSceneTokens.gold.withValues(alpha: .5)
                        : Colors.transparent,
                    width: 2,
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      '${index + 1}',
                      style: const TextStyle(color: CourtSceneTokens.gold),
                    ),
                    if (widget.slots[index] case final PlayerId id) ...[
                      Expanded(child: Center(child: _person(id))),
                      SizedBox(
                        height: 48,
                        child: IconButton(
                          padding: EdgeInsets.zero,
                          tooltip: context.tr('removeFromSeat'),
                          onPressed: widget.onPlace == null
                              ? null
                              : () => widget.onRemove(id),
                          icon: const Icon(Icons.close, size: 18),
                        ),
                      ),
                    ] else
                      const Expanded(
                        child: Icon(
                          Icons.person_outline,
                          color: CourtSceneTokens.gold,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
      const SizedBox(height: 20),
      DragTarget<PlayerId>(
        onWillAcceptWithDetails: (_) => widget.onPlace != null,
        onAcceptWithDetails: (details) => widget.onRemove(details.data),
        builder: (context, candidates, rejected) => Container(
          constraints: const BoxConstraints(minHeight: 100),
          padding: const EdgeInsets.all(8),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              for (final id in widget.unplaced)
                SizedBox(
                  key: ValueKey('unplaced-${id.value}'),
                  width: 90,
                  height: 110,
                  child: _person(id),
                ),
            ],
          ),
        ),
      ),
    ],
  );
}
