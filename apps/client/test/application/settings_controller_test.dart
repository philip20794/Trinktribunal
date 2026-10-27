import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:trinktribunal/application/settings_controller.dart';
import '../support/memory_string_store.dart';

void main() {
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
    expect(() => AppSettings.fromJson(jsonDecode('{"version":1,"language":"fr","reducedMotion":false,"audioEnabled":false}')), throwsFormatException);
    expect(() => controller.update(language: 'fr'), throwsArgumentError);
  });
}
