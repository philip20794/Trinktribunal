import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';

/// Shared local/online presentation; hidden values never enter text or semantics.
class PrivateNumber extends StatelessWidget {
  const PrivateNumber({
    required this.number,
    required this.onReveal,
    required this.onHide,
    this.onConfirm,
    this.confirmKey = 'phoneHideNext',
    super.key,
  });
  final int? number;
  final VoidCallback onReveal, onHide;
  final VoidCallback? onConfirm;
  final String confirmKey;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (number == null)
        FilledButton(onPressed: onReveal, child: const TText('phoneReveal'))
      else ...[
        Text(
          '$number',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.displayLarge,
          semanticsLabel: context.tr('secretNumber', {'number': number}),
        ),
        if (onConfirm != null)
          FilledButton(onPressed: onConfirm, child: TText(confirmKey)),
        TextButton(onPressed: onHide, child: const TText('phoneHide')),
      ],
    ],
  );
}
