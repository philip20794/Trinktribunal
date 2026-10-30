import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../design/avatar_view.dart';
import '../../design/court_scene.dart';
import '../../domain/models/ids.dart';
import '../../domain/user_profile.dart';
import '../../l10n/app_strings.dart';

/// The same ordered group for both local modes; scrolling and dragging stay distinct.
class RosterGrid extends StatelessWidget {
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
      var bestRows = members.length + 1;
      for (
        var candidate = 1;
        candidate <= math.min(members.length, (width / 76).floor().clamp(1, 5));
        candidate++
      ) {
        final rows = (members.length / candidate).ceil();
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
      return SliverGrid.builder(
        itemCount: members.length,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columns,
          mainAxisExtent: size * ratio + 12,
          crossAxisSpacing: 4,
          mainAxisSpacing: 4,
        ),
        itemBuilder: (context, index) {
          final member = members[index];
          Widget portrait() => AvatarView(
            config: member.avatar,
            size: size,
            playerName: member.player.name,
            label: member.player.name,
          );
          return DragTarget<PlayerId>(
            key: ValueKey(member.player.id),
            onWillAcceptWithDetails: (drag) =>
                enabled &&
                drag.data != member.player.id &&
                members.any((p) => p.player.id == drag.data),
            onAcceptWithDetails: (drag) => onMove(
              members.indexWhere((p) => p.player.id == drag.data),
              index,
            ),
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
                fit: StackFit.expand,
                children: [
                  Center(
                    child: LongPressDraggable<PlayerId>(
                      key: ValueKey('roster-drag-${member.player.id.value}'),
                      delay: const Duration(milliseconds: 180),
                      data: member.player.id,
                      maxSimultaneousDrags: enabled ? 1 : 0,
                      feedback: Material(
                        color: Colors.transparent,
                        child: portrait(),
                      ),
                      childWhenDragging: Opacity(
                        opacity: .25,
                        child: portrait(),
                      ),
                      child: InkWell(
                        onTap: enabled ? () => onEdit(member) : null,
                        child: portrait(),
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
                      enabled: enabled,
                      tooltip: context.tr('rosterEditPerson'),
                      icon: const Icon(Icons.more_vert, size: 20),
                      itemBuilder: (_) => [
                        PopupMenuItem(
                          value: 'edit',
                          child: TText('rosterEditPerson'),
                        ),
                        if (!isOwner(member.player.id))
                          PopupMenuItem(
                            value: 'remove',
                            child: TText('rosterRemove'),
                          ),
                      ],
                      onSelected: (action) => action == 'edit'
                          ? onEdit(member)
                          : onRemove(member, index),
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
