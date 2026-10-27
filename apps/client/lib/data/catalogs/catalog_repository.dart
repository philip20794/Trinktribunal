import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'catalog.dart';

class CatalogLoadException implements Exception {
  const CatalogLoadException(this.path, this.cause);
  final String path;
  final Object cause;
  @override
  String toString() => 'Katalog konnte nicht geladen werden: $path ($cause)';
}

class Catalogs {
  Catalogs(
    Map<String, Catalog<Question>> questions,
    Map<String, Catalog<DrinkingRule>> rules, {
    Map<String, String> contentHashes = const {},
  }) : questions = Map.unmodifiable(questions),
       rules = Map.unmodifiable(rules),
       contentHashes = Map.unmodifiable(contentHashes);
  final Map<String, Catalog<Question>> questions;
  final Map<String, Catalog<DrinkingRule>> rules;
  final Map<String, String> contentHashes;
  String get signature => jsonEncode([
    for (final key in (contentHashes.keys.toList()..sort()))
      [key, contentHashes[key]],
  ]);
}

class CatalogRepository {
  CatalogRepository({Future<String> Function(String)? read})
    : _read = read ?? rootBundle.loadString;
  final Future<String> Function(String) _read;

  String _signature(Catalog catalog) => jsonEncode([
    for (final CatalogEntry entry in catalog.entries)
      {
        'id': entry.id,
        'players': {
          for (final role in (entry.players.keys.toList()..sort()))
            role: entry.players[role]!.differentFrom.toList(),
        },
        'excludes': entry is DrinkingRule
            ? entry.excludes.toList()
            : <String>[],
      },
  ]);

  Future<Catalogs> load() async {
    final questions = <String, Catalog<Question>>{};
    final rules = <String, Catalog<DrinkingRule>>{};
    final hashes = <String, String>{};
    String path = 'assets/catalogs/manifest.json';
    try {
      final manifest = jsonDecode(await _read(path)) as Map<String, dynamic>;
      if (manifest['version'] != 1 ||
          manifest['canonicalization'] != 'sorted-keys-utf16-json-v1') {
        throw const CatalogFormatException('Unbekanntes Manifestformat');
      }
      final descriptors = manifest['catalogs'] as List;
      if (descriptors.length != 4) {
        throw const CatalogFormatException('Vier Sprachkataloge erwartet');
      }
      final seen = <String>{};
      for (final raw in descriptors) {
        final descriptor = raw as Map<String, dynamic>;
        final kind = descriptor['kind'];
        final language = descriptor['language'];
        if (!['questions', 'rules'].contains(kind) ||
            !['de', 'en'].contains(language) ||
            descriptor['formatVersion'] != 1 ||
            descriptor['path'] != '$kind/$language.json' ||
            !seen.add('$kind/$language') ||
            descriptor['sha256'] is! String ||
            !RegExp(r'^[a-f0-9]{64}$')
                .hasMatch(descriptor['sha256'] as String)) {
          throw const CatalogFormatException('Ungültiger Manifest-Eintrag');
        }
        path = 'assets/catalogs/${descriptor['path']}';
        hashes['$kind:$language'] = descriptor['sha256'] as String;
        final source = await _read(path);
        final Catalog catalog;
        if (kind == 'questions') {
          final parsed = parseQuestions(source);
          questions[language as String] = parsed;
          catalog = parsed;
        } else {
          final parsed = parseRules(source);
          rules[language as String] = parsed;
          catalog = parsed;
        }
        if (catalog.language != language ||
            jsonEncode(catalog.entries.map((e) => e.id).toList()) !=
                jsonEncode(descriptor['ids'])) {
          throw const CatalogFormatException(
            'Manifest und Katalog stimmen nicht überein',
          );
        }
      }
      if (_signature(questions['de']!) != _signature(questions['en']!) ||
          _signature(rules['de']!) != _signature(rules['en']!)) {
        throw const CatalogFormatException(
          'Sprachen haben unterschiedliche IDs, Rollen oder Ausschlüsse',
        );
      }
      return Catalogs(questions, rules, contentHashes: hashes);
    } on CatalogFormatException {
      rethrow;
    } catch (error) {
      throw CatalogLoadException(path, error);
    }
  }
}

final catalogRepositoryProvider = Provider<CatalogRepository>(
  (ref) => CatalogRepository(),
);
final catalogsProvider = FutureProvider<Catalogs>(
  (ref) => ref.watch(catalogRepositoryProvider).load(),
  retry: (retryCount, error) => null,
);
