import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trinktribunal/design/case_file.dart';
import 'package:trinktribunal/design/court_scene.dart';
import 'package:trinktribunal/design/court_theme.dart';
import 'package:trinktribunal/l10n/app_strings.dart';

void main() {
  for (final width in [320.0, 1440.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'long question keeps paper ink and reachable actions: $width / $scale',
        (tester) async {
          await tester.binding.setSurfaceSize(Size(width, 800));
          addTearDown(() => tester.binding.setSurfaceSize(null));
          var refreshes = 0, advances = 0;
          final question = List.filled(
            12,
            'Eine besonders lange Fallfrage mit Alexandra und Maximilian.',
          ).join(' ');
          await tester.pumpWidget(
            AppLanguageScope(
              language: 'de',
              child: MaterialApp(
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(textScaler: TextScaler.linear(scale)),
                  child: child!,
                ),
                home: CourtScaffold(
                  title: const Text('Fall'),
                  footer: CourtActionBar(
                    primary: CourtPrimaryButton(
                      onPressed: () => advances++,
                      child: const Text('Weiter'),
                    ),
                  ),
                  body: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: CourtQuestion(
                        label: 'Akte 1',
                        text: question,
                        green: 'Ein ausführliches grünes Skalenende mit vielen Einzelheiten',
                        connector: 'bis',
                        red: 'Ein ebenso ausführliches rotes Skalenende',
                        maximum: 60,
                        showRefresh: true,
                        onRefresh: () => refreshes++,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final text = tester.widget<Text>(find.text(question));
          expect(text.style!.color, CourtTokens.ink);
          final refresh = find.byType(IconButton);
          expect(
            tester.getCenter(refresh).dx,
            lessThan(tester.getCenter(find.text('AKTE 1')).dx),
          );
          await tester.tap(refresh);
          await tester.pumpAndSettle();
          expect(refreshes, 1);
          expect(find.text('Weiter').hitTestable(), findsOneWidget);
          await tester.tap(find.text('Weiter'));
          expect(advances, 1);
          final endpoint = find.text(
            'Ein ebenso ausführliches rotes Skalenende',
          );
          await tester.scrollUntilVisible(
            endpoint,
            400,
            scrollable: find.byType(Scrollable).first,
          );
          await tester.pumpAndSettle();
          expect(endpoint, findsOneWidget);
          expect(find.text('Weiter').hitTestable(), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
