import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trinktribunal/design/avatar_view.dart';
import 'package:trinktribunal/domain/avatar_config.dart';
import 'package:trinktribunal/domain/bench_order.dart';
import 'package:trinktribunal/domain/models/ids.dart';
import 'package:trinktribunal/domain/models/player.dart';
import 'package:trinktribunal/domain/user_profile.dart';
import 'package:trinktribunal/features/bench/bench_view.dart';

void main() {
  testWidgets(
    'twenty portraits fit together at 200 percent text without image assets',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(1200, 900),
              textScaler: TextScaler.linear(2),
            ),
            child: Scaffold(
              body: Wrap(
                children: [
                  for (var i = 0; i < 20; i++)
                    SizedBox(
                      width: 120,
                      child: Column(
                        children: [
                          AvatarView(
                            config: AvatarConfig().withOption(
                              'hair',
                              i.isEven ? 'short01' : 'long01',
                            ),
                            size: 76,
                          ),
                          Text('Person ${i + 1}'),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
      expect(find.byType(AvatarView), findsNWidgets(20));
      for (final element in find.byType(AvatarView).evaluate()) {
        final rect = tester.getRect(find.byWidget(element.widget));
        expect(
          const Rect.fromLTWH(0, 0, 1200, 900).contains(rect.bottomRight),
          isTrue,
        );
      }
      expect(find.byType(Image), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  for (final size in [const Size(360, 800), const Size(1440, 1000)]) {
    testWidgets(
      'twenty-person bank survives fifty reordered cases at 200 percent on $size',
      (tester) async {
        await tester.binding.setSurfaceSize(size);
        addTearDown(() => tester.binding.setSurfaceSize(null));
        var order = [for (var i = 0; i < 20; i++) PlayerId('p$i')];
        final profiles = {
          for (final id in order)
            id: UserProfile(
              player: Player(id: id, name: 'Person ${id.value}'),
              avatar: AvatarConfig(),
            ),
        };
        late StateSetter update;
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(
                size: size,
                textScaler: const TextScaler.linear(2),
              ),
              child: Scaffold(
                body: StatefulBuilder(
                  builder: (context, setState) {
                    update = setState;
                    return BenchView(
                      order: order,
                      profiles: profiles,
                      onMove: (from, to) =>
                          setState(() => order = insertPlayer(order, from, to)),
                    );
                  },
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final initialElements = find.byType(AvatarView).evaluate().length;
        final scrollable = tester.state<ScrollableState>(
          find.byType(Scrollable).first,
        );
        final initialExtent = scrollable.position.maxScrollExtent;
        for (var round = 0; round < 50; round++) {
          update(() => order = insertPlayer(order, 0, 19));
          await tester.pumpAndSettle();
          expect(find.byType(AvatarView), findsNWidgets(initialElements));
          expect(order.toSet().length, 20);
          expect(scrollable.position.maxScrollExtent, initialExtent);
          expect(tester.takeException(), isNull);
        }
        // Exercise the actual edge-scroll callback using a drag target's global coordinates.
        final target = tester.widget<DragTarget<PlayerId>>(
          find.byType(DragTarget<PlayerId>).first,
        );
        final bankRect = tester.getRect(find.byType(BenchView));
        target.onMove!(
          DragTargetDetails(
            data: order.first,
            offset: bankRect.bottomCenter - const Offset(0, 1),
          ),
        );
        await tester.pump();
        expect(scrollable.position.pixels, greaterThan(0));
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        expect(find.byType(AvatarView), findsNothing);
      },
    );
  }
}
