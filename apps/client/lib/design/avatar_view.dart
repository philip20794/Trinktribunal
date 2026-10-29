import 'dart:convert';

import 'package:dicebear_core/dicebear_core.dart' show Avatar, Style;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_svg/flutter_svg.dart';

import '../domain/avatar_config.dart';
import '../l10n/app_strings.dart';

/// Bundled DiceBear Adventurer variant; no network requests and no untrusted SVG.
abstract final class TrinkAvatarRenderer {
  static const canvasWidth = 762.0;
  static const canvasHeight = 1080.0;
  // Keep the bottom of the board and only a narrow strip of clothing below.
  static const visibleHeight = 1020.0;

  static final Future<Map<String, dynamic>> _definition = rootBundle
      .loadString('assets/avatars/dicebear/trinktribunal-adventurer-v1.json')
      .then((raw) => jsonDecode(raw) as Map<String, dynamic>);
  static final Future<Style> _style = _definition.then(
    (definition) => Style.parse(jsonEncode(definition)),
  );

  static final Map<String, Future<String>> _portraitCache = {};
  static final Map<String, Future<String>> _headCache = {};
  static final Map<String, Future<String>> _partCache = {};
  static final Map<String, Future<Style>> _previewStyles = {};
  static Future<Style>? _headStyle;

  static const _componentNames = {
    'hair': 'hair',
    'eyes': 'eyes',
    'eyebrows': 'eyebrows',
    'mouth': 'mouth',
    'glasses': 'glasses',
    'earrings': 'earrings',
    'details': 'details',
    'outfit': 'ttOutfit',
    'board': 'ttBoard',
  };

  static Map<String, Object?> options(AvatarConfig config) {
    final s = config.selections;
    return {
      'seed': config.seed,
      'hairVariant': s['hair']!,
      'eyesVariant': s['eyes']!,
      'eyebrowsVariant': s['eyebrows']!,
      'mouthVariant': s['mouth']!,
      'ttOutfitVariant': s['outfit']!,
      'ttBoardVariant': s['board']!,
      'ttHandsVariant': 'holding',
      'ttWallVariant': 'heightChart',
      'ttInitialsVariant': 'blank',
      'ttInitialsProbability': 0,
      'skinColor': s['skinColor']!,
      'hairColor': s['hairColor']!,
      'outfitColor': s['outfitColor']!,
      'glassesProbability': s['glasses'] == 'none' ? 0 : 100,
      if (s['glasses'] != 'none') 'glassesVariant': s['glasses']!,
      'earringsProbability': s['earrings'] == 'none' ? 0 : 100,
      if (s['earrings'] != 'none') 'earringsVariant': s['earrings']!,
      'detailsProbability': s['details'] == 'none' ? 0 : 100,
      if (s['details'] != 'none') 'detailsVariant': s['details']!,
      'idRandomization': false,
    };
  }

  static String _key(AvatarConfig config) =>
      '${config.seed}:${config.selections.entries.map((e) => '${e.key}=${e.value}').join(',')}';

  static Future<String> _remember(
    Map<String, Future<String>> cache,
    String key,
    int maxEntries,
    Future<String> Function() render,
  ) {
    final cached = cache[key];
    if (cached != null) return cached;
    if (cache.length >= maxEntries) cache.remove(cache.keys.first);
    return cache[key] = render();
  }

  static Future<String> svg(AvatarConfig config) => _remember(
    _portraitCache,
    _key(config),
    48,
    () async => Avatar(await _style, options(config)).svg,
  );

  /// A real head-only DiceBear drawing: no body, backdrop, hands or board.
  /// Uses the same selected variants and colors as the full portrait.
  static Future<String> headSvg(AvatarConfig config) =>
      _remember(_headCache, _key(config), 36, () async {
        final style = await (_headStyle ??= _buildHeadStyle());
        return Avatar(style, options(config)).svg;
      });

  static Future<Style> _buildHeadStyle() async {
    final source = await _definition;
    final canvas = source['canvas'] as Map<String, dynamic>;
    final parts = (canvas['elements'] as List).where((item) {
      if (item is! Map) return false;
      return const {
        'head',
        'eyes',
        'eyebrows',
        'mouth',
        'details',
        'glasses',
        'hair',
        'earrings',
      }.contains(item['name']);
    }).toList();
    final revised = {
      ...source,
      'canvas': {
        'width': 610,
        'height': 610,
        'elements': [
          {
            'type': 'element',
            'name': 'g',
            'attributes': {'transform': 'translate(-77 -43)'},
            'children': parts,
          },
        ],
      },
    };
    return Style.parse(jsonEncode(revised));
  }

  /// Render the actual option's SVG component rather than a generic icon.
  /// The cropped component is used ONLY in the dropdown menu, not persisted.
  static Future<String> partSvg(AvatarConfig config, String key, String value) {
    if (!_componentNames.containsKey(key) || value == 'none') {
      return Future.value('');
    }
    final selected = config.withOption(key, value);
    return _remember(_partCache, '${_key(selected)}:$key', 160, () async {
      final style = await _previewStyles.putIfAbsent(
        key,
        () => _buildPartStyle(key),
      );
      return Avatar(style, options(selected)).svg;
    });
  }

