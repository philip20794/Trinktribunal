import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/room_providers.dart';
import '../../data/catalogs/catalog_repository.dart';
import '../../data/protocol/room_message.dart';
import '../../design/case_file.dart';
import '../../l10n/app_strings.dart';
import 'readiness_view.dart';
import '../verdict/online_reveal.dart';

/// Question, own number and result in the dedicated case tab.
class RoomGameScreen extends ConsumerWidget {
  const RoomGameScreen({
    required this.snapshot,
    this.fixedActions = false,
    super.key,
  });
  final SnapshotMessage snapshot;
  final bool fixedActions;
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
          ReadinessView(snapshot: snapshot, showActions: !fixedActions),
        ],
      ),
      data: (catalogs) {
        final assignment = view.question;
        final question = assignment == null
            ? null
            : catalogs.questions[view.config.contentLanguage]!.byId[assignment
                  .contentId];
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
              ReadinessView(snapshot: snapshot, showActions: !fixedActions),
              if (!view.config.allJudges)
                OnlineReveal(snapshot: snapshot, showActions: !fixedActions),
            ],
          );
        }
        final names = {
          if (assignment != null)
            for (final binding in assignment.bindings.values.entries)
              binding.key: profiles[binding.value]!,
        };
        final rendered = question?.renderFor(names);
        return ListenableBuilder(
          listenable: game,
          builder: (context, _) => LayoutBuilder(
            builder: (context, bounds) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (rendered != null)
                  Flexible(
                    flex: bounds.hasBoundedHeight ? 1 : 0,
                    child: CourtQuestion(
                      animationKey: view.roundId,
                      showRefresh:
                          snapshot.you ==
                          (view.config.allJudges
                              ? view.readerId
                              : view.judgeId),
                      onRefresh: game.canReroll
                          ? () => game.rerollCurrentQuestion(
                              gameId: view.gameId!,
                              roundId: view.roundId!,
                            )
                          : null,
                      label: context.tr('caseProgress', {
                        'number': view.completedCases + 1,
                        'total': view.config.targetCases,
                      }),
                      text: rendered.text,
                      green: rendered.green,
                      connector: rendered.connector,
                      red: rendered.red,
                      maximum:
                          (view.frozenRoster.length * view.config.factorTenths +
                              9) ~/
                          10,
                    ),
                  ),
                if (!view.config.allJudges)
                  OnlineReveal(snapshot: snapshot, showActions: !fixedActions),
              ],
            ),
          ),
        );
      },
    );
  }
}
