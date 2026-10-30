import '../support/action_text.dart';

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:trinktribunal/app/router.dart';
import 'package:trinktribunal/application/local_data_providers.dart';
import 'package:trinktribunal/application/profile_controller.dart';
import 'package:trinktribunal/application/room_providers.dart';
import 'package:trinktribunal/data/catalogs/catalog_repository.dart';
import 'package:trinktribunal/data/protocol/room_message.dart';
import 'package:trinktribunal/data/room_credential_store.dart';
import 'package:trinktribunal/data/profile_store.dart';
import 'package:trinktribunal/domain/avatar_config.dart';
import 'package:trinktribunal/features/multiplayer/create.dart';
import 'package:trinktribunal/features/multiplayer/connection.dart';
import 'package:trinktribunal/features/multiplayer/invitation.dart';
import 'package:trinktribunal/features/multiplayer/invite.dart';
import 'package:trinktribunal/features/multiplayer/join.dart';
import 'package:trinktribunal/features/multiplayer/pending_profile.dart';

import '../data/room_test_support.dart';
import '../support/memory_string_store.dart';
import '../support/memory_atomic_state_storage.dart';

Widget host(
  Widget child,
  FakeRoomTransport transport,
  RoomCredentialStore store, {
  String? initialRoute,
  MemoryStringStore? profileStorage,
}) => ProviderScope(
  overrides: [
    roomTransportProvider.overrideWithValue(transport),
    roomCredentialStoreProvider.overrideWithValue(store),
    publicClientBaseProvider.overrideWithValue(
      Uri.parse('https://client.example'),
    ),
    stringStoreProvider.overrideWithValue(
      profileStorage ?? MemoryStringStore(),
    ),
    atomicStateStorageProvider.overrideWithValue(MemoryAtomicStateStorage()),
    catalogRepositoryProvider.overrideWithValue(
      CatalogRepository(read: (path) async => File(path).readAsStringSync()),
    ),
  ],
  child: initialRoute == null
      ? MaterialApp(home: child)
      : MaterialApp(
          initialRoute: initialRoute,
          onGenerateRoute: generateAppRoute,
        ),
);

