import 'package:flutter/material.dart';

import '../../domain/avatar_config.dart';
import '../../l10n/app_strings.dart';

/// Compact editor: the portrait belongs to the parent, outside this scrollable
/// controls area. Two fields per row on a normal phone, one at 200% text scale.
class AvatarOptions extends StatefulWidget {
  const AvatarOptions({
    required this.config,
    required this.onChanged,
    this.keyPrefix = '',
    super.key,
  });
  final AvatarConfig config;
  final String keyPrefix;
  final ValueChanged<AvatarConfig> onChanged;

  @override
  State<AvatarOptions> createState() => _AvatarOptionsState();
}

class _AvatarOptionsState extends State<AvatarOptions> {
  int _tab = 0;

  static const _tabs = [
    ['hair', 'eyes', 'eyebrows', 'mouth', 'glasses', 'earrings', 'details'],
    ['outfit', 'board'],
    ['skinColor', 'hairColor', 'outfitColor'],
  ];
  static const _labels = {
    'hair': ['Frisur', 'Hair'],
    'eyes': ['Augen', 'Eyes'],
    'eyebrows': ['Augenbrauen', 'Brows'],
    'mouth': ['Mund', 'Mouth'],
    'glasses': ['Brille', 'Glasses'],
    'earrings': ['Ohrringe', 'Earrings'],
    'details': ['Gesichtsdetails', 'Face details'],
    'outfit': ['Oberkörper', 'Outfit'],
    'board': ['Schild', 'Nameplate'],
    'skinColor': ['Hautfarbe', 'Skin colour'],
    'hairColor': ['Haarfarbe', 'Hair colour'],
    'outfitColor': ['Kleidungsfarbe', 'Outfit colour'],
  };
  static const _outfits = {
    'tee':['T-Shirt', 'T-shirt'],
    'hoodie':['Hoodie','Hoodie'],
    'suit':['Anzug','Suit'],
    'vest':['Weste','Vest'],
    'sport':['Sport','Sport'],
    'classic':['Klassisch','Classic'],
    'gilded':['Goldrand','Gold trim'],
  };

  String _name(String value, String category, bool english) {
    if (value == 'none') return english ? 'None' : 'Keine';
    if (_outfits.containsKey(value)) return _outfits[value]![english ? 1 : 0];
    if (value.startsWith('#')) return value.toUpperCase();
    if (value.startsWith('short')) {
      return '${english ? "Short" : "Kurz"} ${int.parse(value.substring(5))}';
    }
    if (value.startsWith('long')) {
      return '${english ? "Long" : "Lang"} ${int.parse(value.substring(4))}';
    }
    if (value.startsWith('variant')) {
      return '${english ? "Variant" : "Variante"} ${int.parse(value.substring(7))}';
    }
    return value.isNotEmpty ? '${value[0].toUpperCase()}${value.substring(1)}' : value;
  }

  @override
  Widget build(BuildContext context) {
    final english=AppLanguageScope.of(context).language == 'en';
    final scale=MediaQuery.textScalerOf(context).scale(16);
    final names=english
        ? ['Face', 'Clothes', 'Colours']
        : ['Gesicht', 'Kleidung', 'Farben'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 43,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            itemCount: names.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, i) => ChoiceChip(
              key: ValueKey('avatar-tab-$i'),
              label: Text(names[i]),
              selected: _tab == i,
              onSelected: (_) => setState(() => _tab=i),
              visualDensity: VisualDensity.compact,
            ),
          ),
        ),
        const SizedBox(height: 5),
        Expanded(
          child: LayoutBuilder(
            builder: (context, bounds) {
              final columns = bounds.maxWidth >= 680 && scale < 25
                  ? 3 : bounds.maxWidth >= 290 && scale < 26
                      ? 2 : 1;
              final keys = _tabs[_tab];
              return GridView.builder(
                key: ValueKey('avatar-option-list-$_tab'),
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 20),
                itemCount: keys.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 9,
                  mainAxisExtent: scale >= 26 ? 75 : 61,
                ),
                itemBuilder: (context, index) {
                  final key=keys[index];
                  return DropdownButtonFormField<String>(
                    key: ValueKey('${widget.keyPrefix}avatar-option-$key'),
                    initialValue: widget.config[key],
                    isDense: true,
                    isExpanded: true,
                    menuMaxHeight: 350,
                    decoration: InputDecoration(
                      labelText: _labels[key]![english ? 1 : 0],
                      floatingLabelBehavior: FloatingLabelBehavior.always,
                      border: const OutlineInputBorder(),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 9, vertical: 9),
                    ),
                    items: AvatarCatalog.options[key]!.map((value) =>
                        DropdownMenuItem<String>(
                          value: value,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (value.startsWith('#')) ...[
                                Container(width: 15,height: 15,
                                  decoration: BoxDecoration(
                                    color: Color(int.parse('FF${value.substring(1)}',radix:16)),
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white54)),
                                ),
                                const SizedBox(width: 5),
                              ],
                              Flexible(
                                child: Text(_name(value,key,english),
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 13)),
                              ),
                            ],
                          ),
                        )).toList(),
                    onChanged: (value) {
                      if (value != null) widget.onChanged(widget.config.withOption(key,value));
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
