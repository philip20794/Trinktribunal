import 'models/domain_error.dart';
import 'selection/random_source.dart';

/// DiceBear Adventurer + Trinktribunal additions. Values match the bundled
/// JSON style definition; never send SVG or image bytes through multiplayer.
abstract final class AvatarCatalog {
  static const version = 3;
  static const colorKeys = {'skinColor', 'hairColor', 'outfitColor'};
  static bool accepts(String key, String value) => colorKeys.contains(key)
      ? RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(value)
      : (options[key]?.contains(value) ?? false);
  static const style = 'tt-adventurer-1';
  static const options = <String, List<String>>{
    'hair': [
      'long01',
      'long02',
      'long03',
      'long04',
      'long05',
      'long06',
      'long07',
      'long08',
      'long09',
      'long10',
      'long11',
      'long12',
      'long13',
      'long14',
      'long15',
      'long16',
      'long17',
      'long18',
      'long19',
      'long20',
      'long21',
      'long22',
      'long23',
      'long24',
      'long25',
      'long26',
      'short01',
      'short02',
      'short03',
      'short04',
      'short05',
      'short06',
      'short07',
      'short08',
      'short09',
      'short10',
      'short11',
      'short12',
      'short13',
      'short14',
      'short15',
      'short16',
      'short17',
      'short18',
      'short19',
    ],
    'eyes': [
      'variant01',
      'variant02',
      'variant03',
      'variant04',
      'variant05',
      'variant06',
      'variant07',
      'variant08',
      'variant09',
      'variant10',
      'variant11',
      'variant12',
      'variant13',
      'variant14',
      'variant15',
      'variant16',
      'variant17',
      'variant18',
      'variant19',
      'variant20',
      'variant21',
      'variant22',
      'variant23',
      'variant24',
      'variant25',
      'variant26',
    ],
    'eyebrows': [
      'variant01',
      'variant02',
      'variant03',
      'variant04',
      'variant05',
      'variant06',
      'variant07',
      'variant08',
      'variant09',
      'variant10',
      'variant11',
      'variant12',
      'variant13',
      'variant14',
      'variant15',
    ],
    'mouth': [
      'variant01',
      'variant02',
      'variant03',
      'variant04',
      'variant05',
      'variant06',
      'variant07',
      'variant08',
      'variant09',
      'variant10',
      'variant11',
      'variant12',
      'variant13',
      'variant14',
      'variant15',
      'variant16',
      'variant17',
      'variant18',
      'variant19',
      'variant20',
      'variant21',
      'variant22',
      'variant23',
      'variant24',
      'variant25',
      'variant26',
      'variant27',
      'variant28',
      'variant29',
      'variant30',
    ],
    'glasses': [
      'none',
      'variant01',
      'variant02',
      'variant03',
      'variant04',
      'variant05',
    ],
    'earrings': [
      'none',
      'variant01',
      'variant02',
      'variant03',
      'variant04',
      'variant05',
      'variant06',
    ],
    'details': ['none', 'birthmark', 'blush', 'freckles', 'mustache'],
    'outfit': ['tee', 'hoodie', 'suit', 'vest', 'sport'],
    'board': ['classic', 'gilded'],
    'skinColor': ['#763900', '#9e5622', '#ecad80', '#f2d3b1'],
    'hairColor': [
      '#0e0e0e',
      '#3eac2c',
      '#562306',
      '#592454',
      '#6a4e35',
      '#796a45',
      '#85c2c6',
      '#ab2a18',
      '#ac6511',
      '#afafaf',
      '#b9a05f',
      '#cb6820',
      '#dba3be',
      '#e5d7a3',
    ],
    'outfitColor': [
      '#87384f',
      '#475e74',
      '#405849',
      '#a36a43',
      '#6a537c',
      '#363b43',
    ],
  };
  static const defaults = <String, String>{
    'hair': 'short03',
    'eyes': 'variant05',
    'eyebrows': 'variant03',
    'mouth': 'variant04',
    'glasses': 'none',
    'earrings': 'none',
    'details': 'none',
    'outfit': 'tee',
    'board': 'classic',
    'skinColor': '#ecad80',
    'hairColor': '#6a4e35',
    'outfitColor': '#475e74',
  };

