import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trinktribunal/application/local_data_providers.dart';
import 'package:trinktribunal/application/profile_controller.dart';
import 'package:trinktribunal/data/profile_store.dart';
import 'package:trinktribunal/domain/avatar_config.dart';

import '../support/memory_string_store.dart';
import '../domain/selection_support.dart' show TestRandom;

void main() {
  test('first roster uses the same random starter and persists it for the next launch', () async {
    final storage = MemoryStringStore();
    ProviderContainer container() => ProviderContainer(
      overrides: [stringStoreProvider.overrideWithValue(storage)],
    );
    final first = container();
    addTearDown(first.dispose);
    final profile = await first.read(profileProvider.future);
    final starter = profile.avatar;
    final roster = await first.read(rosterProvider.future);
    expect(roster.members.single.avatar.toJson(), starter.toJson());
    expect(starter.seed, startsWith('tt-'));
    final restored = container();
    addTearDown(restored.dispose);
    final saved = await restored.read(profileProvider.future);
    expect(saved.avatar.toJson(), starter.toJson());
  });
  test(
    'new profiles get a random starter that stays stable until saved',
    () async {
      final storage = MemoryStringStore();
      final first = ProfileController(
        ProfileStore(storage),
        random: TestRandom(),
      );
      final other = ProfileController(
        ProfileStore(MemoryStringStore()),
        random: TestRandom(last: true),
      );
      await first.load();
      final starter = first.avatar;
      expect(starter.seed, isNot(AvatarConfig().seed));
      expect(starter.selections, isNot(other.avatar.selections));
      expect(identical(first.avatar, starter), isTrue);
      await first.load();
      expect(identical(first.avatar, starter), isTrue);
      expect(await first.save(name: 'Alex', avatar: starter), isTrue);
      final restored = ProfileController(
        ProfileStore(storage),
        random: TestRandom(last: true),
      );
      await restored.load();
      expect(restored.avatar.toJson(), starter.toJson());
    },
  );
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
          avatar: AvatarConfig(seed: 'old', selections: {'hair': 'long01'}),
        ),
        true,
      );
      final again = ProfileController(
        ProfileStore(storage),
        newId: () => 'different-id',
      );
      await again.load();
      expect(again.profile!.player.name, 'Alex');
      expect(again.profile!.avatar['hair'], 'long01');
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
      final edited = controller.profile!.avatar.withOption('hair', 'long01');
      expect(edited['hair'], 'long01');
      expect(controller.profile!.avatar['hair'], 'short03');
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
