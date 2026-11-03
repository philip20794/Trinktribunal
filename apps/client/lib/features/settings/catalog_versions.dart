import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/catalogs/catalog_repository.dart';
import '../../l10n/app_strings.dart';

class CatalogVersions extends ConsumerWidget {
  const CatalogVersions({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loaded = ref.watch(catalogsProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.tr('contentVersions'),
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        const TText('contentVersionsHelp'),
        const SizedBox(height: 8),
        loaded.when(
          loading: () => const TText('catalogsLoading'),
          error: (_, _) => const TText('catalogError'),
          data: (catalogs) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final language in ['de', 'en'])
                for (final kind in ['questions', 'rules'])
                  Text(
                    context.tr('contentVersionRow', {
                      'kind': context.tr(
                        kind == 'questions'
                            ? 'contentQuestions'
                            : 'contentRules',
                      ),
                      'language': language.toUpperCase(),
                      'version': kind == 'questions'
                          ? catalogs.questions[language]!.contentVersion
                          : catalogs.rules[language]!.contentVersion,
                    }),
                  ),
              const SizedBox(height: 8),
              TText(switch (catalogs.source) {
                'cached' => 'contentSourceCached',
                'downloaded' => 'contentSourceDownloaded',
                _ => 'contentSourceBundled',
              }),
              TText(
                catalogs.updateChecked
                    ? 'contentCheckSuccess'
                    : 'contentCheckUnavailable',
              ),
            ],
          ),
        ),
      ],
    );
  }
}
