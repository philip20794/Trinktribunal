import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:trinktribunal/data/catalogs/catalog_repository.dart';
import 'package:trinktribunal/data/catalogs/updating_catalog_repository.dart';
import 'package:trinktribunal/data/string_store.dart';
import 'package:trinktribunal/features/settings/catalog_versions.dart';

class MemoryStore implements StringStore {
  String? value;
  bool failWrites = false;
  @override
  Future<String?> read(String key) async => value;
  @override
  Future<void> write(String key, String value) async {
    if (failWrites) throw StateError('full');
    this.value = value;
  }

  @override
  Future<void> remove(String key) async => value = null;
}

Map<String, String> bundle({int version = 1, bool changedText = false}) {
  final manifest = jsonDecode(
    File('assets/catalogs/manifest.json').readAsStringSync(),
  ) as Map;
  final files = <String, String>{};
  for (final entry in manifest['catalogs']) {
    final path = entry['path'] as String;
    final data =
        jsonDecode(File('assets/catalogs/$path').readAsStringSync()) as Map;
    data['contentVersion'] = version;
    if (changedText) data[entry['kind']][0]['text'] = 'Updated text';
    final body = '${jsonEncode(data)}\n';
    entry['contentVersion'] = version;
    entry['sha256'] = sha256.convert(utf8.encode(body)).toString();
    files[path] = body;
  }
  files['manifest.json'] = jsonEncode(manifest);
  return files;
}

CatalogRepository local(Map<String, String> files) => CatalogRepository(
  read: (path) async => files[path.replaceFirst('assets/catalogs/', '')]!,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late MemoryStore store;
  late Map<String, String> baseline;
  setUp(() {
    store = MemoryStore();
    baseline = bundle();
  });

  UpdatingCatalogRepository repository(
    Map<String, String>? remote, {
    Duration? timeout,
    List<Uri>? requests,
  }) => UpdatingCatalogRepository(
    bundled: local(baseline),
    store: store,
    timeout: timeout ?? const Duration(seconds: 1),
    clientFactory: () => MockClient((request) async {
      requests?.add(request.url);
      if (remote == null) throw const SocketException('offline');
      final path = request.url.path.split('/catalogs/').last;
      return http.Response.bytes(utf8.encode(remote[path]!), 200);
    }),
  );

  test('downloads a newer complete bundle and restores it offline', () async {
    final loaded = await repository(bundle(version: 2, changedText: true))
        .load();
    expect(loaded.questions['de']!.contentVersion, 2);
    expect(loaded.questions['de']!.entries.first.text, 'Updated text');
    expect(loaded.source, 'downloaded');
    expect(store.value, isNotNull);
    final offline = await repository(null).load();
    expect(offline.questions['de']!.contentVersion, 2);
    expect(offline.source, 'cached');
    expect(offline.updateChecked, false);
  });

  test('unchanged manifest avoids downloading catalog files', () async {
    final requests = <Uri>[];
    final loaded = await repository(baseline, requests: requests).load();
    expect(loaded.updateChecked, true);
    expect(requests.length, 1);
    expect(requests.single.queryParameters['check'], isNotEmpty);
    expect(store.value, isNull);
  });

  test(
    'checksum mismatch leaves the complete previous bundle intact',
    () async {
      await repository(bundle(version: 2)).load();
      final saved = store.value;
      final broken = bundle(version: 3);
      broken['rules/en.json'] = broken['rules/en.json']!.replaceFirst(
        'swear_penalty',
        'broken',
      );
      final loaded = await repository(broken).load();
      expect(loaded.rules['en']!.contentVersion, 2);
      expect(loaded.updateChecked, false);
      expect(store.value, saved);
    },
  );

  test(
    'rejects downgrades and content changes without a version increase',
    () async {
      await repository(bundle(version: 3)).load();
      final saved = store.value;
      for (final remote in [
        bundle(version: 2),
        bundle(version: 3, changedText: true),
      ]) {
        final loaded = await repository(remote).load();
        expect(loaded.questions['de']!.contentVersion, 3);
        expect(loaded.updateChecked, false);
        expect(store.value, saved);
      }
    },
  );

  test('corrupt cache and no network fall back to bundled content', () async {
    store.value = '{broken';
    final loaded = await repository(null).load();
    expect(loaded.source, 'bundled');
    expect(loaded.rules['de']!.contentVersion, 1);
  });

  test('storage failure still allows a verified update for this run', () async {
    store.failWrites = true;
    final loaded = await repository(bundle(version: 2)).load();
    expect(loaded.rules['de']!.contentVersion, 2);
    expect(store.value, isNull);
  });

  test(
    'slow network times out without blocking startup or writing later',
    () async {
      final response = Completer<http.Response>();
      final repo = UpdatingCatalogRepository(
        bundled: local(baseline),
        store: store,
        timeout: const Duration(milliseconds: 10),
        clientFactory: () => MockClient((_) => response.future),
      );
      expect((await repo.load()).source, 'bundled');
      response.complete(http.Response('{}', 200));
      await Future<void>.delayed(Duration.zero);
      expect(store.value, isNull);
    },
  );

  testWidgets('settings show the actual version of every catalog', (
    tester,
  ) async {
    final catalogs = await repository(bundle(version: 7)).load();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [catalogsProvider.overrideWith((ref) async => catalogs)],
        child: const MaterialApp(home: Scaffold(body: CatalogVersions())),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Version 7'), findsNWidgets(4));
  });
}
