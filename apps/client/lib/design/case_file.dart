import 'package:flutter/material.dart';

import 'court_theme.dart';
import 'court_scene.dart';
import 'court_motion.dart';
import 'illustrated_paper.dart';
import '../l10n/app_strings.dart';

class CaseFile extends StatelessWidget {
  const CaseFile({
    required this.label,
    required this.child,
    this.animationKey,
    this.onRefresh,
    this.showRefresh = false,
    this.illustrated = false,
    super.key,
  });
  final String label;
  final Widget child;
  final Object? animationKey;
  final VoidCallback? onRefresh;
  final bool showRefresh;
  final bool illustrated;

  @override
  Widget build(BuildContext context) => CourtMotion(
    style: CourtMotionStyle.file,
    replayKey: animationKey ?? label,
    child: illustrated
        ? child
        : CourtPaper(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Semantics(
                  header: true,
                  child: Row(
                    children: [
                      if (showRefresh)
                        IconButton(
                          tooltip: context.tr('refreshQuestion'),
                          onPressed: onRefresh,
                          icon: const Icon(Icons.refresh),
                        ),
                      const Icon(
                        Icons.folder_open_outlined,
                        size: 20,
                        color: CourtTokens.blue,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          label.toUpperCase(),
                          style: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(
                                color: CourtTokens.blue,
                                letterSpacing: 1.2,
                              ),
                        ),
                      ),
                    ],
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Divider(color: CourtTokens.border),
                ),
                child,
              ],
            ),
          ),
  );
}

class CourtSeal extends StatelessWidget {
  const CourtSeal({required this.label, this.icon = Icons.gavel, super.key});
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) => CourtMotion(
    style: CourtMotionStyle.stamp,
    replayKey: label,
    child: Semantics(
      label: label,
      child: ExcludeSemantics(
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(
              color: (Theme.of(context).brightness == Brightness.dark
                  ? CourtSceneTokens.gold
                  : CourtTokens.red),
              width: 2,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Wrap(
            spacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Icon(
                icon,
                color: (Theme.of(context).brightness == Brightness.dark
                    ? CourtSceneTokens.gold
                    : CourtTokens.red),
              ),
              Text(
                label,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: (Theme.of(context).brightness == Brightness.dark
                      ? CourtSceneTokens.gold
                      : CourtTokens.red),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class NamePlate extends StatelessWidget {
  const NamePlate({required this.name, required this.position, super.key});
  final String name;
  final int position;

  @override
  Widget build(BuildContext context) => Semantics(
    label: context.tr('positionName', {'position': position, 'name': name}),
    child: ExcludeSemantics(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: CourtTokens.wood,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          '$position · $name',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium
              ?.copyWith(color: CourtTokens.paper),
        ),
      ),
    ),
  );
}

/// Question text is built inside the paper theme, never with a dark-scene style.
class CourtQuestion extends StatelessWidget {
  const CourtQuestion({
    required this.label,
    required this.text,
    required this.green,
    required this.connector,
    required this.red,
    required this.maximum,
    this.animationKey,
    this.onRefresh,
    this.showRefresh = false,
    super.key,
  });
  final String label, text, green, connector, red;
  final int maximum;
  final Object? animationKey;
  final VoidCallback? onRefresh;
  final bool showRefresh;
  @override
  Widget build(BuildContext context) => CaseFile(
    label: label,
    animationKey: (animationKey, text, green, red),
    illustrated: true,
    onRefresh: onRefresh,
    showRefresh: showRefresh,
    child: IllustratedQuestion(
      label: label,
      text: text,
      low: green,
      high: red,
      maximum: maximum,
      showRefresh: showRefresh,
      onRefresh: onRefresh == null
          ? null
          : () => CourtMotionBoundary.run(context, onRefresh!),
    ),
  );
}

class CourtRule extends StatelessWidget {
  const CourtRule({
    required this.text,
    this.title,
    this.animationKey,
    super.key,
  });
  final String text;
  final String? title;
  final Object? animationKey;
  @override
  Widget build(BuildContext context) => CaseFile(
    label: title ?? context.tr('newRule'),
    animationKey: animationKey,
    illustrated: true,
    child: IllustratedRule(title: title ?? context.tr('newRule'), text: text),
  );
}
