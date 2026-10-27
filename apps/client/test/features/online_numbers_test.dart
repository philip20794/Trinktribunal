import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trinktribunal/application/room_controller.dart';
import 'package:trinktribunal/application/room_providers.dart';
import 'package:trinktribunal/data/catalogs/catalog_repository.dart';
import 'package:trinktribunal/data/protocol/room_message.dart';
import 'package:trinktribunal/data/room_credential_store.dart';
import 'package:trinktribunal/design/private_number.dart';
import 'package:trinktribunal/features/multiplayer/connection.dart';
import 'package:trinktribunal/l10n/app_strings.dart';
import 'package:trinktribunal/domain/models/ids.dart';

import '../data/room_test_support.dart';

late Catalogs catalogs;
SnapshotMessage view({
  bool lobby = false,
  bool host = false,
  String language = 'de',
  bool own = true,
}) {
  final base = roomFixture('snapshot') as SnapshotMessage;
  return SnapshotMessage.fromJson({
    ...base.toJson(),
    'you': host ? 'p1' : 'p2',
    'public': {
      ...base.public.toJson(),
      'phase': lobby ? 'lobby' : 'numbers',
      'gameId': lobby ? null : 'game_1',
      'roundId': lobby ? null : 'round_1',
      'judgeId': lobby ? null : 'p1',
      'question': lobby
          ? null
          : {
              'contentId': '003-b',
              'bindings': {'player1': 'p2'},
            },
      'frozenRoster': lobby ? [] : ['p1', 'p2', 'p3'],
      'config': {...base.public.config.toJson(), 'contentLanguage': language},
    },
    'private': !lobby && own ? {'ownNumber': 2} : <String, Object?>{},
  });
}

Future<({RoomController room, FakeRoomTransport transport})> pump(
  WidgetTester tester, {
  bool lobby = false,
  bool host = false,
  String uiLanguage = 'de',
  String contentLanguage = 'de',
  bool own = true,
}) async {
  final transport = FakeRoomTransport(),
      store = RoomCredentialStore(MemoryCredentialBackend()),
      room = RoomController(transport: transport, credentials: store);
  final credential = RoomCredential(
    serverOrigin: testCredential().serverOrigin,
    message: CredentialMessage.fromJson({
      ...testCredential().message.toJson(),
      'playerId': host ? 'p1' : 'p2',
    }),
  );
  addTearDown(room.dispose);
  await room.resume(credential);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        roomControllerProvider.overrideWithValue(room),
        roomCredentialStoreProvider.overrideWithValue(store),
        catalogsProvider.overrideWith((_) async => catalogs),
      ],
      child: AppLanguageScope(
        language: uiLanguage,
        child: const MaterialApp(home: RoomConnectionScreen()),
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
  transport.sockets.last.receive(
    view(lobby: lobby, host: host, language: contentLanguage, own: own),
  );
  await tester.pumpAndSettle();
  return (room: room, transport: transport);
}

