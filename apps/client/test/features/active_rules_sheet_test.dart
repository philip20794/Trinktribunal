import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trinktribunal/design/court_scene.dart';
import 'package:trinktribunal/features/rules/active_rules_sheet.dart';
import 'package:trinktribunal/l10n/app_strings.dart';

import '../design/court_scene_test.dart' show reviewImage;

void main() {
  setUpAll(() async {
    if (const bool.fromEnvironment('TT_RENDER_REVIEW')) {
      final font = FontLoader('CourtRoboto');
      for (final weight in ['regular', 'medium', 'bold']) {
        font.addFont(rootBundle.load('assets/fonts/roboto-$weight.ttf'));
      }
      await font.load();
      await (FontLoader(
        'MaterialIcons',
      )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    }
  });
  for (final language in ['de', 'en']) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'active rules are dark and keep close reachable: $language/$scale',
        (tester) async {
          await tester.binding.setSurfaceSize(const Size(360, 800));
          addTearDown(() => tester.binding.setSurfaceSize(null));
          final rules = List.generate(
            12,
            (index) =>
                '$index. Jede Person beantwortet die Frage und hebt danach ihr Glas.',
          );
          await tester.pumpWidget(
            RepaintBoundary(
              key: const ValueKey('scene-review'),
              child: AppLanguageScope(
                language: language,
                child: MaterialApp(
                  theme: courtSceneTheme(),
                  builder: (context, child) => MediaQuery(
                    data: MediaQuery.of(context)
                        .copyWith(textScaler: TextScaler.linear(scale)),
                    child: child!,
                  ),
                  home: Scaffold(
                    body: Builder(
                      builder: (context) => TextButton(
                        onPressed: () =>
                            showActiveRuleList(context, rules: rules),
                        child: const Text('Open'),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.tap(find.text('Open'));
          await tester.pumpAndSettle();
          expect(
            tester
                .widget<BottomSheet>(find.byType(BottomSheet))
                .backgroundColor,
            CourtSceneTokens.night,
          );
          expect(
            DefaultTextStyle.of(tester.element(find.text(rules.first)))
                .style
                .color,
            CourtSceneTokens.cream,
          );
          final close = find.text(AppStrings(language).get('backToCase'));
          expect(close.hitTestable(), findsOneWidget);
          await reviewImage(
            tester,
            'dark-active-rules-$language-${scale.toInt()}',
          );
          await tester.scrollUntilVisible(
            find.text(rules.last),
            300,
            scrollable: find.byType(Scrollable).last,
          );
          expect(close.hitTestable(), findsOneWidget);
          await tester.tap(close);
          await tester.pumpAndSettle();
          expect(find.byType(BottomSheet), findsNothing);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
