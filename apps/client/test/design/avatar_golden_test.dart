import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trinktribunal/design/avatar_view.dart';
import 'package:trinktribunal/design/court_theme.dart';
import 'package:trinktribunal/domain/avatar_config.dart';

void main() {
  testWidgets(
    'representative v2 portraits and fallback remain recognizable at two sizes',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(720, 288);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final portraits = [
        AvatarConfig.masculine(),
        AvatarConfig.feminine()
            .withOption('hair', 'ponytail')
            .withOption('hairColor', 'copper')
            .withOption('skin', 'dark'),
        AvatarConfig(
          selections: {
            for (final entry in AvatarCatalog.options.entries)
              entry.key: entry.value.last,
          },
        ),
        AvatarConfig.fallback(),
      ];
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: RepaintBoundary(
            key: const ValueKey('portraits'),
            child: ColoredBox(
              color: CourtTokens.paper,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    for (final portrait in portraits)
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            AvatarView(
                              config: portrait,
                              size: 160,
                              label: 'Portrait',
                            ),
                            const SizedBox(height: 8),
                            AvatarView(
                              config: portrait,
                              size: 48,
                              label: 'Portrait',
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await expectLater(
        find.byKey(const ValueKey('portraits')),
        matchesGoldenFile('goldens/avatars-v2.png'),
      );
    },
  );
}
