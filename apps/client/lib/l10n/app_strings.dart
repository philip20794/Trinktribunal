import 'package:flutter/material.dart';

import 'app_strings_data.dart';

/// These values are generated from the paired ARB files by scripts/generate-l10n.mjs.
class AppStrings {
  const AppStrings(this.language);
  final String language;

  String feedback(String message) {
    final key = localizedFeedbackKeys[message];
    if (key != null) return get(key);
    final integer = RegExp(r'^(\w+) muss eine Ganzzahl sein\.$')
        .firstMatch(message);
    if (integer != null) return get('errorInteger', {'field': integer[1]});
    return message;
  }

  String get(String key, [Map<String, Object?> params = const {}]) {
    final dictionary =
        localizedUiStrings[language] ?? localizedUiStrings['de']!;
    final template = dictionary[key] ?? localizedUiStrings['de']![key] ?? key;
    return template.replaceAllMapped(RegExp(r'\{([A-Za-z][A-Za-z0-9]*)\}'), (
      match,
    ) {
      final replacement = params[match[1]];
      return replacement == null ? match[0]! : '$replacement';
    });
  }
}

class AppLanguageScope extends InheritedWidget {
  const AppLanguageScope({
    required this.language,
    required super.child,
    super.key,
  });
  final String language;

  static AppStrings of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<AppLanguageScope>();
    return AppStrings(scope?.language ?? 'de');
  }

  @override
  bool updateShouldNotify(AppLanguageScope oldWidget) =>
      language != oldWidget.language;
}

extension AppStringContext on BuildContext {
  String feedback(String message) =>
      AppLanguageScope.of(this).feedback(message);
  String tr(String key, [Map<String, Object?> params = const {}]) =>
      AppLanguageScope.of(this).get(key, params);
}

class TText extends StatelessWidget {
  const TText(
    this.keyName, {
    super.key,
    this.style,
    this.textAlign,
    this.maxLines,
    this.overflow,
    this.softWrap,
    this.semanticsLabel,
  });
  final String keyName;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;
  final bool? softWrap;
  final String? semanticsLabel;
  @override
  Widget build(BuildContext context) => Text(
    context.tr(keyName),
    style: style,
    textAlign: textAlign,
    maxLines: maxLines,
    overflow: overflow,
    softWrap: softWrap,
    semanticsLabel: semanticsLabel,
  );
}
