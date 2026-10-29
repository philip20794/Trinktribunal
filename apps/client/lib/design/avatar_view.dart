import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_svg/flutter_svg.dart';
import 'package:dicebear_core/dicebear_core.dart';

import '../domain/avatar_config.dart';
import '../l10n/app_strings.dart';

/// Single local generator shared by the profile editor, lobby and game.
/// No network, remote image service, or arbitrary SVG from user input.
abstract final class TrinkAvatarRenderer {
  static final Future<Style> _style = rootBundle
      .loadString('assets/avatars/dicebear/trinktribunal-adventurer-v1.json')
      .then(Style.parse);
  static final Map<String, String> _cache = {};
  static const int _maxCache = 48;

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
      // This custom style is 762x1080; retain the SVG's native aspect ratio.
      'idRandomization': false,
    };
  }

  static Future<String> svg(AvatarConfig config) async {
    final key = '${config.seed}:${config.selections.entries.map((e) => '${e.key}=${e.value}').join(',')}';
    final cached = _cache[key];
    if (cached != null) return cached;
    final style = await _style;
    final result = Avatar(style, options(config)).svg;
    if (_cache.length >= _maxCache) _cache.remove(_cache.keys.first);
    _cache[key] = result;
    return result;
  }
}

/// Portrait with a responsive Flutter name overlay on the SVG nameplate.
/// For display elsewhere in the app, pass the player's actual name.
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
    final actualHeight = size * 1080 / 762;
    return Semantics(
      image: true,
      label: config.isFallback ? context.tr('avatarFallback', {'name': name}) : name,
      child: SizedBox(
        width: size,
        height: actualHeight,
        child: Stack(
          children: [
            Positioned.fill(
              child: FutureBuilder<String>(
                future: TrinkAvatarRenderer.svg(config),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return const Center(child: Icon(Icons.person_outline, size: 42));
                  }
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator(strokeWidth: 2));
                  }
                  return SvgPicture.string(
                    snapshot.requireData,
                    fit: BoxFit.contain,
                    excludeFromSemantics: true,
                  );
                },
              ),
            ),
            if (playerName != null && playerName!.trim().isNotEmpty)
              Positioned(
                left: size * .237,
                width: size * .526,
                top: actualHeight * .792,
                height: actualHeight * .095,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    playerName!.trim(),
                    maxLines: 1,
                    style: TextStyle(
                      color: const Color(0xFFF6E1BA),
                      fontWeight: FontWeight.bold,
                      fontSize: size * .10,
                      shadows: const [Shadow(color: Colors.black, blurRadius: 2)],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
