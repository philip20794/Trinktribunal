import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trinktribunal/application/room_providers.dart';
import 'package:trinktribunal/design/court_scene.dart';
import 'package:trinktribunal/design/court_assets.dart';
import 'package:trinktribunal/features/home/home_screen.dart';
import 'package:trinktribunal/features/multiplayer/create.dart';
import 'package:trinktribunal/features/multiplayer/join.dart';
import 'package:trinktribunal/features/rules/game_rules_screen.dart';
import 'package:trinktribunal/l10n/app_strings.dart';

import '../data/room_test_support.dart';
import '../design/court_scene_test.dart' show reviewImage;
import 'home_profile_settings_test.dart' show tapVisible;
import 'ui_cleanup_test.dart' show host;

void main() {
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
  for (final lang in ['de', 'en']) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('home actions and ordered mode details: $lang/$scale', (
        tester,
      ) async {
        final strings = AppStrings(lang);
        await host(
          tester,
          const HomeScreen(),
          lang,
          scale: scale,
          size: const Size(320, 640),
        );
        for (final title in ['homeNewGame', 'homeJoinGame', 'gameRules']) {
          await tester.ensureVisible(find.text(strings.get(title)));
          await tester.pumpAndSettle();
          expect(find.text(strings.get(title)).hitTestable(), findsOneWidget);
        }
        expect(find.text(strings.get('modeCards')), findsNothing);
        expect(find.byType(AppBar), findsNothing);
        expect(
          find.byTooltip(strings.get('openSettings')).hitTestable(),
          findsOneWidget,
        );
        expect(
          find.byTooltip(strings.get('openProfile')).hitTestable(),
          findsOneWidget,
        );
        expect(find.text(strings.get('homeHearingReady')), findsOneWidget);
        expect(find.text(strings.get('homeHearingQuestion')), findsOneWidget);
        expect(
          tester.getRect(find.text(strings.get('homeHearingQuestion'))).top -
              tester.getRect(find.text(strings.get('homeHearingReady'))).bottom,
          lessThanOrEqualTo(8),
        );
        expect(find.text(strings.get('modePhone')), findsNothing);
        expect(find.text(strings.get('modeMulti')), findsNothing);
        final rules = find.byKey(const ValueKey('home-game-rules'));
        expect(
          find.descendant(
            of: rules,
            matching: find.byIcon(Icons.menu_book_outlined),
          ),
          findsOneWidget,
        );
        expect(tester.getSize(rules).height, greaterThanOrEqualTo(64));
        final box = tester.getRect(rules);
        expect(
          box.top,
          greaterThan(
            tester.getRect(find.byKey(const ValueKey('home-join-game'))).top,
          ),
        );
        await reviewImage(tester, 'home-actions-$lang-${scale.toInt()}');
        await tapVisible(tester, find.text(strings.get('homeNewGame')));
        expect(find.byType(GameModeSelectionScreen), findsOneWidget);
        expect(find.text(strings.get('introContinue')), findsNothing);
        final positions = <double>[];
        for (final asset in [
          CourtAssets.modeCards,
          CourtAssets.modePhone,
          CourtAssets.modePhones,
        ]) {
          final art = find.byWidgetPredicate(
            (w) => w is CourtArt && w.asset == asset,
          );
          if (art.evaluate().isEmpty) {
            await tester.scrollUntilVisible(
              art,
              150,
              scrollable: find.byType(Scrollable).first,
            );
          }
          expect(tester.widget<CourtArt>(art).fit, BoxFit.contain);
        }
        tester
            .state<ScrollableState>(find.byType(Scrollable).first)
            .position
            .jumpTo(0);
        await tester.pumpAndSettle();
        for (final prefix in ['modeCards', 'modePhone', 'modeMulti']) {
          final title = find.text(strings.get(prefix));
          final requirements = find.text(strings.get('${prefix}Requirement'));
          if (title.evaluate().isEmpty) {
            await tester.scrollUntilVisible(
              title,
              160,
              scrollable: find.byType(Scrollable).first,
            );
          }
          final rect = tester.getRect(title);
          final scroll = tester.state<ScrollableState>(
            find.byType(Scrollable).first,
          );
          positions.add(rect.top + scroll.position.pixels);
          await tester.ensureVisible(requirements);
          await tester.pumpAndSettle();
          expect(requirements.hitTestable(), findsOneWidget);
          expect(
            find.text(strings.get('${prefix}Description')),
            findsOneWidget,
          );
          expect(tester.widget<Text>(requirements).style!.fontSize, 12);
          expect(
            tester.getRect(requirements).top,
            greaterThan(tester.getRect(title).top),
          );
        }
        expect(positions[0], lessThan(positions[1]));
        expect(positions[1], lessThan(positions[2]));
        final scroll = tester.state<ScrollableState>(
          find.byType(Scrollable).first,
        );
        scroll.position.jumpTo(0);
        await tester.pumpAndSettle();
        await reviewImage(tester, 'home-mode-selection-$lang-${scale.toInt()}');
        expect(tester.takeException(), isNull);
      });
    }
    testWidgets(
      'join opens code entry directly, rules have their own visible action: $lang',
      (tester) async {
        final strings = AppStrings(lang);
        await host(tester, const HomeScreen(), lang);
        await tester.tap(find.byKey(const ValueKey('home-join-game')));
        await tester.pumpAndSettle();
        expect(find.byType(JoinRoomScreen), findsOneWidget);
        expect(find.text(strings.get('introContinue')), findsNothing);
        expect(find.byType(GameModeSelectionScreen), findsNothing);
        expect(find.byType(TextField), findsOneWidget);
        expect(find.text(strings.get('roomCreate')), findsNothing);
        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('home-game-rules')));
        await tester.pumpAndSettle();
        expect(find.byType(GameRulesScreen), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'online new game proceeds to room creation instead of another create-or-join menu',
    (tester) async {
      await host(tester, const HomeScreen(), 'de');
      final container = ProviderScope.containerOf(
        tester.element(find.byType(HomeScreen)),
      );
      final transport =
          container.read(roomTransportProvider) as FakeRoomTransport;
      transport.entryError = 'NETWORK_UNAVAILABLE';
      await tester.tap(find.byKey(const ValueKey('home-new-game')));
      await tester.pumpAndSettle();
      await tapVisible(
        tester,
        find.text(const AppStrings('de').get('modeMulti')),
      );
      expect(
        find.text(const AppStrings('de').get('introContinue')),
        findsNothing,
      );
      expect(find.byType(CreateRoomScreen), findsOneWidget);
      expect(find.byType(MultiplayerEntryScreen), findsNothing);
      expect(transport.creates, 1);
      expect(transport.joins, 0);
      expect(tester.takeException(), isNull);
    },
  );
}
