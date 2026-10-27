import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:trinktribunal/application/content_history_store.dart';
import 'package:trinktribunal/application/shared_phone_controller.dart';
import 'package:trinktribunal/domain/avatar_config.dart';
import 'package:trinktribunal/domain/models/content_history.dart';
import 'package:trinktribunal/domain/models/ids.dart';
import 'package:trinktribunal/domain/models/player.dart';
import 'package:trinktribunal/domain/user_profile.dart';

import 'selection_support.dart';

List<UserProfile> roster(List<dynamic> ids) => [
  for (final id in ids)
    UserProfile(
      player: Player(id: PlayerId(id as String), name: id),
      avatar: AvatarConfig(),
    ),
];

void main() {
  final fixture = jsonDecode(
    File('../../packages/protocol/fixtures/transitions/core/v1.json')
        .readAsStringSync(),
  ) as Map<String, dynamic>;
  for (final scenario in fixture['scenarios'] as List<dynamic>) {
    test('shared TS/Dart core: ${scenario['id']}', () {
      final history = ContentHistoryStore();
      final ruleIds = (fixture['rules'] as List<dynamic>).cast<String>();
      final session = SharedPhoneController(
        questions: questions([
          for (final id in fixture['questions'] as List<dynamic>)
            questionJson(id as String),
        ]),
        rules: rules([
          for (final id in ruleIds)
            ruleJson(
              id,
              excludes: scenario['excludeRules'] == true
                  ? ruleIds.where((other) => other != id).toList()
                  : [],
            ),
        ]),
        random: TestRandom(),
        clock: () => now,
        newId: () => 'fixture_game',
        historyStore: history,
      );
      final config = session.configure(
        playerCount: 3,
        targetCases: scenario['targetCases'] as int,
        requestedRuleEvents: (scenario['ruleSlots'] as List<dynamic>).length,
      );
      for (final step in scenario['steps'] as List<dynamic>) {
        switch (step['action']) {
          case 'start':
            session.start(config: config, roster: roster(['A', 'B', 'C']));
          case 'skip':
          case 'skipUnconfirmed':
            final round = session.view!.roundId;
            session.completeCase(
              round,
              confirmed: step['action'] == 'skip',
              withoutVerdict: true,
            );
            if (step['repeat'] == true) {
              session.completeCase(
                round,
                confirmed: true,
                withoutVerdict: true,
              );
            }
          case 'continueRule':
            session.continueRule(afterCase: session.view!.completedCases);
          case 'roster':
            session.applyRoster(roster(step['roster'] as List<dynamic>));
          case 'resume':
            session.resumePaused();
        }
        final view = session.view!;
        expect(
          {
            'phase': view.phase.name == 'ruleEvent'
                ? 'rule_event'
                : view.phase.name,
            'completed': view.completedCases,
            'judge': view.judge?.value,
            'question': view.question?.entry.id,
            'drawn': history.history.entries
                .where((entry) => entry.kind == ContentKind.question)
                .length,
            'rules': view.activeRules.length,
            'skippedRules': view.skippedRules,
            'roster': view.roster.map((p) => p.player.id.value).toList(),
          },
          step['expected'],
          reason: '${scenario['id']}/${step['action']}',
        );
      }
    });
  }
}
