import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/room_providers.dart';
import '../../data/catalogs/catalog_repository.dart';
import '../../data/protocol/room_message.dart';
import '../../design/case_file.dart';
import '../../l10n/app_strings.dart';

class OnlineGameProgress extends ConsumerWidget {
  const OnlineGameProgress({required this.snapshot, super.key});
  final SnapshotMessage snapshot;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final view = snapshot.public,
        gameId = view.gameId,
        game = ref.watch(onlineGameProvider),
        catalogs = ref.watch(catalogsProvider).asData?.value;
    if (gameId == null) return const SizedBox.shrink();
    final host = snapshot.you == view.hostId,
        names = {for (final p in view.players) p.playerId: p.profile.name};
    return ListenableBuilder(
      listenable: game,
      builder: (context, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (view.phase == 'finished') ...[
            CourtSeal(label: context.tr('endHearing')),
            Text(
              context.tr('cardFinished', {
                'count': view.completedCases,
                'rules': view.activeRules.length,
              }),
            ),
          ],
          if (view.phase == 'rule_event') ...[
            const TText('newDrinkingRule'),
            const TText('ruleEventHelp'),
          ],
          if (view.activeRules.isNotEmpty) ...[
            Text(
              context.tr('activeRulesCount', {
                'count': view.activeRules.length,
              }),
            ),
            const TText('rulesHelp'),
            for (final assignment in view.activeRules)
              Builder(
                builder: (context) {
                  final matches = catalogs
                      ?.rules[view.config.contentLanguage]
                      ?.entries
                      .where((r) => r.id == assignment.contentId)
                      .toList();
                  if (matches == null || matches.isEmpty) {
                    return const TText('roomErrorGeneric');
                  }
                  final rule = matches.single;
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
          if (host && view.phase == 'judged' && view.roundId != null)
            FilledButton(
              onPressed: game.pending('complete')
                  ? null
                  : () => game.completeCase(
                      gameId: gameId,
                      roundId: view.roundId!,
                    ),
              child: const TText('finishCase'),
            ),
          if (host && view.phase == 'rule_event')
            FilledButton(
              onPressed: game.pending('continue')
                  ? null
                  : () => game.continueRule(
                      gameId: gameId,
                      afterCase: view.completedCases,
                    ),
              child: const TText('backToCase'),
            ),
          if (view.phase == 'paused') ...[
            const TText('gamePaused'),
            if (host)
              FilledButton(
                onPressed: game.pending('resume')
                    ? null
                    : () => game.resumePaused(gameId: gameId),
                child: const TText('roomContinue'),
              ),
          ],
          if (host)
            OutlinedButton(
              onPressed: game.pending('restart')
                  ? null
                  : () async {
                      game.hideSecret();
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const TText('restartTitle'),
                          content: const TText('restartHelp'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const TText('cancel'),
                            ),
                            FilledButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: const TText('restartAction'),
                            ),
                          ],
                        ),
                      );
                      if (context.mounted && confirmed == true) {
                        game.restartGame(gameId: gameId, confirmed: true);
                      }
                    },
              child: const TText('restartGame'),
            ),
        ],
      ),
    );
  }
}
