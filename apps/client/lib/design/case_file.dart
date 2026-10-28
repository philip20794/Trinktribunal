import 'package:flutter/material.dart';

import 'court_theme.dart';
import 'court_scene.dart';
import 'court_motion.dart';
import '../l10n/app_strings.dart';

class CaseFile extends StatelessWidget {
  const CaseFile({
    required this.label,
    required this.child,
    this.animationKey,
    this.onRefresh,
    this.showRefresh = false,
    super.key,
  });
  final String label;
  final Widget child;
  final Object? animationKey;
  final VoidCallback? onRefresh;
  final bool showRefresh;

  @override
  Widget build(BuildContext context) => CourtMotion(
    style: CourtMotionStyle.file,
    replayKey: animationKey ?? label,
    child: CourtPaper(
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
                        ?.copyWith(color: CourtTokens.blue, letterSpacing: 1.2),
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
    animationKey: animationKey,
    onRefresh: onRefresh,
    showRefresh: showRefresh,
    child: Builder(
      builder: (context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(text, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 16),
          _scale('1 · $green', CourtTokens.green),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(connector),
          ),
          _scale('$maximum · $red', CourtSceneTokens.crimson),
        ],
      ),
    ),
  );
  Widget _scale(String text, Color accent) => DecoratedBox(
    decoration: BoxDecoration(
      color: const Color(0xE6FFFBF5),
      border: Border(left: BorderSide(color: accent, width: 4)),
    ),
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Text(
        text,
        style: const TextStyle(
          color: CourtTokens.ink,
          fontWeight: FontWeight.w500,
        ),
      ),
    ),
  );
}
