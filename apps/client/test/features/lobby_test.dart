import '../support/action_text.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trinktribunal/application/room_controller.dart';
import 'package:trinktribunal/application/room_providers.dart';
import 'package:trinktribunal/data/protocol/room_message.dart';
import 'package:trinktribunal/data/room_credential_store.dart';
import 'package:trinktribunal/design/avatar_view.dart';
import 'package:trinktribunal/features/multiplayer/connection.dart';
import 'package:trinktribunal/features/multiplayer/me.dart';
import 'package:trinktribunal/features/multiplayer/pending_profile.dart';
import 'package:trinktribunal/features/multiplayer/room_tools.dart';
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
      'config': {...base.public.config.toJson(), 'allJudges': true},
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
  bool pendingGuest = false,
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
          home: const RoomConnectionScreen(newRoom: true),
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
  final snapshot = lobbySnapshot(host);
  transport.sockets.last.receive(
    pendingGuest
        ? SnapshotMessage.fromJson({
            ...snapshot.toJson(),
            'public': {
              ...snapshot.public.toJson(),
              'players': [
                for (final player in snapshot.public.players)
                  {
                    ...player.toJson(),
                    if (player.playerId.value == 'p2')
                      'profile': {
                        ...player.profile.toJson(),
                        'name': pendingRoomProfileName,
                      },
                  },
              ],
            },
          })
        : snapshot,
  );
  await tester.pumpAndSettle();
  return (room: room, transport: transport);
}

