import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:trinktribunal/domain/config/game_config.dart';
import 'package:trinktribunal/domain/models/domain_error.dart';
import 'package:trinktribunal/domain/models/game_mode.dart';

Map<String, dynamic> fixture(String name) => jsonDecode(
  File('../../packages/protocol/fixtures/rules/$name.json').readAsStringSync(),
) as Map<String, dynamic>;

final capacity = CatalogCapacity(questions: 491, rules: 25);
final invalidConfig = isA<DomainException>().having(
  (e) => e.code,
  'code',
  DomainErrorCode.invalidConfig,
);

GameConfig configFromFixture(Map<String, dynamic> input) => GameConfig.fromJson(
  {
    for (final entry in input.entries)
      if (entry.key != 'eligibleQuestions' && entry.key != 'eligibleRules')
        entry.key: entry.value,
    'contentLanguage': 'de',
  },
  capacity: CatalogCapacity(
    questions: input['eligibleQuestions'] as int,
    rules: input['eligibleRules'] as int,
  ),
);

void main() {
  test('shared config-default fixture runs against the Dart domain', () {
    final data = fixture('config-default');
    final config = configFromFixture(data['input'] as Map<String, dynamic>);
    final expected = data['expected'] as Map<String, dynamic>;
    expect(
      GameConfig(
        mode: GameMode.sharedPhone,
        playerCount: 8,
        capacity: capacity,
      ).toJson(),
      config.toJson(),
    );
    expect(config.targetCases, 50);
    expect(config.requestedRuleEvents, 7);
    expect(config.factorTenths, 15);
    expect(config.maxSecretNumber, expected['maxSecretNumber']);
    expect(config.numberRecipients, expected['numberRecipients']);
    expect(config.scheduledRuleEventCount, expected['scheduledRuleEventCount']);
  });

  test('shared config boundary fixtures', () {
    final data = fixture('config-bounds');
    final inputs = data['input']['cases'] as List;
    final expected = data['expected']['cases'] as List;
    for (var i = 0; i < inputs.length; i++) {
      final input = inputs[i] as Map<String, dynamic>;
      if (expected[i]['valid'] == false) {
        expect(() => configFromFixture(input), throwsA(invalidConfig));
      } else {
        final config = configFromFixture(input);
        expect(config.maxSecretNumber, expected[i]['maxSecretNumber']);
        expect(config.numberRecipients, expected[i]['numberRecipients']);
        expect(
          config.scheduledRuleEventCount,
          expected[i]['scheduledRuleEventCount'],
        );
      }
    }
  });

  test(
    'every player/factor combination rounds up using integer arithmetic',
    () {
      for (var n = 3; n <= 20; n++) {
        for (var factor = 10; factor <= 30; factor++) {
          for (final allJudges in [false, true]) {
            final config = GameConfig(
              mode: GameMode.multiplayer,
              playerCount: n,
              capacity: capacity,
              factorTenths: factor,
              allJudges: allJudges,
            );
            expect(config.maxSecretNumber, (n * factor / 10).ceil());
            expect(config.numberRecipients, n - (allJudges ? 0 : 1));
            expect(
              config.maxSecretNumber,
              greaterThanOrEqualTo(config.numberRecipients),
            );
          }
        }
      }
    },
  );

  test('shared N=20 number-bound fixture', () {
    final data = fixture('secret-number-bounds');
    final input = data['input'];
    final limits = [
      for (final factor in input['factorTenths'] as List)
        GameConfig(
          mode: GameMode.sharedPhone,
          playerCount: input['playerCount'] as int,
          factorTenths: factor as int,
          capacity: capacity,
        ).maxSecretNumber,
    ];
    expect(limits, data['expected']['maxSecretNumbers']);
  });

  for (final mode in GameMode.values) {
    test('${mode.value}: minimum and maximum values', () {
      final minimum = GameConfig(
        mode: mode,
        playerCount: 3,
        targetCases: 1,
        requestedRuleEvents: 0,
        factorTenths: 10,
        capacity: capacity,
      );
      expect(minimum.scheduledRuleEventCount, 0);
      final maximum = GameConfig(
        mode: mode,
        playerCount: 20,
        targetCases: mode.maximumQuestions,
        requestedRuleEvents: mode.maximumRules,
        factorTenths: 30,
        contentLanguage: 'en',
        capacity: capacity,
      );
      expect(maximum.maxSecretNumber, 60);
      expect(maximum.scheduledRuleEventCount, mode.maximumRules);
      for (final entry in {
        'playerCount': [2, 21],
        'targetCases': [0, mode.maximumQuestions + 1],
        'requestedRuleEvents': [-1, mode.maximumRules + 1],
        'factorTenths': [9, 31],
      }.entries) {
        for (final value in entry.value) {
          expect(
            () => GameConfig.fromJson({
              ...maximum.toJson(),
              entry.key: value,
            }, capacity: capacity),
            throwsA(invalidConfig),
            reason: '${entry.key}=$value',
          );
        }
      }
    });
  }

  test('rule request is preserved but scheduled slots are bounded by F-1', () {
    final data = fixture('schedule-edge');
    final cases = data['input']['cases'] as List;
    final expected = data['expected']['cases'] as List;
    for (var i = 0; i < cases.length; i++) {
      final input = cases[i];
      final config = GameConfig(
        mode: GameMode.physicalCards,
        playerCount: 3,
        capacity: capacity,
        targetCases: input['targetCases'] as int,
        requestedRuleEvents: input['requestedRuleEvents'] as int,
      );
      expect(config.requestedRuleEvents, input['requestedRuleEvents']);
      expect(config.scheduledRuleEventCount, expected[i]['effectiveRuleSlots']);
    }
  });

  test(
    'actual catalog capacity constrains targets independently of mode limits',
    () {
      final small = CatalogCapacity(questions: 5, rules: 2);
      final config = GameConfig(
        mode: GameMode.sharedPhone,
        playerCount: 3,
        targetCases: 5,
        requestedRuleEvents: 2,
        capacity: small,
      );
      expect(config.scheduledRuleEventCount, 2);
      expect(
        () => GameConfig.fromJson({
          ...config.toJson(),
          'targetCases': 6,
        }, capacity: small),
        throwsA(invalidConfig),
      );
      expect(
        () => GameConfig.fromJson({
          ...config.toJson(),
          'requestedRuleEvents': 3,
        }, capacity: small),
        throwsA(invalidConfig),
      );
      expect(
        () => GameConfig(
          mode: GameMode.sharedPhone,
          playerCount: 3,
          capacity: small,
        ),
        throwsA(invalidConfig),
      );
      expect(
        () => CatalogCapacity(questions: -1, rules: 0),
        throwsA(invalidConfig),
      );
      expect(
        () => CatalogCapacity(questions: 1, rules: -1),
        throwsA(invalidConfig),
      );
      expect(
        () => GameConfig(
          mode: GameMode.physicalCards,
          playerCount: 3,
          targetCases: 1,
          requestedRuleEvents: 0,
          capacity: CatalogCapacity(questions: 0, rules: 0),
        ),
        throwsA(invalidConfig),
      );
    },
  );

  test('all judges is rejected in both local modes', () {
    for (final mode in [GameMode.physicalCards, GameMode.sharedPhone]) {
      expect(
        () => GameConfig(
          mode: mode,
          playerCount: 3,
          allJudges: true,
          capacity: capacity,
        ),
        throwsA(invalidConfig),
      );
    }
  });

  test('DTO import rejects missing, unknown and incorrectly typed values', () {
    final valid = GameConfig(
      mode: GameMode.sharedPhone,
      playerCount: 8,
      capacity: capacity,
    ).toJson();
    for (final key in valid.keys) {
      final missing = Map<String, Object?>.of(valid)..remove(key);
      expect(
        () => GameConfig.fromJson(missing, capacity: capacity),
        throwsA(invalidConfig),
        reason: 'missing $key',
      );
      expect(
        () => GameConfig.fromJson({...valid, key: null}, capacity: capacity),
        throwsA(invalidConfig),
        reason: 'null $key',
      );
    }
    for (final field in [
      'playerCount',
      'targetCases',
      'requestedRuleEvents',
      'factorTenths',
    ]) {
      for (final value in <Object>[
        double.nan,
        double.infinity,
        double.negativeInfinity,
        15.0,
        15.5,
        '15',
        true,
        [],
        {},
      ]) {
        expect(
          () =>
              GameConfig.fromJson({...valid, field: value}, capacity: capacity),
          throwsA(invalidConfig),
          reason: '$field=$value',
        );
      }
    }
    for (final change in <Map<String, Object?>>[
      {'unexpected': 1},
      {'mode': 'unknown'},
      {'mode': 1},
      {'allJudges': 'false'},
      {'allJudges': 0},
      {'contentLanguage': 'fr'},
      {'contentLanguage': 1},
    ]) {
      expect(
        () => GameConfig.fromJson({...valid, ...change}, capacity: capacity),
        throwsA(invalidConfig),
      );
    }
  });

  test('round trip and mutable DTOs cannot modify frozen options', () {
    final config = GameConfig(
      mode: GameMode.multiplayer,
      playerCount: 8,
      allJudges: true,
      contentLanguage: 'en',
      capacity: capacity,
    );
    final dto = config.toJson();
    final imported = GameConfig.fromJson(dto, capacity: capacity);
    expect(imported.toJson(), jsonDecode(jsonEncode(dto)));
    dto['factorTenths'] = 30;
    expect(imported.factorTenths, 15);
    expect(config.factorTenths, 15);
    // Runtime mutation must also fail, even when static typing is bypassed.
    expect(
      () => (config as dynamic).factorTenths = 30,
      throwsNoSuchMethodError,
    );
  });

  test('domain has no Flutter, Riverpod or IO imports', () {
    for (final file
        in Directory('lib/domain')
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) => f.path.endsWith('.dart'))) {
      final imports = RegExp(r'''(?:import|export)\s+['"]([^'"]+)['"]''')
          .allMatches(file.readAsStringSync());
      for (final match in imports) {
        expect(
          match[1],
          isNot(
            anyOf(
              startsWith('package:flutter'),
              startsWith('package:riverpod'),
              'dart:io',
              'dart:html',
              startsWith('dart:ui'),
            ),
          ),
          reason: file.path,
        );
      }
    }
  });
}