Future<void> tapText(WidgetTester tester, String text) async {
  final finder = find.text(text);
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'a rejected settings save releases the pending control for a deliberate retry',
    (tester) async {
      final fixture = await pump(tester, lobby: true, host: true),
          socket = fixture.transport.sockets.last;
      tester.widgetList<Slider>(find.byType(Slider)).first.onChanged!(7);
      await tester.pump();
      await tapText(tester, 'Einstellungen übernehmen');
      socket.receive(
        ErrorMessage.create(
          requestId: RequestId('settings_error'),
          code: 'RATE_LIMITED',
        ),
      );
      await tester.pumpAndSettle();
      await tapText(tester, 'Einstellungen übernehmen');
      expect(socket.sent.whereType<SetConfigMessage>(), hasLength(2));
    },
  );
  setUpAll(() async {
    catalogs = await CatalogRepository(
      read: (path) => File(path).readAsString(),
    ).load();
  });
  for (final language in ['de', 'en']) {
    testWidgets(
      'host content language $language resolves question and scale with stable binding',
      (tester) async {
        final fixture = await pump(
          tester,
          contentLanguage: language,
          uiLanguage: language == 'de' ? 'en' : 'de',
        );
        final question = catalogs.questions[language]!.entries.firstWhere(
          (q) => q.id == '003-b',
        );
        final snapshot = fixture.room.state.snapshot!,
            name = snapshot.public.players
                .firstWhere((p) => p.playerId.value == 'p2')
                .profile
                .name;
        final rendered = question.renderFor({'player1': name});
        expect(find.text(rendered.text), findsOneWidget);
        expect(find.text('1 · ${rendered.green}'), findsOneWidget);
        expect(find.text('5 · ${rendered.red}'), findsOneWidget);
        expect(find.textContaining('{player1}'), findsNothing);
        expect(
          tester.widget<PrivateNumber>(find.byType(PrivateNumber)).number,
          isNull,
        );
        expect(
          fixture.transport.sockets.last.sent
              .whereType<AcknowledgeNumberMessage>(),
          isEmpty,
        );
      },
    );
  }
  testWidgets(
    'own number hides on lifecycle and tab changes, acknowledgement is explicit and bound to round',
    (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        final fixture = await pump(tester),
            socket = fixture.transport.sockets.last;
        expect(
          find.bySemanticsLabel(RegExp('Deine geheime Zahl: 2')),
          findsNothing,
        );
        await tapText(tester, 'Meine Zahl bewusst öffnen');
        expect(find.text('2'), findsOneWidget);
        await tester.ensureVisible(find.text('2'));
        await tester.pumpAndSettle();
        expect(
          tester.getSemantics(find.text('2')).getSemanticsData().label,
          contains('Deine geheime Zahl: 2'),
        );
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.inactive,
        );
        await tester.pump();
        expect(find.text('2'), findsNothing);
        expect(
          find.bySemanticsLabel(RegExp('Deine geheime Zahl: 2')),
          findsNothing,
        );
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pump();
        expect(find.text('2'), findsNothing);
        await tapText(tester, 'Meine Zahl bewusst öffnen');
        await tester.tap(find.widgetWithText(Tab, 'Ich'));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(Tab, 'Gerichtssaal'));
        await tester.pumpAndSettle();
        expect(find.text('2'), findsNothing);
        expect(socket.sent.whereType<AcknowledgeNumberMessage>(), isEmpty);
        await tapText(tester, 'Meine Zahl bewusst öffnen');
        await tapText(tester, 'Zahl merken und bestätigen');
        expect(find.text('2'), findsNothing);
        final action = socket.sent.whereType<AcknowledgeNumberMessage>().single;
        expect(action.roundId, fixture.room.state.snapshot!.public.roundId);
        expect(action.expectedRevision, 1);
        expect(tester.takeException(), isNull);
      } finally {
        semantics.dispose();
      }
    },
  );
  testWidgets('normal judge gets no secret-number controls', (tester) async {
    await pump(tester, host: true, own: false);
    expect(find.byType(PrivateNumber), findsNothing);
    expect(
      find.text('Als Richter bekommst du in diesem Fall keine Geheimzahl.'),
      findsOneWidget,
    );
  });
  testWidgets(
    'host saves explicit integer configuration before start, without optimistic game transition',
    (tester) async {
      final fixture = await pump(tester, lobby: true, host: true),
          socket = fixture.transport.sockets.last;
      final sliders = tester.widgetList<Slider>(find.byType(Slider)).toList();
      sliders.first.onChanged!(7);
      await tester.pump();
      expect(socket.sent.whereType<SetConfigMessage>(), isEmpty);
      await tapText(tester, 'Einstellungen übernehmen');
      final config = socket.sent.whereType<SetConfigMessage>().single;
      expect(config.config.targetCases, 7);
      expect(config.expectedRevision, 1);
      expect(socket.sent.whereType<StartGameMessage>(), isEmpty);
      final snapshot = fixture.room.state.snapshot!;
      socket.receive(
        SnapshotMessage.fromJson({
          ...snapshot.toJson(),
          'revision': 2,
          'public': {
            ...snapshot.public.toJson(),
            'config': config.config.toJson(),
          },
        }),
      );
      await tester.pumpAndSettle();
      await tapText(tester, 'Verhandlung starten');
      expect(
        socket.sent.whereType<StartGameMessage>().single.expectedRevision,
        2,
      );
      expect(fixture.room.state.snapshot!.public.phase, 'lobby');
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'non-host sees frozen settings summary without editable options or start',
    (tester) async {
      await pump(tester, lobby: true);
      expect(find.byType(Slider), findsNothing);
      expect(find.text('Verhandlung starten'), findsNothing);
      expect(
        find.text('Der Host richtet die Partie ein und startet sie.'),
        findsOneWidget,
      );
    },
  );
}
