import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trinktribunal/application/local_data_providers.dart';
import 'package:trinktribunal/design/avatar_view.dart';
import 'package:trinktribunal/design/hold_action_button.dart';
import 'package:trinktribunal/design/judge_plate.dart';
import 'package:trinktribunal/design/private_number.dart';
import 'package:trinktribunal/domain/avatar_config.dart';
import 'package:trinktribunal/features/setup/card_mode_screen.dart';
import 'package:trinktribunal/features/profile/profile_screen.dart';
import 'package:trinktribunal/l10n/app_strings.dart';

import '../support/hold_action.dart';
import '../support/roster_setup.dart';
import '../design/court_scene_test.dart' show reviewImage;
import 'ui_cleanup_test.dart' show host;

Future<ProviderContainer> cards(WidgetTester tester) async {
  await host(tester, const CardModeScreen(), 'de', size: const Size(390, 844));
  await addTestPlayers(tester);
  await tester.tap(find.text(const AppStrings('de').get('startHearing')));
  await tester.pumpAndSettle();
  return ProviderScope.containerOf(tester.element(find.byType(CardModeScreen)));
}

void main() {
  setUpAll(() async {
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
    await TrinkAvatarRenderer.svg(AvatarConfig(), showBackdrop: false);
  });
  testWidgets(
    'card Next needs 500ms, continues outside, and advances once per touch',
    (tester) async {
      final container = await cards(tester);
      final controller = container.read(localSessionProvider);
      final next = find.byType(HoldActionButton);
      expect(
        tester.widget<HoldActionButton>(next).duration,
        const Duration(milliseconds: 500),
      );
      final short = await tester.startGesture(tester.getCenter(next));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 499));
      await short.up();
      await tester.pump();
      expect(controller.state!.completedCases, 0);
      final held = await tester.startGesture(tester.getCenter(next));
      await tester.pump();
      await held.moveTo(const Offset(4, 4));
      await tester.pump(const Duration(milliseconds: 499));
      expect(controller.state!.completedCases, 0);
      await tester.pump(const Duration(milliseconds: 1));
      expect(controller.state!.completedCases, 1);
      await tester.pump(const Duration(seconds: 2));
      await held.up();
      await tester.pumpAndSettle();
      expect(controller.state!.completedCases, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'judge plate edits own and other local profiles without changing the active case',
    (tester) async {
      final container = await cards(tester);
      final controller = container.read(localSessionProvider);
      for (final own in [true, false]) {
        final before = Map<String, Object?>.of(controller.toSnapshot()!)
          ..remove('roster');
        final id = controller.state!.judge!.player.id;
        await tester.tap(find.byType(JudgePlate));
        await tester.pumpAndSettle();
        if (own) expect(find.byType(ProfileScreen), findsOneWidget);
        await tester.enterText(
          find.byKey(const ValueKey('profile-name')),
          own ? 'Richter Alex' : 'Richter Bea',
        );
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pumpAndSettle();
        await tester.tap(
          find.text(
            const AppStrings('de').get(own ? 'profileSave' : 'rosterApply'),
          ),
        );
        await tester.pumpAndSettle();
        if (own) {
          await tester.tap(find.byType(BackButton));
          await tester.pumpAndSettle();
        }
        expect(controller.state!.judge!.player.id, id);
        expect(
          controller.state!.judge!.player.name,
          own ? 'Richter Alex' : 'Richter Bea',
        );
        expect(
          Map<String, Object?>.of(controller.toSnapshot()!)..remove('roster'),
          before,
        );
        expect(
          tester.widget<JudgePlate>(find.byType(JudgePlate)).profile.player.id,
          id,
        );
        if (own) {
          // The saved-profile snackbar briefly covers the fixed footer.
          await tester.pump(const Duration(seconds: 5));
          await tester.pumpAndSettle();
          await holdAction(tester, find.byType(HoldActionButton));
          expect(controller.state!.completedCases, 1);
          expect(controller.state!.judge!.player.id, isNot(id));
        }
      }
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'shared number front shows a full portrait and nameplate without police wall',
    (tester) async {
      await host(
        tester,
        HeldPrivateNumber(
          fullScreen: true,
          number: null,
          ownerName: 'Alex',
          ownerAvatar: AvatarConfig(),
          onReveal: () {},
          onHide: () {},
          onDone: () {},
        ),
        'de',
      );
      final portrait = tester.widget<AvatarView>(find.byType(AvatarView));
      expect(portrait.playerName, 'Alex');
      expect(portrait.showBackdrop, isFalse);
      expect(find.textContaining('Zahl von'), findsNothing);
      expect(find.bySemanticsLabel(RegExp('Geheime Zahl:')), findsNothing);
      await reviewImage(tester, 'shared-number-avatar-front');
      expect(tester.takeException(), isNull);
    },
  );
}
