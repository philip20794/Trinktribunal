import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trinktribunal/application/room_providers.dart';
import 'package:trinktribunal/data/catalogs/catalog_repository.dart';
import 'package:trinktribunal/data/protocol/room_message.dart';
import 'package:trinktribunal/data/room_credential_store.dart';
import 'package:trinktribunal/features/multiplayer/connection.dart';
import 'package:trinktribunal/features/multiplayer/create.dart';
import 'package:trinktribunal/features/multiplayer/join.dart';
import 'package:trinktribunal/features/multiplayer/me.dart';
import 'package:trinktribunal/l10n/app_strings.dart';

import '../data/room_test_support.dart';
import 'online_numbers_test.dart' as numbers;

void main() {
  setUpAll(() async {
    numbers.catalogs = await CatalogRepository(
      read: (path) => File(path).readAsString(),
    ).load();
  });
  testWidgets(
    'saving an already confirmed online profile returns with a small notice',
    (tester) async {
      await numbers.pump(tester);
      final context = tester.element(find.byType(RoomConnectionScreen));
      Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const RoomProfileScreen()),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.text(const AppStrings('de').get('roomProfileFlush')),
      );
      await tester.pumpAndSettle();
      expect(find.byType(RoomProfileScreen), findsNothing);
      expect(
        find.text(const AppStrings('de').get('savedNotice')),
        findsOneWidget,
      );
      expect(find.byType(SnackBar), findsNothing);
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect(
        find.text(const AppStrings('de').get('savedNotice')),
        findsNothing,
      );
    },
  );
  for (final create in [false, true]) {
    testWidgets(
      'return to existing room from ${create ? "create" : "join"} preserves identity',
      (tester) async {
        final fixture = await numbers.pump(tester, host: true, lobby: true);
        final context = tester.element(find.byType(RoomConnectionScreen));
        final container = ProviderScope.containerOf(context);
        await container
            .read(roomCredentialStoreProvider)
            .save(
              RoomCredential(
                serverOrigin: testCredential().serverOrigin,
                message: CredentialMessage.fromJson({
                  ...testCredential().message.toJson(),
                  'playerId': 'p1',
                }),
              ),
            );
        container.invalidate(savedRoomsProvider);
        final original = fixture.room.state.snapshot!;
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) =>
                create ? const CreateRoomScreen() : const JoinRoomScreen(),
          ),
        );
        for (var frame = 0; frame < 10; frame++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        final code = testCredential().message.roomCode;
        final resume = find.byKey(
          ValueKey(create ? 'resume-hosted-room-$code' : 'resume-room-$code'),
        );
        expect(resume.hitTestable(), findsOneWidget);
        if (!create) {
          expect(
            tester.getRect(resume).bottom,
            lessThan(
              tester.getRect(find.byKey(const ValueKey('room-code'))).top,
            ),
          );
        }
        await tester.tap(resume);
        await tester.pumpAndSettle();
        final socket = fixture.transport.sockets.last;
        await tester.pumpAndSettle();
        expect(fixture.room.state.snapshot!.roomId, original.roomId);
        expect(fixture.room.state.snapshot!.you, original.you);
        expect(fixture.transport.creates, 0);
        expect(socket.sent.whereType<CloseRoomMessage>(), isEmpty);
        expect(find.byType(JoinRoomScreen), findsNothing);
        expect(find.byType(CreateRoomScreen), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
