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
      await tester.tap(find.byTooltip(label));
      await tester.pumpAndSettle();
      await tester.tap(find.text(AppStrings('de').get('cancel')));
      await tester.pumpAndSettle();
      expect(socket.sent.whereType<CloseRoomMessage>(), isEmpty);
      await tester.tap(find.byTooltip(label));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, label));
      await tester.pumpAndSettle();
      expect(socket.sent.whereType<CloseRoomMessage>(), hasLength(1));
      expect(f.room.state.snapshot, isNotNull);
    },
  );
}
