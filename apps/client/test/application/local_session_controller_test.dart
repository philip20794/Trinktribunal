import 'package:flutter_test/flutter_test.dart';
import 'package:trinktribunal/application/local_session_controller.dart';
import 'package:trinktribunal/domain/config/game_config.dart';
import 'package:trinktribunal/domain/models/domain_error.dart';
import 'package:trinktribunal/domain/models/game_mode.dart';

import '../domain/selection_support.dart';

void main() {
  late LocalSessionController controller;
  setUp(() {
    var id = 0;
    controller = LocalSessionController(
      questions: actualQuestions(),
      rules: actualRules(),
      random: TestRandom(),
      clock: () => now,
      newId: () => 'game${id++}',
    );
  });
  test('setup defaults and physical catalog bounds; invalid N=21 rejected', () {
    final defaults = controller.configure(playerCount: 8);
    expect(defaults.targetCases, 50);
    expect(defaults.requestedRuleEvents, 7);
    expect(defaults.factorTenths, 15);
    expect(defaults.maxSecretNumber, 12);
    expect(controller.capacity.questions, 431);
    expect(controller.capacity.rules, 22);
    expect(
      controller
          .configure(playerCount: 20, targetCases: 431, requestedRuleEvents: 22)
          .maxSecretNumber,
      30,
    );
    for (final n in [2, 21]) {
      expect(
        () => controller.configure(playerCount: n),
        throwsA(isA<DomainException>()),
      );
    }
    expect(controller.state, isNull);
  });
  test('complete short session then confirmed restart resets game, retains history', () {
    final config = controller.configure(
      playerCount: 3,
      targetCases: 3,
      requestedRuleEvents: 2,
    );
    controller.start(config);
    final firstId = controller.state!.id;
    final firstQuestion = controller.state!.currentQuestion!.entry.id;
    for (var i = 0; i < 3; i++) {
      final round = controller.state!.currentEventId;
      controller.completeCase(roundId: round, confirmed: true);
      controller.completeCase(roundId: round, confirmed: true);
      if (i < 2) {
        final rule = controller.state!.currentEventId;
        controller.continueAfterRule(rule);
        controller.continueAfterRule(rule);
      }
    }
    expect(controller.state!.phase, GamePhase.finished);
    expect(controller.history.entries.length, 5);
    expect(() => controller.start(config), throwsA(isA<DomainException>()));
    controller.start(config, confirmedRestart: true);
    expect(controller.state!.id, isNot(firstId));
    expect(controller.state!.completedCases, 0);
    expect(controller.state!.rules.active, isEmpty);
    expect(controller.state!.currentQuestion!.entry.id, isNot(firstQuestion));
    expect(controller.history.entries.length, 6);
  });
  test('cancelled completion/abort does not change state; explicit abort keeps history', () {
    controller.start(controller.configure(playerCount: 3));
    final initial = controller.state;
    controller.completeCase(roundId: initial!.currentEventId, confirmed: false);
    controller.abort(confirmed: false);
    expect(identical(initial, controller.state), true);
    controller.abort(confirmed: true);
    expect(controller.state, isNull);
    expect(controller.history.entries.length, 1);
    expect(
      () => controller.completeCase(roundId: 'old', confirmed: true),
      throwsA(isA<DomainException>()),
    );
  });
  test('start revalidates actual catalog capacity and rejects wrong mode', () {
    final small = LocalSessionController(
      questions: questions([questionJson('001-a')]),
      rules: [],
      newId: () => 'small',
    );
    final tooLarge = controller.configure(playerCount: 3);
    expect(() => small.start(tooLarge), throwsA(isA<DomainException>()));
    expect(small.state, isNull);
    final named = GameConfig(
      mode: GameMode.sharedPhone,
      playerCount: 3,
      capacity: CatalogCapacity(questions: 491, rules: 25),
    );
    expect(() => controller.start(named), throwsA(isA<DomainException>()));
  });
}
