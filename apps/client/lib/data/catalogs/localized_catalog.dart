import 'catalog.dart';
import 'catalog_repository.dart';

/// The game state always uses stable IDs. Displaying another language must not
/// redraw questions, change player bindings, counters or secret numbers.
Question localizedQuestion(
  Catalogs catalogs,
  String language,
  Question original,
) {
  final catalog = catalogs.questions[language];
  if (catalog == null) throw StateError('Missing $language questions');
  final question = catalog.byId[original.id];
  if (question != null) return question;
  throw StateError('Missing question ID ${original.id} in $language');
}

DrinkingRule localizedRule(
  Catalogs catalogs,
  String language,
  DrinkingRule original,
) {
  final catalog = catalogs.rules[language];
  if (catalog == null) throw StateError('Missing $language rules');
  final rule = catalog.byId[original.id];
  if (rule != null) return rule;
  throw StateError('Missing rule ID ${original.id} in $language');
}
