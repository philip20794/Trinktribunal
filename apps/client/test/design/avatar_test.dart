import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:trinktribunal/domain/avatar_config.dart';
import 'package:trinktribunal/domain/models/domain_error.dart';
import 'package:trinktribunal/design/avatar_view.dart';
import 'package:trinktribunal/data/protocol/room_message.dart';

import '../domain/selection_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('DiceBear manifest and all selections match the bundled definition', () {
    final manifest=jsonDecode(File('assets/avatars/manifest.json').readAsStringSync()) as Map;
    final style=jsonDecode(File('assets/avatars/dicebear/trinktribunal-adventurer-v1.json')
        .readAsStringSync()) as Map;
    expect(manifest['version'], AvatarCatalog.version);
    expect(currentAvatarVersion, 3);
    expect(manifest['options'], AvatarCatalog.options);
    expect(manifest['canvas'], {'width':762,'height':1080});
    final components=style['components'] as Map;
    for (final entry in {
      'hair':'hair', 'eyes':'eyes', 'eyebrows':'eyebrows',
      'mouth':'mouth', 'outfit':'ttOutfit', 'board':'ttBoard',
    }.entries) {
      final choices=(components[entry.value] as Map)['variants'] as Map;
      expect(AvatarCatalog.options[entry.key], containsAll(choices.keys));
    }
    expect((components['hair'] as Map)['variants'], hasLength(45));
  });

  test('v3 avatars roundtrip every editable choice and a separate seed', () {
    final original=AvatarConfig(seed:'editor-2026');
    for(final option in AvatarCatalog.options.entries) {
      for(final value in option.value) {
        final changed=original.withOption(option.key,value);
        final restored=AvatarConfig.fromJson(jsonDecode(jsonEncode(changed.toJson())));
        expect(restored.isFallback,false);
        expect(restored.seed,'editor-2026');
        expect(restored.selections,changed.selections);
      }
    }
    final random=AvatarConfig.random(TestRandom(last:true));
    expect(random.seed,startsWith('tt-'));
    expect(random.selections.length,AvatarCatalog.options.length);
  });

  test('old stored v1/v2 portraits migrate deterministically, preserving profile', () {
    final v1={for(final e in AvatarCatalog.legacyOptionsV1.entries)e.key:e.value.first};
    final v2={for(final e in AvatarCatalog.oldV2Options.entries)e.key:e.value.first};
    for(final (version,selections) in [(1,v1),(2,v2)]) {
      final raw={'version':version,'selections':selections};
      final migrated=AvatarConfig.fromJson(raw);
      expect(migrated.isFallback,false);
      expect(migrated.seed,startsWith('migrated-'));
      expect(AvatarConfig.fromJson(raw).seed,migrated.seed);
      expect(migrated.toJson()['version'],3);
    }
  });

  test('bad versions, invalid seeds and tampered choices fail closed', () {
    for(final bad in [
      null, {}, 'bad',
      {'version':99,'selections':{}},
      {'version':3,'seed':'bad seed','selections':AvatarCatalog.defaults},
      {'version':3,'seed':'safe','selections':{...AvatarCatalog.defaults,'hair':'alien'}},
    ]) {
      expect(AvatarConfig.fromJson(bad).isFallback,true);
    }
    expect(() => AvatarConfig(selections:{'skinColor':'#NOTHEX'}),
        throwsA(isA<DomainException>()));
    final config=AvatarConfig();
    final copied=config.toJson();
    (copied['selections'] as Map)['hair']='short08';
    expect(config['hair'],'short03');
    expect(() => config.selections.clear(),throwsUnsupportedError);
  });

  test('offline SVG generation is deterministic and uses no image service', () async {
    final one=AvatarConfig(seed:'stable');
    final svg1=await TrinkAvatarRenderer.svg(one);
    final svg2=await TrinkAvatarRenderer.svg(one);
    expect(svg1,svg2);
    expect(svg1,contains('<svg'));
    expect(svg1,contains('<path'));
    expect(svg1,contains('762'));
    expect(TrinkAvatarRenderer.options(one)['ttInitialsVariant'],'blank');
    expect(TrinkAvatarRenderer.options(one)['ttWallVariant'],'heightChart');
    expect(TrinkAvatarRenderer.options(one)['glassesProbability'],0);
    expect(TrinkAvatarRenderer.options(one.withOption('glasses','variant01'))['glassesProbability'],100);
  });
}
