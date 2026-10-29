import '../support/shared_handoff.dart';

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trinktribunal/application/local_data_providers.dart';
import 'package:trinktribunal/application/local_session_controller.dart';
import 'package:trinktribunal/application/shared_phone_controller.dart';
import 'package:trinktribunal/data/catalogs/catalog_repository.dart';
import 'package:trinktribunal/data/protocol/room_message.dart';
import 'package:trinktribunal/domain/avatar_config.dart';
import 'package:trinktribunal/domain/models/ids.dart';
import 'package:trinktribunal/domain/models/player.dart';
import 'package:trinktribunal/domain/user_profile.dart';
import 'package:trinktribunal/features/handoff/shared_game_screen.dart';
import 'package:trinktribunal/features/setup/card_mode_screen.dart';
import 'package:trinktribunal/features/rules/game_rules_screen.dart';
import 'package:trinktribunal/application/room_providers.dart';
import 'package:trinktribunal/l10n/app_strings.dart';

import '../support/memory_atomic_state_storage.dart';
import '../support/memory_string_store.dart';
import 'online_numbers_test.dart' as online;

void main() {
  late Catalogs catalogs;
  setUpAll(() async {
    catalogs = await CatalogRepository(
      read: (path) async => File(path).readAsStringSync(),
    ).load();
    online.catalogs = catalogs;
  });
  for (final language in ['de', 'en']) {
    for (final shared in [false, true]) {
      testWidgets(
        'refreshes local question at 200 percent, shared=$shared, $language',
        (tester) async {
          final cards = LocalSessionController(
            questions: catalogs.questions['de']!.entries,
            rules: catalogs.rules['de']!.entries,
          );
          final phone = SharedPhoneController(
            questions: catalogs.questions['de']!.entries,
            rules: catalogs.rules['de']!.entries,
          );
          final roster = [
            for (final id in ['A', 'B', 'C', 'D'])
              UserProfile(
                player: Player(id: PlayerId(id), name: id),
                avatar: AvatarConfig(),
              ),
          ];
          final config = phone.configure(
            playerCount: 4,
            targetCases: 3,
            requestedRuleEvents: 2,
          );
          if (!shared) {
            cards.start(
              cards.configure(
                playerCount: 4,
                targetCases: 3,
                requestedRuleEvents: 2,
              ),
            );
          }
          if (shared) {
            phone.start(config: config, roster: roster);
            finishSharedNumbers(phone);
          }
          final container = ProviderContainer(
            overrides: [
              catalogsProvider.overrideWith((_) async => catalogs),
              localSessionProvider.overrideWithValue(cards),
              sharedPhoneControllerProvider.overrideWithValue(phone),
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
                  home: shared
                      ? SharedGameScreen(config: config, roster: roster)
                      : const CardModeScreen(),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final before = shared
              ? phone.view!.roundId
              : cards.state!.currentEventId;
          final numbers = phone.toSnapshot()?['numbers'];
          final tooltip = AppStrings(language).get('refreshQuestion');
          for (var i = 0; i < 2; i++) {
            await Scrollable.ensureVisible(
              tester.element(find.byTooltip(tooltip)),
              alignment: .5,
            );
            await tester.pumpAndSettle();
            await tester.tap(find.byTooltip(tooltip));
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
          }
          if (shared) {
            expect(phone.view!.roundId, isNot(before));
            expect(phone.view!.completedCases, 0);
            expect(phone.view!.visibleSecret, isNull);
            expect(phone.toSnapshot()!['numbers'], numbers);
          } else {
            expect(cards.state!.currentEventId, isNot(before));
            expect(cards.state!.completedCases, 0);
            expect(cards.history.entries, hasLength(3));
          }
          final saved = shared ? phone.toSnapshot() : cards.toSnapshot();
          await tester.tap(
            find.byTooltip(AppStrings(language).get('gameRules')),
          );
          await tester.pumpAndSettle();
          expect(find.byType(GameRulesScreen), findsOneWidget);
          expect(phone.view?.visibleSecret, isNull);
          await tester.tap(find.byKey(const ValueKey('rules-back')));
          await tester.pumpAndSettle();
          expect(shared ? phone.toSnapshot() : cards.toSnapshot(), saved);
        },
      );
    }
    for (final judge in [false, true]) {
      testWidgets(
        'online refresh availability and single pending command, judge=$judge, $language',
        (tester) async {
          final f = await online.pump(
            tester,
            host: judge,
            own: !judge,
            uiLanguage: language,
          );
          final button = find.byWidgetPredicate(
            (widget) =>
                widget is IconButton &&
                widget.tooltip == AppStrings(language).get('refreshQuestion'),
          );
          if (judge) {
            await Scrollable.ensureVisible(
              tester.element(button),
              alignment: .5,
            );
            await tester.pumpAndSettle();
            expect(tester.widget<IconButton>(button).onPressed, isNotNull);
          } else {
            expect(button, findsNothing);
          }
          if (judge) {
            await tester.tap(button);
            await tester.pump();
            expect(tester.widget<IconButton>(button).onPressed, isNull);
            expect(
              f.transport.sockets.last.sent.where(
                (m) => m.type == 'rerollCurrentQuestion',
              ),
              hasLength(1),
            );
            final before = f.room.state.snapshot!.public.toJson();
            f.transport.sockets.last.receive(
              ErrorMessage.create(
                requestId: RequestId('exhausted'),
                code: 'CONTENT_EXHAUSTED',
              ),
            );
            await tester.pumpAndSettle();
            expect(
              find.text(AppStrings(language).get('refreshNoQuestion')),
              findsOneWidget,
            );
            expect(f.room.state.snapshot!.public.toJson(), before);
            expect(tester.widget<IconButton>(button).onPressed, isNotNull);
          }
          final beforeRules = f.room.state.snapshot!.toJson();
          final container = ProviderScope.containerOf(
            tester.element(find.byType(GameRulesButton)),
          );
          final game = container.read(onlineGameProvider);
          game.revealOwnNumber();
          await tester.tap(
            find.byTooltip(AppStrings(language).get('gameRules')),
          );
          await tester.pumpAndSettle();
          expect(game.visibleNumber, isNull);
          expect(find.byType(GameRulesScreen), findsOneWidget);
          await tester.tap(find.byKey(const ValueKey('rules-back')));
          await tester.pumpAndSettle();
          expect(f.room.state.snapshot!.toJson(), beforeRules);
        },
      );
    }
  }
}