void main() {
  for (final language in ['de', 'en']) {
    for (final size in [const Size(320, 640), const Size(1440, 900)]) {
      testWidgets(
        'inline QR shows only the share action: $language, $size, 200 percent',
        (tester) async {
          await tester.binding.setSurfaceSize(size);
          addTearDown(() => tester.binding.setSurfaceSize(null));
          final strings = AppStrings(language);
          await pumpLobby(
            tester,
            host: true,
            publicClientBase: Uri.parse('http://127.0.0.1:7357'),
            language: language,
            textScale: 2,
          );
          final invite = find.byType(RoomInvite);
          expect(find.byType(QrImageView), findsOneWidget);
          expect(
            find.descendant(of: invite, matching: find.byType(SelectableText)),
            findsNothing,
          );
          expect(
            find.descendant(
              of: invite,
              matching: actionText(strings.get('roomCopyLink')),
            ),
            findsNothing,
          );
          expect(
            find.descendant(
              of: invite,
              matching: actionText(strings.get('roomShareLink')),
            ),
            findsOneWidget,
          );
          expect(find.byType(RoomTools), findsOneWidget);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
          await tester.pump();
        },
      );
    }
  }
  testWidgets('invitation still offers a room code without a hosted client', (
    tester,
  ) async {
    await pumpLobby(tester, host: true);
    expect(find.byType(QrImageView), findsNothing);
    expect(
      actionText(const AppStrings('de').get('roomInviteUnavailable')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });
  testWidgets('QR guest must save a name before changing tabs', (tester) async {
    final fixture = await pumpLobby(tester, pendingGuest: true);
    final input = find.byKey(const ValueKey('online-name'));
    expect(tester.widget<TextField>(input).controller!.text, isEmpty);
    expect(
      actionText(const AppStrings('de').get('roomNameRequired')),
      findsWidgets,
    );
    await tester.tap(widgetWithActionText(Tab, 'Gerichtssaal'));
    await tester.pumpAndSettle();
    expect(DefaultTabController.of(tester.element(input)).index, 0);
    expect(
      actionText(const AppStrings('de').get('roomNameRequired')),
      findsWidgets,
    );

    await tester.enterText(input, 'Alex');
    await tester.pump(const Duration(milliseconds: 400));
    final edit = fixture.transport.sockets.last.sent
        .whereType<EditOwnProfileMessage>()
        .single;
    expect(edit.profile.name, 'Alex');
    // Typing alone does not unlock the other tabs: the server must acknowledge.
    await tester.tap(widgetWithActionText(Tab, 'Gerichtssaal'));
    await tester.pumpAndSettle();
    expect(DefaultTabController.of(tester.element(input)).index, 0);

    final before = fixture.room.state.snapshot!;
    fixture.transport.sockets.last.receive(
      DeltaMessage.fromJson({
        'type': 'delta',
        'protocolVersion': 2,
        'requestId': 'name-confirmed',
        'roomId': before.roomId.value,
        'you': before.you.value,
        'baseRevision': before.revision,
        'revision': before.revision + 1,
        'publicChanges': {
          'players': [
            for (final player in before.public.players)
              {
                ...player.toJson(),
                if (player.playerId == before.you)
                  'profile': edit.profile.toJson(),
              },
          ],
        },
        'private': {},
      }),
    );
    await tester.pumpAndSettle();
    expect(find.byType(RoomMe), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('host sees missing names and cannot start a game', (
    tester,
  ) async {
    final fixture = await pumpLobby(tester, host: true, pendingGuest: true);
    final message = const AppStrings('de')
        .get('roomStartPendingNames', {'count': 1});
    expect(actionText(message), findsWidgets);
    await tester.tap(widgetWithActionText(FilledButton, 'Verhandlung starten'));
    await tester.pumpAndSettle();
    expect(actionText(message), findsWidgets);
    expect(
      fixture.transport.sockets.last.sent.whereType<StartGameMessage>(),
      isEmpty,
    );
  });

  testWidgets(
    'non-host sees live figures and can edit only its own profile in Me',
    (tester) async {
      final fixture = await pumpLobby(tester),
          socket = fixture.transport.sockets.last;
      expect(widgetWithActionText(Tab, 'Ich'), findsOneWidget);
      expect(widgetWithActionText(Tab, 'Gerichtssaal'), findsOneWidget);
      expect(find.byType(PopupMenuButton<String>), findsNothing);
      await tester.tap(widgetWithActionText(Tab, 'Ich'));
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
        actionText('Profil im Gerichtssaal bestätigt.'),
        250,
        scrollable: find
            .descendant(
              of: find.byType(RoomMe),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      expect(actionText('Profil im Gerichtssaal bestätigt.'), findsOneWidget);
      await tester.tap(widgetWithActionText(Tab, 'Gerichtssaal'));
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
      await tester.scrollUntilVisible(
        find.byKey(const PageStorageKey('room-presence')),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(
        find
            .descendant(
              of: find.byKey(const PageStorageKey('room-presence')),
              matching: find.byType(ListTile),
            )
            .first,
      );
      await tester.pumpAndSettle();
      final list = find.descendant(
        of: find.byType(TabBarView),
        matching: find.byType(ListView),
      );
      await tester.scrollUntilVisible(
        find.byTooltip('p2 verwalten'),
        150,
        scrollable: find
            .descendant(of: list, matching: find.byType(Scrollable))
            .first,
      );
      await Scrollable.ensureVisible(
        tester.element(find.byTooltip('p2 verwalten')),
        alignment: .5,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('p2 verwalten'));
      await tester.pumpAndSettle();
      await tester.tap(actionText('Teilnehmer entfernen'));
      await tester.pumpAndSettle();
      expect(socket.sent.whereType<KickMessage>(), isEmpty);
      await tester.tap(find.byKey(const ValueKey('court-dialog-close')));
      await tester.pumpAndSettle();
      expect(socket.sent.whereType<KickMessage>(), isEmpty);
      await Scrollable.ensureVisible(
        tester.element(find.byTooltip('p2 verwalten')),
        alignment: .5,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('p2 verwalten'));
      await tester.pumpAndSettle();
      await tester.tap(actionText('Teilnehmer entfernen'));
      await tester.pumpAndSettle();
      await tester.tap(
        widgetWithActionText(FilledButton, 'Teilnehmer entfernen'),
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
