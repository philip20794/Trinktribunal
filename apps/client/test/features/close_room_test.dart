import '../support/action_text.dart';

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trinktribunal/data/catalogs/catalog_repository.dart';
import 'package:trinktribunal/data/protocol/room_message.dart';
import 'package:trinktribunal/l10n/app_strings.dart';

import 'online_numbers_test.dart' as numbers;

void main() {
  setUpAll(() async {
    numbers.catalogs = await CatalogRepository(
      read: (path) => File(path).readAsString(),
    ).load();
  });
  for (final host in [true, false]) {
    testWidgets(
      'online avatar back dismisses sheet before room dialog: host=$host',
      (tester) async {
        final fixture = await numbers.pump(tester, host: host, own: false);
        await tester.tap(
          find
              .descendant(
                of: find.byKey(const ValueKey('room-tabs')),
                matching: find.byType(Tab),
              )
              .first,
        );
        await tester.pumpAndSettle();
        final option = find.byWidgetPredicate(
          (w) =>
              w.key is ValueKey<String> &&
              (w.key as ValueKey<String>).value.startsWith(
                'online-avatar-option-hair:',
              ),
        );
        await tester.tap(option);
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('avatar-editor-sheet')),
          findsOneWidget,
        );
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('avatar-editor-sheet')), findsNothing);
        expect(find.byKey(const ValueKey('court-dialog-close')), findsNothing);
        expect(
          fixture.transport.sockets.last.sent.whereType<CloseRoomMessage>(),
          isEmpty,
        );
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('court-dialog-close')),
          findsOneWidget,
        );
        await tester.tap(find.byKey(const ValueKey('court-dialog-close')));
        await tester.pumpAndSettle();
      },
    );
  }
  testWidgets(
    'host room close requires confirmation and does not optimistically erase the session',
    (tester) async {
      final f = await numbers.pump(tester, host: true, own: false),
          socket = f.transport.sockets.last,
          label = AppStrings('de').get('roomClose');
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('court-dialog-close')));
      await tester.pumpAndSettle();
      expect(socket.sent.whereType<CloseRoomMessage>(), isEmpty);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await tester.tap(widgetWithActionText(FilledButton, label));
      await tester.pumpAndSettle();
      expect(socket.sent.whereType<CloseRoomMessage>(), hasLength(1));
      expect(f.room.state.snapshot, isNotNull);
      socket.receive(
        RoomClosedMessage.fromJson({
          'type': 'roomClosed',
          'protocolVersion': 2,
          'requestId': 'close_ack',
        }),
      );
      await tester.pumpAndSettle();
      expect(f.room.state.snapshot, isNull);
    },
  );
}
