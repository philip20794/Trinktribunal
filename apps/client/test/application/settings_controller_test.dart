import 'dart:convert';
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:trinktribunal/application/settings_controller.dart';

import '../support/memory_string_store.dart';

void main() {
  test(
    'queued writes retain latest choice and recover after a failed write',
    () async {
      final store = MemoryStringStore();
      final controller = SettingsController(store);
      var writes = 0;
      store.beforeWrite = () async {
        if (writes++ == 0) throw StateError('synthetic first-write failure');
      };
      final first = controller.update(language: 'en');
      final second = controller.update(reducedMotion: true);
      await Future.wait([first, second]);
      expect(controller.error, isNull);
      final loaded = SettingsController(store);
      await loaded.load();
      expect(loaded.value.language, 'en');
      expect(loaded.value.reducedMotion, true);
      store.failWrite = true;
      await controller.update(audioEnabled: true);
      expect(controller.error, 'settingsSaveFailed');
      store.failWrite = false;
      await controller.update(audioEnabled: false);
      expect(controller.error, isNull);
      controller.dispose();
      loaded.dispose();
    },
  );
  test(
    'finishing a save after disposal does not notify a disposed controller',
    () async {
      final store = MemoryStringStore();
      final gate = Completer<void>();
      store.beforeWrite = () => gate.future;
      final controller = SettingsController(store);
      final save = controller.update(language: 'en');
      controller.dispose();
      gate.complete();
      await save;
      expect(
        store.values[SettingsController.storageKey],
        contains('"language":"en"'),
      );
      expect(
        () => AppSettings.fromJson({
          'version': 1.0,
          'language': 'de',
          'reducedMotion': false,
          'audioEnabled': false,
        }),
        throwsFormatException,
      );
    },
  );
  test('defaults and persisted language, motion and audio', () async {
    final store = MemoryStringStore();
    final first = SettingsController(store);
    await first.load();
    expect(first.value.language, 'de');
    expect(first.value.reducedMotion, isFalse);
    expect(first.value.audioEnabled, isFalse);
    await first.update(language: 'en', reducedMotion: true, audioEnabled: true);
    final loaded = SettingsController(store);
    await loaded.load();
    expect(loaded.value.language, 'en');
    expect(loaded.value.reducedMotion, isTrue);
    expect(loaded.value.audioEnabled, isTrue);
  });

  test('corrupt or unsupported settings fall back safely', () async {
    final store = MemoryStringStore();
    await store.write(SettingsController.storageKey, '{"version":2}');
    final controller = SettingsController(store);
    await controller.load();
    expect(controller.value.language, 'de');
    expect(controller.error, 'settingsInvalid');
    expect(
      () => AppSettings.fromJson(
        jsonDecode(
          '{"version":1,"language":"fr","reducedMotion":false,"audioEnabled":false}',
        ),
      ),
      throwsFormatException,
    );
    expect(() => controller.update(language: 'fr'), throwsArgumentError);
  });
}
