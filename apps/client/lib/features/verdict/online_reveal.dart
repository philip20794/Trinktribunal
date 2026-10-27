import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/room_providers.dart';
import '../../data/protocol/room_message.dart';
import '../../design/case_file.dart';
import '../../l10n/app_strings.dart';

/// Displays only committed server fields; it never calculates truth or sips locally.
class OnlineReveal extends ConsumerWidget {
  const OnlineReveal({required this.snapshot, super.key});
  final SnapshotMessage snapshot;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final view = snapshot.public,
        game = ref.watch(onlineGameProvider),
        gameId = view.gameId,
        roundId = view.roundId;
    if (view.config.allJudges ||
        !['revealing', 'judged'].contains(view.phase) ||
        gameId == null ||
        roundId == null) {
      return const SizedBox.shrink();
    }
    final names = {
          for (final player in view.players)
            player.playerId: player.profile.name,
        },
        verdict = view.phase == 'judged' ? view.result : null;
    return ListenableBuilder(
      listenable: game,
      builder: (context, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            context.tr('onlineRevealProgress', {
              'count': view.revealCursor,
              'total': view.frozenRoster.length - 1,
            }),
          ),
          if (view.phase == 'revealing' && snapshot.you == view.hostId)
            FilledButton(
              onPressed: game.pending('reveal')
                  ? null
                  : () => game.revealNext(
                      gameId: gameId,
                      roundId: roundId,
                      expectedCursor: view.revealCursor,
                    ),
              child: const TText('phoneRevealNext'),
            ),
          if (verdict != null) ...[
            CourtSeal(
              label: context.tr('wrongPositionsCount', {
                'count': verdict.errors,
              }),
            ),
            for (final penalty in verdict.penalties)
              Text(
                context.tr('sips', {
                  'name':
                      names[penalty.playerId] ??
                      context.tr('onlineRemovedParticipant'),
                  'count': penalty.sips,
                }),
              ),
          ],
        ],
      ),
    );
  }
}
