import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/room_providers.dart';
import '../../data/protocol/room_message.dart';
import '../../design/case_file.dart';
import '../../l10n/app_strings.dart';
import 'personal_verdict.dart';

/// Displays only committed server fields; it never calculates truth or sips locally.
class OnlineReveal extends ConsumerWidget {
  const OnlineReveal({
    required this.snapshot,
    this.showActions = true,
    super.key,
  });
  final SnapshotMessage snapshot;
  final bool showActions;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final view = snapshot.public,
        game = ref.watch(onlineGameProvider),
        gameId = view.gameId,
        roundId = view.roundId;
    if (!['revealing', 'judged'].contains(view.phase) ||
        gameId == null ||
        roundId == null) {
      return const SizedBox.shrink();
    }
    final names = {
          for (final player in view.players)
            player.playerId: player.profile.name,
        },
        verdict = view.phase == 'judged' ? view.result : null;
    final content = ListenableBuilder(
      listenable: game,
      builder: (context, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            context.tr('onlineRevealProgress', {
              'count': view.revealCursor,
              'total':
                  view.frozenRoster.length - (view.config.allJudges ? 0 : 1),
            }),
          ),
          if (showActions) OnlineRevealAction(snapshot: snapshot),
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
          if (view.config.allJudges) PersonalVerdict(snapshot: snapshot),
        ],
      ),
    );
    return view.phase == 'judged'
        ? CaseFile(label: context.tr('verdictHeading'), child: content)
        : content;
  }
}

class OnlineRevealAction extends ConsumerWidget {
  const OnlineRevealAction({required this.snapshot, super.key});
  final SnapshotMessage snapshot;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final game = ref.watch(onlineGameProvider),
        view = snapshot.public,
        gameId = view.gameId,
        roundId = view.roundId;
    if (view.phase != 'revealing' ||
        !game.canGuideRound ||
        gameId == null ||
        roundId == null) {
      return const SizedBox.shrink();
    }
    return ListenableBuilder(
      listenable: game,
      builder: (context, _) => FilledButton(
        onPressed: game.pending('reveal')
            ? null
            : () => game.revealNext(
                gameId: gameId,
                roundId: roundId,
                expectedCursor: view.revealCursor,
              ),
        child: const TText('phoneRevealNext'),
      ),
    );
  }
}
