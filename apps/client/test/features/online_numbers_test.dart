import '../support/hold_action.dart';

import 'package:trinktribunal/design/hold_action_button.dart';
import 'package:trinktribunal/design/case_stage.dart';

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
import 'package:trinktribunal/design/court_theme.dart';
import 'package:trinktribunal/design/court_scene.dart';
import 'package:trinktribunal/features/multiplayer/connection.dart';
import 'package:trinktribunal/features/multiplayer/invite.dart';
import 'package:trinktribunal/l10n/app_strings.dart';
import 'package:trinktribunal/domain/models/ids.dart';

import '../data/room_test_support.dart';
import '../support/memory_string_store.dart';

import 'package:trinktribunal/application/local_data_providers.dart';

late Catalogs catalogs;
SnapshotMessage view({
  bool lobby = false,
  bool allJudges = false,
  bool host = false,
  String language = 'de',
  bool own = true,
  String? playerId,
}) {
  final base = roomFixture('snapshot') as SnapshotMessage;
  return SnapshotMessage.fromJson({
    ...base.toJson(),
    'you': playerId ?? (host ? 'p1' : 'p2'),
    'public': {
      ...base.public.toJson(),
      'phase': lobby ? 'lobby' : 'numbers',
      'gameId': lobby ? null : 'game_1',
      'roundId': lobby ? null : 'round_1',
      'judgeId': lobby || allJudges ? null : 'p1',
      'readerId': !lobby && allJudges ? 'p1' : null,
      'question': lobby
          ? null
          : {
              'contentId': '003-b',
              'bindings': {'player1': 'p2'},
            },
      'frozenRoster': lobby ? [] : ['p1', 'p2', 'p3'],
      'config': {
        ...base.public.config.toJson(),
        'contentLanguage': language,
        'allJudges': allJudges,
      },
    },
    'private': !lobby && own ? {'ownNumber': 2} : <String, Object?>{},
  });
}

