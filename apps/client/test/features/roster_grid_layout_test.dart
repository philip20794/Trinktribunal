import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trinktribunal/application/local_data_providers.dart';
import 'package:trinktribunal/design/avatar_view.dart';
import 'package:trinktribunal/domain/avatar_config.dart';
import 'package:trinktribunal/features/setup/player_roster.dart';

import '../design/court_scene_test.dart' show reviewImage;
import '../support/roster_setup.dart';
import 'ui_cleanup_test.dart' show host;

void main() {
  setUpAll(() async {
    await TrinkAvatarRenderer.svg(AvatarConfig());
    if (!const bool.fromEnvironment('TT_RENDER_REVIEW')) return;
    final font = FontLoader('CourtRoboto');
    for (final weight in ['regular', 'medium', 'bold']) {
      font.addFont(rootBundle.load('assets/fonts/roboto-$weight.ttf'));
    }
    await font.load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });
  for (final cards in [false, true]) {
    testWidgets('local roster uses adjacent full avatars: cards=$cards', (
      tester,
    ) async {
      await host(
        tester,
        PlayerRosterScreen(cardMode: cards),
        'de',
        size: const Size(390, 844),
      );
      await addTestPlayers(tester);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(PlayerRosterScreen)),
      );
      final people = container.read(rosterProvider).requireValue.members;
      final first = tester.getRect(find.byKey(ValueKey(people[0].player.id)));
      final second = tester.getRect(find.byKey(ValueKey(people[1].player.id)));
      expect(second.top, closeTo(first.top, 1));
      expect(second.left, greaterThan(first.left));
      expect(find.byType(AvatarView), findsNWidgets(3));
      expect(find.byType(ReorderableListView), findsNothing);
      for (var frame = 0; frame < 3; frame++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pump();
      }
      await reviewImage(tester, 'local-roster-${cards ? "cards" : "phone"}');
      expect(tester.takeException(), isNull);
    });
  }
}
