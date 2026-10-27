import 'package:flutter/material.dart';

import 'court_theme.dart';
import '../l10n/app_strings.dart';

class CaseFile extends StatelessWidget {
  const CaseFile({required this.label, required this.child, super.key});
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            label.toUpperCase(),
            style: Theme.of(context).textTheme.labelLarge
                ?.copyWith(color: CourtTokens.blue, letterSpacing: 1.2),
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
  Widget build(BuildContext context) => Semantics(
    label: label,
    child: ExcludeSemantics(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: CourtTokens.red, width: 2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Wrap(
          spacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Icon(icon, color: CourtTokens.red),
            Text(
              label,
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(color: CourtTokens.red),
            ),
          ],
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
