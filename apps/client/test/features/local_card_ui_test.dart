import 'package:trinktribunal/design/court_dialog.dart';

import '../support/roster_setup.dart';
import '../support/hold_action.dart';

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trinktribunal/application/local_data_providers.dart';
import 'package:trinktribunal/data/catalogs/catalog_repository.dart';
import 'package:trinktribunal/domain/local_game_reducer.dart';
import 'package:trinktribunal/domain/models/game_mode.dart';
import 'package:trinktribunal/features/setup/card_mode_screen.dart';
import 'package:trinktribunal/l10n/app_strings.dart';

import '../support/memory_atomic_state_storage.dart';
import '../support/memory_string_store.dart';

void main() {
  late Catalogs catalogs;
  setUpAll(() async {
    catalogs = await CatalogRepository(
      read: (path) => File(path).readAsString(),
    ).load();
  });
  for (final language in ['de', 'en']) {
    testWidgets(
      '50 cases + 7 rules with fresh-controller resume and fixed Next, $language, 200 percent',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(360, 800));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final storage = MemoryAtomicStateStorage(),
            strings = AppStrings(language);
        final containers = <ProviderContainer>[];
        addTearDown(() {
          for (final container in containers) {
            container.dispose();
          }
        });
        Future<ProviderContainer> mount() async {
          final container = ProviderContainer(
            overrides: [
              catalogsProvider.overrideWith((_) async => catalogs),
              stringStoreProvider.overrideWithValue(MemoryStringStore()),
              atomicStateStorageProvider.overrideWithValue(storage),
            ],
          );
          containers.add(container);
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
                  home: const CardModeScreen(),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          return container;
        }

        var container = await mount();
        await addTestPlayers(tester);
        final start = find.text(strings.get('startHearing'));
        await tester.ensureVisible(start);
        await Scrollable.ensureVisible(tester.element(start), alignment: .5);
        await tester.pumpAndSettle();
        expect(start.hitTestable(), findsOneWidget);
        await tester.tap(start);
        await tester.pumpAndSettle();
        var cards = container.read(localSessionProvider);
        expect(cards.state!.roster.map((p) => p.player.name), [
          'Alex',
          'Bea',
          'Cleo',
        ]);
        expect(cards.state!.judge!.player.name, 'Alex');
        expect(cards.state!.config.targetCases, 50);
        expect(cards.state!.config.requestedRuleEvents, 7);
        expect(
          container.read(profileProvider).asData?.value.profile,
          isNotNull,
        );
        Future<void> next() async {
          final target = find.text(
            strings.get(
              cards.state!.phase == GamePhase.ruleEvent
                  ? 'ruleUnderstood'
                  : 'nextCase',
            ),
          );
          expect(target.hitTestable(), findsOneWidget);
          if (cards.state!.phase == GamePhase.casePresented) {
            await holdAction(tester, target);
          } else {
            await tester.tap(target);
          }
          await tester.pumpAndSettle();
          expect(
            cards.state!.judge,
            cards.state!.roster[cards.state!.completedCases % 3],
          );
          expect(find.byType(CourtDialog), findsNothing);
          expect(tester.takeException(), isNull);
        }

        while (cards.state!.completedCases < 8) {
          await next();
        }
        await container.read(localStateTransactionProvider).save();
        final before = cards.toSnapshot();
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
        container = await mount();
        cards = container.read(localSessionProvider);
        expect(cards.toSnapshot(), before);
        while (cards.state!.phase != GamePhase.finished) {
          await next();
        }
        expect(cards.state!.completedCases, 50);
        expect(cards.state!.rules.active.length, 7);
        expect(
          cards.state!.lastCompletion,
          CaseCompletion.playedWithoutRecordedVerdict,
        );
        expect(cards.state!.manualErrors, isNull);
        expect(find.text(strings.get('nextCase')), findsNothing);
        expect(find.text(strings.get('gameFinishedBody')), findsOneWidget);
        expect(find.byTooltip(strings.get('activeRules')), findsNothing);
        await tester.tap(find.byKey(const ValueKey('finished-new-game')));
        await tester.pumpAndSettle();
        expect(cards.state, isNull);
        expect(find.text(strings.get('startHearing')), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
