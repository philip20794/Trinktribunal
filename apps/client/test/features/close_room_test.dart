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
