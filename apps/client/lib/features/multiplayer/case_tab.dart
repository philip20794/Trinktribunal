import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/room_providers.dart';
import '../../data/catalogs/catalog_repository.dart';
import '../../data/protocol/room_message.dart';
import '../../design/case_file.dart';
import '../../design/court_scene.dart';
import '../../design/illustrated_paper.dart';
import '../../l10n/app_strings.dart';
import 'game_screen.dart';
import 'game_progress.dart';

class RoomCaseTab extends ConsumerWidget {
  const RoomCaseTab({required this.snapshot, super.key});
  final SnapshotMessage snapshot;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final view = snapshot.public,
        catalogs = ref.watch(catalogsProvider).asData?.value;
    final names = {
      for (final player in view.players) player.playerId: player.profile.name,
    };
    String? ruleText(Assignment assignment) {
      final matches = catalogs?.rules[view.config.contentLanguage]?.entries
          .where((r) => r.id == assignment.contentId)
          .toList();
      if (matches == null || matches.length != 1) return null;
      final rule = matches.single;
      if (assignment.bindings.values.length != rule.players.length ||
          !assignment.bindings.values.keys.toSet().containsAll(
            rule.players.keys,
          ) ||
          assignment.bindings.values.values.any(
            (id) => !names.containsKey(id),
          )) {
        return null;
      }
      return rule.render(rule.text, {
        for (final entry in assignment.bindings.values.entries)
          entry.key: names[entry.value]!,
      });
    }

    if (view.phase == 'lobby') {
      return const Center(child: TText('onlineHostStarts'));
    }
    final guide = names[view.config.allJudges ? view.readerId : view.judgeId];
    void rules() {
      ref.read(onlineGameProvider).hideSecret();
      showModalBottomSheet<void>(
        context: context,
        useSafeArea: true,
        isScrollControlled: true,
        backgroundColor: CourtSceneTokens.parchment,
        showDragHandle: true,
        builder: (_) => Theme(
          data: courtPaperTheme(),
          child: DefaultTextStyle(
            style: courtPaperTheme().textTheme.bodyLarge!,
            child: FractionallySizedBox(
              heightFactor: .7,
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  Text(
                    context.tr('activeRulesCount', {
                      'count': view.activeRules.length,
                    }),
                    style: courtPaperTheme().textTheme.titleLarge,
                  ),
                  if (view.activeRules.isEmpty) const TText('phoneRulesEmpty'),
                  for (final rule in view.activeRules)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        ruleText(rule) ?? context.tr('roomErrorGeneric'),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        CaseProgressHeader(
          completed: view.completedCases,
          total: view.config.targetCases,
          rules: view.activeRules.length,
          onRules: rules,
        ),
        if (guide != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(context.tr('caseGuide', {'name': guide})),
          ),
        if (view.phase == 'rule_event')
          if (view.activeRules.isNotEmpty &&
              ruleText(view.activeRules.last) != null)
            CourtRule(
              text: ruleText(view.activeRules.last)!,
              animationKey: '${view.gameId}:${view.completedCases}',
            )
          else
            const TText('roomErrorGeneric')
        else if (!['paused', 'finished'].contains(view.phase))
          RoomGameScreen(snapshot: snapshot, fixedActions: true)
        else
          OnlineGameProgress(snapshot: snapshot, showActions: false),
      ],
    );
  }
}
