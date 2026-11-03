import 'dart:convert';

import 'package:http/http.dart' as http;

import '../preferences_string_store.dart';
import '../string_store.dart';
import 'catalog.dart';
import 'catalog_repository.dart';

/// One startup transaction: keep a complete validated bundle, never partial files.
class UpdatingCatalogRepository extends CatalogRepository {
  UpdatingCatalogRepository({
    CatalogRepository? bundled,
    StringStore? store,
    http.Client Function()? clientFactory,
    this.timeout = const Duration(seconds: 6),
  }) : _bundled = bundled ?? CatalogRepository(),
       _store = store ?? PreferencesStringStore(),
       _clientFactory = clientFactory ?? http.Client.new;

  static const cacheKey = 'catalogs.live.v1';
  static const baseUrl =
      'https://raw.githubusercontent.com/philip20794/Trinktribunal/main/apps/client/assets/catalogs/';
  final CatalogRepository _bundled;
  final StringStore _store;
  final http.Client Function() _clientFactory;
  final Duration timeout;

  Future<Catalogs> _parse(Map<String, dynamic> files) => CatalogRepository(
    read: (path) async => files[path] as String,
    verifyHashes: true,
  ).load();

  bool _acceptable(Catalogs next, Catalogs current) {
    for (final language in ['de', 'en']) {
      for (final kind in ['questions', 'rules']) {
        final nextVersion = kind == 'questions'
            ? next.questions[language]!.contentVersion
            : next.rules[language]!.contentVersion;
        final currentVersion = kind == 'questions'
            ? current.questions[language]!.contentVersion
            : current.rules[language]!.contentVersion;
        if (nextVersion < currentVersion ||
            (nextVersion == currentVersion &&
                next.contentHashes['$kind:$language'] !=
                    current.contentHashes['$kind:$language'])) {
          return false;
        }
      }
    }
    return true;
  }

  @override
  Future<Catalogs> load() async {
    var current = await _bundled.load();
    try {
      final cached = await _store.read(cacheKey);
      if (cached != null) {
        final parsed = await _parse(jsonDecode(cached) as Map<String, dynamic>);
        if (_acceptable(parsed, current)) {
          current = parsed.withStatus('cached', false);
        }
      }
    } catch (_) {
      // Corrupt or unavailable storage must not prevent offline play.
    }

    final client = _clientFactory();
    try {
      final files = await _download(client, current).timeout(timeout);
      if (files == null) return current.withStatus(current.source, true);
      final next = await _parse(files);
      if (!_acceptable(next, current)) return current;
      try {
        await _store.write(cacheKey, jsonEncode(files));
      } catch (_) {
        // The verified update is still usable for this run.
      }
      return next.withStatus('downloaded', true);
    } catch (_) {
      return current;
    } finally {
      client.close();
    }
  }

  Future<Map<String, dynamic>?> _download(
    http.Client client,
    Catalogs current,
  ) async {
    final nonce = DateTime.now().microsecondsSinceEpoch.toString();
    Future<String> fetch(String path) async {
      final response = await client.get(
        Uri.parse('$baseUrl$path?check=$nonce'),
      );
      if (response.statusCode != 200 || response.bodyBytes.length > 2000000) {
        throw const CatalogFormatException('Catalog download failed');
      }
      return utf8.decode(response.bodyBytes);
    }

    final manifest = await fetch('manifest.json');
    final decoded = jsonDecode(manifest) as Map;
    if (decoded['version'] != 1 ||
        decoded['canonicalization'] != 'sorted-keys-utf16-json-v1') {
      throw const CatalogFormatException('Unsupported manifest');
    }
    final descriptors = decoded['catalogs'] as List;
    // Validate the remote manifest even when there is no new content.
    if (descriptors.length != 4) {
      throw const CatalogFormatException('Invalid manifest');
    }
    final seen = <String>{};
    var unchanged = true;
    for (final entry in descriptors) {
      final kind = entry['kind'], language = entry['language'];
      if (!['questions', 'rules'].contains(kind) ||
          !['de', 'en'].contains(language) ||
          entry['formatVersion'] != 1 ||
          entry['path'] != '$kind/$language.json' ||
          entry['contentVersion'] is! int ||
          entry['contentVersion'] < 1 ||
          !seen.add('$kind:$language')) {
        throw const CatalogFormatException('Invalid manifest entry');
      }
      final version = kind == 'questions'
          ? current.questions[language]!.contentVersion
          : current.rules[language]!.contentVersion;
      if (entry['sha256'] != current.contentHashes['$kind:$language'] ||
          entry['contentVersion'] != version) {
        unchanged = false;
      }
    }
    if (unchanged) return null;
    final files = <String, dynamic>{'assets/catalogs/manifest.json': manifest};
    // Only fixed known paths are requested, never arbitrary manifest URLs.
    await Future.wait([
      for (final kind in ['questions', 'rules'])
        for (final language in ['de', 'en'])
          fetch('$kind/$language.json').then((body) {
            files['assets/catalogs/$kind/$language.json'] = body;
          }),
    ]);
    return files;
  }
}
