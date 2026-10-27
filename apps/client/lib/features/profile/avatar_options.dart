import 'package:flutter/material.dart';

import '../../domain/avatar_config.dart';
import '../../l10n/app_strings.dart';

class AvatarOptions extends StatelessWidget {
  const AvatarOptions({
    required this.config,
    required this.onChanged,
    super.key,
  });
  final AvatarConfig config;
  final ValueChanged<AvatarConfig> onChanged;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      for (final category in AvatarCatalog.options.entries)
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: DropdownButtonFormField<String>(
            key: ValueKey('${category.key}:${config[category.key]}'),
            initialValue: config[category.key],
            isExpanded: true,
            decoration: InputDecoration(
              labelText: context.tr('avatarCategory${category.key}'),
            ),
            items: category.value
                .map(
                  (value) => DropdownMenuItem(
                    value: value,
                    child: Text(context.tr('avatarOption$value')),
                  ),
                )
                .toList(),
            onChanged: (value) {
              if (value != null) {
                onChanged(config.withOption(category.key, value));
              }
            },
          ),
        ),
    ],
  );
}
