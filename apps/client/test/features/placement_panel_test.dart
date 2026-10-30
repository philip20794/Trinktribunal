import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trinktribunal/design/avatar_view.dart';
import 'package:trinktribunal/domain/avatar_config.dart';
import 'package:trinktribunal/domain/models/ids.dart';
import 'package:trinktribunal/domain/models/player.dart';
import 'package:trinktribunal/domain/user_profile.dart';
import 'package:trinktribunal/features/bench/placement_bank.dart';

import '../accessibility/screen_matrix_test.dart' show accessibilityHost;
import '../design/court_scene_test.dart' show reviewImage;

Future<void> pumpBank(
  WidgetTester tester, {
  int count = 3,
  Size size = const Size(360, 600),
  double scale = 1,
  bool animations = false,
}) async {
  await tester.binding.setSurfaceSize(size);
  final profiles = <PlayerId, UserProfile>{
    for (var i = 0; i < count; i++)
      PlayerId('p$i'): UserProfile(
        player: Player(
          id: PlayerId('p$i'),
          name: count == 3
              ? ['Zora', 'anna', 'Bernd'][i]
              : 'Person ${i.toString().padLeft(2, '0')}',
        ),
        avatar: AvatarConfig(),
      ),
  };
  final slots = List<PlayerId?>.filled(count, null);
  await tester.pumpWidget(
    accessibilityHost(
      Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: !animations),
          child: RepaintBoundary(
            key: const ValueKey('scene-review'),
            child: Scaffold(
              backgroundColor: const Color(0xFF231A17),
              body: StatefulBuilder(
                builder: (context, update) => PlacementBank(
                  slots: List.of(slots),
                  unplaced: profiles.keys
                      .where((id) => !slots.contains(id))
                      .toList(),
                  profiles: profiles,
                  onPlace: (id, index) => update(() {
                    final old = slots.indexOf(id), displaced = slots[index];
                    if (old >= 0) slots[old] = displaced;
                    slots[index] = id;
                  }),
                  onRemove: (id) => update(() {
                    final index = slots.indexOf(id);
                    if (index >= 0) slots[index] = null;
                  }),
                ),
              ),
            ),
          ),
        ),
      ),
      textScale: scale,
      size: size,
    ),
  );
  await tester.pumpAndSettle();
}

Finder keyed(String key) => find.byKey(ValueKey(key));
Finder get gridScroll => find.descendant(
  of: find.byType(GridView),
  matching: find.byType(Scrollable),
);
Finder get poolScroll => find.descendant(
  of: keyed('placement-pool-list'),
  matching: find.byType(Scrollable),
);

Future<TestGesture> startPoolDrag(WidgetTester tester, String id) async {
  final gesture = await tester.startGesture(
    tester.getCenter(keyed('unplaced-$id')),
  );
  await tester.pump(const Duration(milliseconds: 200));
  return gesture;
}

