import 'package:trinktribunal/design/court_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trinktribunal/application/local_data_providers.dart';
import 'package:trinktribunal/design/avatar_view.dart';
import 'package:trinktribunal/design/court_scene.dart';
import 'package:trinktribunal/domain/avatar_config.dart';
import 'package:trinktribunal/features/profile/profile_screen.dart';
import 'package:trinktribunal/l10n/app_strings.dart';

import '../accessibility/screen_matrix_test.dart' show accessibilityHost;
import 'court_scene_test.dart' show reviewImage;

Finder key(String value) => find.byKey(ValueKey(value));
Finder get preview => key('profile-avatar-preview');
Finder get sheet => key('avatar-editor-sheet');

Future<void> host(
  WidgetTester tester,
  Size size,
  double scale,
  String lang,
) async {
  await tester.binding.setSurfaceSize(size);
  await tester.pumpWidget(
    RepaintBoundary(
      key: const ValueKey('scene-review'),
      child: accessibilityHost(
        const ProfileScreen(),
        size: size,
        textScale: scale,
        language: lang,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> renderEditor(WidgetTester tester, String name) async {
  if (!const bool.fromEnvironment('TT_RENDER_REVIEW')) return;
  // SVG loading crosses real asset IO and the widget test's simulated clock.
  for (var pass = 0; pass < 3; pass++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pumpAndSettle();
  }
  await reviewImage(tester, name);
}

void main() {
  setUpAll(() async {
    await TrinkAvatarRenderer.svg(AvatarConfig());
    // Complete memoized SVG futures outside individual FakeAsync test zones.
    for (final hair in AvatarCatalog.options['hair']!) {
      await TrinkAvatarRenderer.partSvg(AvatarConfig(), 'hair', hair);
    }
    for (final hair in ['long01', 'long02']) {
      await TrinkAvatarRenderer.svg(AvatarConfig().withOption('hair', hair));
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
  });
  for (final scale in [1.0, 2.0]) {
    for (final scenario in [
      (size: const Size(320, 640), lang: 'de'),
      (size: const Size(390, 844), lang: 'en'),
      (size: const Size(1000, 700), lang: 'de'),
      (size: const Size(844, 390), lang: 'en'),
    ]) {
      testWidgets(
        'sheet follows the board and covers save: ${scenario.size}/${scenario.lang}/$scale',
        (tester) async {
          addTearDown(() => tester.binding.setSurfaceSize(null));
          await host(tester, scenario.size, scale, scenario.lang);
          final name = key('profile-name');
          final board = tester.getRect(key('avatar-nameplate-target'));
          expect(board.contains(tester.getCenter(name)), isTrue);
          expect(find.byType(TextField), findsOneWidget);
          final field = tester.widget<TextField>(name);
          expect(field.decoration!.prefixIcon, isNull);
          expect(field.decoration!.suffixIcon, isNull);
          await tester.tapAt(board.topLeft + const Offset(6, 6));
          await tester.pump();
          expect(tester.testTextInput.isVisible, isTrue);
          await tester.enterText(name, 'Alexandra Beispiel');
          await tester.testTextInput.receiveAction(TextInputAction.done);
          await tester.pumpAndSettle();
          expect(
            tester.widget<AvatarView>(preview).playerName,
            'Alexandra Beispiel',
          );
          await renderEditor(
            tester,
            'avatar-editor-${scenario.size.width.toInt()}-${scale.toInt()}',
          );
          await tester.tap(key('avatar-option-hair:short03'));
          await tester.pumpAndSettle();
          final sheetRect = tester.getRect(sheet);
          final currentBoard = tester.getRect(key('avatar-nameplate-target'));
          expect(sheetRect.top, closeTo(currentBoard.top, 1));
          expect(
            sheetRect.bottom,
            greaterThan(tester.getRect(find.byType(CourtPrimaryButton)).top),
          );
          expect(tester.getRect(preview).top, lessThan(sheetRect.top));
          expect(find.byType(DropdownButtonFormField<String>), findsNothing);
          expect(
            find.textContaining(RegExp(r'^(Variante|Variant) \d')),
            findsNothing,
          );
          await tester.tap(key('avatar-variant-hair-long01'));
          await tester.pumpAndSettle();
          await tester.tap(key('avatar-variant-hair-long02'));
          await tester.pumpAndSettle();
          expect(tester.widget<AvatarView>(preview).config['hair'], 'long02');
          expect(sheet, findsOneWidget);
          final semantics = tester.ensureSemantics();
          expect(
            tester.getSemantics(key('avatar-variant-hair-long02')),
            matchesSemantics(
              isButton: true,
              isSelected: true,
              hasSelectedState: true,
              hasTapAction: true,
              isFocusable: true,
              hasFocusAction: true,
              label: scenario.lang == 'en' ? 'Hair 2' : 'Frisur 2',
            ),
          );
          semantics.dispose();
          await renderEditor(
            tester,
            'avatar-sheet-${scenario.size.width.toInt()}-${scale.toInt()}',
          );
          final save = find.text(AppStrings(scenario.lang).get('profileSave'));
          expect(save.hitTestable(), findsNothing);
          await tester.tap(key('avatar-sheet-close'));
          await tester.pumpAndSettle();
          expect(save.hitTestable(), findsOneWidget);
          await tester.tap(save);
          await tester.pumpAndSettle();
          final container = ProviderScope.containerOf(
            tester.element(find.byType(ProfileScreen)),
          );
          final saved = container.read(profileProvider).requireValue.profile!;
          expect(saved.player.name, 'Alexandra Beispiel');
          expect(saved.avatar['hair'], 'long02');
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
  testWidgets(
    'colour wheel previews hue and saturation live while its sheet stays open',
    (tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await host(tester, const Size(390, 844), 1, 'de');
      await tester.enterText(key('profile-name'), 'Alex');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      await tester.tap(key('avatar-tab-2'));
      await tester.pumpAndSettle();
      final before = tester.widget<AvatarView>(preview).config;
      await tester.tap(key('avatar-option-skinColor:${before['skinColor']}'));
      await tester.pumpAndSettle();
      final wheel = key('avatar-color-wheel');
      final rect = tester.getRect(wheel);
      await tester.tapAt(rect.center + Offset(rect.width * .43, 0));
      await tester.pumpAndSettle();
      final hue = tester.widget<AvatarView>(preview).config['skinColor'];
      expect(hue, isNot(before['skinColor']));
      final gesture = await tester.startGesture(rect.center);
      await gesture.moveBy(Offset(rect.width * .12, rect.height * .12));
      await gesture.up();
      await tester.pumpAndSettle();
      final current = tester.widget<AvatarView>(preview).config['skinColor'];
      expect(current, isNot(hue));
      expect(sheet, findsOneWidget);
      expect(find.byType(CourtDialog), findsNothing);
      await renderEditor(tester, 'avatar-colour-sheet');
      await tester.tap(key('avatar-sheet-close'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(const AppStrings('de').get('profileSave')));
      await tester.pumpAndSettle();
      final container = ProviderScope.containerOf(
        tester.element(find.byType(ProfileScreen)),
      );
      expect(
        container
            .read(profileProvider)
            .requireValue
            .profile!
            .avatar['skinColor'],
        current,
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'back, Escape and header swipe dismiss the sheet without leaving the editor',
    (tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await host(tester, const Size(390, 844), 1, 'de');
      for (final method in ['back', 'escape', 'swipe']) {
        await tester.tap(key('avatar-option-eyes:variant05'));
        await tester.pumpAndSettle();
        if (method == 'back') {
          await tester.binding.handlePopRoute();
        } else if (method == 'escape') {
          await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        } else {
          await tester.drag(key('avatar-sheet-header'), const Offset(0, 70));
        }
        await tester.pumpAndSettle();
        expect(sheet, findsNothing, reason: method);
        expect(find.byType(ProfileScreen), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'keyboard resize keeps name on board, footer visible and 24-character limit',
    (tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      await host(tester, const Size(320, 640), 2, 'de');
      await tester.tapAt(
        tester.getTopLeft(key('avatar-nameplate-target')) + const Offset(6, 6),
      );
      await tester.pump();
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await tester.pumpAndSettle();
      final name = key('profile-name');
      expect(name.hitTestable(), findsOneWidget);
      expect(
        tester
            .getRect(key('avatar-nameplate-target'))
            .contains(tester.getCenter(name)),
        isTrue,
      );
      await tester.enterText(name, 'ABCDEFGHIJKLMNOPQRSTUVWXYZ');
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(name).controller!.text, hasLength(24));
      expect(find.byType(CourtPrimaryButton).hitTestable(), findsOneWidget);
      await renderEditor(tester, 'avatar-editor-keyboard');
      expect(tester.takeException(), isNull);
    },
  );
}
