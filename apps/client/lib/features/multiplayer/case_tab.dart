import '../rules/active_rules_sheet.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/room_providers.dart';
import '../../data/catalogs/catalog_repository.dart';
import '../../data/protocol/room_message.dart';
import '../../design/case_file.dart';
import '../../design/judge_plate.dart';
import '../../domain/avatar_config.dart';
import '../../domain/models/player.dart';
import '../../domain/user_profile.dart';
import '../../l10n/app_strings.dart';
import 'game_screen.dart';
import '../../design/case_stage.dart';
import 'game_progress.dart';
import 'me.dart';

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
      final rule = catalogs
          ?.rules[view.config.contentLanguage]
          ?.byId[assignment.contentId];
      if (rule == null) return null;
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
    final guideId = view.config.allJudges ? view.readerId : view.judgeId;
    final guides = view.players.where((p) => p.playerId == guideId);
    final guide = guides.isEmpty ? null : guides.first;
    void rules() {
      ref.read(onlineGameProvider).hideSecret();
      showActiveRuleList(
        context,
        rules: [
          for (final rule in view.activeRules)
            ruleText(rule) ?? context.tr('roomErrorGeneric'),
        ],
      );
    }

    final game = ref.watch(onlineGameProvider);
    return ListenableBuilder(
      listenable: game,
      builder: (context, _) => CaseStage(
        number: game.visibleNumber,
        rules: view.activeRules.length,
        onRules: rules,
        judge: guide == null
            ? null
            : JudgePlate(
                onTap: guide.playerId != snapshot.you
                    ? null
                    : () {
                        game.hideSecret();
                        Navigator.of(context).push<void>(
                          MaterialPageRoute(
                            builder: (_) => const RoomProfileScreen(),
                          ),
                        );
                      },
                profile: UserProfile(
                  player: Player(id: guide.playerId, name: guide.profile.name),
                  avatar: AvatarConfig.fromJson(guide.profile.avatar.toJson()),
                ),
              ),
        child: view.phase == 'rule_event'
            ? view.activeRules.isNotEmpty &&
                      ruleText(view.activeRules.last) != null
                  ? CourtRule(
                      text: ruleText(view.activeRules.last)!,
                      animationKey: '${view.gameId}:${view.completedCases}',
                    )
                  : const TText('roomErrorGeneric')
            : !['paused', 'finished'].contains(view.phase)
            ? RoomGameScreen(snapshot: snapshot, fixedActions: true)
            : OnlineGameProgress(snapshot: snapshot, showActions: false),
      ),
    );
  }
}