void main() {
  setUpAll(() async {
    await TrinkAvatarRenderer.svg(AvatarConfig());
    await TrinkAvatarRenderer.headSvg(AvatarConfig());
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
  testWidgets(
    'alphabetical heads and names stay on the right; tap places a person',
    (tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await pumpBank(tester);
      expect(find.byType(AvatarHeadView), findsNWidgets(3));
      expect(find.byType(AvatarView), findsNothing);
      expect(
        tester.getTopLeft(keyed('unplaced-p1')).dy,
        lessThan(tester.getTopLeft(keyed('unplaced-p2')).dy),
      );
      expect(
        tester.getTopLeft(keyed('unplaced-p2')).dy,
        lessThan(tester.getTopLeft(keyed('unplaced-p0')).dy),
      );
      expect(tester.getSize(keyed('placement-pool-panel')).width, 56);
      await reviewImage(tester, 'placement-head-pool');
      await tester.tap(keyed('unplaced-p1'));
      await tester.pumpAndSettle();
      await tester.tap(keyed('order-seat-0'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<PlacementBank>(find.byType(PlacementBank)).slots.first,
        PlayerId('p1'),
      );
      expect(find.byType(AvatarView), findsOneWidget);
      expect(keyed('unplaced-p1'), findsNothing);
      expect(keyed('remove-seat-0'), findsNothing);
      expect(find.text('anna'), findsOneWidget);
      expect(
        tester.getSize(find.byType(GridView)).width,
        tester.getSize(find.byType(PlacementBank)).width,
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'drag animates to 20 percent and 16px; right edge opens and accepts return',
    (tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await pumpBank(tester, animations: true);
      final gesture = await startPoolDrag(tester, 'p1');
      await gesture.moveTo(tester.getCenter(keyed('order-seat-0')));
      await tester.pump(const Duration(milliseconds: 90));
      final shrinking = tester.getSize(keyed('placement-pool-panel')).width;
      expect(shrinking, greaterThan(16));
      expect(shrinking, lessThan(56));
      await tester.pump(const Duration(milliseconds: 150));
      expect(
        tester.getSize(keyed('placement-pool-panel')).width,
        closeTo(16, .1),
      );
      expect(
        tester.widget<AnimatedOpacity>(keyed('placement-pool-opacity')).opacity,
        .2,
      );
      await gesture.up();
      await tester.pumpAndSettle();
      expect(
        tester.widget<PlacementBank>(find.byType(PlacementBank)).slots.first,
        PlayerId('p1'),
      );

      final placed = find.descendant(
        of: keyed('order-seat-0'),
        matching: find.byType(Draggable<PlayerId>),
      );
      final returning = await tester.startGesture(
        tester.getCenter(placed) + const Offset(-15, 12),
      );
      await returning.moveBy(const Offset(-25, 0));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 220));
      expect(
        tester.getSize(keyed('placement-pool-panel')).width,
        closeTo(16, .1),
      );
      await returning.moveTo(const Offset(356, 280));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 220));
      expect(
        tester.getSize(keyed('placement-pool-panel')).width,
        closeTo(56, .1),
      );
      expect(
        tester.widget<AnimatedOpacity>(keyed('placement-pool-opacity')).opacity,
        1,
      );
      await returning.up();
      await tester.pumpAndSettle();
      expect(
        tester.widget<PlacementBank>(find.byType(PlacementBank)).slots.first,
        isNull,
      );
      expect(keyed('unplaced-p1').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('pool scrolls independently and canceled drag keeps its person', (
    tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpBank(tester, count: 20, size: const Size(320, 420));
    final grid = tester.state<ScrollableState>(gridScroll);
    await tester.scrollUntilVisible(
      keyed('unplaced-p19'),
      200,
      scrollable: poolScroll,
    );
    await tester.pumpAndSettle();
    expect(grid.position.pixels, 0);
    final pool = tester.state<ScrollableState>(poolScroll);
    expect(pool.position.pixels, greaterThan(0));
    final before = pool.position.pixels;
    final gesture = await startPoolDrag(tester, 'p19');
    await gesture.moveTo(const Offset(-50, 150));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();
    expect(
      tester.widget<PlacementBank>(find.byType(PlacementBank)).unplaced,
      hasLength(20),
    );
    expect(pool.position.pixels, closeTo(before, .1));
    expect(tester.getSize(keyed('placement-pool-panel')).width, 56);
    expect(tester.takeException(), isNull);
  });
  for (final scale in [1.0, 2.0]) {
    testWidgets(
      'adaptive occupied seats fit and survive resize at text scale $scale',
      (tester) async {
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await pumpBank(
          tester,
          count: 20,
          size: const Size(900, 800),
          scale: scale,
        );
        await reviewImage(tester, 'placement-pool-full-${scale.toInt()}');
        var bank = tester.widget<PlacementBank>(find.byType(PlacementBank));
        for (var index = 0; index < 20; index++) {
          bank.onPlace!(PlayerId('p$index'), index);
        }
        await tester.pumpAndSettle();
        final large = tester
            .widgetList<AvatarView>(find.byType(AvatarView))
            .first
            .size;
        expect(
          tester.state<ScrollableState>(gridScroll).position.maxScrollExtent,
          closeTo(0, .1),
        );
        await reviewImage(tester, 'placement-wide-${scale.toInt()}');
        await tester.binding.setSurfaceSize(const Size(320, 420));
        await tester.pumpAndSettle();
        for (final portrait in tester.widgetList<AvatarView>(
          find.byType(AvatarView),
        )) {
          expect(
            portrait.size,
            inInclusiveRange(
              PlacementBank.minAvatarSize,
              PlacementBank.maxAvatarSize,
            ),
          );
          expect(portrait.size, lessThan(large));
        }
        await tester.scrollUntilVisible(
          keyed('order-seat-19'),
          200,
          scrollable: gridScroll,
        );
        await tester.pumpAndSettle();
        expect(keyed('order-seat-19').hitTestable(), findsOneWidget);
        await reviewImage(tester, 'placement-small-${scale.toInt()}');
        expect(tester.takeException(), isNull);
      },
    );
  }
}
