import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trinktribunal/data/catalogs/catalog.dart';
import 'package:trinktribunal/data/catalogs/catalog_diagnostics.dart';
import 'package:trinktribunal/data/catalogs/catalog_repository.dart';

Map<String, dynamic> question() => {
  'version': 1,
  'language': 'de',
  'questions': [
    {
      'id': '001-a',
      'text': 'Frage',
      'scale': {'green': 'wenig', 'connector': 'bis', 'red': 'viel'},
    },
  ],
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'bundled assets load all four languages and filter named content',
    () async {
      final data = await CatalogRepository().load();
      for (final language in ['de', 'en']) {
        expect(data.questions[language]!.entries.length, 491);
        expect(data.questions[language]!.withoutPlayers.length, 431);
        expect(data.rules[language]!.entries.length, 29);
        expect(data.rules[language]!.withoutPlayers.length, 26);
      }
      expect(() => data.questions.clear(), throwsUnsupportedError);
      expect(
        () => data.questions['de']!.entries.clear(),
        throwsUnsupportedError,
      );
    },
  );
  test(
    'one supplied binding renders text and both scale ends consistently',
    () {
      final q = question();
      final entry = (q['questions'] as List).first as Map;
      entry['text'] = '{player1} und {player1}';
      entry['scale']['green'] = '{player1}';
      entry['scale']['red'] = '{player1}';
      entry['players'] = {
        'player1': {'selection': 'random'},
      };
      final parsed = parseQuestions(jsonEncode(q)).entries.single;
      final rendered = parsed.renderFor({'player1': 'Alex'});
      expect(rendered.text, 'Alex und Alex');
      expect(rendered.green, 'Alex');
      expect(rendered.red, 'Alex');
      expect(
        () => parsed.renderFor({}),
        throwsA(isA<CatalogFormatException>()),
      );
      expect(() => parsed.players.clear(), throwsUnsupportedError);
    },
  );
  test('scale-only role is allowed, undefined scale role rejected', () {
    final q = question();
    final entry = (q['questions'] as List).first as Map;
    entry['scale']['green'] = '{player1}';
    expect(
      () => parseQuestions(jsonEncode(q)),
      throwsA(isA<CatalogFormatException>()),
    );
    entry['players'] = {
      'player1': {'selection': 'random'},
    };
    expect(
      parseQuestions(jsonEncode(q)).entries.single
          .renderFor({'player1': 'Kim'})
          .green,
      'Kim',
    );
  });
  for (final source in [
    '{',
    '[]',
    '{}',
    '{"version":2,"language":"de","questions":[]}',
  ]) {
    test(
      'typed format error for $source',
      () => expect(
        () => parseQuestions(source),
        throwsA(isA<CatalogFormatException>()),
      ),
    );
  }
  test('reject duplicate IDs, unused roles and bad references', () {
    final q = question();
    final entries = q['questions'] as List;
    entries.add(entries.first);
    expect(
      () => parseQuestions(jsonEncode(q)),
      throwsA(isA<CatalogFormatException>()),
    );
    entries.removeLast();
    entries.first['players'] = {
      'player1': {'selection': 'random'},
    };
    expect(
      () => parseQuestions(jsonEncode(q)),
      throwsA(isA<CatalogFormatException>()),
    );
    entries.first['text'] = '{player1}';
    entries.first['players'] = {
      'player1': <String, dynamic>{
        'selection': 'random',
        'differentFrom': ['player1'],
      },
    };
    expect(
      () => parseQuestions(jsonEncode(q)),
      throwsA(isA<CatalogFormatException>()),
    );
  });
  test('rule exclusions require reciprocal existing other IDs', () {
    final r = {
      'version': 1,
      'language': 'de',
      'rules': [
        {
          'id': 'one',
          'text': 'Eins',
          'excludes': ['two'],
        },
        {'id': 'two', 'text': 'Zwei', 'excludes': <String>[]},
      ],
    };
    expect(
      () => parseRules(jsonEncode(r)),
      throwsA(isA<CatalogFormatException>()),
    );
    (r['rules'] as List).last['excludes'] = ['one'];
    expect(parseRules(jsonEncode(r)).entries.length, 2);
  });
  test('missing asset has typed path-bearing load error', () async {
    await expectLater(
      CatalogRepository(read: (path) async => throw StateError('missing'))
          .load(),
      throwsA(
        isA<CatalogLoadException>().having(
          (e) => e.path,
          'path',
          'assets/catalogs/manifest.json',
        ),
      ),
    );
  });
  test(
    'manifest ID drift and unsupported format fail with typed errors',
    () async {
      for (final version in [1, 2]) {
        final repo = CatalogRepository(
          read: (path) async {
            final data = await File(path).readAsString();
            if (!path.endsWith('manifest.json')) return data;
            final json = jsonDecode(data) as Map;
            json['version'] = version;
            json['catalogs'][0]['ids'] = ['missing'];
            return jsonEncode(json);
          },
        );
        await expectLater(repo.load(), throwsA(isA<CatalogFormatException>()));
      }
    },
  );
  testWidgets(
    'diagnostic displays helpful malformed fixture error and allows retry',
    (tester) async {
      var calls = 0;
      final container = ProviderContainer(
        overrides: [
          catalogRepositoryProvider.overrideWithValue(
            CatalogRepository(
              read: (path) async {
                calls++;
                return '{}';
              },
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: Scaffold(body: CatalogDiagnostics())),
        ),
      );
      await tester.tap(find.text('Katalogdiagnose'));
      await tester.runAsync(
        () => expectLater(
          container.read(catalogsProvider.future),
          throwsA(isA<CatalogFormatException>()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Katalogfehler'), findsOneWidget);
      expect(find.textContaining('Manifestformat'), findsOneWidget);
      await tester.tap(find.byTooltip('Erneut laden'));
      await tester.runAsync(
        () => expectLater(
          container.read(catalogsProvider.future),
          throwsA(isA<CatalogFormatException>()),
        ),
      );
      await tester.pumpAndSettle();
      expect(calls, 2);
    },
  );
}
