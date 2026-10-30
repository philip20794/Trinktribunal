import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trinktribunal/design/court_dialog.dart';
import 'package:trinktribunal/design/court_scene.dart';
import 'package:trinktribunal/design/illustrated_paper.dart';
import 'package:trinktribunal/l10n/app_strings.dart';

import 'court_scene_test.dart' show reviewImage;
import '../features/ui_cleanup_test.dart' show host;

void main() {
  testWidgets(
    'real dialog actions are short, padded and retain their accessible meaning',
    (tester) async {
      await host(
        tester,
        CourtScaffold(
          bodyBuilder: (context) => Center(
            child: FilledButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (context) => CourtDialog(
                  title: const TText('roomCloseTitle'),
                  content: const TText('roomBackHostHelp'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const TText('cancel'),
                    ),
                    OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const TText('roomBackOnly'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(context),
                      child: const TText('roomClose'),
                    ),
                  ],
                ),
              ),
              child: const Text('Popup'),
            ),
          ),
        ),
        'de',
        size: const Size(390, 844),
      );
      await tester.tap(find.text('Popup'));
      await tester.pumpAndSettle();
      expect(find.text(const AppStrings('de').get('cancel')), findsNothing);
      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Löschen'), findsOneWidget);
      expect(find.byIcon(Icons.home_outlined), findsOneWidget);
      expect(find.byIcon(Icons.delete_outline_rounded), findsOneWidget);
      final destructive = tester.widget<Text>(find.text('Löschen'));
      expect(
        destructive.semanticsLabel,
        const AppStrings('de').get('roomClose'),
      );
      final paper = tester.getRect(find.byType(IllustratedPaper));
      final close = tester.getRect(
        find.byKey(const ValueKey('court-dialog-close')),
      );
      expect(paper.right - close.right, greaterThan(50));
      expect(close.top - paper.top, greaterThan(60));
      for (var frame = 0; frame < 3; frame++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pump();
      }
      await reviewImage(tester, 'compact-dialog-actions');
      await tester.tap(find.byKey(const ValueKey('court-dialog-close')));
      await tester.pumpAndSettle();
      expect(find.byType(CourtDialog), findsNothing);
    },
  );
  setUpAll(() async {
    if (!const bool.fromEnvironment('TT_RENDER_REVIEW')) return;
    final font = FontLoader('CourtRoboto');
    for (final weight in ['regular', 'medium', 'bold']) {
      font.addFont(rootBundle.load('assets/fonts/roboto-$weight.ttf'));
    }
    await font.load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });
  for (final scale in [1.0, 2.0]) {
    testWidgets(
      'parchment keeps actions reachable with long content at $scale',
      (tester) async {
        await host(
          tester,
          CourtScaffold(
            bodyBuilder: (context) => Center(
              child: FilledButton(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (context) => CourtDialog(
                    title: const Text('Zur laufenden Runde?'),
                    content: Text(
                      List.filled(
                        scale == 1 ? 1 : 12,
                        'Deine Runde bleibt gespeichert.',
                      ).join(' '),
                    ),
                    actions: [
                      OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Fortsetzen'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Neu starten'),
                      ),
                    ],
                  ),
                ),
                child: const Text('Popup'),
              ),
            ),
          ),
          'de',
          size: const Size(320, 640),
          scale: scale,
        );
        await tester.tap(find.text('Popup'));
        await tester.pumpAndSettle();
        expect(find.text('Fortsetzen').hitTestable(), findsOneWidget);
        expect(find.text('Neu starten').hitTestable(), findsOneWidget);
        expect(
          find.byKey(const ValueKey('court-dialog-close')).hitTestable(),
          findsOneWidget,
        );
        if (scale == 1) {
          expect(
            tester
                .getRect(find.widgetWithText(OutlinedButton, 'Fortsetzen'))
                .top,
            closeTo(
              tester
                  .getRect(find.widgetWithText(FilledButton, 'Neu starten'))
                  .top,
              2,
            ),
          );
        }
        for (var frame = 0; frame < 3; frame++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 50)),
          );
          await tester.pump();
        }
        await reviewImage(tester, 'parchment-dialog-${scale.toInt()}');
        await tester.tap(find.byKey(const ValueKey('court-dialog-close')));
        await tester.pumpAndSettle();
        expect(find.byType(CourtDialog), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
