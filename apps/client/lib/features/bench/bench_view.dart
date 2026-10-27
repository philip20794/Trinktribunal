import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../design/avatar_view.dart';
import '../../design/case_file.dart';
import '../../design/court_theme.dart';
import '../../domain/bench_order.dart';
import '../../domain/models/ids.dart';
import '../../domain/user_profile.dart';

class BenchView extends StatefulWidget {
  const BenchView({
    required this.order,
    required this.profiles,
    this.onMove,
    this.revealedNumbers = const {},
    this.incorrect = const {},
    super.key,
  });
  final List<PlayerId> order;
  final Map<PlayerId, UserProfile> profiles;
  final void Function(int from, int to)? onMove;
  final Map<PlayerId, int> revealedNumbers;
  final Set<PlayerId> incorrect;
  @override
  State<BenchView> createState() => _BenchViewState();
}

class _BenchViewState extends State<BenchView> {
  final _scroll = ScrollController();
  PlayerId? _selected;
  @override
  void dispose() {
    _scroll.dispose();
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
    if (from >= 0 && from != to) widget.onMove!(from, to);
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
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final columns = CourtTokens.bankColumns(
        constraints.maxWidth,
        MediaQuery.textScalerOf(context).scale(16) / 16,
      );
      final rows = (widget.order.length + columns - 1) ~/ columns;
      return SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.62,
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
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (var col = 0; col < columns; col++)
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                              ),
                              child:
                                  snakeIndex(row, col, columns) <
                                      widget.order.length
                                  ? _tile(snakeIndex(row, col, columns))
                                  : const SizedBox.shrink(),
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
  );

  Widget _tile(int index) {
    final id = widget.order[index];
    final profile = widget.profiles[id]!;
    final editable = widget.onMove != null;
    return DragTarget<PlayerId>(
      onWillAcceptWithDetails: (details) =>
          editable && widget.order.contains(details.data),
      onMove: (details) => _edgeScroll(details.offset),
      onAcceptWithDetails: (details) {
        setState(() => _selected = null);
        widget.onMove?.call(widget.order.indexOf(details.data), index);
      },
      builder: (context, candidates, rejected) => Focus(
        onKeyEvent: (node, event) {
          if (!editable ||
              event is! KeyDownEvent ||
              !HardwareKeyboard.instance.isAltPressed) {
            return KeyEventResult.ignored;
          }
          final delta = event.logicalKey == LogicalKeyboardKey.arrowUp
              ? -1
              : event.logicalKey == LogicalKeyboardKey.arrowDown
              ? 1
              : 0;
          if (delta == 0 ||
              index + delta < 0 ||
              index + delta >= widget.order.length) {
            return KeyEventResult.ignored;
          }
          widget.onMove!(index, index + delta);
          return KeyEventResult.handled;
        },
        child: AnimatedContainer(
          duration: CourtTokens.motionDuration(
            MediaQuery.disableAnimationsOf(context),
          ),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: CourtTokens.file,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: candidates.isNotEmpty || _selected == id
                  ? CourtTokens.red
                  : CourtTokens.border,
              width: candidates.isNotEmpty || _selected == id ? 3 : 1,
            ),
          ),
          child: Column(
            children: [
              InkWell(
                onTap: editable ? () => _tap(id) : null,
                child: Column(
                  children: [
                    AvatarView(
                      config: profile.avatar,
                      size: 76,
                      label: profile.player.name,
                    ),
                    NamePlate(name: profile.player.name, position: index + 1),
                  ],
                ),
              ),
              if (widget.revealedNumbers.containsKey(id))
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Zahl ${widget.revealedNumbers[id]} · ${widget.incorrect.contains(id) ? '✕ Falsche Position' : '✓ Richtige Position'}',
                  ),
                ),
              if (editable) ...[
                LongPressDraggable<PlayerId>(
                  data: id,
                  feedback: Material(
                    elevation: 4,
                    child: SizedBox(
                      width: 120,
                      child: NamePlate(
                        name: profile.player.name,
                        position: index + 1,
                      ),
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
                      tooltip: 'Position ${index + 1} nach vorn',
                      onPressed: index > 0
                          ? () => widget.onMove!(index, index - 1)
                          : null,
                      icon: const Icon(Icons.arrow_upward),
                    ),
                    IconButton(
                      tooltip: 'Position ${index + 1} nach hinten',
                      onPressed: index < widget.order.length - 1
                          ? () => widget.onMove!(index, index + 1)
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
    );
  }
}
