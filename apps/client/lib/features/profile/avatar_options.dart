import 'package:flutter/material.dart';

import '../../domain/avatar_config.dart';

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
            decoration: InputDecoration(labelText: _labels[category.key]),
            items: category.value
                .map(
                  (value) => DropdownMenuItem(
                    value: value,
                    child: Text(_values[value] ?? value),
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

const _labels = {
  'face': 'Kopfform',
  'skin': 'Hautton',
  'eyes': 'Augen',
  'brows': 'Brauen',
  'nose': 'Nase',
  'mouth': 'Ausdruck',
  'hair': 'Frisur',
  'hairColor': 'Haarfarbe',
  'beard': 'Bart',
  'top': 'Oberteil',
  'topColor': 'Kleidungsfarbe',
  'glasses': 'Brille',
  'hat': 'Hut',
  'extra': 'Extra',
};
const _values = {
  'round': 'Rund',
  'square': 'Kantig',
  'long': 'Lang',
  'light': 'Hell',
  'medium': 'Mittel',
  'brown': 'Braun',
  'dark': 'Dunkel',
  'open': 'Offen',
  'sleepy': 'Entspannt',
  'calm': 'Ruhig',
  'raised': 'Angehoben',
  'smile': 'Lächeln',
  'neutral': 'Neutral',
  'surprised': 'Überrascht',
  'short': 'Kurz',
  'curly': 'Lockig',
  'bald': 'Keine Haare',
  'black': 'Schwarz',
  'gold': 'Goldblond',
  'gray': 'Grau',
  'none': 'Ohne',
  'stubble': 'Stoppeln',
  'full': 'Vollbart',
  'shirt': 'Shirt',
  'jacket': 'Jacke',
  'blue': 'Graublau',
  'red': 'Rot',
  'green': 'Grün',
  'cap': 'Kappe',
  'bowtie': 'Fliege',
};
