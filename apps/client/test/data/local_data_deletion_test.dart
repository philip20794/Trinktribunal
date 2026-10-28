import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:trinktribunal/application/profile_controller.dart';
import 'package:trinktribunal/data/atomic_state_storage_io.dart';
import 'package:trinktribunal/data/profile_store.dart';
import 'package:trinktribunal/domain/avatar_config.dart';

import 'local_state_transaction_test.dart' show Harness;
import '../support/memory_atomic_state_storage.dart';
import '../support/memory_string_store.dart';

void main() {
  test('profile deletion removes only its key and failed deletion retains the loaded profile', () async {
    final storage = MemoryStringStore()..values['unrelated'] = 'keep';
    final profile = ProfileController(
      ProfileStore(storage),
      newId: () => 'profile',
    );
    expect(await profile.save(name: 'Alex', avatar: AvatarConfig()), isTrue);
    final original = profile.profile;
    storage.failWrite = true;
    expect(await profile.delete(), isFalse);
    expect(profile.profile, same(original));
    expect(storage.values.containsKey(ProfileStore.key), isTrue);
    storage.failWrite = false;
    expect(await profile.delete(), isTrue);
    expect(profile.profile, isNull);
    expect(storage.values, {'unrelated': 'keep'});
    expect((await ProfileStore(storage).load()).profile, isNull);
  });

  test('profile deletion cannot overtake a pending profile save', () async {
    final entered = Completer<void>(), release = Completer<void>();
    final storage = MemoryStringStore()
      ..beforeWrite = () async {
        entered.complete();
        await release.future;
      };
    final profile = ProfileController(
      ProfileStore(storage),
      newId: () => 'profile',
    );
    final save = profile.save(name: 'Alex', avatar: AvatarConfig());
    await entered.future;
    expect(await profile.delete(), isFalse);
    release.complete();
    expect(await save, isTrue);
    storage.beforeWrite = null;
    expect(await profile.delete(), isTrue);
    expect(storage.values.containsKey(ProfileStore.key), isFalse);
  });

  test('deleting both games sanitizes primary and recovery slots but retains six-hour history', () async {
    final storage = MemoryAtomicStateStorage(), h = Harness(storage);
    h.startCards();
    h.startPhone();
    await h.transaction.save();
    await h.transaction.save();
    final history = h.history.history.entries.map((e) => e.eventId).toList();
    expect(jsonDecode(storage.backup!)['cards'], isNotNull);
    expect(await h.transaction.deleteGames(), isTrue);
    expect(h.cards.state, isNull);
    expect(h.phone.view, isNull);
    expect(storage.backup, storage.primary);
    for (final value in await storage.readCandidates()) {
      final data = jsonDecode(value);
      expect(data['cards'], isNull);
      expect(data['shared'], isNull);
      expect((data['history'] as List).map((e) => e['eventId']), history);
    }
    storage.primary = 'corrupted after successful deletion';
    final restored = Harness(storage);
    await restored.transaction.load();
    expect(restored.cards.state, isNull);
    expect(restored.phone.view, isNull);
    expect(restored.history.history.entries.map((e) => e.eventId), history);
  });

  test('queued old save cannot resurrect a deleted game; later new game remains valid', () async {
    final storage = MemoryAtomicStateStorage(), h = Harness(storage);
    final entered = Completer<void>(), release = Completer<void>();
    var first = true;
    storage.beforeCommit = () async {
      if (first) {
        first = false;
        entered.complete();
        await release.future;
      }
    };
    h.startCards();
    final oldId = h.cards.state!.currentEventId, pending = h.transaction.save();
    await entered.future;
    final deleted = h.transaction.deleteGames();
    h.startCards();
    final newId = h.cards.state!.currentEventId, later = h.transaction.save();
    release.complete();
    await pending;
    expect(await deleted, isTrue);
    await later;
    expect(newId, isNot(oldId));
    expect(jsonDecode(storage.backup!)['cards'], isNull);
    final restored = Harness(storage);
    await restored.transaction.load();
    expect(restored.cards.state!.currentEventId, newId);
  });

  test(
    'partial storage failure is reported and retry cleans both slots',
    () async {
      final storage = MemoryAtomicStateStorage(), h = Harness(storage);
      h.startCards();
      await h.transaction.save();
      storage.failAfterBackup = true;
      expect(await h.transaction.deleteGames(), isFalse);
      expect(h.transaction.error, contains('nicht vollständig gelöscht'));
      expect(jsonDecode(storage.primary!)['cards'], isNotNull);
      storage.failAfterBackup = false;
      expect(await h.transaction.deleteGames(), isTrue);
      expect(h.transaction.error, isNull);
      expect(storage.backup, storage.primary);
      expect(jsonDecode(storage.primary!)['cards'], isNull);
    },
  );

  test(
    'real file adapter replaces an old recovery copy during deletion',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'trinktribunal-delete-',
      );
      addTearDown(() async {
        for (final file in directory.listSync().whereType<File>()) {
          await file.delete();
        }
        await directory.delete();
      });
      final storage = FileAtomicStateStorage(() async => directory);
      await storage.commit('old private game');
      await storage.commit(
        'new private game',
        previousValid: 'old private game',
      );
      await storage.commit(
        'sanitized',
        previousValid: 'new private game',
        resetBackup: true,
      );
      expect(await storage.readCandidates(), ['sanitized', 'sanitized']);
    },
  );
}
