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
  for (final lobby in [true, false]) {
    for (final allJudges in [false, true]) {
      for (final host in [false, true]) {
        testWidgets(
          'avatar/category swipe isolation: lobby=$lobby/allJudges=$allJudges/host=$host',
          (tester) async {
            await tester.binding.setSurfaceSize(const Size(390, 844));
            addTearDown(() => tester.binding.setSurfaceSize(null));
            await numbers.pump(
              tester,
              lobby: lobby,
              allJudges: allJudges,
              host: host,
            );
            final roomBar = find.byKey(const ValueKey('room-tabs'));
            final roomTabs = find.descendant(
              of: roomBar,
              matching: find.byType(Tab),
            );
            final roomController = DefaultTabController.of(
              tester.element(roomBar),
            );
            await tester.tap(roomTabs.first);
            await tester.pumpAndSettle();
            final categoryBar = find.byKey(
              const ValueKey('avatar-category-tabs'),
            );
            final categoryController = tester
                .widget<TabBar>(categoryBar)
                .controller!;
            final options = find.byKey(const ValueKey('avatar-category-pages'));
            Future<void> swipeOptions(double dx, int expected) async {
              await tester.drag(options, Offset(dx, 0));
              await tester.pumpAndSettle();
              expect(categoryController.index, expected);
              expect(roomController.index, 0);
            }

            await swipeOptions(-260, 1);
            await swipeOptions(-260, 2);
            await swipeOptions(-260, 2);
            await swipeOptions(260, 1);
            await swipeOptions(260, 0);
            await swipeOptions(260, 0);
            await tester.drag(categoryBar, const Offset(-260, 0));
            await tester.pumpAndSettle();
            expect(categoryController.index, 1);
            expect(roomController.index, 0);
            await tester.tap(find.byKey(const ValueKey('avatar-tab-2')));
            await tester.pumpAndSettle();
            expect(categoryController.index, 2);
            expect(roomController.index, 0);
            final portrait = tester.getRect(
              find.byKey(const ValueKey('online-avatar-preview')),
            );
            await tester.dragFrom(
              Offset(portrait.center.dx, portrait.top + portrait.height * .25),
              const Offset(-260, 0),
            );
            await tester.pumpAndSettle();
            expect(roomController.index, 1);
            expect(tester.takeException(), isNull);
            await tester.pumpWidget(const SizedBox());
            await tester.pumpAndSettle();
          },
        );
      }
    }
  }
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
    'running room administration keeps settings visible with every control disabled',
    (tester) async {
      final fixture = await numbers.pump(tester, host: true, allJudges: true);
      final tabs = find.descendant(
        of: find.byKey(const ValueKey('room-tabs')),
        matching: find.byType(Tab),
      );
      await tester.tap(tabs.last);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('game-settings-paper')), findsOneWidget);
      expect(tester.widget<Switch>(find.byType(Switch)).onChanged, isNull);
      expect(
        tester
            .widget<DropdownButton<String>>(find.byType(DropdownButton<String>))
            .onChanged,
        isNull,
      );
      for (final slider in tester.widgetList<Slider>(find.byType(Slider))) {
        expect(slider.onChanged, isNull);
      }
      expect(
        find.text(const AppStrings('de').get('roomSettingsAutoSave')),
        findsNothing,
      );
      expect(
        find.text(const AppStrings('de').get('localGameOptions')),
        findsNothing,
      );
      final stop = find.byKey(const ValueKey('stop-room-game'));
      await tester.ensureVisible(stop);
      await tester.pumpAndSettle();
      await tester.tap(stop);
      await tester.pumpAndSettle();
      final command = fixture.transport.sockets.last.sent
          .whereType<RestartGameMessage>()
          .single;
      expect(command.setupOnly, isTrue);
      final base = fixture.room.state.snapshot!;
      fixture.transport.sockets.last.receive(
        SnapshotMessage.fromJson({
          ...base.toJson(),
          'revision': base.revision + 1,
          'public': {
            ...base.public.toJson(),
            'phase': 'lobby',
            'gameId': null,
            'roundId': null,
            'question': null,
            'frozenRoster': [],
            'judgeId': null,
            'readerId': null,
            'activeRules': [],
            'completedCases': 0,
          },
          'private': <String, Object?>{},
        }),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('stop-room-game')), findsNothing);
      expect(tester.widget<Switch>(find.byType(Switch)).onChanged, isNotNull);
      for (final slider in tester.widgetList<Slider>(find.byType(Slider))) {
        expect(slider.onChanged, isNotNull);
      }
      expect(
        fixture.transport.sockets.last.sent.whereType<StartGameMessage>(),
        isEmpty,
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'all-judges toggle sits inside the open parchment above cases and explains the rule',
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
        find.descendant(
          of: find.byKey(const ValueKey('game-settings-paper')),
          matching: toggle,
        ),
        findsOneWidget,
      );
      expect(
        tester.getTopLeft(toggle).dy,
        lessThan(
          tester
              .getTopLeft(find.byKey(const ValueKey('settings-cases-value')))
              .dy,
        ),
      );
      expect(
        tester.widget(find.byKey(const PageStorageKey('room-game-settings'))),
        isNot(isA<ExpansionTile>()),
      );
      await tester.tap(info);
      await tester.pumpAndSettle();
      expect(find.text(strings.get('gameRulesAllJudgesBody')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'guest has no room tools; all-judges courtroom has no connection roster',
    (tester) async {
      await numbers.pump(tester, lobby: true, allJudges: true);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('room-tabs')),
          matching: find.byType(Tab),
        ),
        findsNWidgets(3),
      );
      expect(find.byType(QrImageView), findsNothing);
      expect(find.byKey(const PageStorageKey('host-room-tools')), findsNothing);
      await tester.tap(
        find
            .descendant(
              of: find.byKey(const ValueKey('room-tabs')),
              matching: find.byType(Tab),
            )
            .at(1),
      );
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
