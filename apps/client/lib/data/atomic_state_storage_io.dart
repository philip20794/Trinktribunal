import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'atomic_state_storage.dart';

AtomicStateStorage createAtomicStateStorage() =>
    FileAtomicStateStorage(() async {
      final support = await getApplicationSupportDirectory();
      return Directory('${support.path}/trinktribunal');
    });

final class FileAtomicStateStorage implements AtomicStateStorage {
  FileAtomicStateStorage(this.directory);
  final Future<Directory> Function() directory;
  @override
  Future<List<String>> readCandidates() async {
    final root = await directory();
    final result = <String>[];
    for (final name in ['local-state.json', 'local-state.backup.json']) {
      final file = File('${root.path}/$name');
      try {
        if (await file.exists()) result.add(await file.readAsString());
      } on FormatException {
        result.add(''); // Keep trying the valid backup after invalid UTF-8.
      }
    }
    return result;
  }

  @override
  Future<void> commit(String envelope, {String? previousValid}) async {
    final root = await directory();
    await root.create(recursive: true);
    final temporary = File('${root.path}/local-state.pending.json');
    await temporary.writeAsString(envelope, flush: true);
    if (previousValid != null) {
      final backup = File('${root.path}/local-state.backup.pending.json');
      await backup.writeAsString(previousValid, flush: true);
      await backup.rename('${root.path}/local-state.backup.json');
    }
    // Android's same-filesystem rename replaces the complete flushed file.
    await temporary.rename('${root.path}/local-state.json');
  }
}
