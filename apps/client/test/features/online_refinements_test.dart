import 'dart:io';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trinktribunal/data/catalogs/catalog_repository.dart';
import 'package:trinktribunal/data/protocol/room_message.dart';
import 'package:trinktribunal/l10n/app_strings.dart';
import 'package:trinktribunal/design/illustrated_paper.dart';
import 'package:trinktribunal/design/court_drag_hint.dart';
import 'package:trinktribunal/design/avatar_view.dart';
import 'package:trinktribunal/domain/avatar_config.dart';

import '../support/memory_string_store.dart';
import '../design/court_scene_test.dart' show reviewImage;
import 'online_numbers_test.dart' as numbers;
import 'personal_verdict_test.dart' show personalView;

void main() {
  setUpAll(() async {
    numbers.catalogs = await CatalogRepository(
      read: (path) => File(path).readAsString(),
    ).load();
    await TrinkAvatarRenderer.svg(AvatarConfig());
    for (final profile in personalView(errors: 2).public.players) {
      await TrinkAvatarRenderer.svg(
        AvatarConfig.fromJson(profile.profile.avatar.toJson()),
      );
    }
    final loaded = Completer<void>();
    final stream = PaperImages.ruleImage.resolve(ImageConfiguration.empty);
    final listener = ImageStreamListener(
      (image, _) {
        image.dispose();
        if (!loaded.isCompleted) loaded.complete();
      },
      onError: (Object error, StackTrace? stack) {
        if (!loaded.isCompleted) loaded.completeError(error, stack);
      },
    );
    stream.addListener(listener);
    await loaded.future;
    stream.removeListener(listener);

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
    'game swipes stay between Court and Case; the avatar preview can leave Me',
    (tester) async {
      await numbers.pump(tester, allJudges: true, host: true);
      final controller = DefaultTabController.of(
        tester.element(find.byKey(const ValueKey('room-tabs'))),
      );
      expect(controller.index, 2);
      Future<void> swipe(Offset offset) async {
        await tester.drag(find.byKey(const ValueKey('room-tab-pages')), offset);
        await tester.pumpAndSettle();
      }

      await swipe(const Offset(-450, 0));
      expect(controller.index, 2);
      await swipe(const Offset(450, 0));
      expect(controller.index, 1);
      await swipe(const Offset(450, 0));
      expect(controller.index, 1);
      for (final index in [0, 3]) {
        await tester.tap(
          find
              .descendant(
                of: find.byKey(const ValueKey('room-tabs')),
                matching: find.byType(Tab),
              )
              .at(index),
        );
        await tester.pumpAndSettle();
        expect(controller.index, index);
        if (index == 0) {
          final portrait = tester.getRect(
            find.byKey(const ValueKey('online-avatar-preview')),
          );
          await tester.dragFrom(
            Offset(portrait.center.dx, portrait.top + portrait.height * .25),
            const Offset(-450, 0),
          );
          await tester.pumpAndSettle();
          expect(controller.index, 1);
        } else {
          await swipe(const Offset(-450, 0));
          expect(controller.index, index);
        }
      }
    },
  );
  testWidgets(
    'the drag demonstration is floating, finite and remembered across room visits',
    (tester) async {
      final store = MemoryStringStore();
      await numbers.pump(tester, allJudges: true, tutorialStore: store);
      expect(store.values['online.courtTutorialSeen.v1'], isNull);
      await tester.tap(
        find
            .descendant(
              of: find.byKey(const ValueKey('room-tabs')),
              matching: find.byType(Tab),
            )
            .at(1),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(
        store.values['online.courtTutorialSeen.v1'],
        'true',
        reason: 'tutorial preference written',
      );
      await tester.pump();
      expect(find.byType(CourtDragHint), findsOneWidget);
      expect(store.values['online.courtTutorialSeen.v1'], 'true');
      await reviewImage(tester, 'online-first-drag-hint');
      await tester.pump(const Duration(seconds: 7));
      await tester.pumpAndSettle();
      expect(find.byType(CourtDragHint), findsNothing);
      await tester.pumpWidget(const SizedBox());
      await numbers.pump(tester, allJudges: true, tutorialStore: store);
      await tester.tap(
        find
            .descendant(
              of: find.byKey(const ValueKey('room-tabs')),
              matching: find.byType(Tab),
            )
            .at(1),
      );
      await tester.pumpAndSettle();
      expect(find.byType(CourtDragHint), findsNothing);
    },
  );
  testWidgets('only the reader sees the paper reroll', (tester) async {
    final fixture = await numbers.pump(tester, allJudges: true, host: true);
    const refresh = ValueKey('case-paper-refresh');
    expect(find.byKey(refresh), findsOneWidget);
    final base = fixture.room.state.snapshot!;
    fixture.transport.sockets.last.receive(
      SnapshotMessage.fromJson({
        ...base.toJson(),
        'revision': 2,
        'public': {...base.public.toJson(), 'readerId': 'p2'},
      }),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(refresh), findsNothing);
  });
  for (final errors in [2, 0]) {
    testWidgets('review court verdict and visible positions: $errors errors', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(360, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final fixture = await numbers.pump(tester, allJudges: true);
      fixture.transport.sockets.last.receive(
        personalView(errors: errors, cursor: 4, revision: 2),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find
            .descendant(
              of: find.byKey(const ValueKey('room-tabs')),
              matching: find.byType(Tab),
            )
            .at(1),
      );
      await tester.pumpAndSettle();
      await reviewImage(tester, 'online-verdict-$errors');
      if (errors > 0) {
        await tester.tap(
          find.widgetWithText(FilledButton, AppStrings('de').get('confirm')),
        );
        await tester.pumpAndSettle();
        await reviewImage(tester, 'online-positions-after-verdict');
      }
      expect(tester.takeException(), isNull);
    });
  }
}