  static Future<Style> _buildPartStyle(String key) async {
    final source = await _definition;
    final componentName = _componentNames[key]!;
    final component = (source['components'] as Map)[componentName] as Map;
    final w = (component['width'] as num).toDouble();
    final h = (component['height'] as num).toDouble();
    // Bespoke crops keep the torso and sign readable at menu-icon size.
    final crop = key == 'outfit'
        ? (left: 100.0, top: 592.0, width: 560.0, height: 290.0)
        : key == 'board'
        ? (left: 90.0, top: 776.0, width: 585.0, height: 238.0)
        : (left: 0.0, top: 0.0, width: w, height: h);
    final element = <String, Object?>{
      'type': 'component',
      'name': componentName,
      if (crop.left != 0 || crop.top != 0)
        'attributes': {'transform': 'translate(-${crop.left} -${crop.top})'},
    };
    final revised = {
      ...source,
      'canvas': {
        'width': crop.width,
        'height': crop.height,
        'elements': [element],
      },
    };
    return Style.parse(jsonEncode(revised));
  }
}

/// Original portrait proportions with a short crop below the nameplate.
class AvatarView extends StatelessWidget {
  const AvatarView({
    required this.config,
    this.size = 96,
    this.label = 'Menschliche Spielfigur',
    this.playerName,
    super.key,
  });

  final AvatarConfig config;
  final double size;
  final String label;
  final String? playerName;

  @override
  Widget build(BuildContext context) {
    final name = label == 'Menschliche Spielfigur'
        ? context.tr('humanCharacter')
        : label;
    final fullHeight =
        size *
        TrinkAvatarRenderer.canvasHeight /
        TrinkAvatarRenderer.canvasWidth;
    final croppedHeight =
        size *
        TrinkAvatarRenderer.visibleHeight /
        TrinkAvatarRenderer.canvasWidth;
    return Semantics(
      label: config.isFallback
          ? context.tr('avatarFallback', {'name': name})
          : name,
      image: true,
      child: SizedBox(
        width: size,
        height: croppedHeight,
        child: ClipRect(
          child: Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              Positioned(
                top: 0,
                left: 0,
                width: size,
                height: fullHeight,
                child: FutureBuilder<String>(
                  future: TrinkAvatarRenderer.svg(config),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return const Icon(Icons.person_outline);
                    }
                    if (!snapshot.hasData) {
                      return const Center(child: Icon(Icons.person_outline));
                    }
                    return SvgPicture.string(
                      snapshot.requireData,
                      fit: BoxFit.fill,
                      excludeFromSemantics: true,
                    );
                  },
                ),
              ),
              if (playerName != null && playerName!.trim().isNotEmpty)
                Positioned(
                  left: size * .237,
                  width: size * .526,
                  top: fullHeight * .792,
                  height: fullHeight * .095,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      playerName!.trim(),
                      maxLines: 1,
                      style: TextStyle(
                        color: const Color(0xFFF6E1BA),
                        fontWeight: FontWeight.bold,
                        fontSize: size * .10,
                        shadows: const [
                          Shadow(color: Colors.black, blurRadius: 2),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class AvatarHeadView extends StatelessWidget {
  const AvatarHeadView({
    required this.config,
    this.size = 36,
    this.label = 'Avatar',
    super.key,
  });
  final AvatarConfig config;
  final double size;
  final String label;

  @override
  Widget build(BuildContext context) => Semantics(
    image: true,
    label: label,
    child: SizedBox.square(
      dimension: size,
      child: ClipOval(
        child: ColoredBox(
          color: const Color(0xFFF2DFBE),
          child: FutureBuilder<String>(
            future: TrinkAvatarRenderer.headSvg(config),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Icon(Icons.person_outline, size: 18);
              }
              return SvgPicture.string(
                snapshot.requireData,
                fit: BoxFit.contain,
                excludeFromSemantics: true,
              );
            },
          ),
        ),
      ),
    ),
  );
}

/// One exact selectable DiceBear component thumbnail.
class AvatarPartPreview extends StatelessWidget {
  const AvatarPartPreview({
    required this.config,
    required this.category,
    required this.variant,
    this.size = 39,
    super.key,
  });
  final AvatarConfig config;
  final String category, variant;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (variant == 'none') {
      return SizedBox.square(
        dimension: size,
        child: const Icon(Icons.remove, size: 18),
      );
    }
    return SizedBox.square(
      dimension: size,
      child: FutureBuilder<String>(
        future: TrinkAvatarRenderer.partSvg(config, category, variant),
        builder: (context, snapshot) {
          if (!snapshot.hasData || snapshot.requireData.isEmpty) {
            return const SizedBox.shrink();
          }
          return SvgPicture.string(
            snapshot.requireData,
            fit: BoxFit.contain,
            excludeFromSemantics: true,
          );
        },
      ),
    );
  }
}
