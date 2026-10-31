import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trinktribunal/design/court_theme.dart';
import 'package:trinktribunal/design/game_settings_panel.dart';
import 'package:trinktribunal/features/setup/player_roster.dart';
import 'package:trinktribunal/l10n/app_strings.dart';

import 'court_scene_test.dart' show reviewImage;

Future<void> pumpSettings(
  WidgetTester tester, {
  Size size = const Size(390, 844),
  String language = 'de',
  double textScale = 1,
  Widget? child,
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    AppLanguageScope(
      language: language,
      child: MaterialApp(
        theme: courtTheme(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: RepaintBoundary(
            key: const ValueKey('scene-review'),
            child: child!,
          ),
        ),
        home:
            child ??
            const LocalGameOptionsScreen(cases: 50, rules: 7, factor: 20),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    final fonts = FontLoader('CourtRoboto');
    for (final weight in ['regular', 'medium', 'bold']) {
      fonts.addFont(rootBundle.load('assets/fonts/roboto-$weight.ttf'));
    }
    await fonts.load();
    final icons = FontLoader('MaterialIcons');
    icons.addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
  });

  for (final language in ['de', 'en']) {
    for (final width in [280.0, 320.0, 390.0, 600.0]) {
      for (final scale in [1.0, 2.0]) {
        testWidgets('online five-row paper: $language/$width/$scale', (
          tester,
        ) async {
          await pumpSettings(
            tester,
            size: Size(width, 900),
            language: language,
            textScale: scale,
            child: Scaffold(
              body: ListView(
                children: [
                  GameSettingsPanel(
                    cases: 50,
                    rules: 7,
                    factorTenths: 40,
                    maxCases: 150,
                    maxRules: 25,
                    allJudges: true,
                    contentLanguage: 'de',
                    onAllJudgesChanged: (_) {},
                    onLanguageChanged: (_) {},
                    onCasesChanged: (_) {},
                    onRulesChanged: (_) {},
                    onFactorChanged: (_) {},
                  ),
                ],
              ),
            ),
          );
          final content = tester.getRect(
            find.byKey(const ValueKey('game-settings-content')),
          );
          for (final control in [Switch, DropdownButton<String>, Slider]) {
            for (final element in find.byType(control).evaluate()) {
              final rect = tester.getRect(find.byWidget(element.widget));
              expect(content.inflate(.1).contains(rect.topLeft), isTrue);
              expect(content.inflate(.1).contains(rect.bottomRight), isTrue);
            }
          }
          expect(find.text('4×'), findsOneWidget);
          expect(tester.takeException(), isNull);
          if ((language == 'de' && scale == 1) ||
              (language == 'en' && width == 320 && scale == 2)) {
            await reviewImage(
              tester,
              'settings-online-$language-${width.toInt()}-${scale.toInt()}',
            );
          }
        });
      }
    }
  }
  testWidgets('running game keeps the whole paper visible and disabled', (
    tester,
  ) async {
    await pumpSettings(
      tester,
      child: Scaffold(
        body: GameSettingsPanel(
          cases: 50,
          rules: 7,
          factorTenths: 20,
          maxCases: 150,
          maxRules: 25,
          allJudges: true,
          contentLanguage: 'en',
          enabled: false,
          onAllJudgesChanged: (_) => fail('Disabled toggle'),
          onLanguageChanged: (_) => fail('Disabled language'),
          onCasesChanged: (_) => fail('Disabled cases'),
          onRulesChanged: (_) => fail('Disabled rules'),
          onFactorChanged: (_) => fail('Disabled factor'),
        ),
      ),
    );
    expect(find.byKey(const ValueKey('game-settings-paper')), findsOneWidget);
    expect(tester.widget<Switch>(find.byType(Switch)).onChanged, isNull);
    expect(
      tester
          .widget<DropdownButton<String>>(find.byType(DropdownButton<String>))
          .onChanged,
      isNull,
    );
    for (final slider in tester.widgetList<Slider>(find.byType(Slider))) {
      expect(slider.onChanged, isNull);
    }
    expect(tester.takeException(), isNull);
  });

  for (final language in ['de', 'en']) {
    for (final width in [280.0, 320.0, 390.0, 600.0]) {
      for (final scale in [1.0, 2.0]) {
        testWidgets('settings stay on the paper: $language/$width/$scale', (
          tester,
        ) async {
          await pumpSettings(
            tester,
            size: Size(width, 900),
            language: language,
            textScale: scale,
          );
          final content = tester.getRect(
            find.byKey(const ValueKey('game-settings-content')),
          );
          for (final id in ['cases', 'rules', 'numbers']) {
            for (final part in ['value', 'slider']) {
              final rect = tester.getRect(
                find.byKey(ValueKey('settings-$id-$part')),
              );
              expect(content.inflate(.1).contains(rect.topLeft), isTrue);
              expect(content.inflate(.1).contains(rect.bottomRight), isTrue);
            }
          }
          final contents = find.byKey(const ValueKey('game-settings-content'));
          for (final type in [Text, Image, Icon]) {
            for (final element
                in find
                    .descendant(of: contents, matching: find.byType(type))
                    .evaluate()) {
              final rect = tester.getRect(find.byWidget(element.widget));
              expect(content.inflate(.1).contains(rect.topLeft), isTrue);
              expect(content.inflate(.1).contains(rect.bottomRight), isTrue);
            }
          }
          expect(find.text('2×'), findsOneWidget);
          final example = AppStrings(language)
              .get('settingsNumberExample', {'count': 6, 'maximum': 12});
          expect(find.text(example), findsNothing);
          final cases = tester.widget<Slider>(
            find.byKey(const ValueKey('settings-cases-slider')),
          );
          expect((cases.min, cases.max, cases.divisions), (10.0, 150.0, 140));
          final numbers = tester.widget<Slider>(
            find.byKey(const ValueKey('settings-numbers-slider')),
          );
          expect(
            (numbers.min, numbers.max, numbers.divisions),
            (10.0, 40.0, 6),
          );
          expect(tester.takeException(), isNull);
          if ((language == 'de' && scale == 1) ||
              (language == 'en' && width == 320 && scale == 2)) {
            await reviewImage(
              tester,
              'settings-$language-${width.toInt()}-${scale.toInt()}',
            );
          }
          await tester.pumpWidget(const SizedBox());
        });
      }
    }
  }

  testWidgets(
    'short screens scroll the whole paper and keep the controls reachable',
    (tester) async {
      await pumpSettings(tester, size: const Size(320, 480), textScale: 2);
      final numbers = find.byKey(const ValueKey('settings-numbers-slider'));
      await tester.ensureVisible(numbers);
      await tester.pumpAndSettle();
      expect(numbers.hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'drag updates the multiplier in half steps, apply returns existing values',
    (tester) async {
      ({int cases, int rules, int factor})? result;
      await pumpSettings(
        tester,
        child: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                result =
                    await Navigator.push<({int cases, int rules, int factor})>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const LocalGameOptionsScreen(
                          cases: 50,
                          rules: 7,
                          factor: 20,
                          playerCount: 7,
                        ),
                      ),
                    );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      final slider = find.byKey(const ValueKey('settings-numbers-slider'));
      await tester.drag(slider, const Offset(30, 0));
      await tester.pump();
      final changed = tester.widget<Slider>(slider).value.round();
      expect(changed, greaterThan(20));
      expect(
        find.text(
          'Bei 7 Spielern: Karten von 1 bis ${(7 * changed + 9) ~/ 10}',
        ),
        findsNothing,
      );
      expect(changed % 5, 0);
      expect(find.text('2×'), findsNothing);
      final label = find.text(const AppStrings('de').get('rosterApply'));
      await tester.tap(label);
      await tester.pumpAndSettle();
      expect(result, (cases: 50, rules: 7, factor: changed));
    },
  );

  testWidgets('ten cases clamp additional rules to nine; help still opens', (
    tester,
  ) async {
    await pumpSettings(tester);
    final cases = tester.widget<Slider>(
      find.byKey(const ValueKey('settings-cases-slider')),
    );
    tester
        .widget<Slider>(find.byKey(const ValueKey('settings-rules-slider')))
        .onChanged!(25);
    await tester.pump();
    cases.onChanged!(10);
    await tester.pump();
    final rules = tester.widget<Slider>(
      find.byKey(const ValueKey('settings-rules-slider')),
    );
    expect(rules.value, 9);
    expect(rules.onChanged, isNotNull);
    final help = const AppStrings('de').get('localFactorHelp');
    await tester.tap(find.byTooltip(help));
    await tester.pumpAndSettle();
    expect(find.text(help), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
