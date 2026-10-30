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
  for (final kind in ['roster', 'bench', 'bench-compact', 'seats']) {
    testWidgets(
      '$kind: hover previews insertion; return cancels; release commits once',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(360, 640));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        var order = List<PlayerId>.of(ids);
        var commits = 0;
        var edits = 0;
        late VoidCallback remoteUpdate;
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
                      remoteUpdate = () =>
                          update(() => order = ids.reversed.toList());
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
                              onEdit: (_) => edits++,
                              onRemove: (_, _) {},
                              isOwner: (_) => false,
                            ),
                          ],
                        ),
                        'bench' || 'bench-compact' => BenchView(
                          compactControls: kind == 'bench-compact',
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
            destination = kind == 'bench'
                ? (tester.getCenter(seat(1)) + tester.getCenter(seat(2))) / 2
                : (tester.getCenter(seat(2)) + tester.getCenter(seat(3))) / 2;
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
        expect(ghosts, findsOneWidget);
        expect(find.byKey(const ValueKey('drag-origin-ghost')), findsNothing);
        final gap = tester.widget<Opacity>(
          find.descendant(of: ghosts, matching: find.byType(Opacity)).first,
        );
        expect(gap.opacity, 0);
        expect(find.byType(LiftedDragAvatar), findsWidgets);
        final feedbackUnit = find
            .descendant(
              of: find.byType(LiftedDragAvatar),
              matching: find.byType(ReorderAvatarUnit),
            )
            .first;
        final feedbackRect = tester.getRect(feedbackUnit);
        final feedbackNumber = tester.getRect(
          find.descendant(
            of: feedbackUnit,
            matching: find.byKey(const ValueKey('avatar-number')),
          ),
        );
        expect(feedbackNumber.left, closeTo(feedbackRect.left + 8 * 1.055, 1));
        expect(feedbackNumber.top, closeTo(feedbackRect.top, 1));
        if (kind == 'roster') {
          expect(
            find.descendant(
              of: feedbackUnit,
              matching: find.byType(PopupMenuButton<String>),
            ),
            findsOneWidget,
          );
        }
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
        final neighbour = find
            .byWidgetPredicate(
              (widget) =>
                  widget is DragPreviewSlide &&
                  !widget.ghost &&
                  widget.offset != Offset.zero,
            )
            .first;
        final slide = tester.widget<DragPreviewSlide>(neighbour);
        final transform = tester.widget<Transform>(
          find
              .descendant(of: neighbour, matching: find.byType(Transform))
              .first,
        );
        final translation = transform.transform.getTranslation();
        final travelled = Offset(translation.x, translation.y).distance;
        expect(travelled, greaterThan(0));
        expect(travelled, lessThan(slide.offset.distance));
        // Measure real targets and rendered transforms while the finger stays down.
        final moving = tester
            .widgetList<DragPreviewSlide>(find.byType(DragPreviewSlide))
            .where((s) => !s.ghost && s.offset != Offset.zero)
            .toList();
        expect(moving.any((s) => s.offset.dx < 0), isTrue);
        expect(moving.any((s) => s.offset.dx > 0), isTrue);
        for (final item in moving) {
          final finder = find.byKey(item.key!);
          final avatar = tester.widget<AvatarView>(
            find
                .descendant(of: finder, matching: find.byType(AvatarView))
                .first,
          );
          expect(item.offset.dy, 0);
          expect(item.offset.dx.abs(), closeTo(avatar.size * .25, .01));
          final unit = find
              .descendant(of: finder, matching: find.byType(ReorderAvatarUnit))
              .first;
          final number = find.descendant(
            of: unit,
            matching: find.byKey(const ValueKey('avatar-number')),
          );
          expect(
            tester.getTopLeft(number),
            tester.getTopLeft(unit) + const Offset(8, 0),
          );
          tester.element(unit).visitAncestorElements((element) {
            if (element.widget is DragTarget<PlayerId>) return false;
            final widget = element.widget;
            if (widget is DecoratedBox && widget.decoration is BoxDecoration) {
              expect((widget.decoration as BoxDecoration).border, isNull);
            }
            return true;
          });
        }
        await reviewImage(tester, 'ghost-insertion-$kind');
        await drag.moveTo(tester.getCenter(seat(1)));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 230));
        expect(commits, 0);
        expect(order, ids);
        expect(
          tester.widget<DragPreviewSlide>(ghosts).offset,
          isNot(slide.offset),
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
        await tester.pump();
        await drag.cancel();
        await tester.pumpAndSettle();
        expect(order, ids);
        expect(commits, 0);
        drag = await pickUp();
        await drag.moveTo(destination);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        final beforeDrop = {
          for (final slide in tester.widgetList<DragPreviewSlide>(
            find.byType(DragPreviewSlide),
          ))
            if (!slide.ghost) slide.key!: slide.offset,
        };
        Offset rendered(Finder finder) {
          final matrix = tester
              .widget<Transform>(
                find
                    .descendant(of: finder, matching: find.byType(Transform))
                    .first,
              )
              .transform;
          return Offset(matrix.getTranslation().x, matrix.getTranslation().y);
        }

        await drag.up();
        expect(commits, 0);
        await tester.pump();
        expect(find.byKey(const ValueKey('reorder-landing')), findsOneWidget);
        final opening = tester
            .widgetList<DragPreviewSlide>(find.byType(DragPreviewSlide))
            .firstWhere((s) => !s.ghost && beforeDrop[s.key] != s.offset);
        final openingFinder = find.byKey(opening.key!);
        expect(
          (rendered(openingFinder) - beforeDrop[opening.key]!).distance,
          lessThan(.01),
        );
        await tester.pump(const Duration(milliseconds: 120));
        expect(commits, 0);
        expect(rendered(openingFinder), isNot(beforeDrop[opening.key]));
        expect(rendered(openingFinder), isNot(opening.offset));
        await tester.pumpAndSettle();
        expect(commits, 1);
        expect(
          order,
          kind == 'bench'
              ? [ids[1], ids[0], ids[2], ids[3]]
              : [ids[1], ids[2], ids[0], ids[3]],
        );
        expect(ghosts, findsNothing);
        if (kind == 'roster') {
          await tester.tap(find.byKey(const ValueKey('roster-menu-a')));
          await tester.pumpAndSettle();
          await tester.tap(find.byType(PopupMenuItem<String>).first);
          await tester.pumpAndSettle();
          expect(edits, 1);
        }
        // A server/parent update during landing wins over the pending local drop.
        drag = await pickUp();
        await drag.moveTo(tester.getCenter(seat(0)));
        await tester.pump();
        await drag.up();
        await tester.pump();
        remoteUpdate();
        await tester.pumpAndSettle();
        expect(commits, 1);
        expect(order, ids.reversed.toList());
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
  test(
    'half gap is 50 percent wide in both row directions and with a pool player',
    () {
      for (final reversed in [false, true]) {
        final cells = List.generate(
          4,
          (i) => Rect.fromLTWH((reversed ? 3 - i : i) * 100, 0, 100, 100),
        );
        final offsets = halfReorderGap<String>(
          slots: ['a', 'b', 'c', 'd'],
          preview: ['a', 'd', 'b', 'c'],
          dragged: 'd',
          cells: cells,
          avatarWidth: 100,
        );
        expect(offsets['a']!.dx, reversed ? 25 : -25);
        expect(offsets['b']!.dx, reversed ? -25 : 25);
        expect((offsets['a']! - offsets['b']!).dx.abs(), 50);
        final pool = halfReorderGap<String>(
          slots: ['a', 'b', null, 'd'],
          preview: ['a', 'c', 'b', 'd'],
          dragged: 'c',
          cells: cells,
          avatarWidth: 100,
        );
        expect((pool['a']! - pool['b']!).dx.abs(), 50);
      }
    },
  );
  test(
    'cell halves identify insertion boundaries after removing the source',
    () {
      const cell = Rect.fromLTWH(100, 0, 100, 100);
      for (final reversed in [false, true]) {
        expect(
          reorderInsertionIndex(
            source: 3,
            hovered: 1,
            cell: cell,
            pointer: const Offset(110, 50),
            count: 4,
            reversed: reversed,
          ),
          reversed ? 2 : 1,
        );
        expect(
          reorderInsertionIndex(
            source: 3,
            hovered: 1,
            cell: cell,
            pointer: const Offset(190, 50),
            count: 4,
            reversed: reversed,
          ),
          reversed ? 1 : 2,
        );
      }
    },
  );
  test('only the active insertion row opens at a row boundary', () {
    const slots = ['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i'];
    const preview = ['a', 'b', 'c', 'i', 'd', 'e', 'f', 'g', 'h'];
    final cells = List.generate(
      9,
      (i) => Rect.fromLTWH(i % 3 * 100, i ~/ 3 * 120, 100, 108),
    );
    for (final active in [2, 3]) {
      final offsets = halfReorderGap<String>(
        slots: slots,
        preview: preview,
        dragged: 'i',
        cells: cells,
        avatarWidth: 100,
        activeIndex: active,
      );
      for (var i = 0; i < slots.length - 1; i++) {
        if (i ~/ 3 != active ~/ 3) expect(offsets[slots[i]], Offset.zero);
      }
    }
    final between = reorderBetweenRows(
      cells: cells,
      pointer: const Offset(150, 114),
      source: 8,
    );
    expect(between, (cell: 3, index: 3));
    expect(
      reorderBetweenRows(
        cells: cells,
        pointer: const Offset(150, 114),
        source: 0,
      ),
      (cell: 3, index: 2),
    );
  });
  testWidgets(
    'three rows: gap drop keeps other rows still and animates row changes',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(540, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      var order = List.generate(9, (i) => PlayerId('row-$i'));
      final original = List<PlayerId>.of(order);
      final people = {
        for (final id in order)
          id: UserProfile(
            player: Player(id: id, name: id.value),
            avatar: AvatarConfig(),
          ),
      };
      var commits = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: courtSceneTheme(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(size: const Size(540, 1000)),
            child: child!,
          ),
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, update) => BenchView(
                compactControls: true,
                order: order,
                profiles: people,
                onMove: (from, to) => update(() {
                  commits++;
                  order = insertPlayer(order, from, to);
                }),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final upper = tester.getRect(find.byKey(ValueKey(order[2])));
      final lower = tester.getRect(find.byKey(ValueKey(order[3])));
      final gap = Offset(270, (upper.bottom + lower.top) / 2);
      final drag = await tester.startGesture(
        tester.getCenter(draggable(order.last)),
      );
      await tester.pump(const Duration(milliseconds: 550));
      await drag.moveTo(gap);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      Finder slide(int i) =>
          find.byKey(ValueKey(('bench-preview', original[i], 0)));
      Offset rendered(Finder finder) {
        final matrix = tester
            .widget<Transform>(
              find
                  .descendant(of: finder, matching: find.byType(Transform))
                  .first,
            )
            .transform;
        return Offset(matrix.getTranslation().x, matrix.getTranslation().y);
      }

      for (final i in [0, 1, 2, 6, 7]) {
        expect(tester.widget<DragPreviewSlide>(slide(i)).offset, Offset.zero);
        expect(rendered(slide(i)), Offset.zero);
      }
      for (final i in [3, 4, 5]) {
        expect(
          tester.widget<DragPreviewSlide>(slide(i)).offset,
          const Offset(19, 0),
        );
      }
      expect(commits, 0);
      await drag.up();
      await tester.pump();
      final full = tester.widget<DragPreviewSlide>(slide(5)).offset;
      expect(full.dy, greaterThan(0));
      await tester.pump(const Duration(milliseconds: 120));
      expect(rendered(slide(5)).dy, greaterThan(0));
      expect(rendered(slide(5)).dy, lessThan(full.dy));
      expect(commits, 0);
      await tester.pumpAndSettle();
      expect(commits, 1);
      expect(order[3], original.last);
      expect(tester.takeException(), isNull);
    },
  );
}
