import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../data/protocol/room_message.dart';
import '../../design/avatar_view.dart';
import '../../design/court_scene.dart';
import '../../design/seat_hint.dart';
import '../../domain/avatar_config.dart';
import '../../l10n/app_strings.dart';
import 'pending_profile.dart';

/// The waiting room uses the whole viewport, without the sorting bank's controls.
class LobbyBench extends StatelessWidget {
  const LobbyBench({required this.snapshot, super.key});

  final SnapshotMessage snapshot;

  static const minAvatarSize = 64.0;
  static const maxAvatarSize = 128.0;
  static const _portraitRatio =
      TrinkAvatarRenderer.visibleHeight / TrinkAvatarRenderer.canvasWidth;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final players = snapshot.public.players;
      if (players.isEmpty) return const SizedBox.shrink();
      final width = math.max(0.0, constraints.maxWidth - 16);
      final height = math.max(0.0, constraints.maxHeight - 16);
      final textHeight = MediaQuery.textScalerOf(context).scale(13) * 1.3 * 2;
      // Reserve two full name lines, portrait padding, and a light seat cue.
      final rowChrome = textHeight + 32;
      final minCellWidth = math.max(
        minAvatarSize + 16,
        MediaQuery.textScalerOf(context).scale(13) * 6,
      );
      final maxColumns = math.min(
        players.length,
        (width / minCellWidth).floor().clamp(1, 4),
      );
      var columns = 1;
      var avatarSize = minAvatarSize;
      var bestOverflow = double.infinity;
      var bestRows = players.length + 1;
      var bestComfort = 0.0;
      for (var candidate = 1; candidate <= maxColumns; candidate++) {
        final rows = (players.length / candidate).ceil();
        final widthLimit = math.min(maxAvatarSize, width / candidate - 16);
        final heightLimit = (height / rows - rowChrome) / _portraitRatio;
        final size = math
            .min(widthLimit, math.max(minAvatarSize, heightLimit))
            .clamp(0.0, maxAvatarSize);
        final overflow = math.max(
          0.0,
          rows * (size * _portraitRatio + rowChrome) - height,
        );
        // At a comfortable 96 px, favor fewer rows over even larger portraits.
        final comfort = math.min(size, 96.0);
        if (overflow < bestOverflow - .01 ||
            ((overflow - bestOverflow).abs() < .01 &&
                (comfort > bestComfort + .01 ||
                    ((comfort - bestComfort).abs() < .01 &&
                        (rows < bestRows ||
                            (rows == bestRows && size > avatarSize + .01)))))) {
          columns = candidate;
          avatarSize = size;
          bestOverflow = overflow;
          bestRows = rows;
          bestComfort = comfort;
        }
      }
      return SingleChildScrollView(
        key: const PageStorageKey('online-lobby-bench'),
        padding: const EdgeInsets.all(8),
        child: Column(
          children: [
            for (var start = 0; start < players.length; start += columns)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (var col = 0; col < columns; col++)
                          Expanded(
                            child: start + col >= players.length
                                ? const SizedBox.shrink()
                                : Builder(
                                    builder: (context) {
                                      final player = players[start + col];
                                      final name =
                                          needsRoomName(player.profile.name)
                                          ? context.tr('roomUnnamedPlayer')
                                          : player.profile.name;
                                      return Padding(
                                        key: ValueKey(
                                          'lobby-player-${player.playerId.value}',
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                        ),
                                        child: Column(
                                          children: [
                                            AvatarView(
                                              showBackdrop: false,
                                              config: AvatarConfig.fromJson(
                                                player.profile.avatar.toJson(),
                                              ),
                                              size: avatarSize,
                                              label: name,
                                              playerName: name,
                                            ),
                                            const SizedBox(height: 2),
                                            SizedBox(
                                              height: textHeight,
                                              child: Tooltip(
                                                message: name,
                                                child: Text(
                                                  name,
                                                  maxLines: 2,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  textAlign: TextAlign.center,
                                                  style: const TextStyle(
                                                    fontSize: 13,
                                                    height: 1.3,
                                                    color:
                                                        CourtSceneTokens.cream,
                                                  ),
                                                ),
                                              ),
                                            ),
                                            const SeatHint(),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
          ],
        ),
      );
    },
  );
}
