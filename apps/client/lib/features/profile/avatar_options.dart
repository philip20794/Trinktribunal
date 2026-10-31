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

class _AvatarOptionsState extends State<AvatarOptions>
    with SingleTickerProviderStateMixin {
  static const _dark = Color(0xFF382017),
      _cream = Color(0xFFFFF1D7),
      _gold = Color(0xFFE9BC73);
  late final _controller = TabController(length: _tabs.length, vsync: this);
  double _drag = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

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
    return LayoutBuilder(
      builder: (context, bounds) {
        final tabHeight = bounds.maxHeight.clamp(0.0, 48.0);
        final gap = (bounds.maxHeight - tabHeight).clamp(0.0, 5.0);
        return GestureDetector(
          key: const ValueKey('avatar-options-tabs'),
          behavior: HitTestBehavior.opaque,
          onHorizontalDragStart: (_) => _drag = 0,
          onHorizontalDragUpdate: (details) =>
              _drag += details.primaryDelta ?? 0,
          onHorizontalDragEnd: (details) {
            final velocity = details.primaryVelocity ?? 0;
            if (_drag.abs() < 40 && velocity.abs() < 200) return;
            final left = velocity.abs() >= 200 ? velocity < 0 : _drag < 0;
            _controller.animateTo(
              (_controller.index + (left ? 1 : -1)).clamp(0, _tabs.length - 1),
            );
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: tabHeight,
                child: TabBar(
                  key: const ValueKey('avatar-category-tabs'),
                  controller: _controller,
                  indicatorColor: _gold,
                  labelColor: _gold,
                  unselectedLabelColor: _cream,
                  dividerColor: _gold.withValues(alpha: .3),
                  labelPadding: const EdgeInsets.symmetric(horizontal: 4),
                  labelStyle: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  tabs: [
                    for (var index = 0; index < tabs.length; index++)
                      Tab(
                        key: ValueKey('avatar-tab-$index'),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(tabs[index], maxLines: 1),
                        ),
                      ),
                  ],
                ),
              ),
              SizedBox(height: gap),
              Expanded(
                child: TabBarView(
                  key: const ValueKey('avatar-category-pages'),
                  controller: _controller,
                  children: [
                    for (var tab = 0; tab < _tabs.length; tab++)
                      LayoutBuilder(
                        builder: (context, bounds) {
                          final columns = bounds.maxWidth >= 280 && scale < 25
                              ? 3
                              : bounds.maxWidth >= 290 && scale < 26
                              ? 2
                              : 1;
                          final keys = _tabs[tab];
                          return GridView.builder(
                            key: ValueKey('avatar-option-list-$tab'),
                            padding: const EdgeInsets.fromLTRB(14, 7, 14, 20),
                            itemCount: keys.length,
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: columns,
                                  crossAxisSpacing: 10,
                                  mainAxisSpacing: 10,
                                  mainAxisExtent: tab == 2
                                      ? (scale >= 26 ? 160 : 120)
                                      : (scale >= 26 ? 100 : 94),
                                ),
                            itemBuilder: (context, index) =>
                                _field(keys[index], english),
                          );
                        },
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
