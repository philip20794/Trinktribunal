import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trinktribunal/application/room_controller.dart';
import 'package:trinktribunal/application/room_providers.dart';
import 'package:trinktribunal/data/protocol/room_message.dart';
import 'package:trinktribunal/data/room_credential_store.dart';
import 'package:trinktribunal/design/avatar_view.dart';
import 'package:trinktribunal/features/multiplayer/connection.dart';
import 'package:trinktribunal/features/multiplayer/courtroom.dart';
import 'package:trinktribunal/features/multiplayer/me.dart';
import 'package:trinktribunal/features/multiplayer/invite.dart';
import 'package:trinktribunal/l10n/app_strings.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../data/room_test_support.dart';

SnapshotMessage lobbySnapshot(bool host) {
  final base = roomFixture('snapshot') as SnapshotMessage;
  return SnapshotMessage.fromJson({
    ...base.toJson(),
    'you': host ? 'p1' : 'p2',
    'public': {
      ...base.public.toJson(),
      'phase': 'lobby',
      'gameId': null,
      'roundId': null,
      'judgeId': null,
      'readerId': null,
      'question': null,
      'frozenRoster': [],
      'pendingRoster': [],
    },
    'private': {},
  });
}

Future<({RoomController room, FakeRoomTransport transport})> pumpLobby(
  WidgetTester tester, {
  bool host = false,
  Uri? publicClientBase,
  String language = 'de',
  double textScale = 1,
}) async {
  final transport = FakeRoomTransport(),
      store = RoomCredentialStore(MemoryCredentialBackend()),
      room = RoomController(transport: transport, credentials: store);
  addTearDown(room.dispose);
  final saved = RoomCredential(
    serverOrigin: testCredential().serverOrigin,
    message: CredentialMessage.fromJson({
      ...testCredential().message.toJson(),
      'playerId': host ? 'p1' : 'p2',
    }),
  );
  await room.resume(saved);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        publicClientBaseProvider.overrideWithValue(publicClientBase),
        roomControllerProvider.overrideWithValue(room),
        roomCredentialStoreProvider.overrideWithValue(store),
      ],
      child: AppLanguageScope(
        language: language,
        child: MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
          home: const RoomConnectionScreen(),
        ),
      ),
    ),
  );
  await tester.pump();
  transport.sockets.last.receive(
    AuthenticatedMessage.fromJson({
      ...roomFixture('authenticated').toJson(),
      'playerId': host ? 'p1' : 'p2',
    }),
  );
  transport.sockets.last.receive(lobbySnapshot(host));
  await tester.pumpAndSettle();
  return (room: room, transport: transport);
}

