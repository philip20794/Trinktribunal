import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:trinktribunal/data/catalogs/catalog_repository.dart';
import 'package:trinktribunal/data/protocol/room_message.dart';
import 'package:trinktribunal/data/room_credential_store.dart';
import 'package:trinktribunal/design/avatar_view.dart';
import 'package:trinktribunal/domain/avatar_config.dart';
import 'package:trinktribunal/features/multiplayer/create.dart';
import 'package:trinktribunal/features/multiplayer/game_settings.dart';
import 'package:trinktribunal/features/multiplayer/courtroom.dart';
import 'package:trinktribunal/features/multiplayer/room_tools.dart';
import 'package:trinktribunal/l10n/app_strings.dart';

import '../data/room_test_support.dart';
import '../design/court_scene_test.dart' show reviewImage;
import 'online_numbers_test.dart' as numbers;
import 'room_entry_test.dart' as entry;

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
    numbers.catalogs = await CatalogRepository(
      read: (path) => File(path).readAsString(),
    ).load();
    await TrinkAvatarRenderer.svg(AvatarConfig());
  });
  for (final language in ['de', 'en']) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'host tools live in their own tab, fresh rooms open QR: $language/$scale',
        (tester) async {
          await tester.binding.setSurfaceSize(const Size(360, 800));
          addTearDown(() => tester.binding.setSurfaceSize(null));
          final fixture = await numbers.pump(
            tester,
            lobby: true,
            host: true,
            newRoom: true,
            textScale: scale,
            uiLanguage: language,
            publicClientBase: Uri.parse('https://client.example'),
          );
          final strings = AppStrings(language);
          expect(find.byType(Tab), findsNWidgets(3));
          expect(find.byType(RoomCourtroom), findsNothing);
          expect(find.byType(QrImageView), findsOneWidget);
          expect(find.byType(RoomTools), findsOneWidget);
          expect(find.byIcon(Icons.logout), findsNothing);
          expect(find.byIcon(Icons.gavel), findsNothing);
          await reviewImage(tester, 'room-me-$language-${scale.toInt()}');
          await numbers.tapText(tester, strings.get('localGameOptions'));
          expect(find.byType(RoomSettingsScreen), findsNothing);
          expect(find.byType(RoomGameSettings), findsOneWidget);
          expect(find.text(strings.get('onlineSaveSettings')), findsNothing);
          await reviewImage(
            tester,
            'inline-room-settings-$language-${scale.toInt()}',
          );
          expect(find.byKey(const ValueKey('add-demo-player')), findsOneWidget);
          expect(find.byType(Slider), findsNWidgets(3));
          expect(tester.takeException(), isNull);
          expect(
            fixture.transport.sockets.last.sent.whereType<SetConfigMessage>(),
            isEmpty,
          );
        },
      );
    }
  }
  testWidgets(
    'all-judges toggle sits above game settings and explains the rule',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await numbers.pump(
        tester,
        lobby: true,
        host: true,
        newRoom: true,
        publicClientBase: Uri.parse('https://client.example'),
      );
      const strings = AppStrings('de');
      final toggle = find.byKey(const ValueKey('room-all-judges'));
      final info = find.byTooltip(strings.get('gameRulesAllJudgesBody'));
      expect(toggle, findsOneWidget);
      await tester.ensureVisible(info);
      await tester.pumpAndSettle();
      expect(
        tester.getTopLeft(toggle).dy,
        lessThan(
          tester.getTopLeft(
            find.byKey(const PageStorageKey('room-game-settings')),
          ).dy,
        ),
      );
      await tester.tap(info);
      await tester.pumpAndSettle();
      expect(
        find.text(strings.get('gameRulesAllJudgesBody')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'guest has no room tools; all-judges courtroom has no connection roster',
    (tester) async {
      await numbers.pump(tester, lobby: true, allJudges: true);
      expect(find.byType(Tab), findsNWidgets(3));
      expect(find.byType(QrImageView), findsNothing);
      expect(find.byKey(const PageStorageKey('host-room-tools')), findsNothing);
      await tester.tap(find.byType(Tab).at(1));
      await tester.pumpAndSettle();
      expect(find.byType(RoomCourtroom), findsOneWidget);
      expect(find.byKey(const ValueKey('presence-p1')), findsNothing);
      expect(find.byType(ExpansionTile), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('existing room keeps administration and QR open', (tester) async {
    await numbers.pump(
      tester,
      lobby: true,
      host: true,
      publicClientBase: Uri.parse('https://client.example'),
    );
    expect(find.byType(QrImageView), findsOneWidget);
    await numbers.tapText(tester, AppStrings('de').get('localGameOptions'));
    expect(find.byType(RoomSettingsScreen), findsNothing);
    expect(find.byType(RoomGameSettings), findsOneWidget);
  });
  testWidgets(
    'create from entry needs no profile form and only sends one create',
    (tester) async {
      final transport = FakeRoomTransport(),
          store = RoomCredentialStore(MemoryCredentialBackend());
      await tester.pumpWidget(
        entry.host(const MultiplayerEntryScreen(), transport, store),
      );
      await tester.pumpAndSettle();
      final create = tester
          .widget<FilledButton>(
            find.widgetWithText(
              FilledButton,
              AppStrings('de').get('roomCreate'),
            ),
          )
          .onPressed!;
      create();
      create();
      for (var i = 0; i < 20 && transport.connections == 0; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(transport.creates, 1);
      expect(transport.lastProfile!.name, 'Spieler');
      expect(transport.lastProfile!.avatar.version, 3);
      expect(find.byKey(const ValueKey('room-name')), findsNothing);
      transport.sockets.last.accepted();
      await tester.pumpAndSettle();
      expect(transport.creates, 1);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
