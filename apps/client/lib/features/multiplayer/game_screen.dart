import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/room_providers.dart';
import '../../data/catalogs/catalog.dart';
import '../../data/catalogs/catalog_repository.dart';
import '../../data/protocol/room_message.dart';
import '../../design/case_file.dart';
import '../../design/private_number.dart';
import '../../l10n/app_strings.dart';
import 'readiness_view.dart';
import '../verdict/online_reveal.dart';

/// Game section inside the existing courtroom tab; profiles remain on Me.
class RoomGameScreen extends ConsumerWidget {
  const RoomGameScreen({required this.snapshot, super.key});
  final SnapshotMessage snapshot;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalogs = ref.watch(catalogsProvider),
        game = ref.watch(onlineGameProvider),
        view = snapshot.public;
    return catalogs.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => Column(
        children: [
          const TText('roomErrorGeneric'),
          ReadinessView(snapshot: snapshot),
        ],
      ),
      data: (catalogs) {
        final assignment = view.question;
        Question? question;
        if (assignment != null) {
          for (final candidate
              in catalogs.questions[view.config.contentLanguage]!.entries) {
            if (candidate.id == assignment.contentId) {
              question = candidate;
              break;
            }
          }
        }
        final profiles = {
          for (final player in view.players)
            player.playerId: player.profile.name,
        };
        if (assignment != null &&
            (question == null ||
                assignment.bindings.values.length != question.players.length ||
                !assignment.bindings.values.keys.toSet().containsAll(
                  question.players.keys,
                ) ||
                assignment.bindings.values.values.any(
                  (id) => !profiles.containsKey(id),
                ))) {
          return Column(
            children: [
              const TText('roomErrorGeneric'),
              ReadinessView(snapshot: snapshot),
              OnlineReveal(snapshot: snapshot),
            ],
          );
        }
        final names = {
          if (assignment != null)
            for (final binding in assignment.bindings.values.entries)
              binding.key: profiles[binding.value]!,
        };
        final rendered = question?.renderFor(names);
        final judge = profiles[view.judgeId];
        final reader = profiles[view.readerId];
        return ListenableBuilder(
          listenable: game,
          builder: (context, _) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (view.config.allJudges) const TText('onlineAllJudges'),
              Text(
                context.tr('casesCompleted', {
                  'done': view.completedCases,
                  'total': view.config.targetCases,
                }),
              ),
              if (judge != null)
                Text(context.tr('onlineJudge', {'name': judge})),
              if (reader != null)
                Text(context.tr('onlineReader', {'name': reader})),
              const TText('rosterFrozen'),
              if (rendered != null)
                CaseFile(
                  animationKey: view.roundId,
                  label: context.tr('caseNumber', {
                    'number': view.completedCases + 1,
                  }),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        rendered.text,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 16),
                      Text('1 · ${rendered.green}'),
                      Text(rendered.connector),
                      Text(
                        '${(view.frozenRoster.length * view.config.factorTenths + 9) ~/ 10} · ${rendered.red}',
                      ),
                    ],
                  ),
                ),
              if (snapshot.private.ownNumber != null) ...[
                const TText('onlineOwnNumber'),
                PrivateNumber(
                  number: game.visibleNumber,
                  onReveal: game.revealOwnNumber,
                  onHide: game.hideSecret,
                  onConfirm:
                      view.phase == 'numbers' &&
                          !game.acknowledged &&
                          !game.ackPending
                      ? game.acknowledgeNumber
                      : null,
                  confirmKey: 'onlineConfirmNumber',
                ),
                if (view.phase == 'numbers' &&
                    (game.acknowledged || game.ackPending))
                  const TText('onlineNumberConfirmed'),
              ] else if (view.phase == 'numbers' &&
                  view.judgeId == snapshot.you)
                const TText('onlineJudgeNoNumber'),
              ReadinessView(snapshot: snapshot),
              OnlineReveal(snapshot: snapshot),
            ],
          ),
        );
      },
    );
  }
}