  // The original v2 IDs are retained only for reading existing local profiles.
  static const oldV2Options = <String, List<String>>{
    'face': ['round', 'square', 'long', 'heart'],
    'skin': ['light', 'medium', 'brown', 'dark', 'olive'],
    'eyes': ['open', 'sleepy', 'wink'],
    'brows': ['calm', 'raised', 'stern'],
    'nose': ['round', 'long', 'button'],
    'mouth': ['smile', 'neutral', 'surprised', 'smirk'],
    'hair': ['short', 'curly', 'long', 'bald', 'ponytail'],
    'hairColor': ['brown', 'black', 'gold', 'gray', 'copper'],
    'beard': ['none', 'stubble', 'full', 'moustache'],
    'top': ['shirt', 'jacket', 'waistcoat'],
    'topColor': ['blue', 'red', 'green', 'brown', 'plum'],
    'glasses': ['none', 'round', 'rectangular'],
    'hat': ['none', 'cap', 'tricorn'],
    'extra': ['none', 'bowtie', 'badge'],
  };
  static const legacyOptionsV1 = <String, List<String>>{
    'face': ['round', 'square', 'long'],
    'skin': ['light', 'medium', 'brown', 'dark'],
    'eyes': ['open', 'sleepy'],
    'brows': ['calm', 'raised'],
    'nose': ['round', 'long'],
    'mouth': ['smile', 'neutral', 'surprised'],
    'hair': ['short', 'curly', 'long', 'bald'],
    'hairColor': ['brown', 'black', 'gold', 'gray'],
    'beard': ['none', 'stubble', 'full'],
    'top': ['shirt', 'jacket'],
    'topColor': ['blue', 'red', 'green', 'brown'],
    'glasses': ['none', 'round'],
    'hat': ['none', 'cap'],
    'extra': ['none', 'bowtie'],
  };
}

/// Immutable, versioned avatar choices. A seed changes only the unspecified
/// DiceBear details; manual selections remain stable when switching tabs.
final class AvatarConfig {
  factory AvatarConfig({
    String seed = 'trinktribunal',
    Map<String, String> selections = const {},
  }) {
    if (!_validSeed(seed) ||
        selections.entries.any((e) => !AvatarCatalog.accepts(e.key, e.value))) {
      throw const DomainException(
        DomainErrorCode.invalidConfig,
        'Ungültige Avatar-Auswahl.',
      );
    }
    return AvatarConfig._(
      seed,
      Map.unmodifiable({...AvatarCatalog.defaults, ...selections}),
      false,
    );
  }
  const AvatarConfig._(this.seed, this.selections, this.isFallback);
  final String seed;
  final Map<String, String> selections;
  final bool isFallback;
  static bool _validSeed(String value) =>
      value.isNotEmpty &&
      value.length <= 64 &&
      RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(value);

  String operator [](String key) => selections[key]!;
  AvatarConfig withOption(String key, String value) =>
      AvatarConfig(seed: seed, selections: {...selections, key: value});
  AvatarConfig withSeed(String value) =>
      AvatarConfig(seed: value, selections: selections);
  Map<String, Object> toJson() => {
    'version': AvatarCatalog.version,
    'seed': seed,
    'selections': Map<String, String>.of(selections),
  };

  factory AvatarConfig.fromJson(Object? raw) {
    if (raw is! Map || raw['selections'] is! Map) {
      return AvatarConfig.fallback();
    }
    final version = raw['version'];
    final options = version == 1
        ? AvatarCatalog.legacyOptionsV1
        : version == 2
        ? AvatarCatalog.oldV2Options
        : AvatarCatalog.options;
    if (version != 1 && version != 2 && version != 3) {
      return AvatarConfig.fallback();
    }
    final values = raw['selections'] as Map;
    if (values.length != options.length ||
        values.entries.any(
          (e) =>
              e.key is! String ||
              e.value is! String ||
              !(version == 3
                  ? AvatarCatalog.accepts(e.key as String, e.value as String)
                  : (options[e.key]?.contains(e.value) ?? false)),
        )) {
      return AvatarConfig.fallback();
    }
    if (version == 3) {
      final seed = raw['seed'];
      if (seed is! String || !_validSeed(seed)) return AvatarConfig.fallback();
      return AvatarConfig(
        seed: seed,
        selections: values.cast<String, String>(),
      );
    }
    // Old saved portraits cannot be reconstructed in the new illustration
    // system. Derive a stable replacement seed without discarding the profile.
    final serialized = options.keys.map((k) => values[k]).join('-');
    var hash = 2166136261;
    for (final unit in serialized.codeUnits) {
      hash = ((hash ^ unit) * 16777619) & 0xffffffff;
    }
    return AvatarConfig(seed: 'migrated-${hash.toRadixString(16)}');
  }

  factory AvatarConfig.fallback() => AvatarConfig._(
    'fallback',
    Map.unmodifiable(AvatarCatalog.defaults),
    true,
  );
  factory AvatarConfig.random(RandomSource random) => AvatarConfig(
    seed: 'tt-${random.nextInt(0x7fffffff).toRadixString(16)}',
    selections: {
      for (final e in AvatarCatalog.options.entries)
        e.key: choose(e.value, random),
    },
  );
  // Legacy helpers kept for existing call sites but no gender restrictions.
  factory AvatarConfig.masculine() => AvatarConfig(seed: 'starter-1');
  factory AvatarConfig.feminine() => AvatarConfig(seed: 'starter-2');
}
