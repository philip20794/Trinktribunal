import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trinktribunal/data/protocol/room_message.dart';
import 'package:trinktribunal/features/multiplayer/host_status.dart';
import 'package:trinktribunal/l10n/app_strings.dart';

import '../data/room_test_support.dart';

void main() {
  testWidgets(
    'host status follows authoritative presence and revision with no local takeover timer',
    (tester) async {
      final base = roomFixture('snapshot') as SnapshotMessage;
      Future<void> show(SnapshotMessage snapshot) => tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: OnlineHostStatus(snapshot: snapshot)),
        ),
      );
      final offline = SnapshotMessage.fromJson({
        ...base.toJson(),
        'public': {
          ...base.public.toJson(),
          'players': base.public.players
              .map(
                (p) => {
                  ...p.toJson(),
                  'connected': p.playerId != base.public.hostId,
                },
              )
              .toList(),
        },
      });
      await show(offline);
      expect(
        find.text(AppStrings('de').get('onlineHostGrace')),
        findsOneWidget,
      );
      await tester.pump(const Duration(seconds: 91));
      expect(
        find.text(AppStrings('de').get('onlineHostGrace')),
        findsOneWidget,
      );
      final name = base.public.players
          .firstWhere((p) => p.playerId == base.you)
          .profile
          .name;
      await show(
        SnapshotMessage.fromJson({
          ...base.toJson(),
          'public': {
            ...base.public.toJson(),
            'hostId': base.you.value,
            'hostRevision': 1,
          },
        }),
      );
      expect(
        find.text(AppStrings('de').get('onlineHostYou', {'name': name})),
        findsOneWidget,
      );
      expect(find.byType(FilledButton), findsNothing);
    },
  );
}
