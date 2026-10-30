import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trinktribunal/application/local_data_providers.dart';
import 'package:trinktribunal/design/avatar_view.dart';
import 'package:trinktribunal/features/home/home_screen.dart';
import 'package:trinktribunal/features/profile/profile_screen.dart';
import 'package:trinktribunal/features/settings/settings_screen.dart';
import 'package:trinktribunal/features/setup/player_roster.dart';
import 'package:trinktribunal/l10n/app_strings.dart';

import '../accessibility/screen_matrix_test.dart' show accessibilityHost;
import '../support/hold_action.dart';

import 'package:trinktribunal/design/hold_action_button.dart';

Future<void> host(
  WidgetTester tester,
  Widget child,
  String language, {
  double scale = 1,
  Size size = const Size(360, 800),
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    accessibilityHost(
      Builder(
        builder: (context) {
          return MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(scale)),
            child: child,
          );
        },
      ),
      language: language,
      size: size,
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  if (finder.evaluate().isEmpty &&
      find.byType(SettingsScreen).evaluate().isNotEmpty) {
    final advanced = find.byType(ExpansionTile);
    if (advanced.evaluate().isEmpty) {
      await tester.scrollUntilVisible(
        advanced,
        200,
        scrollable: find.byType(Scrollable).first,
      );
    }
    if (advanced.evaluate().isNotEmpty) {
      await tester.ensureVisible(advanced);
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(of: advanced, matching: find.byType(ListTile)).first,
      );
      await tester.pumpAndSettle();
    }
  }
  if (finder.evaluate().isEmpty) {
    final scroll = tester.state<ScrollableState>(find.byType(Scrollable).first);
    scroll.position.jumpTo(0);
    await tester.pumpAndSettle();
  }
  if (finder.hitTestable().evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      finder,
      200,
      scrollable: find.byType(Scrollable).first,
    );
  }
  await Scrollable.ensureVisible(tester.element(finder), alignment: .5);
  await tester.pumpAndSettle();
  expect(finder.hitTestable(), findsOneWidget);
  if (find
      .ancestor(of: finder, matching: find.byType(HoldActionButton))
      .evaluate()
      .isNotEmpty) {
    await holdAction(tester, finder);
  } else {
    await tester.tap(finder);
  }
  await tester.pumpAndSettle();
}

void main() {
  for (final language in ['de', 'en']) {
    testWidgets(
      'home: all three modes fit at normal phone height and navigate, $language',
      (tester) async {
        final strings = AppStrings(language);
        await host(tester, const HomeScreen(), language);
        for (final entry in {
          'modeCards': PlayerRosterScreen,
          'modePhone': PlayerRosterScreen,
        }.entries) {
          await tester.tap(find.text(strings.get('homeNewGame')));
          await tester.pumpAndSettle();
          final mode = find.text(strings.get(entry.key));
          await tapVisible(tester, mode);
          expect(find.byType(entry.value), findsOneWidget);
          await tester.tap(find.byType(BackButton));
          await tester.pumpAndSettle();
          expect(find.byType(GameModeSelectionScreen), findsOneWidget);
          await tester.tap(find.byType(BackButton));
          await tester.pumpAndSettle();
          expect(find.byType(HomeScreen), findsOneWidget);
        }
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'profile: live nameplate, validation, save and reopen at 200 percent, $language',
      (tester) async {
        final strings = AppStrings(language);
        await host(tester, const HomeScreen(), language, scale: 2);
        await tester.tap(find.byTooltip(strings.get('openProfile')));
        await tester.pumpAndSettle();
        expect(find.byType(ProfileScreen), findsOneWidget);
        final container = ProviderScope.containerOf(
          tester.element(find.byType(ProfileScreen)),
        );
        final save = find.text(strings.get('profileSave'));
        expect(save.hitTestable(), findsOneWidget);
        await tester.tap(save);
        await tester.pumpAndSettle();
        expect(container.read(profileProvider).requireValue.profile, isNull);
        final field = find.byType(TextField);
        await tapVisible(tester, field);
        const name = 'Alexandra von Beispiel';
        await tester.enterText(field, name);
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pumpAndSettle();
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<AvatarView>(
                find.byKey(const ValueKey('profile-avatar-preview')),
              )
              .playerName,
          name,
        );
        await tester.tap(save);
        await tester.pumpAndSettle();
        expect(
          container.read(profileProvider).requireValue.profile!.player.name,
          name,
        );
        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip(strings.get('openProfile')));
        await tester.pumpAndSettle();
        // Name entry is now fixed above the scrolling avatar options.
        expect(
          tester.widget<TextField>(find.byType(TextField)).controller!.text,
          name,
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'settings: language and preferences remain persisted and back reachable, $language',
      (tester) async {
        final strings = AppStrings(language);
        await host(tester, const HomeScreen(), language);
        await tester.tap(find.byTooltip(strings.get('openSettings')));
        await tester.pumpAndSettle();
        final container = ProviderScope.containerOf(
          tester.element(find.byType(SettingsScreen)),
        );
        final controller = container.read(settingsProvider).requireValue;
        await tester.tap(find.byType(DropdownButtonFormField<String>));
        await tester.pumpAndSettle();
        await tester.tap(find.text(strings.get('english')).last);
        await tester.pumpAndSettle();
        expect(controller.value.language, 'en');
        final motion = find.byWidgetPredicate(
          (w) =>
              w is SwitchListTile &&
              (w.title as Text).data == strings.get('reducedMotion'),
        );
        await tapVisible(tester, motion);
        expect(controller.value.reducedMotion, isTrue);
        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip(strings.get('openSettings')));
        await tester.pumpAndSettle();
        expect(
          container.read(settingsProvider).requireValue.value.language,
          'en',
        );
        expect(
          container.read(settingsProvider).requireValue.value.reducedMotion,
          isTrue,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
}