void main() {
  for (final language in ['de', 'en']) {
    for (final size in [const Size(320, 640), const Size(1440, 900)]) {
      testWidgets(
        'inline QR opens, copies and closes repeatedly: $language, $size, 200 percent',
        (tester) async {
          await tester.binding.setSurfaceSize(size);
          addTearDown(() => tester.binding.setSurfaceSize(null));
          final strings = AppStrings(language);
          String? copied;
          tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            SystemChannels.platform,
            (call) async {
              if (call.method == 'Clipboard.setData') {
                copied = (call.arguments as Map)['text'] as String;
              }
              if (call.method == 'Clipboard.hasStrings') {
                return {'value': copied != null};
              }
              return null;
            },
          );
          addTearDown(
            () => tester.binding.defaultBinaryMessenger
                .setMockMethodCallHandler(SystemChannels.platform, null),
          );
          final fixture = await pumpLobby(
            tester,
            host: true,
            publicClientBase: Uri.parse('http://127.0.0.1:7357'),
            language: language,
            textScale: 2,
          );
          final mouse = await tester.createGesture(
            kind: PointerDeviceKind.mouse,
          );
          await mouse.addPointer(location: const Offset(5, 5));
          for (var attempt = 0; attempt < 2; attempt++) {
            expect(find.byType(QrImageView), findsOneWidget);
            final link =
                'http://127.0.0.1:7357/join?room=${fixture.room.roomCode}';
            expect(
              tester.widget<SelectableText>(find.byType(SelectableText)).data,
              link,
            );
            final copy = find.text(strings.get('roomCopyLink'));
            await Scrollable.ensureVisible(tester.element(copy), alignment: .5);
            await tester.pumpAndSettle();
            await mouse.moveTo(tester.getCenter(copy));
            await tester.tap(copy);
            await tester.pumpAndSettle();
            expect(copied, link);
            final close = find.byKey(const ValueKey('room-tools-close'));
            await tester.ensureVisible(close);
            await tester.pumpAndSettle();
            await tester.tap(close);
            await tester.pumpAndSettle();
            expect(find.byType(QrImageView), findsNothing);
            final toggle = find.byKey(const ValueKey('room-tools-toggle'));
            await mouse.moveTo(tester.getCenter(toggle));
            await tester.tap(toggle);
            await tester.pumpAndSettle();
            expect(find.byType(RoomCourtroom), findsOneWidget);
            expect(tester.takeException(), isNull);
          }
          await mouse.removePointer();
          await tester.pumpWidget(const SizedBox());
          await tester.pump();
        },
      );
    }
  }
  testWidgets('invitation still offers a room code without a hosted client', (
    tester,
  ) async {
    await pumpLobby(tester);
    expect(find.byType(QrImageView), findsNothing);
    expect(
      find.text(const AppStrings('de').get('roomInviteUnavailable')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });
  testWidgets(
    'non-host sees live figures and can edit only its own profile in Me',
    (tester) async {
      final fixture = await pumpLobby(tester),
          socket = fixture.transport.sockets.last;
      expect(find.widgetWithText(Tab, 'Ich'), findsOneWidget);
      expect(find.widgetWithText(Tab, 'Gerichtssaal'), findsOneWidget);
      expect(find.byType(PopupMenuButton<String>), findsNothing);
      await tester.tap(find.widgetWithText(Tab, 'Ich'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('online-name')),
        'New Alex',
      );
      await tester.pump(const Duration(milliseconds: 350));
      final action = socket.sent.whereType<EditOwnProfileMessage>().single;
      expect(action.profile.name, 'New Alex');
      expect(action.toJson().containsKey('playerId'), isFalse);
      final base = fixture.room.state.snapshot!;
      final updated = base.public.players
          .map(
            (player) => {
              ...player.toJson(),
              if (player.playerId == base.you)
                'profile': action.profile.toJson(),
            },
          )
          .toList();
      socket.receive(
        DeltaMessage.fromJson({
          'type': 'delta',
          'protocolVersion': 2,
          'requestId': 'update',
          'roomId': base.roomId.value,
          'you': base.you.value,
          'baseRevision': base.revision,
          'revision': base.revision + 1,
          'publicChanges': {'players': updated},
          'private': {},
        }),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Profil im Gerichtssaal bestätigt.'),
        250,
        scrollable: find
            .descendant(
              of: find.byType(RoomMe),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      expect(find.text('Profil im Gerichtssaal bestätigt.'), findsOneWidget);
      await tester.tap(find.widgetWithText(Tab, 'Gerichtssaal'));
      await tester.pumpAndSettle();
      expect(find.textContaining('New Alex'), findsWidgets);
      expect(tester.takeException(), isNull);
      final avatars = tester.widgetList<AvatarView>(find.byType(AvatarView));
      expect(avatars.any((view) => view.label == 'New Alex'), isTrue);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    },
  );
  testWidgets(
    'host management requires explicit removal confirmation and binds the current revision',
    (tester) async {
      final fixture = await pumpLobby(tester, host: true),
          socket = fixture.transport.sockets.last;
      final list = find.descendant(
        of: find.byType(RoomCourtroom),
        matching: find.byType(ListView),
      );
      await tester.scrollUntilVisible(
        find.byTooltip('p2 verwalten'),
        150,
        scrollable: find
            .descendant(of: list, matching: find.byType(Scrollable))
            .first,
      );
      final outer = tester.state<ScrollableState>(
        find.descendant(of: list, matching: find.byType(Scrollable)).first,
      );
      outer.position.jumpTo(outer.position.maxScrollExtent);
      await tester.pumpAndSettle();
      expect(find.text('Host'), findsOneWidget);
      await tester.tap(find.byTooltip('p2 verwalten'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Teilnehmer entfernen'));
      await tester.pumpAndSettle();
      expect(socket.sent.whereType<KickMessage>(), isEmpty);
      await tester.tap(find.text('Abbrechen'));
      await tester.pumpAndSettle();
      expect(socket.sent.whereType<KickMessage>(), isEmpty);
      await tester.tap(find.byTooltip('p2 verwalten'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Teilnehmer entfernen'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(FilledButton, 'Teilnehmer entfernen'),
      );
      await tester.pumpAndSettle();
      final kick = socket.sent.whereType<KickMessage>().single;
      expect(kick.targetPlayerId.value, 'p2');
      expect(kick.confirmed, isTrue);
      expect(kick.expectedRevision, fixture.room.state.snapshot!.revision);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    },
  );
}
