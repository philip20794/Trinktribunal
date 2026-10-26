import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'catalog_repository.dart';

class CatalogDiagnostics extends ConsumerWidget {
  const CatalogDiagnostics({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!kDebugMode) return const SizedBox.shrink();
    return ExpansionTile(
      title: const Text('Katalogdiagnose'),
      children: [
        ref
            .watch(catalogsProvider)
            .when(
              loading: () =>
                  const ListTile(title: Text('Kataloge werden geladen …')),
              error: (error, stack) => ListTile(
                title: const Text('Katalogfehler'),
                subtitle: Text('$error'),
                trailing: IconButton(
                  tooltip: 'Erneut laden',
                  onPressed: () => ref.invalidate(catalogsProvider),
                  icon: const Icon(Icons.refresh),
                ),
              ),
              data: (data) => Column(
                children: [
                  for (final language in ['de', 'en'])
                    ListTile(
                      title: Text(
                        '${language.toUpperCase()}: ${data.questions[language]!.entries.length} Fragen · ${data.rules[language]!.entries.length} Regeln',
                      ),
                      subtitle: Text(
                        'Ohne Namen: ${data.questions[language]!.withoutPlayers.length} Fragen · ${data.rules[language]!.withoutPlayers.length} Regeln',
                      ),
                    ),
                ],
              ),
            ),
      ],
    );
  }
}
