import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trinktribunal/application/local_data_providers.dart';
import 'package:trinktribunal/application/shared_phone_controller.dart';
import 'package:trinktribunal/design/case_file.dart';
import 'package:trinktribunal/design/private_number.dart';
import 'package:trinktribunal/features/home/home_screen.dart';
import 'package:trinktribunal/features/home/mode_preview_screen.dart';
import 'package:trinktribunal/features/handoff/shared_game_screen.dart';
import 'package:trinktribunal/features/setup/card_mode_screen.dart';
import 'package:trinktribunal/features/setup/player_roster.dart';
import 'package:trinktribunal/l10n/app_strings.dart';

import '../data/local_state_transaction_test.dart' show Harness;
import '../support/memory_atomic_state_storage.dart';
import '../support/memory_string_store.dart';
import '../design/court_scene_test.dart' show reviewImage;
import 'ui_cleanup_test.dart' show host;
import 'home_profile_settings_test.dart' show tapVisible;

const review = bool.fromEnvironment('TT_RENDER_REVIEW');
void main() {
  setUpAll(() async {
    if (!review) return;
    final font = FontLoader('CourtRoboto');
    for (final weight in ['regular', 'medium', 'bold']) {
      font.addFont(rootBundle.load('assets/fonts/roboto-$weight.ttf'));
    }
    await font.load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });

  for (final cardMode in [true, false]) {
    test(
      'new game resets only its selected mode, recovery slot and no draw history; failed reset restores memory: cards=$cardMode',
      () async {
        final storage = MemoryAtomicStateStorage(), h = Harness(storage);
        h.startCards();
        h.startPhone();
        await h.transaction.save();
        final card = h.cards.state!.currentEventId,
            phone = h.phone.view!.roundId;
        final history = h.history.history.entries.length;
        storage.failAfterBackup = true;
        expect(await h.transaction.resetGame(cardMode: cardMode), isFalse);
        expect(h.cards.state!.currentEventId, card);
        expect(h.phone.view!.roundId, phone);
        storage.failAfterBackup = false;
        expect(await h.transaction.resetGame(cardMode: cardMode), isTrue);
        for (final raw in await storage.readCandidates()) {
          final data = jsonDecode(raw);
          expect(data[cardMode ? 'cards' : 'shared'], isNull);
          expect(data[cardMode ? 'shared' : 'cards'], isNotNull);
        }
        expect(h.history.history.entries.length, history);
      },
    );

    testWidgets(
      'home asks continue/new, cancellation and resume preserve both games: cards=$cardMode',
      (tester) async {
        const strings = AppStrings('de');
        await host(tester, const HomeScreen(), 'de');
        final container = ProviderScope.containerOf(
          tester.element(find.byType(HomeScreen)),
        );
        await container.read(localResumeProvider.future);
        final roster = await container.read(rosterProvider.future);
        for (final name in ['Alex', 'Bea', 'Cleo']) {
          await roster.add(name);
        }
        final cards = container.read(localSessionProvider),
            phone = container.read(sharedPhoneControllerProvider);
        cards.start(
          cards.configure(
            playerCount: 3,
            targetCases: 3,
            requestedRuleEvents: 1,
          ),
        );
        phone.start(
          config: phone.configure(
            playerCount: 3,
            targetCases: 3,
            requestedRuleEvents: 1,
          ),
          roster: roster.members,
        );
        await container.read(localStateTransactionProvider).save();
        final cardId = cards.state!.currentEventId,
            phoneId = phone.view!.roundId;
        final entry = find.text(
          strings.get(cardMode ? 'modeCards' : 'modePhone'),
        );
        await tapVisible(tester, entry);
        expect(find.byType(AlertDialog), findsOneWidget);
        await reviewImage(tester, 'phone-resume-$cardMode');
        await tester.tap(find.text(strings.get('cancel')));
        await tester.pumpAndSettle();
        expect(cards.state!.currentEventId, cardId);
        expect(phone.view!.roundId, phoneId);
        await tapVisible(tester, entry);
        await tester.tap(find.text(strings.get('resumeGame')));
        await tester.pumpAndSettle();
        expect(
          find.byType(cardMode ? CardModeScreen : SharedGameScreen),
          findsOneWidget,
        );
        expect(find.byType(ModePreviewScreen), findsNothing);
        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();
        await tapVisible(tester, entry);
        await tester.tap(
          find.widgetWithText(FilledButton, strings.get('newGame')),
        );
        await tester.pumpAndSettle();
        expect(find.byType(ModePreviewScreen), findsOneWidget);
        expect(cardMode ? cards.state == null : phone.view == null, isTrue);
        expect(
          cardMode ? phone.view!.roundId : cards.state!.currentEventId,
          cardMode ? phoneId : cardId,
        );
        expect(roster.members.length, 3);
        await tester.tap(find.text(strings.get('introContinue')));
        await tester.pumpAndSettle();
        expect(
          find.byType(cardMode ? CardModeScreen : PlayerRosterScreen),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final language in ['de', 'en']) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'shared setup, settings, handoff and private hold $language/$scale',
        (tester) async {
          final strings = AppStrings(language);
          await host(
            tester,
            const PlayerRosterScreen(),
            language,
            scale: scale,
            size: const Size(390, 844),
          );
          expect(find.byType(Slider), findsNothing);
          final container = ProviderScope.containerOf(
            tester.element(find.byType(PlayerRosterScreen)),
          );
          for (final name in ['Alex', 'Bea', 'Cleo']) {
            await tester.enterText(
              find.byKey(const ValueKey('quick-player-name')),
              name,
            );
            await tester.testTextInput.receiveAction(TextInputAction.done);
            await tester.pumpAndSettle();
          }
          tester.testTextInput.hide();
          FocusManager.instance.primaryFocus?.unfocus();
          await tester.pumpAndSettle();
          await reviewImage(tester, 'phone-list-$language-${scale.toInt()}');
          await tapVisible(tester, find.text(strings.get('localGameOptions')));
          expect(find.byType(Slider), findsNWidgets(3));
          await reviewImage(tester, 'phone-options-$language-${scale.toInt()}');
          tester.widgetList<Slider>(find.byType(Slider)).first.onChanged!(3);
          await tester.pumpAndSettle();
          await tester.tap(find.text(strings.get('rosterApply')));
          await tester.pumpAndSettle();
          expect(find.byType(Slider), findsNothing);
          await tester.tap(find.text(strings.get('startHearing')));
          await tester.pumpAndSettle();
          final game = container.read(sharedPhoneControllerProvider);
          expect(game.view!.config.targetCases, 3);
          await reviewImage(
            tester,
            'phone-question-$language-${scale.toInt()}',
          );
          expect(find.text('bis'), findsNothing);
          expect(
            find.text(strings.get('questionRange', {'max': 5})),
            findsOneWidget,
          );
          await tapVisible(tester, find.text(strings.get('phoneStartNumbers')));
          expect(game.view!.numberStage, SharedNumberStage.recipientHandoff);
          await reviewImage(tester, 'phone-handoff-$language-${scale.toInt()}');
          expect(find.byType(CourtQuestion), findsNothing);
          final name = game.view!.name(game.view!.recipient!);
          await tester.tap(find.text(strings.get('phoneIAm', {'name': name})));
          await tester.pumpAndSettle();
          expect(find.text(strings.get('yourNumber')), findsOneWidget);
          final done = find.widgetWithText(
            FilledButton,
            strings.get('phoneDoneNext'),
          );
          expect(tester.widget<FilledButton>(done).onPressed, isNull);
          await reviewImage(
            tester,
            'phone-secret-hidden-$language-${scale.toInt()}',
          );
          final reveal = find.text(strings.get('phoneHoldNumber'));
          expect(reveal.hitTestable(), findsOneWidget);
          expect(done.hitTestable(), findsOneWidget);
          final gesture = await tester.startGesture(tester.getCenter(reveal));
          await tester.pump();
          expect(game.view!.visibleSecret, isNotNull);
          await reviewImage(
            tester,
            'phone-secret-visible-$language-${scale.toInt()}',
          );
          await gesture.up();
          await tester.pumpAndSettle();
          expect(game.view!.visibleSecret, isNull);
          expect(tester.widget<FilledButton>(done).onPressed, isNotNull);
          await tester.tap(done);
          await tester.pumpAndSettle();
          expect(find.byType(HeldPrivateNumber), findsNothing);
          expect(game.view!.numberStage, SharedNumberStage.recipientHandoff);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets(
    'actual drag handle reorders compact rows without changing identities',
    (tester) async {
      await host(tester, const PlayerRosterScreen(allowStart: false), 'de');
      final container = ProviderScope.containerOf(
        tester.element(find.byType(PlayerRosterScreen)),
      );
      final roster = await container.read(rosterProvider.future);
      for (final name in ['Alex', 'Bea', 'Cleo']) {
        await tester.enterText(
          find.byKey(const ValueKey('quick-player-name')),
          name,
        );
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pumpAndSettle();
      }
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      final before = roster.members.toList();
      final handle = find.descendant(
        of: find.byKey(ValueKey(before.first.player.id)),
        matching: find.byType(ReorderableDragStartListener),
      );
      final target = find.byKey(ValueKey(before.last.player.id));
      final gesture = await tester.startGesture(tester.getCenter(handle));
      await gesture.moveBy(const Offset(0, 5));
      await tester.pump(const Duration(milliseconds: 300));
      await gesture.moveTo(
        Offset(
          tester.getCenter(handle).dx,
          tester.getBottomRight(target).dy + 80,
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));
      await gesture.up();
      await tester.pumpAndSettle();
      expect(roster.members.map((p) => p.player.id), [
        before[1].player.id,
        before[2].player.id,
        before[0].player.id,
      ]);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'failed swipe retains its row; successful deletion offers undo for three seconds',
    (tester) async {
      await host(tester, const PlayerRosterScreen(allowStart: false), 'de');
      final container = ProviderScope.containerOf(
        tester.element(find.byType(PlayerRosterScreen)),
      );
      final roster = await container.read(rosterProvider.future);
      await tester.enterText(
        find.byKey(const ValueKey('quick-player-name')),
        'Alex',
      );
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      final person = roster.members.single;
      final storage = container.read(stringStoreProvider) as MemoryStringStore;
      storage.failWrite = true;
      await tester.drag(
        find.byKey(ValueKey(person.player.id)),
        const Offset(500, 0),
      );
      await tester.pumpAndSettle();
      expect(roster.members.single.player.id, person.player.id);
      expect(find.text('Rückgängig'), findsNothing);
      storage.failWrite = false;
      await tester.drag(
        find.byKey(ValueKey(person.player.id)),
        const Offset(-500, 0),
      );
      await tester.pumpAndSettle();
      expect(roster.members, isEmpty);
      expect(
        tester.widget<SnackBar>(find.byType(SnackBar)).duration,
        const Duration(seconds: 3),
      );
      expect(find.text('Rückgängig'), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      expect(find.text('Rückgängig'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
