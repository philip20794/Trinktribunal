import 'package:flutter/material.dart';

import '../../design/avatar_view.dart';
import '../../domain/avatar_config.dart';
import '../../l10n/app_strings.dart';

const avatarOptionLabels = {
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

/// Existing labelled preview fields, opening the editor's persistent sheet.
class AvatarOptions extends StatefulWidget {
  const AvatarOptions({
    required this.config,
    required this.onOpenSheet,
    this.keyPrefix = '',
    super.key,
  });
  final AvatarConfig config;
  final String keyPrefix;
  final ValueChanged<String> onOpenSheet;
  @override
  State<AvatarOptions> createState() => _AvatarOptionsState();
}

class _AvatarOptionsState extends State<AvatarOptions> {
  static const _dark = Color(0xFF382017),
      _cream = Color(0xFFFFF1D7),
      _gold = Color(0xFFE9BC73);
  int _tab = 0;
  static const _tabs = [
    ['hair', 'eyes', 'eyebrows', 'mouth', 'glasses', 'earrings', 'details'],
    ['outfit', 'board'],
    ['skinColor', 'hairColor', 'outfitColor'],
  ];

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
    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
  );

  Widget _field(String key, bool english) {
    final selected = widget.config[key];
    final label = avatarOptionLabels[key]![english ? 1 : 0];
    final colorField = AvatarCatalog.colorKeys.contains(key);
    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: _dark,
        borderRadius: BorderRadius.circular(5),
        child: InkWell(
          key: ValueKey('${widget.keyPrefix}avatar-option-$key:$selected'),
          borderRadius: BorderRadius.circular(5),
          onTap: () => widget.onOpenSheet(key),
          child: colorField
              ? Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 10,
                  ),
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
                          color: Color(
                            int.parse('FF${selected.substring(1)}', radix: 16),
                          ),
                          border: Border.all(color: _gold, width: 2),
                        ),
                      ),
                    ],
                  ),
                )
              : InputDecorator(
                  decoration: _decoration(label),
                  child: Center(
                    child: AvatarPartPreview(
                      config: widget.config,
                      category: key,
                      variant: selected,
                      size: 52,
                    ),
                  ),
                ),
        ),
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
                itemBuilder: (context, index) => _field(keys[index], english),
              );
            },
          ),
        ),
      ],
    );
  }
}
