import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:trinktribunal/application/roster_controller.dart';
import 'package:trinktribunal/data/profile_store.dart';
import 'package:trinktribunal/domain/avatar_config.dart';

import '../domain/selection_support.dart';
import '../support/memory_string_store.dart';

void main() {
  late MemoryStringStore storage;
  late RosterController controller;
  setUp(() {
    storage = MemoryStringStore();
    var id = 0;
    controller = RosterController(
      storage,
      random: TestRandom(),
      newId: () => 'p${id++}',
    );
  });
  test('CRUD, stable identities, same-name disambiguation and insertion order persist', () async {
    for (final name in ['Alex', 'Alex', 'Chris', 'Dana']) {
      expect(await controller.add(name), true);
    }
    expect(controller.canStart, true);
    final ids = controller.members.map((m) => m.player.id).toList();
    expect(
      controller.displayName(controller.members[0]),
      isNot(controller.displayName(controller.members[1])),
    );
    expect(await controller.move(0, 2), true);
    expect(controller.members.map((m) => m.player.id), [
      ids[1],
      ids[2],
      ids[0],
      ids[3],
    ]);
    expect(
      await controller.update(ids[0], 'Renamed', AvatarConfig.feminine()),
      true,
    );
    expect(controller.members[2].player.id, ids[0]);
    final restored = RosterController(storage);
    await restored.load();
    expect(restored.members[2].player.name, 'Renamed');
    expect(
      restored.members[2].avatar.selections,
      AvatarConfig.feminine().selections,
    );
    expect(await controller.remove(ids[1]), true);
    expect(controller.members.length, 3);
    expect(() => controller.members.clear(), throwsUnsupportedError);
  });
  test('empty names, 21st player and invalid positions are rejected without writing', () async {
    expect(await controller.add('  '), false);
    expect(await controller.add('x' * 25), false);
    expect(controller.members, isEmpty);
    for (var i = 0; i < 20; i++) {
      expect(await controller.add('P$i'), true);
    }
    final before = storage.values[RosterController.key];
    expect(await controller.add('21'), false);
    expect(controller.members.length, 20);
    expect(await controller.move(0, 20), false);
    expect(await controller.move(-1, 2), false);
    expect(storage.values[RosterController.key], before);
    expect(controller.canStart, true);
  });
  test('write failure preserves previous roster, profile template is never overwritten', () async {
    storage.values[ProfileStore.key] = 'unrelated profile';
    await controller.add('Alex');
    final id = controller.members.single.player.id;
    storage.failWrite = true;
    expect(await controller.remove(id), false);
    expect(controller.members.single.player.id, id);
    expect(controller.error, isNotNull);
    expect(storage.values[ProfileStore.key], 'unrelated profile');
    expect(controller.canStart, false);
  });
  test('corrupt roster/duplicate IDs are recoverable and unknown avatars use fallback', () async {
    storage.values[RosterController.key] = 'bad';
    await controller.load();
    expect(controller.error, isNotNull);
    await controller.add('Alex');
    final raw = jsonDecode(
      storage.values[RosterController.key]!,
    ) as Map<String, dynamic>;
    raw['members'][0]['avatar'] = {'version': 99};
    storage.values[RosterController.key] = jsonEncode(raw);
    final restored = RosterController(storage);
    await restored.load();
    expect(restored.members.single.avatar.isFallback, true);
    raw['members'].add(raw['members'][0]);
    storage.values[RosterController.key] = jsonEncode(raw);
    final corrupt = RosterController(storage);
    await corrupt.load();
    expect(corrupt.members, isEmpty);
    expect(corrupt.error, isNotNull);
  });
}
