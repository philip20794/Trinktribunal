import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trinktribunal/application/local_data_providers.dart';
import 'package:trinktribunal/application/shared_phone_controller.dart';
import 'package:trinktribunal/data/catalogs/catalog_repository.dart';
import 'package:trinktribunal/design/case_file.dart';
import 'package:trinktribunal/design/private_number.dart';
import 'package:trinktribunal/domain/models/game_mode.dart';
import 'package:trinktribunal/features/handoff/shared_game_screen.dart';
import 'package:trinktribunal/l10n/app_strings.dart';

import '../application/shared_handoff_test.dart' show people;
import '../domain/selection_support.dart' show TestRandom;
import '../support/memory_atomic_state_storage.dart';
import '../support/memory_string_store.dart';

Future<void> tap(WidgetTester tester, String text) async {
  final finder = find.text(text);
  if (finder.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      finder,
      350,
      scrollable: find.byType(Scrollable).first,
    );
  }
  await Scrollable.ensureVisible(tester.element(finder), alignment: .5);
  await tester.pumpAndSettle();
  expect(finder.hitTestable(), findsOneWidget);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  late Catalogs catalogs;
  setUpAll(() async {
    catalogs = await CatalogRepository(
      read: (path) async => File(path).readAsStringSync(),
    ).load();
  });
  for (final count in [3, 20]) {
    for (final language in ['de', 'en']) {
      testWidgets(
        '$count duplicate names, $language, 200 percent: handoff, private hold and question rerolls and manual judge change',
        (tester) async {
          await tester.binding.setSurfaceSize(const Size(360, 800));
          addTearDown(() => tester.binding.setSurfaceSize(null));
          final game = SharedPhoneController(
            questions: catalogs.questions['de']!.entries,
            rules: catalogs.rules['de']!.entries,
            random: TestRandom(),
          );
          final roster = people(count), strings = AppStrings(language);
          final config = game.configure(
            playerCount: count,
            targetCases: 3,
            requestedRuleEvents: 0,
          );
          final container = ProviderContainer(
            overrides: [
              catalogsProvider.overrideWith((_) async => catalogs),
              sharedPhoneControllerProvider.overrideWithValue(game),
              atomicStateStorageProvider.overrideWithValue(
                MemoryAtomicStateStorage(),
              ),
              stringStoreProvider.overrideWithValue(MemoryStringStore()),
            ],
          );
          addTearDown(container.dispose);
          await container.read(catalogsProvider.future);
          await tester.pumpWidget(
            UncontrolledProviderScope(
              container: container,
              child: AppLanguageScope(
                language: language,
                child: MaterialApp(
                  builder: (context, child) => MediaQuery(
                    data: MediaQuery.of(context).copyWith(
                      textScaler: const TextScaler.linear(2),
                      disableAnimations: true,
                    ),
                    child: child!,
                  ),
                  home: SharedGameScreen(config: config, roster: roster),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.byType(CaseFile), findsNothing);
          expect(find.byType(HeldPrivateNumber), findsOneWidget);
          String identity() => strings.get('phoneIdentity', {
            'name': 'Alex',
            'seat':
                game.view!.roster.indexWhere(
                  (p) => p.player.id == game.view!.recipient,
                ) +
                1,
          });
          final first = game.view!;
          expect(find.byType(CaseFile), findsNothing);
          expect(find.byType(HeldPrivateNumber), findsOneWidget);
          final hold = find.text(strings.get('phoneHoldNumber'));
          await tester.scrollUntilVisible(hold, 350);
          await Scrollable.ensureVisible(tester.element(hold), alignment: .5);
          await tester.pumpAndSettle();
          expect(hold.hitTestable(), findsOneWidget);
          final gesture = await tester.startGesture(tester.getCenter(hold));
          await tester.pump();
          expect(game.view!.visibleSecret, isNotNull);
          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.inactive,
          );
          await tester.pumpAndSettle();
          expect(game.view!.visibleSecret, isNull);
          expect(game.view!.numberStage, SharedNumberStage.recipientHandoff);
          expect(game.view!.recipient, first.recipient);
          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.resumed,
          );
          await tester.pump();
          await gesture.up();
          await tap(tester, strings.get('phoneIAm', {'name': identity()}));
          Future<void> look() async {
            final hold = find.text(strings.get('phoneHoldNumber'));
            final gesture = await tester.startGesture(tester.getCenter(hold));
            await tester.pump();
            await gesture.up();
            await tester.pump();
          }

          await look();
          final done = find.ancestor(
            of: find.text(strings.get('phoneDoneNext')),
            matching: find.byType(FilledButton),
          );
          await tester.scrollUntilVisible(done, 350);
          final callback = tester.widget<FilledButton>(done).onPressed!;
          callback();
          callback();
          await tester.pumpAndSettle();
          expect(game.toSnapshot()!['handoffIndex'], 1);
          for (var i = 2; i < count; i++) {
            expect(find.byType(CaseFile), findsNothing);
            expect(find.byType(HeldPrivateNumber), findsNothing);
            await tap(tester, strings.get('phoneIAm', {'name': identity()}));
            await look();
            await tap(tester, strings.get('phoneDoneNext'));
            expect(game.view!.visibleSecret, isNull);
          }
          expect(game.view!.numberStage, SharedNumberStage.judgeHandoff);
          expect(game.view!.recipient, isNull);
          expect(find.byType(CaseFile), findsNothing);
          expect(find.byType(HeldPrivateNumber), findsNothing);
          await tap(
            tester,
            strings.get('phoneIAm', {
              'name': strings.get('phoneIdentity', {'name': 'Alex', 'seat': 1}),
            }),
          );
          expect(game.view!.phase, GamePhase.answers);
          expect(game.view!.completedCases, 0);
          expect(find.byType(CaseFile), findsOneWidget);
          Future<void> primary(String key) async {
            final button = find.text(strings.get(key));
            expect(button.hitTestable(), findsOneWidget);
            await tester.tap(button);
            await tester.pumpAndSettle();
          }

          final numbers = game.toSnapshot()!['numbers'];
          for (var i = 0; i < 3; i++) {
            final refresh = find.byTooltip(strings.get('refreshQuestion'));
            await tester.ensureVisible(refresh);
            await tester.tap(refresh);
            await tester.pumpAndSettle();
            expect(game.view!.phase, GamePhase.answers);
            expect(game.toSnapshot()!['numbers'], numbers);
            expect(find.byType(HeldPrivateNumber), findsNothing);
            expect(find.text(strings.get('phoneBeginOrder')), findsNothing);
          }
          expect(game.view!.verdict, isNull);
          await primary('phoneComplete');
          expect(game.view!.completedCases, 1);
          expect(game.view!.numberStage, SharedNumberStage.recipientNumber);
          expect(game.view!.recipient, first.judge);
          expect(find.byType(HeldPrivateNumber), findsOneWidget);
          expect(game.view!.visibleSecret, isNull);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
