import '../domain/models/content_history.dart';

/// Shared device history for both local modes; durable storage follows TT-027.
final class ContentHistoryStore {
  ContentHistory _history = ContentHistory([]);
  ContentHistory get history => _history;
  void merge(ContentHistory incoming) {
    var merged = _history;
    for (final entry in incoming.entries) {
      merged = merged.record(entry);
    }
    _history = merged.entries.length == incoming.entries.length
        ? incoming
        : merged;
  }
}
