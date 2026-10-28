import 'package:flutter/material.dart';

import '../../l10n/app_strings.dart';

Future<void> showGameRules(BuildContext context) =>
    Navigator.of(context)
        .push<void>(MaterialPageRoute(builder: (_) => const GameRulesScreen()));

class GameRulesButton extends StatelessWidget {
  const GameRulesButton({this.beforeOpen, super.key});
  final VoidCallback? beforeOpen;
  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: context.tr('gameRules'),
    icon: const Icon(Icons.help_outline),
    onPressed: () {
      beforeOpen?.call();
      showGameRules(context);
    },
  );
}

class GameRulesScreen extends StatelessWidget {
  const GameRulesScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const TText('gameRules')),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            for (final section in [
              'Setup',
              'Errors',
              'Normal',
              'AllJudges',
              'Rotation',
              'ExtraRules',
              'Next',
            ])
              Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Semantics(
                      header: true,
                      child: TText(
                        'gameRules${section}Title',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TText('gameRules${section}Body'),
                  ],
                ),
              ),
          ],
        ),
      ),
    ),
  );
}
