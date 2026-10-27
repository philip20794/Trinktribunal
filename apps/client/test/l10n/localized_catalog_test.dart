import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:trinktribunal/application/local_session_controller.dart';
import 'package:trinktribunal/application/settings_controller.dart';
import 'package:trinktribunal/data/catalogs/catalog_repository.dart';
import 'package:trinktribunal/data/catalogs/localized_catalog.dart';
import '../support/memory_string_store.dart';

void main() {
  test('all English question and rule IDs resolve to the same catalog identity', () async {
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
  });

  test('switching UI language does not draw again or mutate a running case', () async {
    final catalogs = await CatalogRepository(
      read: (path) async => File(path).readAsStringSync(),
    ).load();
    final game = LocalSessionController(
      questions: catalogs.questions['de']!.entries,
      rules: catalogs.rules['de']!.entries,
    );
    game.start(game.configure(playerCount: 8, targetCases: 3, requestedRuleEvents: 0));
    final id = game.state!.id.value;
    final questionId = game.state!.currentQuestion!.entry.id;
    final historyLength = game.history.entries.length;
    final settings = SettingsController(MemoryStringStore());
    await settings.load();
    await settings.update(language: 'en');
    final localized = localizedQuestion(
      catalogs, settings.value.language, game.state!.currentQuestion!.entry,
    );
    expect(localized.id, questionId);
    expect(game.state!.id.value, id);
    expect(game.state!.currentQuestion!.entry.id, questionId);
    expect(game.history.entries.length, historyLength);
  });
}
