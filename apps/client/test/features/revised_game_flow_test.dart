import 'package:trinktribunal/design/hold_action_button.dart';
import 'package:trinktribunal/design/case_stage.dart';
import 'package:trinktribunal/design/illustrated_paper.dart';

import '../support/hold_action.dart';

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trinktribunal/data/catalogs/catalog_repository.dart';
import 'package:trinktribunal/data/protocol/room_message.dart';
import 'package:trinktribunal/domain/models/ids.dart';
import 'package:trinktribunal/features/bench/placement_bank.dart';
import 'package:trinktribunal/design/judge_plate.dart';
import 'package:trinktribunal/design/avatar_view.dart';
import 'package:trinktribunal/domain/avatar_config.dart';
import 'package:trinktribunal/l10n/app_strings.dart';
import 'package:trinktribunal/features/profile/profile_screen.dart';
import 'package:trinktribunal/features/setup/player_roster.dart';
import 'package:trinktribunal/features/setup/card_mode_screen.dart';
import 'package:trinktribunal/application/local_data_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../accessibility/screen_matrix_test.dart' show accessibilityHost;
import '../support/roster_setup.dart';

import '../design/court_scene_test.dart' show reviewImage;
import 'online_numbers_test.dart' as numbers;

void main() {
  setUpAll(() async {
    await TrinkAvatarRenderer.svg(AvatarConfig());
    await TrinkAvatarRenderer.headSvg(AvatarConfig());
    for (final key in [
      'hair',
      'eyes',
      'eyebrows',
      'mouth',
      'glasses',
      'earrings',
      'details',
    ]) {
      await TrinkAvatarRenderer.partSvg(
        AvatarConfig(),
        key,
        AvatarConfig()[key],
      );
    }
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
    numbers.catalogs = await CatalogRepository(
      read: (path) => File(path).readAsString(),
    ).load();
  });
  testWidgets(
    'each new all-judge case resets the seats; incomplete order cannot be confirmed',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final fixture = await numbers.pump(tester, allJudges: true, host: true);
      final base = fixture.room.state.snapshot!;
      void receive(String phase, String round, int revision) {
        fixture.transport.sockets.last.receive(
          SnapshotMessage.fromJson({
            ...base.toJson(),
            'revision': revision,
            'public': {
              ...base.public.toJson(),
              'phase': phase,
              'roundId': round,
            },
          }),
        );
      }

      receive('ordering', 'round_1', 2);
      await tester.pumpAndSettle();
      var bank = tester.widget<PlacementBank>(find.byType(PlacementBank));
      expect(bank.slots, everyElement(isNull));
      expect(bank.unplaced, hasLength(3));
      final label = AppStrings('de').get('phoneConfirmOrder');
      expect(find.widgetWithText(FilledButton, label), findsNothing);
      final pool = List<PlayerId>.of(bank.unplaced);
      for (var index = 0; index < pool.length; index++) {
        bank.onPlace!(pool[index], index);
      }
      await tester.pumpAndSettle();
      bank = tester.widget<PlacementBank>(find.byType(PlacementBank));
      expect(bank.unplaced, isEmpty);
      expect(bank.slots, pool);
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, label))
            .onPressed,
        isNotNull,
      );
      await reviewImage(tester, 'new-order-filled');
      receive('numbers', 'round_2', 3);
      await tester.pumpAndSettle();
      expect(find.byType(JudgePlate), findsOneWidget);
      receive('ordering', 'round_2', 4);
      await tester.pumpAndSettle();
      bank = tester.widget<PlacementBank>(find.byType(PlacementBank));
      expect(bank.slots, everyElement(isNull));
      expect(bank.unplaced, hasLength(3));
      await reviewImage(tester, 'new-order-empty');
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('non-host judge can close a normal case from fixed footer', (
    tester,
  ) async {
    final fixture = await numbers.pump(tester, playerId: 'p2', own: false);
    final base = fixture.room.state.snapshot!;
    fixture.transport.sockets.last.receive(
      SnapshotMessage.fromJson({
        ...base.toJson(),
        'revision': 2,
        'public': {...base.public.toJson(), 'judgeId': 'p2'},
      }),
    );
    await tester.pumpAndSettle();
    expect(find.byType(Tab), findsNWidgets(2));
    expect(find.byType(JudgePlate), findsOneWidget);
    final next = find.widgetWithText(
      HoldActionButton,
      AppStrings('de').get('nextJudge'),
    );
    expect(next.hitTestable(), findsOneWidget);
    await holdAction(tester, next);
    await tester.pumpAndSettle();
    expect(
      fixture.transport.sockets.last.sent
          .whereType<CompleteWithoutVerdictMessage>()
          .single
          .expectedRevision,
      2,
    );
    expect(fixture.room.state.snapshot!.public.completedCases, 0);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'both local setups share the same named roster and card judge portrait',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      var cards = true;
      late StateSetter update;
      await tester.pumpWidget(
        RepaintBoundary(
          key: const ValueKey('scene-review'),
          child: accessibilityHost(
            StatefulBuilder(
              builder: (context, setState) {
                update = setState;
                return PlayerRosterScreen(
                  key: ValueKey(cards),
                  cardMode: cards,
                );
              },
            ),
            textScale: 1,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await addTestPlayers(tester);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(PlayerRosterScreen)),
      );
      final first = container.read(rosterControllerProvider).members.first;
      update(() => cards = false);
      await tester.pumpAndSettle();
      expect(container.read(rosterControllerProvider).members.first, first);
      expect(find.text('Alex'), findsOneWidget);
      update(() => cards = true);
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(FilledButton, AppStrings('de').get('startHearing')),
      );
      await tester.pumpAndSettle();
      expect(find.byType(CardModeScreen), findsOneWidget);
      expect(
        tester.widget<JudgePlate>(find.byType(JudgePlate)).profile.toJson(),
        first.toJson(),
      );
      final shown = tester.widget<JudgePlate>(find.byType(JudgePlate)).profile;
      await tester.runAsync(() => TrinkAvatarRenderer.headSvg(shown.avatar));
      await tester.pumpAndSettle();
      await reviewImage(tester, 'new-card-case-judge');
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'avatar controls have three columns, warm backgrounds and no visible hex codes',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        RepaintBoundary(
          key: const ValueKey('scene-review'),
          child: accessibilityHost(const ProfileScreen(), textScale: 1),
        ),
      );
      await tester.pumpAndSettle();
      final fields = find.byType(DropdownButtonFormField<String>);
      final rects = [for (var i = 0; i < 3; i++) tester.getRect(fields.at(i))];
      expect(rects[0].top, rects[2].top);
      expect(rects[0].left, lessThan(rects[1].left));
      await reviewImage(tester, 'new-avatar-controls');
      await tester.ensureVisible(find.byKey(const ValueKey('avatar-tab-2')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('avatar-tab-2')));
      await tester.pumpAndSettle();
      expect(find.textContaining('#'), findsNothing);
      await reviewImage(tester, 'new-avatar-colours');
      expect(tester.takeException(), isNull);
    },
  );
  for (final size in [const Size(320, 640), const Size(360, 800)]) {
    testWidgets(
      'case paper fits without scrolling on $size and holds its secret on the back',
      (tester) async {
        await tester.binding.setSurfaceSize(size);
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final semantics = tester.ensureSemantics();
        try {
          await numbers.pump(tester);
          final stage = find.byType(CaseStage);
          final stageBounds = tester.getRect(stage);
          final paperBounds = tester.getRect(find.byType(IllustratedPaper));
          expect(paperBounds.left, greaterThanOrEqualTo(stageBounds.left - .1));
          expect(paperBounds.right, lessThanOrEqualTo(stageBounds.right + .1));
          expect(
            paperBounds.bottom,
            lessThanOrEqualTo(stageBounds.bottom + .1),
          );
          expect(
            find.descendant(of: stage, matching: find.byType(Scrollable)),
            findsNothing,
          );
          expect(find.byType(CaseProgressHeader), findsNothing);
          final refresh = find.byKey(const ValueKey('case-paper-refresh'));
          expect(refresh, findsNothing);

          expect(tester.widget<FlipCase>(find.byType(FlipCase)).number, isNull);
          await reviewImage(tester, 'case-fitted-${size.width.toInt()}');
          final target = find.text(AppStrings('de').get('holdToReveal'));
          final gesture = await startChargedHold(tester, target);
          expect(tester.widget<FlipCase>(find.byType(FlipCase)).number, 2);
          await tester.pump();
          expect(
            find.bySemanticsLabel(
              AppStrings('de').get('secretNumber', {'number': 2}),
            ),
            findsOneWidget,
          );
          await reviewImage(tester, 'case-secret-${size.width.toInt()}');
          await gesture.up();
          await tester.pump();
          expect(tester.widget<FlipCase>(find.byType(FlipCase)).number, isNull);
          expect(
            find.bySemanticsLabel(
              AppStrings('de').get('secretNumber', {'number': 2}),
            ),
            findsNothing,
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        } finally {
          semantics.dispose();
        }
      },
    );
  }
  testWidgets(
    'reader gets the next-judge hold instead of the secret after the verdict',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final fixture = await numbers.pump(tester, allJudges: true, host: true);
      final base = fixture.room.state.snapshot!;
      fixture.transport.sockets.last.receive(
        SnapshotMessage.fromJson({
          ...base.toJson(),
          'revision': 2,
          'public': {
            ...base.public.toJson(),
            'phase': 'judged',
            'revealCursor': 3,
            'revealed': [
              for (var i = 0; i < 3; i++)
                {'playerId': 'p${i + 1}', 'number': i + 1},
            ],
          },
          'private': {
            'ownNumber': 2,
            'ownOrder': ['p1', 'p2', 'p3'],
            'ownResult': {'errors': 0, 'sips': 0},
          },
        }),
      );
      await tester.pumpAndSettle();
      final secret = find.widgetWithText(
        HoldActionButton,
        AppStrings('de').get('holdToReveal'),
      );
      final next = find.widgetWithText(
        HoldActionButton,
        AppStrings('de').get('nextJudge'),
      );
      expect(secret, findsNothing);
      await tester.tap(
        find.widgetWithText(Tab, AppStrings('de').get('caseTabTitle')),
      );
      await tester.pumpAndSettle();
      expect(next.hitTestable(), findsOneWidget);
      final early = await tester.startGesture(tester.getCenter(next));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 799));
      await early.up();
      await tester.pumpAndSettle();
      expect(
        fixture.transport.sockets.last.sent.whereType<CompleteCaseMessage>(),
        isEmpty,
      );
      await holdAction(tester, next);
      expect(
        fixture.transport.sockets.last.sent.whereType<CompleteCaseMessage>(),
        hasLength(1),
      );
      expect(tester.takeException(), isNull);
    },
  );
}
