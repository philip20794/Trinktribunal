import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:trinktribunal/application/profile_controller.dart';
import 'package:trinktribunal/data/profile_store.dart';
import 'package:trinktribunal/domain/avatar_config.dart';

import '../support/memory_string_store.dart';

void main() {
  late MemoryStringStore storage;
  late ProfileController controller;
  setUp(() {
    storage = MemoryStringStore();
    controller = ProfileController(
      ProfileStore(storage),
      newId: () => 'stable-id',
    );
  });
  test(
    'profile survives a new controller and renames preserve stable identity',
    () async {
      await controller.load();
      expect(controller.profile, isNull);
      expect(
        await controller.save(
          name: '  Alex  ',
          avatar: AvatarConfig.feminine(),
        ),
        true,
      );
      final again = ProfileController(
        ProfileStore(storage),
        newId: () => 'different-id',
      );
      await again.load();
      expect(again.profile!.player.name, 'Alex');
      expect(again.profile!.avatar['hair'], 'long');
      expect(
        await again.save(name: 'Ä', avatar: AvatarConfig.masculine()),
        true,
      );
      expect(again.profile!.player.id.value, 'stable-id');
      expect(again.profile!.player.name, 'Ä');
    },
  );
  test('invalid name or write failure retains last valid profile and persisted bytes', () async {
    await controller.save(name: 'Alex', avatar: AvatarConfig());
    final previous = storage.values[ProfileStore.key];
    for (final name in [' ', 'x' * 25]) {
      expect(await controller.save(name: name, avatar: AvatarConfig()), false);
      expect(controller.error, isNotNull);
      expect(controller.profile!.player.name, 'Alex');
      expect(storage.values[ProfileStore.key], previous);
    }
    storage.failWrite = true;
    expect(
      await controller.save(name: 'Changed', avatar: AvatarConfig()),
      false,
    );
    expect(controller.profile!.player.name, 'Alex');
    expect(storage.values[ProfileStore.key], previous);
  });
  test('damaged JSON/name/version recovers; unknown avatar retains profile identity', () async {
    for (final value in ['bad', '[]', '{}', '{"version":99}']) {
      storage.values[ProfileStore.key] = value;
      await controller.load();
      expect(controller.profile, isNull);
      expect(controller.error, isNotNull);
    }
    await controller.save(name: 'Alex', avatar: AvatarConfig());
    final data =
        jsonDecode(storage.values[ProfileStore.key]!) as Map<String, dynamic>;
    data['avatar'] = {'version': 99};
    storage.values[ProfileStore.key] = jsonEncode(data);
    await controller.load();
    expect(controller.profile!.player.id.value, 'stable-id');
    expect(controller.profile!.avatar.isFallback, true);
    expect(controller.error, isNotNull);
  });
  test(
    'read failure is reported; unsaved editor changes never mutate profile',
    () async {
      await controller.save(name: 'Alex', avatar: AvatarConfig());
      final edited = controller.profile!.avatar.withOption('hair', 'long');
      expect(edited['hair'], 'long');
      expect(controller.profile!.avatar['hair'], 'short');
      storage.failRead = true;
      await controller.load();
      expect(controller.profile!.player.name, 'Alex');
      expect(controller.error, isNotNull);
    },
  );
  test('concurrent save is guarded and a failed save can be retried', () async {
    final gate = Completer<void>();
    storage.beforeWrite = () => gate.future;
    final first = controller.save(name: 'First', avatar: AvatarConfig());
    expect(
      await controller.save(name: 'Second', avatar: AvatarConfig()),
      false,
    );
    gate.complete();
    expect(await first, true);
    expect(controller.profile!.player.name, 'First');
    storage.beforeWrite = null;
    expect(await controller.save(name: 'Second', avatar: AvatarConfig()), true);
    expect(controller.profile!.player.name, 'Second');
  });
}
