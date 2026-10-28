import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/room_providers.dart';
import '../../data/protocol/room_message.dart';
import '../../l10n/app_strings.dart';

class ReadinessView extends ConsumerWidget {
  const ReadinessView({
    required this.snapshot,
    this.showActions = true,
    super.key,
  });
  final SnapshotMessage snapshot;
  final bool showActions;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final game = ref.watch(onlineGameProvider),
        view = snapshot.public,
        roundId = view.roundId,
        gameId = view.gameId;
    if (roundId == null || gameId == null) return const SizedBox.shrink();
    final host = snapshot.you == view.hostId, answers = view.phase == 'answers';
    final participants = {
      for (final player in view.players) player.playerId: player,
    };
    final recipients = view.frozenRoster
        .where((id) => answers || view.config.allJudges || id != view.judgeId)
        .toList();
    return ListenableBuilder(
      listenable: game,
      builder: (context, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (['numbers', 'answers'].contains(view.phase)) ...[
            if (answers) const TText('phoneAnswersHelp'),
            ExpansionTile(
              initiallyExpanded: recipients.length <= 5,
              tilePadding: EdgeInsets.zero,
              title: TText(
                answers ? 'onlineReadyAnswers' : 'onlineReadyNumbers',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              children: [
                for (final id in recipients)
                  ListTile(
                    dense: true,
                    title: Text(
                      participants[id]?.profile.name ??
                          context.tr('onlineRemovedParticipant'),
                    ),
                    subtitle: TText(
                      participants[id]?.connected != true
                          ? 'onlineReadyDisconnected'
                          : participants[id]?.ready == true
                          ? 'onlineReadyDone'
                          : 'onlineReadyWaiting',
                    ),
                  ),
              ],
            ),
            if (showActions) ReadinessActions(snapshot: snapshot),
            if (game.pending('ready')) const TText('onlineReadySending'),
          ],
          if (host &&
              [
                'numbers',
                'answers',
                'ordering',
                'revealing',
                'judged',
                'paused',
              ].contains(view.phase))
            OutlinedButton(
              onPressed: game.pending('complete')
                  ? null
                  : () async {
                      game.hideSecret();
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const TText('skipCaseTitle'),
                          content: const TText('onlineSkipHelp'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const TText('cancel'),
                            ),
                            FilledButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: const TText('finishCase'),
                            ),
                          ],
                        ),
                      );
                      if (context.mounted && confirmed == true) {
                        game.completeWithoutVerdict(
                          gameId: gameId,
                          roundId: roundId,
                          confirmed: true,
                        );
                      }
                    },
              child: const TText('withoutVerdict'),
            ),
        ],
      ),
    );
  }
}

/// The same authoritative actions can be hosted in the sticky courtroom footer.
class ReadinessActions extends ConsumerWidget {
  const ReadinessActions({required this.snapshot, super.key});
  final SnapshotMessage snapshot;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final game = ref.watch(onlineGameProvider),
        view = snapshot.public,
        roundId = view.roundId,
        gameId = view.gameId;
    if (roundId == null || gameId == null) return const SizedBox.shrink();
    final answers = view.phase == 'answers', host = snapshot.you == view.hostId;
    final participants = {
      for (final player in view.players) player.playerId: player,
    };
    return ListenableBuilder(
      listenable: game,
      builder: (context, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (answers && view.frozenRoster.contains(snapshot.you))
            FilledButton(
              onPressed:
                  !game.pending('ready') &&
                      participants[snapshot.you]?.ready != true
                  ? () =>
                        game.readyForOrdering(gameId: gameId, roundId: roundId)
                  : null,
              child: const TText('onlineAnswerReady'),
            ),
          if (answers && host)
            FilledButton(
              onPressed: game.canBeginOrdering && !game.pending('begin')
                  ? () => game.beginOrdering(gameId: gameId, roundId: roundId)
                  : null,
              child: const TText('phoneBeginOrder'),
            ),
        ],
      ),
    );
  }
}