Future<({RoomController room, FakeRoomTransport transport})> pump(
  WidgetTester tester, {
  bool lobby = false,
  bool allJudges = false,
  bool host = false,
  String uiLanguage = 'de',
  String contentLanguage = 'de',
  bool own = true,
  bool newRoom = false,
  double textScale = 1,
  ThemeData? theme,
  Uri? publicClientBase,
  String? playerId,
  MemoryStringStore? tutorialStore,
}) async {
  final transport = FakeRoomTransport(),
      store = RoomCredentialStore(MemoryCredentialBackend()),
      room = RoomController(transport: transport, credentials: store);
  final credential = RoomCredential(
    serverOrigin: testCredential().serverOrigin,
    message: CredentialMessage.fromJson({
      ...testCredential().message.toJson(),
      'playerId': playerId ?? (host ? 'p1' : 'p2'),
    }),
  );
  addTearDown(room.dispose);
  await room.resume(credential);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        stringStoreProvider.overrideWithValue(
          tutorialStore ??
              (MemoryStringStore()
                ..values['online.courtTutorialSeen.v1'] = 'true'),
        ),
        if (publicClientBase != null)
          publicClientBaseProvider.overrideWithValue(publicClientBase),
        roomControllerProvider.overrideWithValue(room),
        roomCredentialStoreProvider.overrideWithValue(store),
        catalogsProvider.overrideWith((_) async => catalogs),
      ],
      child: RepaintBoundary(
        key: const ValueKey('scene-review'),
        child: AppLanguageScope(
          language: uiLanguage,
          child: MaterialApp(
            theme: theme,
            home: RoomConnectionScreen(newRoom: newRoom),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(textScale),
                disableAnimations: true,
              ),
              child: child!,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  transport.sockets.last.receive(
    AuthenticatedMessage.fromJson({
      ...roomFixture('authenticated').toJson(),
      'playerId': playerId ?? (host ? 'p1' : 'p2'),
    }),
  );
  transport.sockets.last.receive(
    view(
      lobby: lobby,
      allJudges: allJudges,
      host: host,
      language: contentLanguage,
      own: own,
      playerId: playerId,
    ),
  );
  await tester.pumpAndSettle();
  return (room: room, transport: transport);
}

Future<void> tapText(WidgetTester tester, String text) async {
  var finder = find.text(text);
  if (finder.evaluate().isEmpty &&
      ['de', 'en'].any(
        (language) => [
          AppStrings(language).get('phoneReveal'),
          AppStrings(language).get('phoneHide'),
        ].contains(text),
      )) {
    finder = find.byKey(const ValueKey('compact-private-number'));
  }
  if (finder.evaluate().isEmpty &&
      [
        'de',
        'en',
      ].any((lang) => text == AppStrings(lang).get('localGameOptions'))) {
    await tester.ensureVisible(find.byType(Tab).last);
    await tester.tap(find.byType(Tab).last);
    await tester.pumpAndSettle();
  }
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  if (find
      .ancestor(of: finder, matching: find.byType(HoldActionButton))
      .evaluate()
      .isNotEmpty) {
    await holdAction(tester, finder);
  } else {
    await tester.tap(finder);
  }
  await tester.pumpAndSettle();
}

void main() {
  for (final scale in [1.0, 2.0]) {
    testWidgets(
      'case hold fills the footer before and after completing an order: $scale',
      (tester) async {
        final fixture = await pump(tester, allJudges: true, textScale: scale);
        final base = fixture.room.state.snapshot!;
        fixture.transport.sockets.last.receive(
          SnapshotMessage.fromJson({
            ...base.toJson(),
            'revision': 2,
            'public': {...base.public.toJson(), 'phase': 'ordering'},
          }),
        );
        await tester.pumpAndSettle();
        await tester.tap(
          find.widgetWithText(Tab, const AppStrings('de').get('caseTabTitle')),
        );
        await tester.pumpAndSettle();
        final container = ProviderScope.containerOf(
          tester.element(find.byType(RoomConnectionScreen)),
        );
        final order = container.read(onlineOrderProvider);
        for (final complete in [false, true]) {
          if (complete) {
            for (var i = 0; i < base.public.frozenRoster.length; i++) {
              order.place(base.public.frozenRoster[i], i);
            }
            await tester.pumpAndSettle();
          }
          expect(find.byType(HoldActionButton), findsOneWidget);
          expect(
            tester.getSize(find.byType(HoldActionButton)).width,
            closeTo(tester.getSize(find.byType(CourtActionBar)).width - 40, .1),
          );
        }
        expect(
          fixture.transport.sockets.last.sent.whereType<SubmitOrderMessage>(),
          isEmpty,
        );
      },
    );
  }
  testWidgets('the first held number survives another player becoming ready', (
    tester,
  ) async {
    final fixture = await pump(tester, allJudges: true);
    final held = await startChargedHold(
      tester,
      find.text(AppStrings('de').get('holdToReveal')),
    );
    expect(tester.widget<FlipCase>(find.byType(FlipCase)).number, 2);
    final base = fixture.room.state.snapshot!;
    fixture.transport.sockets.last.receive(
      SnapshotMessage.fromJson({
        ...base.toJson(),
        'revision': base.revision + 1,
        'public': {
          ...base.public.toJson(),
          'players': [
            for (final player in base.public.players)
              {
                ...player.toJson(),
                if (player.playerId.value == 'p3') 'ready': true,
              },
          ],
        },
      }),
    );
    await tester.pumpAndSettle();
    expect(tester.widget<FlipCase>(find.byType(FlipCase)).number, 2);
    for (final key in [
      'onlineAnswerReady',
      'phoneBeginOrder',
      'goToCourtroom',
    ]) {
      expect(find.text(AppStrings('de').get(key)), findsNothing);
    }
    await held.up();
    await tester.pumpAndSettle();
    expect(tester.widget<FlipCase>(find.byType(FlipCase)).number, isNull);
  });
  for (final language in ['de', 'en']) {
    for (final host in [false, true]) {
      testWidgets(
        'online number screen at 200 percent, $language, host=$host',
        (tester) async {
          await tester.binding.setSurfaceSize(const Size(360, 800));
          addTearDown(() => tester.binding.setSurfaceSize(null));
          final semantics = tester.ensureSemantics();
          try {
            await pump(
              tester,
              uiLanguage: language,
              host: host,
              own: !host,
              textScale: 2,
              theme: courtTheme(),
            );
            expect(tester.takeException(), isNull);
            expect(
              find.bySemanticsLabel(
                RegExp(AppStrings(language).get('secretNumber', {'number': 2})),
              ),
              findsNothing,
            );
            await expectLater(
              tester,
              meetsGuideline(labeledTapTargetGuideline),
            );
            await expectLater(
              tester,
              meetsGuideline(androidTapTargetGuideline),
            );
            for (final element in find.byType(Scrollable).evaluate().toList()) {
              if (!element.mounted) continue;
              final state =
                  (element as StatefulElement).state as ScrollableState;
              state.position.jumpTo(state.position.maxScrollExtent);
              await tester.pumpAndSettle();
              expect(tester.takeException(), isNull);
            }
          } finally {
            semantics.dispose();
          }
        },
      );
    }
  }
  testWidgets(
    'host completion stays reachable when a departed question reference cannot render',
    (tester) async {
      final fixture = await pump(tester, host: true, own: false),
          socket = fixture.transport.sockets.last,
          base = fixture.room.state.snapshot!;
      socket.receive(
        SnapshotMessage.fromJson({
          ...base.toJson(),
          'revision': 2,
          'public': {
            ...base.public.toJson(),
            'players': base.public.players
                .where((player) => player.playerId.value != 'p2')
                .map((player) => player.toJson())
                .toList(),
          },
        }),
      );
      await tester.pumpAndSettle();
      await tapText(tester, AppStrings('de').get('nextJudge'));
      expect(
        socket.sent
            .whereType<CompleteWithoutVerdictMessage>()
            .single
            .expectedRevision,
        2,
      );
    },
  );
  testWidgets('a rejected automatic settings save offers a deliberate retry', (
    tester,
  ) async {
    final fixture = await pump(tester, lobby: true, host: true),
        socket = fixture.transport.sockets.last;
    await tapText(tester, AppStrings('de').get('localGameOptions'));
    tester.widgetList<Slider>(find.byType(Slider)).first.onChanged!(7);
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    expect(socket.sent.whereType<SetConfigMessage>(), hasLength(1));
    socket.receive(
      ErrorMessage.create(
        requestId: RequestId('settings_error'),
        code: 'RATE_LIMITED',
      ),
    );
    await tester.pumpAndSettle();
    final retry = AppStrings('de').get('retry');
    expect(
      tester
          .widget<TextButton>(find.widgetWithText(TextButton, retry))
          .onPressed,
      isNotNull,
    );
    await tapText(tester, retry);
    expect(socket.sent.whereType<SetConfigMessage>(), hasLength(2));
  });
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
        expect(find.text(rendered.green), findsOneWidget);
        expect(find.text(rendered.red), findsOneWidget);
        expect(find.textContaining('{player1}'), findsNothing);
        expect(tester.widget<FlipCase>(find.byType(FlipCase)).number, isNull);
        expect(
          fixture.transport.sockets.last.sent
              .whereType<AcknowledgeNumberMessage>(),
          isEmpty,
        );
      },
    );
  }
  testWidgets(
    'charged number is hidden on release, background and tab changes',
    (tester) async {
      final fixture = await pump(tester),
          socket = fixture.transport.sockets.last;
      final target = find.text(AppStrings('de').get('holdToReveal'));
      var gesture = await startChargedHold(tester, target);
      expect(tester.widget<FlipCase>(find.byType(FlipCase)).number, 2);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pumpAndSettle();
      expect(tester.widget<FlipCase>(find.byType(FlipCase)).number, isNull);
      await gesture.up();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      gesture = await startChargedHold(tester, target);
      await tester.tap(
        find.widgetWithText(Tab, AppStrings('de').get('roomMeTab')),
      );
      await tester.pumpAndSettle();
      await gesture.up();
      await tester.tap(
        find.widgetWithText(Tab, AppStrings('de').get('caseTabTitle')),
      );
      await tester.pumpAndSettle();
      expect(tester.widget<FlipCase>(find.byType(FlipCase)).number, isNull);
      gesture = await startChargedHold(tester, target);
      expect(tester.widget<FlipCase>(find.byType(FlipCase)).number, 2);
      await gesture.up();
      await tester.pumpAndSettle();
      expect(tester.widget<FlipCase>(find.byType(FlipCase)).number, isNull);
      expect(socket.sent.whereType<AcknowledgeNumberMessage>(), hasLength(1));
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('normal judge gets no secret-number controls', (tester) async {
    await pump(tester, host: true, own: false);
    expect(find.byType(PrivateNumber), findsNothing);
    expect(
      find.text('Als Richter bekommst du in diesem Fall keine Geheimzahl.'),
      findsNothing,
    );
  });
  testWidgets(
    'host automatically saves integer settings before start, without optimistic game transition',
    (tester) async {
      final fixture = await pump(tester, lobby: true, host: true),
          socket = fixture.transport.sockets.last;
      await tapText(tester, AppStrings('de').get('localGameOptions'));
      final sliders = tester.widgetList<Slider>(find.byType(Slider)).toList();
      sliders.first.onChanged!(7);
      await tester.pump();
      expect(socket.sent.whereType<SetConfigMessage>(), isEmpty);
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
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
      expect(find.byKey(const PageStorageKey('host-room-tools')), findsNothing);
      expect(find.text('Verhandlung starten'), findsNothing);
      expect(find.byType(Slider), findsNothing);
    },
  );
}
