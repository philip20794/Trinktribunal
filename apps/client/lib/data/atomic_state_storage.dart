/// The entire envelope is one replace operation; games and history never split.
abstract interface class AtomicStateStorage {
  Future<List<String>> readCandidates();

  /// resetBackup replaces recovery copies with this sanitized envelope too.
  Future<void> commit(
    String envelope, {
    String? previousValid,
    bool resetBackup = false,
  });
}
