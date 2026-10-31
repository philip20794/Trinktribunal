import '../../design/game_finished_panel.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/room_providers.dart';
import '../../data/catalogs/catalog_repository.dart';
import '../../data/protocol/room_message.dart';
import '../../design/case_file.dart';
import '../../design/hold_action_button.dart';
import '../../l10n/app_strings.dart';

class OnlineGameProgress extends ConsumerWidget {
  const OnlineGameProgress({
    required this.snapshot,
    this.showActions = true,
    super.key,
  });
  final SnapshotMessage snapshot;
  final bool showActions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final view = snapshot.public,
        gameId = view.gameId,
        game = ref.watch(onlineGameProvider),
        catalogs = ref.watch(catalogsProvider).asData?.value;
    if (gameId == null) return const SizedBox.shrink();
    final host = snapshot.you == view.hostId,
        names = {for (final p in view.players) p.playerId: p.profile.name};
    if (view.phase == 'finished') {
      return ListenableBuilder(
        listenable: game,
        builder: (context, _) => GameFinishedPanel(
          onNewGame: host && !game.pending('setup')
              ? () => game.returnToSetup(gameId: gameId)
              : null,
          waitingForHost: !host,
        ),
      );
    }
    return ListenableBuilder(
      listenable: game,
      builder: (context, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (view.phase == 'rule_event') ...[const TText('newDrinkingRule')],
          if (view.activeRules.isNotEmpty)
            ExpansionTile(
              key: ValueKey('${view.gameId}:${view.phase == 'rule_event'}'),
              initiallyExpanded: view.phase == 'rule_event',
              tilePadding: EdgeInsets.zero,
              title: Text(
                context.tr('activeRulesCount', {
                  'count': view.activeRules.length,
                }),
              ),
              children: [
                for (final assignment in view.activeRules)
                  Builder(
                    builder: (context) {
                      final rule = catalogs
                          ?.rules[view.config.contentLanguage]
                          ?.byId[assignment.contentId];
                      if (rule == null) return const TText('roomErrorGeneric');
                      if (assignment.bindings.values.length !=
                              rule.players.length ||
                          !assignment.bindings.values.keys.toSet().containsAll(
                            rule.players.keys,
                          ) ||
                          assignment.bindings.values.values.any(
                            (id) => !names.containsKey(id),
                          )) {
                        return const TText('roomErrorGeneric');
                      }
                      final rendered = rule.render(rule.text, {
                        for (final b in assignment.bindings.values.entries)
                          b.key: names[b.value]!,
                      });
                      return CaseFile(
                        label: context.tr('activeRules'),
                        child: Text(rendered),
                      );
                    },
                  ),
              ],
            ),

          if (view.phase == 'paused') ...[
            const TText('gamePaused'),
            if (view.pauseReason == 'insufficient_players')
              const TText('onlinePausePlayers'),
          ],
          if (showActions) OnlineProgressAction(snapshot: snapshot),
        ],
      ),
    );
  }
}

class OnlineProgressAction extends ConsumerWidget {
  const OnlineProgressAction({required this.snapshot, super.key});
  final SnapshotMessage snapshot;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final game = ref.watch(onlineGameProvider),
        view = snapshot.public,
        gameId = view.gameId;
    if (gameId == null || !game.canGuideRound) {
      return const SizedBox.shrink();
    }
    return ListenableBuilder(
      listenable: game,
      builder: (context, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (view.phase == 'judged' && view.roundId != null)
            HoldActionButton(
              duration: const Duration(milliseconds: 800),
              key: ValueKey('next-judge-${view.roundId}'),
              icon: Icons.arrow_forward_rounded,
              label: context.tr('nextJudge'),
              onCompleted: game.pending('complete')
                  ? null
                  : () => game.completeCase(
                      gameId: gameId,
                      roundId: view.roundId!,
                    ),
            ),
          if (view.phase == 'rule_event')
            FilledButton(
              onPressed: game.pending('continue')
                  ? null
                  : () => game.continueRule(
                      gameId: gameId,
                      afterCase: view.completedCases,
                    ),
              child: const TText('ruleUnderstood'),
            ),
          if (view.phase == 'paused' && snapshot.you == view.hostId)
            FilledButton(
              onPressed:
                  game.pending('resume') ||
                      view.pauseReason == 'insufficient_players' &&
                          game.activeCount < 3
                  ? null
                  : () => game.resumePaused(gameId: gameId),
              child: const TText('roomContinue'),
            ),
        ],
      ),
    );
  }
}

/// The judge closes a case played at the table, without a digital verdict.
class OnlineNextCaseAction extends ConsumerWidget {
  const OnlineNextCaseAction({required this.snapshot, super.key});
  final SnapshotMessage snapshot;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final game = ref.watch(onlineGameProvider), view = snapshot.public;
    return ListenableBuilder(
      listenable: game,
      builder: (context, _) => HoldActionButton(
        duration: const Duration(milliseconds: 800),
        key: ValueKey('next-judge-${view.roundId}'),
        icon: Icons.arrow_forward_rounded,
        label: context.tr('nextJudge'),
        onCompleted: game.pending('complete')
            ? null
            : () {
                if (view.gameId == null || view.roundId == null) return;
                if (view.phase == 'judged') {
                  game.completeCase(
                    gameId: view.gameId!,
                    roundId: view.roundId!,
                  );
                } else {
                  game.completeWithoutVerdict(
                    gameId: view.gameId!,
                    roundId: view.roundId!,
                    confirmed: true,
                  );
                }
              },
      ),
    );
  }
}