void main() {
  testWidgets('QR join preserves both the saved name and avatar', (
    tester,
  ) async {
    final local = MemoryStringStore();
    final profile = ProfileController(ProfileStore(local));
    final avatar = AvatarConfig.feminine();
    await profile.save(name: 'Gespeicherte Alex', avatar: avatar);
    final transport = FakeRoomTransport();
    final store = RoomCredentialStore(MemoryCredentialBackend());
    await tester.pumpWidget(
      host(
        const SizedBox(),
        transport,
        store,
        initialRoute: '/join?room=ABCD2345',
        profileStorage: local,
      ),
    );
    for (var i = 0; i < 20 && transport.connections == 0; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(transport.joins, 1);
    expect(transport.lastProfile!.name, 'Gespeicherte Alex');
    expect(transport.lastProfile!.avatar.selections, avatar.selections);
    expect(find.byKey(const ValueKey('room-code')), findsNothing);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });
  testWidgets(
    'create uses the local profile template and storage retry never creates a second room',
    (tester) async {
      final local = MemoryStringStore(),
          profileController = ProfileController(ProfileStore(local));
      await profileController.save(
        name: 'Saved Alex',
        avatar: AvatarConfig.feminine(),
      );
      final backend = MemoryCredentialBackend()..fail = true,
          store = RoomCredentialStore(backend),
          transport = FakeRoomTransport();
      await tester.pumpWidget(
        host(const CreateRoomScreen(), transport, store, profileStorage: local),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('room-name')), findsNothing);
      expect(find.byKey(const ValueKey('room-submit')), findsNothing);
      expect(transport.creates, 0);
      backend.fail = false;
      await tester.tap(find.byKey(const ValueKey('room-create-retry')));
      await tester.pump();
      await tester.pump();
      expect(transport.creates, 1);
      expect(transport.lastProfile!.name, 'Saved Alex');
      expect(
        transport.lastProfile!.avatar.selections,
        AvatarConfig.feminine().selections,
      );
      expect(transport.connections, 1);
      transport.sockets.last.accepted();
      await tester.pumpAndSettle();
      expect((await store.load()).credentials, hasLength(1));
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    },
  );
  for (final size in [
    const Size(360, 800),
    const Size(390, 844),
    const Size(1440, 900),
  ]) {
    testWidgets('entry remains usable at ${size.width} x ${size.height}', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final transport = FakeRoomTransport(),
          store = RoomCredentialStore(MemoryCredentialBackend());
      await tester.pumpWidget(
        host(const JoinRoomScreen(initialCode: 'ABCD2345'), transport, store),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('room-submit')),
        100,
        scrollable: find
            .descendant(
              of: find.byType(ListView).last,
              matching: find.byType(Scrollable),
            )
            .first,
      );
      expect(tester.takeException(), isNull);
      expect(transport.joins, 0);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });
  }
  testWidgets(
    'forget locally works without any configured server and does not claim a server leave',
    (tester) async {
      final backend = MemoryCredentialBackend(),
          store = RoomCredentialStore(backend);
      await store.save(testCredential());
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            roomCredentialStoreProvider.overrideWithValue(store),
            roomTransportProvider.overrideWith(
              (ref) => throw StateError('not configured'),
            ),
          ],
          child: const MaterialApp(home: MultiplayerEntryScreen()),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Nur lokal vergessen'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining(
          'Deine Teilnahme im Raum wird dadurch nicht beendet.',
        ),
        findsOneWidget,
      );
      await tester.tap(
        widgetWithActionText(FilledButton, 'Nur lokal vergessen'),
      );
      await tester.pumpAndSettle();
      expect((await store.load()).credentials, isEmpty);
      expect(actionText('Partie fortsetzen'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  test('join routes are bounded closed relative inputs; invitation uses the public client origin only', () {
    expect(codeFromJoinRoute('/join?room=abcd-23%2045'), 'ABCD2345');
    for (final bad in [
      '/join?room=ABCD2345&token=secret',
      '/join?room=ABCD2345&room=ABCD2345',
      'https://foreign.example/join?room=ABCD2345',
      '//foreign.example/join?room=ABCD2345',
      '/join?room=ABCD2345#token',
      '/join?room=%ZZ',
      '/join?room=ABCD2345&host=true',
      '/join?room=${'X' * 257}',
    ]) {
      expect(codeFromJoinRoute(bad), isNull);
    }
    final uri = invitationUri(Uri.parse('https://client.example'), 'abcd-2345');
    expect(uri.toString(), 'https://client.example/join?room=ABCD2345');
    expect(uri.queryParameters.keys, ['room']);
    for (final base in [
      'https://user:pass@example.com',
      'https://example.com/api',
      'javascript:alert(1)',
      'https://example.com?resumeToken=secret',
    ]) {
      expect(
        () => invitationUri(Uri.parse(base), 'ABCD2345'),
        throwsFormatException,
      );
    }
  });
  testWidgets('a QR join link immediately joins with a pending name', (
    tester,
  ) async {
    final transport = FakeRoomTransport(),
        store = RoomCredentialStore(MemoryCredentialBackend());
    await tester.pumpWidget(
      host(
        const SizedBox(),
        transport,
        store,
        initialRoute: '/join?room=abcd-23%2045',
      ),
    );
    for (var i = 0; i < 20 && transport.connections == 0; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(find.byKey(const ValueKey('room-code')), findsNothing);
    expect(find.byKey(const ValueKey('room-submit')), findsNothing);
    expect(transport.joins, 1);
    expect(transport.connections, 1);
    expect(transport.lastProfile!.name, pendingRoomProfileName);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.byType(RoomConnectionScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });
  testWidgets(
    'QR link resumes the existing identity instead of creating duplicate players',
    (tester) async {
      final transport = FakeRoomTransport(),
          store = RoomCredentialStore(MemoryCredentialBackend());
      await store.save(testCredential());
      await tester.pumpWidget(
        host(
          const SizedBox(),
          transport,
          store,
          initialRoute: '/join?room=ABCD2345',
        ),
      );
      for (var i = 0; i < 20 && transport.connections == 0; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(transport.joins, 0);
      expect(transport.connections, 1);
      expect((await store.load()).credentials, hasLength(1));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      expect(find.byType(RoomConnectionScreen), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'manual code entry resumes the stored identity without creating a duplicate',
    (tester) async {
      final backend = MemoryCredentialBackend(),
          store = RoomCredentialStore(backend),
          transport = FakeRoomTransport();
      final saved = RoomCredential(
        serverOrigin: testCredential().serverOrigin,
        message: CredentialMessage.fromJson({
          ...testCredential().message.toJson(),
          'playerId': 'previous',
        }),
      );
      await store.save(saved);
      await tester.pumpWidget(
        host(const MultiplayerEntryScreen(), transport, store),
      );
      await tester.pumpAndSettle();
      expect(actionText('Partie fortsetzen'), findsOneWidget);
      await tester.tap(actionText('ABCD2345 · Spieler previous'));
      await tester.pump();
      await tester.pump();
      expect(transport.joins, 0);
      expect(transport.connections, 1);
      // The resumed identity is the stored one; use a matching server-auth projection.
      transport.sockets.last.receive(
        AuthenticatedMessage.fromJson({
          ...roomFixture('authenticated').toJson(),
          'playerId': 'previous',
        }),
      );
      transport.sockets.last.receive(
        SnapshotMessage.fromJson({
          ...roomFixture('snapshot').toJson(),
          'you': 'previous',
        }),
      );
      await tester.pumpAndSettle();
      expect((await store.load()).credentials, hasLength(1));
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      await tester.pumpWidget(
        host(const JoinRoomScreen(initialCode: 'ABCD2345'), transport, store),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const ValueKey('room-submit')));
      await tester.tap(find.byKey(const ValueKey('room-submit')));
      await tester.pump();
      await tester.pump();
      expect(transport.joins, 0);
      expect((await store.load()).credentials, hasLength(1));
      transport.sockets.last.receive(
        AuthenticatedMessage.fromJson({
          ...roomFixture('authenticated').toJson(),
          'playerId': 'previous',
        }),
      );
      transport.sockets.last.receive(
        SnapshotMessage.fromJson({
          ...roomFixture('snapshot').toJson(),
          'you': 'previous',
        }),
      );
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    },
  );
  testWidgets(
    'room-full error is understandable and does not create a fabricated session',
    (tester) async {
      final transport = FakeRoomTransport()..entryError = 'ROOM_FULL',
          store = RoomCredentialStore(MemoryCredentialBackend());
      await tester.pumpWidget(
        host(const JoinRoomScreen(initialCode: 'ABCD2345'), transport, store),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const ValueKey('room-submit')));
      await tester.tap(find.byKey(const ValueKey('room-submit')));
      await tester.pumpAndSettle();
      expect(find.textContaining('Der Raum ist voll.'), findsOneWidget);
      expect(transport.connections, 0);
      expect((await store.load()).credentials, isEmpty);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    },
  );
  testWidgets(
    'local QR payload is only a public invitation and clipboard failure offers a usable fallback',
    (tester) async {
      final transport = FakeRoomTransport(),
          store = RoomCredentialStore(MemoryCredentialBackend());
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            throw PlatformException(code: 'blocked');
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await tester.pumpWidget(
        host(
          const Scaffold(body: RoomInvite(code: 'ABCD2345')),
          transport,
          store,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(QrImageView), findsOneWidget);
      final payload = tester
          .widget<SelectableText>(find.byType(SelectableText))
          .data!;
      expect(payload, 'https://client.example/join?room=ABCD2345');
      expect(payload, isNot(contains(testCredential().message.resumeToken)));
      expect(payload, isNot(contains('8787')));
      await tester.tap(actionText('Einladungslink kopieren'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Kopieren nicht möglich.'), findsOneWidget);
      expect(find.byType(SelectableText), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
