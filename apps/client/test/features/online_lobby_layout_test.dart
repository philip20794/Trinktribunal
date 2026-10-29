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
import 'package:trinktribunal/domain/models/ids.dart';
import 'package:trinktribunal/features/bench/bench_view.dart';
import 'package:trinktribunal/features/multiplayer/create.dart';
import 'package:trinktribunal/features/multiplayer/game_settings.dart';
import 'package:trinktribunal/l10n/app_strings.dart';

import '../data/room_test_support.dart';
import '../design/court_scene_test.dart' show reviewImage;
import 'online_numbers_test.dart' as numbers;
import 'room_entry_test.dart' as entry;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    numbers.catalogs = await CatalogRepository(
      read: (path) => File(path).readAsString(),
    ).load();
    await TrinkAvatarRenderer.svg(AvatarConfig());
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
  });

  for (final language in ['de', 'en']) {
    for (final size in [const Size(320, 740), const Size(1440, 1000)]) {
      for (final scale in [1.0, 2.0]) {
        testWidgets(
          'floating lobby tools and compact controls: $language/$size/$scale',
          (tester) async {
            await tester.binding.setSurfaceSize(size);
            addTearDown(() => tester.binding.setSurfaceSize(null));
            final fixture = await numbers.pump(
              tester,
              lobby: true,
              host: true,
              uiLanguage: language,
              textScale: scale,
              publicClientBase: Uri.parse('https://client.example'),
            );
            final initial = fixture.room.state.snapshot!;
            fixture.transport.sockets.last.receive(
              SnapshotMessage.fromJson({
                ...initial.toJson(),
                'revision': initial.revision + 1,
                'public': {...initial.public.toJson(), 'hostRevision': 0},
              }),
            );
            await tester.pumpAndSettle();
            final strings = AppStrings(language);
            expect(find.byType(Slider), findsNothing);
            expect(find.byType(QrImageView), findsOneWidget);
            expect(find.text(strings.get('roomRetention')), findsNothing);
            expect(find.text(strings.get('localGameOptions')), findsOneWidget);
            final toggle = find.byKey(const ValueKey('room-tools-toggle'));
            final togglePosition = tester.getTopLeft(toggle);
            await reviewImage(
              tester,
              'lobby-open-$language-${size.width.toInt()}-${scale.toInt()}',
            );
            await tester.ensureVisible(
              find.byKey(const ValueKey('room-tools-close')),
            );
            await tester.pumpAndSettle();
            await tester.tap(find.byKey(const ValueKey('room-tools-close')));
            await tester.pumpAndSettle();
            expect(find.byType(QrImageView), findsNothing);
            expect(find.text(strings.get('localGameOptions')), findsNothing);
            expect(tester.getTopLeft(toggle), togglePosition);
            expect(
              tester.getTopLeft(find.byType(BenchView)).dy -
                  tester
                      .getBottomLeft(
                        find.text(strings.get('roomJoinedCount', {'count': 3})),
                      )
                      .dy,
              closeTo(12, .1),
            );
            expect(
              tester.widget<BenchView>(find.byType(BenchView)).compactControls,
              isTrue,
            );
            expect(find.byIcon(Icons.arrow_upward), findsNothing);
            expect(find.byIcon(Icons.arrow_downward), findsNothing);
            expect(
              find.byKey(const ValueKey('compact-drag-p1')),
              findsOneWidget,
            );
            await reviewImage(
              tester,
              'lobby-closed-$language-${size.width.toInt()}-${scale.toInt()}',
            );
            final next = find.byKey(const ValueKey('compact-move-right-p1'));
            await tester.ensureVisible(next);
            await tester.pumpAndSettle();
            await tester.tap(next);
            await tester.pumpAndSettle();
            final socket = fixture.transport.sockets.last;
            final move = socket.sent.whereType<ReorderRosterMessage>().single;
            expect(move.playerIds.map((p) => p.value), ['p2', 'p1', 'p3']);
            final snapshot = fixture.room.state.snapshot!;
            socket.receive(
              SnapshotMessage.fromJson({
                ...snapshot.toJson(),
                'revision': snapshot.revision + 1,
              }),
            );
            await tester.pumpAndSettle();
            expect(find.byType(QrImageView), findsNothing);
            await tester.tap(toggle);
            await tester.pumpAndSettle();
            expect(find.byType(QrImageView), findsOneWidget);
            await tester.tap(find.text(strings.get('localGameOptions')));
            await tester.pumpAndSettle();
            expect(find.byType(RoomSettingsScreen), findsOneWidget);
            expect(find.byType(Slider), findsNWidgets(3));
            expect(find.text(strings.get('localCasesHelp')), findsOneWidget);
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  }

  testWidgets('guest has invitation and read-only settings, no host controls', (
    tester,
  ) async {
    await numbers.pump(
      tester,
      lobby: true,
      publicClientBase: Uri.parse('https://client.example'),
    );
    expect(find.byType(QrImageView), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('room-tools-toggle')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('compact-drag-p1')), findsNothing);
    expect(find.text(AppStrings('de').get('startHearing')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('room-tools-toggle')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppStrings('de').get('localGameOptions')));
    await tester.pumpAndSettle();
    expect(find.byType(RoomSettingsScreen), findsOneWidget);
    expect(find.byType(Slider), findsNothing);
  });

  testWidgets(
    'host start guards duplicate taps and remains retryable after server rejection',
    (tester) async {
      final fixture = await numbers.pump(tester, lobby: true, host: true);
      final socket = fixture.transport.sockets.last;
      final start = find.widgetWithText(
        FilledButton,
        AppStrings('de').get('startHearing'),
      );
      final callback = tester.widget<FilledButton>(start).onPressed!;
      callback();
      callback();
      await tester.pumpAndSettle();
      expect(socket.sent.whereType<StartGameMessage>(), hasLength(1));
      expect(tester.widget<FilledButton>(start).onPressed, isNull);
      socket.receive(
        ErrorMessage.create(
          requestId: RequestId('start_rejected'),
          code: 'RATE_LIMITED',
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.widget<FilledButton>(start).onPressed, isNotNull);
      expect(fixture.room.state.snapshot!.public.phase, 'lobby');
      await tester.tap(start);
      await tester.pumpAndSettle();
      expect(socket.sent.whereType<StartGameMessage>(), hasLength(2));
    },
  );

  testWidgets('real drag on floating handle sends roster insertion', (
    tester,
  ) async {
    final fixture = await numbers.pump(tester, lobby: true, host: true);
    await tester.tap(find.byKey(const ValueKey('room-tools-toggle')));
    await tester.pumpAndSettle();
    final drag = find.byKey(const ValueKey('compact-drag-p1'));
    await tester.ensureVisible(drag);
    await tester.pumpAndSettle();
    final gesture = await tester.startGesture(tester.getCenter(drag));
    await tester.pump(const Duration(milliseconds: 600));
    await gesture.moveTo(
      tester.getCenter(find.byKey(ValueKey(PlayerId('p2')))),
    );
    await tester.pump(const Duration(milliseconds: 100));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(
      fixture.transport.sockets.last.sent
          .whereType<ReorderRosterMessage>()
          .single
          .playerIds
          .map((p) => p.value),
      ['p2', 'p1', 'p3'],
    );
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
