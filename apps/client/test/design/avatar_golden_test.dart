import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trinktribunal/design/avatar_view.dart';
import 'package:trinktribunal/domain/avatar_config.dart';
import 'package:trinktribunal/l10n/app_strings.dart';

void main() {
  setUpAll(() async {
    final config = AvatarConfig(seed: 'warm-remount');
    await TrinkAvatarRenderer.svg(config, showBackdrop: false);
    await TrinkAvatarRenderer.headSvg(config);
  });
  testWidgets('DiceBear portrait stays visible at compact and editor sizes', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: AppLanguageScope(
          language: 'de',
          child: Scaffold(
            body: Column(
              children: [
                AvatarHeadView(
                  config: AvatarConfig(seed: 'test-small'),
                  size: 36,
                  label: 'Alex',
                ),
                AvatarView(
                  config: AvatarConfig(seed: 'test-small'),
                  size: 48,
                  playerName: 'Alex',
                ),
                AvatarView(
                  config: AvatarConfig(seed: 'test-large'),
                  size: 180,
                  playerName: 'Alexandra',
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(AvatarView), findsNWidgets(2));
    expect(find.byType(AvatarHeadView), findsOneWidget);
    expect(find.text('Alexandra'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('warm portrait and head render on the very first remount frame', (
    tester,
  ) async {
    final config = AvatarConfig(seed: 'warm-remount');
    for (var epoch = 0; epoch < 3; epoch++) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Row(
              children: [
                AvatarView(
                  key: ValueKey(('portrait', epoch)),
                  config: config,
                  size: 96,
                  showBackdrop: false,
                  playerName: 'Warm',
                ),
                AvatarHeadView(key: ValueKey(('head', epoch)), config: config),
              ],
            ),
          ),
        ),
      );
      // Deliberately no pumpAndSettle before checking the first rendered frame.
      expect(find.byIcon(Icons.person_outline), findsNothing);
      expect(find.byType(SvgPicture), findsNWidgets(2));
      await tester.pumpAndSettle();
    }
    expect(tester.takeException(), isNull);
  });
}
