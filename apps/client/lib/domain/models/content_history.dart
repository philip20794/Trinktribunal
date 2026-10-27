import 'domain_error.dart';

enum ContentKind { question, rule }

final class ContentHistoryEntry {
  ContentHistoryEntry({
    required this.eventId,
    required this.kind,
    required this.contentId,
    required DateTime timestampUtc,
  }) : timestampUtc = timestampUtc.toUtc() {
    if (eventId.trim().isEmpty || contentId.trim().isEmpty) {
      throw const DomainException(
        DomainErrorCode.invalidState,
        'Historieneinträge brauchen Ereignis- und Inhalts-ID.',
      );
    }
  }

  final String eventId;
  final ContentKind kind;
  final String contentId;
  final DateTime timestampUtc;
}

/// Language-neutral device/room state, deliberately independent of GameState.
final class ContentHistory {
  ContentHistory(Iterable<ContentHistoryEntry> entries)
    : entries = List.unmodifiable(entries) {
    if (this.entries.map((e) => e.eventId).toSet().length !=
        this.entries.length) {
      throw const DomainException(
        DomainErrorCode.invalidState,
        'Doppelte Ereignis-ID in der Inhaltshistorie.',
      );
    }
  }

  final List<ContentHistoryEntry> entries;

  int recentCount(ContentKind kind, String contentId, DateTime nowUtc) {
    final cutoff = nowUtc.toUtc().subtract(const Duration(hours: 6));
    return entries
        .where(
          (entry) =>
              entry.kind == kind &&
              entry.contentId == contentId &&
              entry.timestampUtc.isAfter(cutoff),
        )
        .length;
  }

  /// Idempotent retry; a reused event ID with different data is rejected.
  ContentHistory record(ContentHistoryEntry entry) {
    for (final previous in entries) {
      if (previous.eventId != entry.eventId) continue;
      if (previous.kind == entry.kind &&
          previous.contentId == entry.contentId &&
          previous.timestampUtc == entry.timestampUtc) {
        return this;
      }
      throw const DomainException(
        DomainErrorCode.invalidState,
        'Ereignis-ID mit abweichendem Inhalt wiederverwendet.',
      );
    }
    return ContentHistory([...entries, entry]);
  }
}
