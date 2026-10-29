import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trinktribunal/application/local_data_providers.dart';
import 'package:trinktribunal/design/case_file.dart';
import 'package:trinktribunal/design/avatar_view.dart';
import 'package:trinktribunal/design/court_scene.dart';
import 'package:trinktribunal/domain/avatar_config.dart';
import 'package:trinktribunal/domain/bench_order.dart';
import 'package:trinktribunal/domain/models/ids.dart';
import 'package:trinktribunal/domain/models/player.dart';
import 'package:trinktribunal/domain/user_profile.dart';
import 'package:trinktribunal/features/bench/bench_view.dart';
import 'package:trinktribunal/features/setup/player_roster.dart';
import 'package:trinktribunal/l10n/app_strings.dart';

import '../accessibility/screen_matrix_test.dart' show accessibilityHost;

Map<PlayerId, UserProfile> profiles(int count) => {
  for (var i = 0; i < count; i++)
    PlayerId('p$i'): UserProfile(
      player: Player(id: PlayerId('p$i'), name: 'Alexandra Beispiel'),
      avatar: AvatarConfig(),
    ),
};

Future<void> showInScroll(WidgetTester tester, Finder target) async {
  await Scrollable.ensureVisible(tester.element(target), alignment: .5);
  await tester.pumpAndSettle();
  expect(target.hitTestable(), findsOneWidget);
}

void main() {
  for (final count in [3, 4, 5, 7, 20]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        '$count duplicate long names: snake geometry and labels at $scale',
        (tester) async {
          await tester.binding.setSurfaceSize(const Size(360, 800));
          addTearDown(() => tester.binding.setSurfaceSize(null));
          final people = profiles(count), ids = profiles(count).keys.toList();
          await tester.pumpWidget(
            accessibilityHost(
              Builder(
                builder: (context) => MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(textScaler: TextScaler.linear(scale)),
                  child: CourtScaffold(
                    body: Padding(
                      padding: const EdgeInsets.all(16),
                      child: BenchView(order: ids, profiles: people),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final columns = scale == 1 ? 3 : 2;
          final base = tester.getRect(find.byKey(ValueKey(ids.first)));
          for (var i = 0; i < count; i++) {
            final position = snakePosition(i, columns);
            final rect = tester.getRect(find.byKey(ValueKey(ids[i])));
            expect(
              rect.left,
              closeTo(base.left + position.column * (328 / columns), .1),
            );
            if (position.row == 0) expect(rect.top, base.top);
            if (position.row > 0) expect(rect.top, greaterThan(base.top));
          }
          expect(find.byType(NamePlate), findsNothing);
          expect(find.byType(AvatarView), findsNWidgets(count));
          expect(find.byType(DragTarget<PlayerId>), findsNWidgets(count));
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets(
    'tap insertion and drag keep identity order and revealed values bound to IDs',
    (tester) async {
      var order = profiles(7).keys.toList();
      final original = List<PlayerId>.of(order), people = profiles(7);
      final numbers = {for (var i = 0; i < order.length; i++) order[i]: i + 11};
      await tester.pumpWidget(
        accessibilityHost(
          Scaffold(
            body: StatefulBuilder(
              builder: (context, update) => BenchView(
                order: order,
                profiles: people,
                revealedNumbers: numbers,
                onMove: (from, to) =>
                    update(() => order = insertPlayer(order, from, to)),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      Finder person(PlayerId id) => find
          .descendant(
            of: find.byKey(ValueKey(id)),
            matching: find.byType(InkWell),
          )
          .first;
      await showInScroll(tester, person(original[0]));
      await tester.tap(person(original[0]));
      await tester.pumpAndSettle();
      await showInScroll(tester, person(original[2]));
      await tester.tap(person(original[2]));
      await tester.pumpAndSettle();
      expect(order, [
        original[1],
        original[2],
        original[0],
        ...original.skip(3),
      ]);
      final target = find.byKey(ValueKey(original[1]));
      await showInScroll(tester, target);
      final dragTarget = tester.widget<DragTarget<PlayerId>>(target);
      // Exercise the actual drop callback after the first insertion.
      dragTarget.onAcceptWithDetails!(
        DragTargetDetails(data: original[2], offset: Offset.zero),
      );
      await tester.pumpAndSettle();
      expect(order, [
        original[2],
        original[1],
        original[0],
        ...original.skip(3),
      ]);
      expect(numbers[original[0]], 11);
      expect(numbers[original[2]], 13);
      final numberText = find.descendant(
        of: find.byKey(ValueKey(original[2])),
        matching: find.textContaining('13'),
      );
      expect(numberText, findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  for (final language in ['de', 'en']) {
    testWidgets(
      'compact roster quick add, reorder, edit, swipe and undo, $language',
      (tester) async {
        final strings = AppStrings(language);
        await tester.pumpWidget(
          accessibilityHost(
            const PlayerRosterScreen(allowStart: false),
            language: language,
          ),
        );
        await tester.pumpAndSettle();
        final container = ProviderScope.containerOf(
          tester.element(find.byType(PlayerRosterScreen)),
        );
        final roster = container.read(rosterProvider).requireValue;
        for (final name in ['Alex', 'Alex', 'Cleo']) {
          await tester.enterText(
            find.byKey(const ValueKey('quick-player-name')),
            name,
          );
          await tester.testTextInput.receiveAction(TextInputAction.done);
          await tester.pumpAndSettle();
        }
        tester.testTextInput.hide();
        await tester.pumpAndSettle();
        expect(find.byType(BenchView), findsNothing);
        final before = roster.members.map((p) => p.player.id).toList();
        tester
            .widget<ReorderableListView>(find.byType(ReorderableListView))
            .onReorderItem!(0, 2);
        await tester.pumpAndSettle();
        expect(roster.members.map((p) => p.player.id), [
          before[1],
          before[2],
          before[0],
        ]);
        final row = find.byKey(ValueKey(before[0]));
        await showInScroll(tester, row);
        await tester.tap(
          find.descendant(of: row, matching: find.byType(ListTile)),
        );
        await tester.pumpAndSettle();
        await tester.enterText(
          find.descendant(
            of: find.byType(AlertDialog),
            matching: find.byType(TextField),
          ),
          'Renamed',
        );
        await tester.tap(find.text(strings.get('rosterApply')));
        await tester.pumpAndSettle();
        expect(roster.members.last.player.id, before[0]);
        final person = roster.members.first;
        final deleteRow = find.byKey(ValueKey(person.player.id));
        await showInScroll(tester, deleteRow);
        await tester.drag(deleteRow, const Offset(700, 0));
        await tester.pumpAndSettle();
        expect(
          roster.members.any((p) => p.player.id == person.player.id),
          isFalse,
        );
        await tester.tap(find.text(strings.get('undo')));
        await tester.pumpAndSettle();
        expect(roster.members.first.player.id, person.player.id);
        expect(roster.members.first.avatar.toJson(), person.avatar.toJson());
        expect(tester.takeException(), isNull);
      },
    );
  }
}
