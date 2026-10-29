import 'package:flutter/material.dart';

import '../../design/avatar_view.dart';
import '../../domain/avatar_config.dart';
import '../../l10n/app_strings.dart';
import 'avatar_color_picker.dart';

/// Editor options scroll independently of the fixed large portrait.
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
  static const _dark = Color(0xFF382017);
  static const _cream = Color(0xFFFFF1D7);
  static const _gold = Color(0xFFE9BC73);
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
    'tee': ['T-Shirt', 'T-shirt'],
    'hoodie': ['Hoodie', 'Hoodie'],
    'suit': ['Anzug', 'Suit'],
    'vest': ['Weste', 'Vest'],
    'sport': ['Sport', 'Sport'],
    'classic': ['Klassisch', 'Classic'],
    'gilded': ['Goldrand', 'Gold trim'],
  };

  String _name(String value, bool english) {
    if (value == 'none') return english ? 'None' : 'Keine';
    if (_outfits.containsKey(value)) return _outfits[value]![english ? 1 : 0];
    if (value.startsWith('short')) {
      return '${english ? 'Short' : 'Kurz'} ${int.parse(value.substring(5))}';
    }
    if (value.startsWith('long')) {
      return '${english ? 'Long' : 'Lang'} ${int.parse(value.substring(4))}';
    }
    if (value.startsWith('variant')) {
      return '${english ? 'Variant' : 'Variante'} ${int.parse(value.substring(7))}';
    }
    return value;
  }

  InputDecoration _decoration(String title) => InputDecoration(
    labelText: title,
    labelStyle: const TextStyle(color: _cream),
    floatingLabelBehavior: FloatingLabelBehavior.always,
    border: const OutlineInputBorder(),
    enabledBorder: const OutlineInputBorder(
      borderSide: BorderSide(color: _gold),
    ),
    filled: true,
    fillColor: const Color(0xFF714A32),
    isDense: false,
    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
  );

  Future<void> _chooseColor(String key, bool english) async {
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AvatarColorPickerDialog(
        initialHex: widget.config[key],
        english: english,
      ),
    );
    if (!mounted || value == null) return;
    widget.onChanged(widget.config.withOption(key, value));
  }

  Widget _colorField(String key, bool english) {
    final hex = widget.config[key];
    final color = Color(int.parse('FF${hex.substring(1)}', radix: 16));
    final label = _labels[key]![english ? 1 : 0];
    return Material(
      color: _dark,
      borderRadius: BorderRadius.circular(5),
      child: InkWell(
        key: ValueKey('${widget.keyPrefix}avatar-option-$key:$hex'),
        borderRadius: BorderRadius.circular(5),
        onTap: () => _chooseColor(key, english),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(color: _cream, fontSize: 13),
              ),
              const SizedBox(height: 8),
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color,
                  border: Border.all(color: _gold, width: 2),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _variantField(String key, bool english) {
    final selected = widget.config[key];
    final values = AvatarCatalog.options[key]!;
    return Theme(
      data: Theme.of(context).copyWith(
        canvasColor: _dark,
        textTheme: Theme.of(context).textTheme.apply(bodyColor: _cream),
      ),
      child: DropdownButtonFormField<String>(
        key: ValueKey('${widget.keyPrefix}avatar-option-$key:$selected'),
        initialValue: selected,
        isDense: false,
        isExpanded: true,
        itemHeight: 64,
        menuMaxHeight: 360,
        dropdownColor: const Color(0xFF714A32),
        iconEnabledColor: _gold,
        style: const TextStyle(color: _cream, fontSize: 13),
        decoration: _decoration(_labels[key]![english ? 1 : 0]),
        selectedItemBuilder: (context) => [
          for (final value in values)
            Center(
              child: AvatarPartPreview(
                config: widget.config,
                category: key,
                variant: value,
                size: 52,
              ),
            ),
        ],
        items: [
          for (final value in values)
            DropdownMenuItem<String>(
              value: value,
              child: Row(
                children: [
                  AvatarPartPreview(
                    config: widget.config,
                    category: key,
                    variant: value,
                    size: 48,
                  ),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      _name(value, english),
                      style: const TextStyle(color: _cream, fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
        ],
        onChanged: (value) {
          if (value != null) {
            widget.onChanged(widget.config.withOption(key, value));
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final english = AppLanguageScope.of(context).language == 'en';
    final scale = MediaQuery.textScalerOf(context).scale(16);
    final tabs = english
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
            itemCount: tabs.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, index) => ChoiceChip(
              key: ValueKey('avatar-tab-$index'),
              label: Text(tabs[index]),
              selected: _tab == index,
              onSelected: (_) => setState(() => _tab = index),
              backgroundColor: _dark,
              selectedColor: const Color(0xFF704626),
              labelStyle: const TextStyle(color: _cream),
              checkmarkColor: _gold,
              side: const BorderSide(color: _gold),
              visualDensity: VisualDensity.compact,
            ),
          ),
        ),
        const SizedBox(height: 5),
        Expanded(
          child: LayoutBuilder(
            builder: (context, bounds) {
              final columns = bounds.maxWidth >= 280 && scale < 25
                  ? 3
                  : bounds.maxWidth >= 290 && scale < 26
                  ? 2
                  : 1;
              final keys = _tabs[_tab];
              return GridView.builder(
                key: ValueKey('avatar-option-list-$_tab'),
                padding: const EdgeInsets.fromLTRB(14, 7, 14, 20),
                itemCount: keys.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  mainAxisExtent: _tab == 2 ? 120 : (scale >= 26 ? 100 : 94),
                ),
                itemBuilder: (context, index) {
                  final key = keys[index];
                  return AvatarCatalog.colorKeys.contains(key)
                      ? _colorField(key, english)
                      : _variantField(key, english);
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
