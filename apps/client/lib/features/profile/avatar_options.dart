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
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final columns =
          constraints.maxWidth >= 560 &&
              MediaQuery.textScalerOf(context).scale(16) <= 24
          ? 2
          : 1;
      final width = (constraints.maxWidth - (columns - 1) * 12) / columns;
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          for (final category in AvatarCatalog.options.entries)
            SizedBox(
              width: width,
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
    },
  );
}
