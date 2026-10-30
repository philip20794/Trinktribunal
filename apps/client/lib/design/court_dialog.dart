import 'package:flutter/material.dart';

import 'court_assets.dart';
import 'court_scene.dart';
import 'illustrated_paper.dart';

/// Responsive parchment shared by confirmations and informational dialogs.
class CourtDialog extends StatelessWidget {
  const CourtDialog({
    this.title,
    this.content,
    this.actions = const [],
    this.scrollable = false,
    super.key,
  });
  final Widget? title, content;
  final List<Widget> actions;
  final bool scrollable;

  @override
  Widget build(BuildContext context) => Dialog(
    backgroundColor: Colors.transparent,
    surfaceTintColor: Colors.transparent,
    elevation: 0,
    insetPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 540),
      child: Theme(
        data: courtPaperTheme().copyWith(
          filledButtonTheme: FilledButtonThemeData(
            style: FilledButton.styleFrom(
              backgroundColor: CourtSceneTokens.crimson,
              foregroundColor: CourtSceneTokens.cream,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
              minimumSize: const Size(48, 48),
              textStyle: const TextStyle(
                fontFamily: 'CourtRoboto',
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          outlinedButtonTheme: OutlinedButtonThemeData(
            style: OutlinedButton.styleFrom(
              foregroundColor: CourtSceneTokens.crimson,
              side: const BorderSide(color: Color(0xFF93642F)),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
              minimumSize: const Size(48, 48),
              textStyle: const TextStyle(
                fontFamily: 'CourtRoboto',
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        child: LayoutBuilder(
          builder: (context, bounds) {
            final width = bounds.maxWidth;
            return Stack(
              children: [
                IllustratedPaper(
                  asset: CourtAssets.popup,
                  slice: const Rect.fromLTRB(180, 350, 720, 1100),
                  rule: false,
                  growToContent: true,
                  height: width * .85,
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      width * .17,
                      width * .32,
                      width * .17,
                      width * .16,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: SingleChildScrollView(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (title != null)
                                  DefaultTextStyle(
                                    style: paperTextStyle(
                                      21,
                                      weight: FontWeight.w700,
                                    ),
                                    textAlign: TextAlign.center,
                                    child: Semantics(
                                      header: true,
                                      child: title!,
                                    ),
                                  ),
                                if (content != null)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 16,
                                    ),
                                    child: DefaultTextStyle(
                                      style: paperTextStyle(15),
                                      textAlign: TextAlign.center,
                                      child: content!,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        if (actions.isNotEmpty)
                          LayoutBuilder(
                            builder: (context, area) {
                              final paired =
                                  actions.length > 1 &&
                                  area.maxWidth >= 200 &&
                                  MediaQuery.textScalerOf(context).scale(16) <=
                                      24;
                              return Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                alignment: WrapAlignment.center,
                                children: [
                                  for (final action in actions)
                                    SizedBox(
                                      width: paired
                                          ? (area.maxWidth - 8) / 2
                                          : area.maxWidth,
                                      child: action,
                                    ),
                                ],
                              );
                            },
                          ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  top: width * .19,
                  right: width * .12,
                  child: IconButton(
                    key: const ValueKey('court-dialog-close'),
                    tooltip: MaterialLocalizations.of(context)
                        .closeButtonTooltip,
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    ),
  );
}
