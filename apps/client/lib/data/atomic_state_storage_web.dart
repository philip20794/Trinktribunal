import 'package:web/web.dart' as web;

import 'atomic_state_storage.dart';

AtomicStateStorage createAtomicStateStorage() => BrowserAtomicStateStorage();

final class BrowserAtomicStateStorage implements AtomicStateStorage {
  static const primaryKey = 'trinktribunal.local-state.v1';
  static const backupKey = 'trinktribunal.local-state.v1.backup';
  @override
  Future<List<String>> readCandidates() async => [
    if (web.window.localStorage.getItem(primaryKey) case final String value)
      value,
    if (web.window.localStorage.getItem(backupKey) case final String value)
      value,
  ];
  @override
  Future<void> commit(String envelope, {String? previousValid}) async {
    // setItem is atomic with respect to failure. Quota/security errors propagate
    // to the coordinator; a failed replacement retains the previous envelope.
    if (previousValid != null) {
      web.window.localStorage.setItem(backupKey, previousValid);
    }
    web.window.localStorage.setItem(primaryKey, envelope);
  }
}
