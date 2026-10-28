import 'models/domain_error.dart';
import 'selection/random_source.dart';

abstract final class AvatarCatalog {
  static const version = 2;
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
  static const options = <String, List<String>>{
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
  static const defaults = <String, String>{
    'face': 'round',
    'skin': 'medium',
    'eyes': 'open',
    'brows': 'calm',
    'nose': 'round',
    'mouth': 'smile',
    'hair': 'short',
    'hairColor': 'brown',
    'beard': 'none',
    'top': 'shirt',
    'topColor': 'blue',
    'glasses': 'none',
    'hat': 'none',
    'extra': 'none',
  };
  static const layers = [
    'background',
    'torso',
    'hairBack',
    'ears',
    'face',
    'eyes',
    'brows',
    'nose',
    'mouth',
    'beard',
    'hairFront',
    'glasses',
    'hat',
    'extra',
  ];
}

final class AvatarConfig {
  factory AvatarConfig({Map<String, String> selections = const {}}) {
    if (selections.entries.any(
      (entry) =>
          !(AvatarCatalog.options[entry.key]?.contains(entry.value) ?? false),
    )) {
      throw const DomainException(
        DomainErrorCode.invalidConfig,
        'Unbekannte Avatar-Ebene oder Auswahl.',
      );
    }
    return AvatarConfig._(
      Map.unmodifiable({...AvatarCatalog.defaults, ...selections}),
      false,
    );
  }
  const AvatarConfig._(this.selections, this.isFallback);

  factory AvatarConfig.fromJson(Object? raw) {
    try {
      if (raw is! Map ||
          raw.length != 2 ||
          raw['version'] is! int ||
          ![1, AvatarCatalog.version].contains(raw['version']) ||
          raw['selections'] is! Map) {
        return AvatarConfig.fallback();
      }
      final values = raw['selections'] as Map;
      final options = raw['version'] == 1
          ? AvatarCatalog.legacyOptionsV1
          : AvatarCatalog.options;
      if (values.length != AvatarCatalog.options.length ||
          !values.keys.toSet().containsAll(AvatarCatalog.options.keys) ||
          values.entries.any(
            (entry) => !(options[entry.key]?.contains(entry.value) ?? false),
          )) {
        return AvatarConfig.fallback();
      }
      return AvatarConfig(
        selections: values.map(
          (key, value) => MapEntry(key as String, value as String),
        ),
      );
    } on Object {
      return AvatarConfig.fallback();
    }
  }

  factory AvatarConfig.fallback() =>
      AvatarConfig._(Map.unmodifiable(AvatarCatalog.defaults), true);
  factory AvatarConfig.random(RandomSource random) => AvatarConfig(
    selections: {
      for (final category in AvatarCatalog.options.entries)
        category.key: choose(category.value, random),
    },
  );
  factory AvatarConfig.masculine() => AvatarConfig(
    selections: {'face': 'square', 'hair': 'short', 'beard': 'stubble'},
  );
  factory AvatarConfig.feminine() => AvatarConfig(
    selections: {'face': 'long', 'hair': 'long', 'mouth': 'smile'},
  );

  final Map<String, String> selections;
  final bool isFallback;
  String operator [](String key) => selections[key]!;
  AvatarConfig withOption(String key, String value) =>
      AvatarConfig(selections: {...selections, key: value});
  Map<String, Object> toJson() => {
    'version': AvatarCatalog.version,
    'selections': Map<String, String>.of(selections),
  };
}
