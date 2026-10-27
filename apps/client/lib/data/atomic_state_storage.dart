/// The entire envelope is one replace operation; games and history never split.
abstract interface class AtomicStateStorage {
  Future<List<String>> readCandidates();
  Future<void> commit(String envelope, {String? previousValid});
}
