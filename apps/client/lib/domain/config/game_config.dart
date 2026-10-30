import 'dart:math' as math;

import '../models/domain_error.dart';
import '../models/game_mode.dart';

/// The actual eligible catalog sizes, after filtering for the selected mode.
final class CatalogCapacity {
  CatalogCapacity({required this.questions, required this.rules}) {
    if (questions < 0 || rules < 0) {
      _invalid('Kataloggrößen dürfen nicht negativ sein.');
    }
  }

  final int questions;
  final int rules;
}

/// Options frozen at game start. No floating point factor or mutable DTO retained.
final class GameConfig {
  factory GameConfig({
    required GameMode mode,
    required int playerCount,
    required CatalogCapacity capacity,
    int targetCases = 50,
    int requestedRuleEvents = 7,
    int factorTenths = 20,
    bool allJudges = false,
    String contentLanguage = 'de',
  }) {
    if (playerCount < 3 || playerCount > 20) {
      _invalid('Es werden 3 bis 20 Spieler benötigt.');
    }
    if (targetCases < 1 ||
        targetCases > math.min(mode.maximumQuestions, capacity.questions)) {
      _invalid('Fallziel außerhalb des geeigneten Fragenbestands.');
    }
    if (requestedRuleEvents < 0 ||
        requestedRuleEvents > math.min(mode.maximumRules, capacity.rules)) {
      _invalid('Regelziel außerhalb des geeigneten Regelbestands.');
    }
    if (factorTenths < 10 || factorTenths > 30) {
      _invalid('Der Faktor muss in Zehnteln zwischen 10 und 30 liegen.');
    }
    if (allJudges && mode != GameMode.multiplayer) {
      _invalid('Alle sind Richter ist nur im Multiplayer verfügbar.');
    }
    if (contentLanguage != 'de' && contentLanguage != 'en') {
      _invalid('Nicht unterstützte Inhaltssprache.');
    }
    final maximum = (playerCount * factorTenths + 9) ~/ 10;
    if (maximum < playerCount - (allJudges ? 0 : 1)) {
      _invalid('Der Zahlenbereich reicht nicht für alle Empfänger.');
    }
    return GameConfig._(
      mode,
      playerCount,
      targetCases,
      requestedRuleEvents,
      factorTenths,
      allJudges,
      contentLanguage,
    );
  }

  const GameConfig._(
    this.mode,
    this.playerCount,
    this.targetCases,
    this.requestedRuleEvents,
    this.factorTenths,
    this.allJudges,
    this.contentLanguage,
  );

  factory GameConfig.fromJson(
    Map<String, Object?> json, {
    required CatalogCapacity capacity,
  }) {
    const fields = {
      'mode',
      'playerCount',
      'targetCases',
      'requestedRuleEvents',
      'factorTenths',
      'allJudges',
      'contentLanguage',
    };
    if (json.length != fields.length ||
        !json.keys.toSet().containsAll(fields)) {
      _invalid('Konfiguration enthält fehlende oder unbekannte Felder.');
    }
    final mode = GameMode.values
        .where((m) => m.value == json['mode'])
        .firstOrNull;
    if (mode == null ||
        json['allJudges'] is! bool ||
        json['contentLanguage'] is! String) {
      _invalid('Ungültiger Modus, Richteroption oder Inhaltssprache.');
    }
    int integer(String key) {
      final value = json[key];
      if (value is! int) _invalid('$key muss eine Ganzzahl sein.');
      return value;
    }

    return GameConfig(
      mode: mode,
      playerCount: integer('playerCount'),
      targetCases: integer('targetCases'),
      requestedRuleEvents: integer('requestedRuleEvents'),
      factorTenths: integer('factorTenths'),
      allJudges: json['allJudges'] as bool,
      contentLanguage: json['contentLanguage'] as String,
      capacity: capacity,
    );
  }

  final GameMode mode;
  final int playerCount;
  final int targetCases;
  final int requestedRuleEvents;
  final int factorTenths;
  final bool allJudges;
  final String contentLanguage;

  int get maxSecretNumber => (playerCount * factorTenths + 9) ~/ 10;
  int get numberRecipients => playerCount - (allJudges ? 0 : 1);
  int get scheduledRuleEventCount =>
      math.min(requestedRuleEvents, targetCases - 1);

  Map<String, Object> toJson() => {
    'mode': mode.value,
    'playerCount': playerCount,
    'targetCases': targetCases,
    'requestedRuleEvents': requestedRuleEvents,
    'factorTenths': factorTenths,
    'allJudges': allJudges,
    'contentLanguage': contentLanguage,
  };
}

Never _invalid(String message) =>
    throw DomainException(DomainErrorCode.invalidConfig, message);
