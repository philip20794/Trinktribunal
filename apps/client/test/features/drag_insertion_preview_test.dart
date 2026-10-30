import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trinktribunal/design/avatar_view.dart';
import 'package:trinktribunal/design/drag_preview_slide.dart';
import 'package:trinktribunal/design/court_scene.dart';
import 'package:trinktribunal/domain/avatar_config.dart';
import 'package:trinktribunal/domain/bench_order.dart';
import 'package:trinktribunal/domain/models/ids.dart';
import 'package:trinktribunal/domain/models/player.dart';
import 'package:trinktribunal/domain/user_profile.dart';
import 'package:trinktribunal/features/bench/bench_view.dart';
import 'package:trinktribunal/features/bench/placement_bank.dart';
import 'package:trinktribunal/features/bench/roster_grid.dart';

import '../design/court_scene_test.dart' show reviewImage;

final ids = [
  for (final id in ['a', 'b', 'c', 'd']) PlayerId(id),
];
final profiles = {
  for (final id in ids)
    id: UserProfile(
      player: Player(id: id, name: id.value),
      avatar: AvatarConfig(),
    ),
};

Finder draggable(PlayerId id) => find.byWidgetPredicate(
  (widget) => widget is Draggable<PlayerId> && widget.data == id,
);
Finder get ghosts => find.byWidgetPredicate(
  (widget) => widget is DragPreviewSlide && widget.ghost,
);

void main() {
  setUpAll(() async {
    await TrinkAvatarRenderer.svg(AvatarConfig(), showBackdrop: false);
    if (const bool.fromEnvironment('TT_RENDER_REVIEW')) {
      final font = FontLoader('CourtRoboto');
      for (final weight in ['regular', 'medium', 'bold']) {
        font.addFont(rootBundle.load('assets/fonts/roboto-$weight.ttf'));
      }
      await font.load();
      await (FontLoader(
        'MaterialIcons',
      )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    }
  });
  for (final kind in ['roster', 'bench', 'seats']) {
    testWidgets(
      '$kind: hover previews insertion; return cancels; release commits once',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(360, 640));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        var order = List<PlayerId>.of(ids);
        var commits = 0;
        await tester.pumpWidget(
          MaterialApp(
            theme: courtSceneTheme(),
            builder: (context, child) => RepaintBoundary(
              key: const ValueKey('scene-review'),
              child: child!,
            ),
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  height: 500,
                  width: 360,
                  child: StatefulBuilder(
                    builder: (context, update) {
                      void move(int from, int to) => update(() {
                        commits++;
                        order = insertPlayer(order, from, to);
                      });
                      return switch (kind) {
                        'roster' => CustomScrollView(
                          slivers: [
                            RosterGrid(
                              members: order
                                  .map((id) => profiles[id]!)
                                  .toList(),
                              onMove: move,
                              onEdit: (_) {},
                              onRemove: (_, _) {},
                              isOwner: (_) => false,
                            ),
                          ],
                        ),
                        'bench' => BenchView(
                          order: order,
                          profiles: profiles,
                          onMove: move,
                        ),
                        _ => PlacementBank(
                          slots: order,
                          unplaced: const [],
                          profiles: profiles,
                          onPlace: (id, index) => update(() {
                            commits++;
                            order = placePlayer(
                              order,
                              id,
                              index,
                            ).whereType<PlayerId>().toList();
                          }),
                          onRemove: (_) {},
                        ),
                      };
                    },
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        Finder seat(int index) => find.byKey(
          kind == 'seats'
              ? ValueKey('order-seat-$index')
              : ValueKey(order[index]),
        );
        final home = tester.getCenter(seat(0)),
            destination = tester.getCenter(seat(2));
        Future<TestGesture> pickUp() async {
          final drag = await tester.startGesture(
            tester.getCenter(draggable(ids.first)),
          );
          await tester.pump(const Duration(milliseconds: 550));
          return drag;
        }

        var drag = await pickUp();
        await drag.moveTo(destination);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 120));
        expect(commits, 0);
        expect(order, ids);
        await reviewImage(tester, 'ghost-insertion-$kind');
        expect(ghosts, findsOneWidget);
        expect(
          tester.widget<DragPreviewSlide>(ghosts).offset,
          isNot(Offset.zero),
        );
        expect(
          tester
              .widgetList<DragPreviewSlide>(find.byType(DragPreviewSlide))
              .where((slide) => slide.offset != Offset.zero)
              .length,
          greaterThanOrEqualTo(3),
        );
        for (final avatar in tester.widgetList<AvatarView>(
          find.byType(AvatarView),
        )) {
          expect(avatar.showBackdrop, isFalse);
        }
        await drag.moveTo(home);
        await tester.pump(const Duration(milliseconds: 300));
        await drag.up();
        await tester.pumpAndSettle();
        expect(order, ids);
        expect(commits, 0);
        expect(ghosts, findsNothing);
        drag = await pickUp();
        await drag.moveTo(destination);
        await tester.pump(const Duration(milliseconds: 300));
        await drag.up();
        await tester.pumpAndSettle();
        expect(commits, 1);
        expect(order, [ids[1], ids[2], ids[0], ids[3]]);
        expect(ghosts, findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }
  test(
    'inserting from the pool preserves other people and consumes a vacancy',
    () {
      final slots = [ids[0], ids[1], null, ids[3]];
      expect(placePlayer(slots, ids[2], 1), [ids[0], ids[2], ids[1], ids[3]]);
      expect(slots, [ids[0], ids[1], null, ids[3]]);
      expect(placePlayer(slots, ids[3], 0), [ids[3], ids[0], ids[1], null]);
    },
  );
}
