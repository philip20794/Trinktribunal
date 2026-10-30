import 'package:flutter/material.dart';

import 'court_assets.dart';
import 'court_scene.dart';
import 'illustrated_paper.dart';
import '../l10n/app_strings.dart';

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

  Widget? _compactAction(BuildContext context, Widget action) {
    if (action is! ButtonStyleButton) return action;
    final original = action.child;
    final key = original is TText ? original.keyName : null;
    if (['cancel', 'back', 'roomToolsClose'].contains(key)) return null;
    final (labelKey, icon) = switch (key) {
      'resumeGame' ||
      'roomContinue' => ('dialogResume', Icons.play_arrow_rounded),
      'newGame' => ('dialogNew', Icons.add_rounded),
      'discard' ||
      'homeDiscardAction' ||
      'maintenanceDelete' ||
      'roomForget' ||
      'roomClose' => ('dialogDelete', Icons.delete_outline_rounded),
      'roomLeave' => ('dialogLeave', Icons.logout_rounded),
      'roomBackOnly' => ('dialogHome', Icons.home_outlined),
      'replaceHostedRoomConfirm' => (
        'dialogReplace',
        Icons.restart_alt_rounded,
      ),
      'confirm' ||
      'phoneConfirmOrder' => ('dialogConfirm', Icons.check_rounded),
      'finishCase' => ('dialogFinish', Icons.done_all_rounded),
      'restartAction' => ('dialogRestart', Icons.replay_rounded),
      'roomKick' => ('dialogKick', Icons.person_remove_outlined),
      _ => (null, Icons.check_rounded),
    };
    final resume =
        action.key is ValueKey<String> &&
        (action.key! as ValueKey<String>).value.startsWith(
          'resume-hosted-room-',
        );
    final short = labelKey ?? (resume ? 'dialogResume' : null);
    if (short == null) return action;
    final fullLabel = original is TText
        ? context.tr(original.keyName)
        : original is Text
        ? original.data ?? context.tr(short)
        : context.tr(short);
    final child = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ExcludeSemantics(
          child: Icon(resume ? Icons.play_arrow_rounded : icon, size: 19),
        ),
        const SizedBox(height: 3),
        Text(
          context.tr(short),
          semanticsLabel: fullLabel,
          textAlign: TextAlign.center,
        ),
      ],
    );
    if (action is FilledButton) {
      return FilledButton(
        key: action.key,
        onPressed: action.onPressed,
        focusNode: action.focusNode,
        autofocus: action.autofocus,
        style: action.style,
        child: child,
      );
    }
    if (action is OutlinedButton) {
      return OutlinedButton(
        key: action.key,
        onPressed: action.onPressed,
        focusNode: action.focusNode,
        autofocus: action.autofocus,
        style: action.style,
        child: child,
      );
    }
    return TextButton(
      key: action.key,
      onPressed: action.onPressed,
      focusNode: action.focusNode,
      autofocus: action.autofocus,
      style: action.style,
      child: child,
    );
  }

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
            final choices = actions
                .map((action) => _compactAction(context, action))
                .whereType<Widget>()
                .toList();
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
                      width * .20,
                      width * .38,
                      width * .20,
                      width * .20,
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
                        if (choices.isNotEmpty)
                          LayoutBuilder(
                            builder: (context, area) {
                              final paired =
                                  choices.length > 1 &&
                                  area.maxWidth >= 170 &&
                                  MediaQuery.textScalerOf(context).scale(16) <=
                                      24;
                              return Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                alignment: WrapAlignment.center,
                                children: [
                                  for (final action in choices)
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
                  top: width * .23,
                  right: width * .17,
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
