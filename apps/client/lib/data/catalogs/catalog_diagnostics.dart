import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'catalog_repository.dart';
import '../../l10n/app_strings.dart';

class CatalogDiagnostics extends ConsumerWidget {
  const CatalogDiagnostics({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!kDebugMode) return const SizedBox.shrink();
    return ExpansionTile(
      title: const TText('catalogDiagnostics'),
      children: [
        ref
            .watch(catalogsProvider)
            .when(
              loading: () => const ListTile(title: TText('catalogsLoading')),
              error: (error, stack) => ListTile(
                title: const TText('catalogError'),
                subtitle: Text('$error'),
                trailing: IconButton(
                  tooltip: context.tr('reload'),
                  onPressed: () => ref.invalidate(catalogsProvider),
                  icon: const Icon(Icons.refresh),
                ),
              ),
              data: (data) => Column(
                children: [
                  for (final language in ['de', 'en'])
                    ListTile(
                      title: Text(
                        context.tr('catalogCounts', {
                          'language': language.toUpperCase(),
                          'questions': data.questions[language]!.entries.length,
                          'rules': data.rules[language]!.entries.length,
                        }),
                      ),
                      subtitle: Text(
                        context.tr('catalogNoNames', {
                          'questions':
                              data.questions[language]!.withoutPlayers.length,
                          'rules': data.rules[language]!.withoutPlayers.length,
                        }),
                      ),
                    ),
                ],
              ),
            ),
      ],
    );
  }
}
