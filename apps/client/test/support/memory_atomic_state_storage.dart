import 'package:trinktribunal/data/atomic_state_storage.dart';

final class MemoryAtomicStateStorage implements AtomicStateStorage {
  String? primary;
  String? backup;
  bool failRead = false;
  bool failAfterBackup = false;
  Future<void> Function()? beforeCommit;
  @override
  Future<List<String>> readCandidates() async {
    if (failRead) throw StateError('synthetic unavailable storage');
    return [?primary, ?backup];
  }

  @override
  Future<void> commit(String envelope, {String? previousValid}) async {
    if (beforeCommit != null) await beforeCommit!();
    if (previousValid != null) backup = previousValid;
    if (failAfterBackup) throw StateError('synthetic crash before replace');
    primary = envelope;
  }
}
