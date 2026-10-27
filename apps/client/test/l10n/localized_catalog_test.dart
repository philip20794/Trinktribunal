import 'dart:io';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:trinktribunal/application/local_session_controller.dart';
import 'package:trinktribunal/application/settings_controller.dart';
import 'package:trinktribunal/application/shared_phone_controller.dart';
import 'package:trinktribunal/domain/avatar_config.dart';
import 'package:trinktribunal/domain/models/player.dart';
import 'package:trinktribunal/domain/user_profile.dart';

import '../domain/selection_support.dart';

import 'package:trinktribunal/data/catalogs/catalog_repository.dart';
import 'package:trinktribunal/data/catalogs/catalog.dart';
import 'package:trinktribunal/data/catalogs/localized_catalog.dart';

import '../support/memory_string_store.dart';

void main() {
  test('named case and active rule switch language with identical numbers, bindings and counters', () async {
    final catalogs = await CatalogRepository(
      read: (path) async => File(path).readAsStringSync(),
    ).load();
    final game = SharedPhoneController(
      questions: catalogs.questions['de']!.entries
          .where((q) => q.players.isNotEmpty)
          .take(3)
          .toList(),
      rules: catalogs.rules['de']!.entries,
      random: TestRandom(),
      clock: () => now,
      newId: () => 'language-switch',
    );
    game.start(
      config: game.configure(
        playerCount: 4,
        targetCases: 3,
        requestedRuleEvents: 2,
      ),
      roster: [
        for (final id in players)
          UserProfile(
            player: Player(id: id, name: id.value),
            avatar: AvatarConfig(),
          ),
      ],
    );
    final snapshot = jsonEncode(game.toSnapshot());
    final view = game.view!;
    final english = localizedQuestion(
      catalogs,
      'en',
      view.question!.entry as Question,
    ).renderFor(view.question!.names(view.names));
    expect(english.text, isNot((view.question!.entry as Question).text));
    expect(english.text, isNot(contains('{player')));
    expect(jsonEncode(game.toSnapshot()), snapshot);
    game.completeCase(view.roundId, confirmed: true, withoutVerdict: true);
    final rule = game.view!.newRule!;
    final afterRule = jsonEncode(game.toSnapshot());
    expect(
      localizedRule(catalogs, 'en', rule.entry as DrinkingRule).id,
      rule.entry.id,
    );
    expect(
      localizedRule(catalogs, 'en', rule.entry as DrinkingRule).text,
      isNot(rule.entry.text),
    );
    expect(jsonEncode(game.toSnapshot()), afterRule);
  });
  test(
    'all English question and rule IDs resolve to the same catalog identity',
    () async {
      final catalogs = await CatalogRepository(
        read: (path) async => File(path).readAsStringSync(),
      ).load();
      for (final question in catalogs.questions['de']!.entries) {
        expect(localizedQuestion(catalogs, 'en', question).id, question.id);
      }
      for (final rule in catalogs.rules['de']!.entries) {
        expect(localizedRule(catalogs, 'en', rule).id, rule.id);
      }
      expect(catalogs.questions['de']!.entries.length, 491);
      expect(catalogs.rules['en']!.entries.length, 25);
    },
  );

  test(
    'switching UI language does not draw again or mutate a running case',
    () async {
      final catalogs = await CatalogRepository(
        read: (path) async => File(path).readAsStringSync(),
      ).load();
      final game = LocalSessionController(
        questions: catalogs.questions['de']!.entries,
        rules: catalogs.rules['de']!.entries,
      );
      game.start(
        game.configure(playerCount: 8, targetCases: 3, requestedRuleEvents: 0),
      );
      final id = game.state!.id.value;
      final questionId = game.state!.currentQuestion!.entry.id;
      final historyLength = game.history.entries.length;
      final settings = SettingsController(MemoryStringStore());
      await settings.load();
      await settings.update(language: 'en');
      final localized = localizedQuestion(
        catalogs,
        settings.value.language,
        game.state!.currentQuestion!.entry as Question,
      );
      expect(localized.id, questionId);
      expect(game.state!.id.value, id);
      expect(game.state!.currentQuestion!.entry.id, questionId);
      expect(game.history.entries.length, historyLength);
    },
  );
}
