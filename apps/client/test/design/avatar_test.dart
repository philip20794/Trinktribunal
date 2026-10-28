import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:trinktribunal/design/avatar_view.dart';
import 'package:trinktribunal/domain/avatar_config.dart';
import 'package:trinktribunal/domain/models/domain_error.dart';
import 'package:trinktribunal/data/protocol/room_message.dart';

import '../domain/selection_support.dart';

Future<List<int>> render(AvatarConfig config, {int width = 160}) async {
  final recorder = ui.PictureRecorder();
  AvatarPainter(config)
      .paint(ui.Canvas(recorder), ui.Size(width.toDouble(), width * 1.125));
  final picture = recorder.endRecording();
  final image = await picture.toImage(width, (width * 1.125).round());
  final data = await image.toByteData();
  final bytes = data!.buffer.asUint8List().toList();
  image.dispose();
  picture.dispose();
  return bytes;
}

void main() {
  test('manifest, options and vector layer order agree', () {
    final manifest = jsonDecode(
      File('assets/avatars/manifest.json').readAsStringSync(),
    );
    expect(manifest['version'], AvatarCatalog.version);
    expect(manifest['options'], AvatarCatalog.options);
    expect(manifest['layers'], AvatarCatalog.layers);
    expect(manifest['canvas'], {'width': 160, 'height': 180});
    expect(manifest['legacyOptionsV1'], AvatarCatalog.legacyOptionsV1);
    expect(currentAvatarVersion, AvatarCatalog.version);
    expect(File('assets/avatars/manifest.json').lengthSync(), lessThan(4096));
    expect(File('lib/design/avatar_view.dart').lengthSync(), lessThan(16384));
    expect(
      utf8.encode(jsonEncode(AvatarConfig().toJson())).length,
      lessThan(512),
    );
    expect(AvatarCatalog.options.length, 14);
    expect(
      AvatarCatalog.options.values.fold<int>(
        0,
        (sum, values) => sum + values.length,
      ),
      53,
    );
    expect(
      AvatarCatalog.options.values.fold<int>(
        1,
        (count, values) => count * values.length,
      ),
      87480000,
    );
  });
  test(
    'known v1 portraits retain all selections and upgrade only their version',
    () {
      for (final entry in AvatarCatalog.legacyOptionsV1.entries) {
        for (final value in entry.value) {
          final selections = {...AvatarCatalog.defaults, entry.key: value};
          final restored = AvatarConfig.fromJson({
            'version': 1,
            'selections': selections,
          });
          expect(restored.isFallback, isFalse);
          expect(restored.selections, selections);
          expect(restored.toJson()['version'], AvatarCatalog.version);
        }
      }
      expect(
        AvatarConfig.fromJson({
          'version': 1,
          'selections': {...AvatarCatalog.defaults, 'hat': 'tricorn'},
        }).isFallback,
        isTrue,
      );
    },
  );
  test('all options roundtrip; presets allow unrestricted further changes', () {
    for (final category in AvatarCatalog.options.entries) {
      for (final value in category.value) {
        final config = AvatarConfig().withOption(category.key, value);
        final restored = AvatarConfig.fromJson(
          jsonDecode(jsonEncode(config.toJson())),
        );
        expect(restored.isFallback, false);
        expect(restored.selections, config.selections);
      }
    }
    expect(
      AvatarConfig.feminine().withOption('beard', 'full')['beard'],
      'full',
    );
    expect(AvatarConfig.masculine().withOption('hair', 'long')['hair'], 'long');
    expect(
      AvatarConfig.random(TestRandom(last: true)).selections.values,
      isNotEmpty,
    );
  });
  test('unknown versions/IDs/types fall back safely; editor rejects invalid selections', () {
    for (final invalid in <Object?>[
      null,
      'bad',
      {},
      {'version': 99, 'selections': {}},
      {
        'version': 1,
        'selections': {...AvatarCatalog.defaults, 'hair': 'alien'},
      },
      {
        'version': 1,
        'selections': {...AvatarCatalog.defaults, 'face': 3},
      },
    ]) {
      expect(AvatarConfig.fromJson(invalid).isFallback, true);
    }
    expect(
      () => AvatarConfig(selections: {'skin': '#00ff00'}),
      throwsA(isA<DomainException>()),
    );
    final config = AvatarConfig();
    final json = config.toJson();
    (json['selections'] as Map)['skin'] = 'dark';
    expect(config['skin'], 'medium');
    expect(() => config.selections.clear(), throwsUnsupportedError);
  });
  test(
    'every visible option changes vector pixels and small/large render safely',
    () async {
      final base = await render(AvatarConfig());
      for (final category in AvatarCatalog.options.entries) {
        for (final value in category.value.where(
          (value) => value != AvatarCatalog.defaults[category.key],
        )) {
          final rendered = await render(
            AvatarConfig().withOption(category.key, value),
          );
          expect(
            rendered,
            isNot(equals(base)),
            reason: '${category.key}=$value',
          );
        }
      }
      for (final width in [48, 320]) {
        final bytes = await render(AvatarConfig.feminine(), width: width);
        expect(bytes.any((b) => b != 0), true);
      }
      expect(await render(AvatarConfig.fallback()), isNot(equals(base)));
    },
  );
}
