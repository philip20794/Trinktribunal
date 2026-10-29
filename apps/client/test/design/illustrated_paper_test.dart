import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trinktribunal/design/case_file.dart';
import 'package:trinktribunal/design/court_assets.dart';
import 'package:trinktribunal/design/court_scene.dart';
import 'package:trinktribunal/design/illustrated_paper.dart';
import 'package:trinktribunal/l10n/app_strings.dart';

import 'court_scene_test.dart' show reviewImage;

class CountingBundle extends CachingAssetBundle {
  final loads = <String, int>{};
  @override
  Future<ByteData> load(String key) {
    loads.update(key, (value) => value + 1, ifAbsent: () => 1);
    return rootBundle.load(key);
  }
}

void main() {
  setUpAll(() async {
    if (const bool.fromEnvironment('TT_RENDER_REVIEW')) {
      final loader = FontLoader('CourtRoboto');
      for (final weight in ['regular', 'medium', 'bold']) {
        loader.addFont(rootBundle.load('assets/fonts/roboto-$weight.ttf'));
      }
      await loader.load();
    }
  });

  test('font fitting respects bounds and fits when the minimum fits', () {
    for (final scale in [1.0, 2.0]) {
      final scaler = TextScaler.linear(scale);
      for (final text in [
        'Kurz',
        List.filled(12, 'Lange Fallfrage').join(' '),
      ]) {
        const bounds = Size(260, 240);
        final size = fitPaperFont(text, bounds, scaler, TextDirection.ltr);
        expect(size, inInclusiveRange(16, 28));
        if (measurePaperText(text, 260, 16, scaler, TextDirection.ltr).height <=
            240) {
          expect(
            measurePaperText(text, 260, size, scaler, TextDirection.ltr).height,
            lessThanOrEqualTo(240),
          );
        } else {
          expect(size, 16);
        }
      }
    }
  });

  for (final language in ['de', 'en']) {
    testWidgets('decoded papers survive rounds, tabs and resize; $language', (
      tester,
    ) async {
      final bundle = CountingBundle();
      var rule = false, long = false, round = 1, scale = 1.0;
      late StateSetter update;
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        DefaultAssetBundle(
          bundle: bundle,
          child: AppLanguageScope(
            language: language,
            child: MaterialApp(
              home: PaperAssetWarmup(
                child: StatefulBuilder(
                  builder: (context, setState) {
                    update = setState;
                    final strings = AppStrings(language);
                    final text = long
                        ? List.filled(
                            18,
                            'Alexandra und Maximilian beantworten diese Frage.',
                          ).join(' ')
                        : 'Wie begrüßt du einen Richter auf einer Party?';
                    return MediaQuery(
                      data: MediaQuery.of(context)
                          .copyWith(textScaler: TextScaler.linear(scale)),
                      child: RepaintBoundary(
                        key: const ValueKey('scene-review'),
                        child: CourtScaffold(
                          title: Text(
                            rule ? strings.get('newRule') : 'Fallakte',
                          ),
                          footer: CourtActionBar(
                            primary: FilledButton(
                              onPressed: () {},
                              child: Text(strings.get('ruleUnderstood')),
                            ),
                          ),
                          body: SingleChildScrollView(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: rule
                                  ? CourtRule(text: text)
                                  : CourtQuestion(
                                      label: 'Fall $round / 10',
                                      text: text,
                                      green: 'Sehr freundlich',
                                      connector: 'bis',
                                      red: 'Sehr unfreundlich',
                                      maximum: 12,
                                      showRefresh: true,
                                      onRefresh: () {},
                                    ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      );
      await tester.runAsync(() async {
        final context = tester.element(find.byType(PaperAssetWarmup));
        await Future.wait(
          PaperImages.providers.map(
            (provider) => precacheImage(provider, context),
          ),
        );
      });
      await tester.pumpAndSettle();
      expect(
        tester.widget<RawImage>(find.byType(RawImage).last).image,
        isNotNull,
      );
      await reviewImage(tester, 'case-paper-$language');
      update(() {
        rule = true;
      });
      await tester.pumpAndSettle();
      await reviewImage(tester, 'rule-paper-$language');
      for (var i = 0; i < 12; i++) {
        update(() {
          rule = i.isEven;
          long = i > 3;
          round++;
          scale = 2;
        });
        await tester.binding.setSurfaceSize(Size(i.isEven ? 320 : 1440, 844));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(
          tester.widget<RawImage>(find.byType(RawImage).last).image,
          isNotNull,
        );
        final fitted = tester.widgetList<Text>(
          find.descendant(
            of: find.byType(FittedPaperText),
            matching: find.byType(Text),
          ),
        );
        expect(
          fitted.every(
            (t) => t.style!.fontSize! >= 14 && t.style!.fontSize! <= 28,
          ),
          isTrue,
        );
      }
      expect(bundle.loads[CourtAssets.caseSheet], 1);
      expect(bundle.loads[CourtAssets.ruleSheet], 1);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  }
}
