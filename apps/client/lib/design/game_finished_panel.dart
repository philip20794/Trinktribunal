import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import 'court_scene.dart';
import 'illustrated_paper.dart';

/// Shared final case file. Starting again always returns to editable setup.
class GameFinishedPanel extends StatelessWidget {
  const GameFinishedPanel({
    this.onNewGame,
    this.waitingForHost = false,
    super.key,
  });
  final VoidCallback? onNewGame;
  final bool waitingForHost;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, bounds) {
      final width = math.min(PaperGeometry.maxWidth, bounds.maxWidth);
      final height = bounds.hasBoundedHeight ? bounds.maxHeight : width * 1.5;
      final geometry = CaseCardGeometry.fit(Size(width, math.max(1, height)));
      final content = geometry.contentRect;
      final scale = geometry.size.width / 400;
      Widget text(String value, double maximum) => LayoutBuilder(
        builder: (context, box) => FittedPaperText(
          value,
          height: box.maxHeight,
          min: 8 * scale,
          max: maximum * scale,
          weight: FontWeight.w700,
        ),
      );
      return Align(
        alignment: Alignment.topCenter,
        heightFactor: 1,
        child: Theme(
          data: courtPaperTheme(),
          child: SizedBox.fromSize(
            size: geometry.size,
            child: Stack(
              children: [
                IllustratedPaper(
                  rule: false,
                  height: geometry.size.height,
                  proportional: true,
                  child: const SizedBox.expand(),
                ),
                Positioned.fromRect(
                  rect: content,
                  child: Column(
                    key: const ValueKey('game-finished-content'),
                    children: [
                      Expanded(
                        flex: 2,
                        child: text(context.tr('endHearing'), 27),
                      ),
                      SizedBox(
                        height: 10 * scale,
                        child: PaperDivider(scale: scale),
                      ),
                      Expanded(
                        flex: 4,
                        child: text(context.tr('gameFinishedBody'), 24),
                      ),
                      if (waitingForHost)
                        Expanded(
                          child: text(context.tr('onlineHostStarts'), 16),
                        ),
                      SizedBox(height: 12 * scale),
                      SizedBox(
                        width: double.infinity,
                        height: math.max(48, content.height * .17),
                        child: FilledButton(
                          key: const ValueKey('finished-new-game'),
                          style: courtSceneTheme().filledButtonTheme.style,
                          onPressed: onNewGame,
                          child: const FittedBox(
                            fit: BoxFit.scaleDown,
                            child: TText('newGame'),
                          ),
                        ),
                      ),
                      SizedBox(height: 8 * scale),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
