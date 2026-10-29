import 'dart:async';
import 'dart:convert';

import '../data/atomic_state_storage.dart';
import '../domain/models/content_history.dart';
import '../domain/selection/random_source.dart';
import '../domain/snapshot_codec.dart';
import 'content_history_store.dart';
import 'local_session_controller.dart';
import 'shared_phone_controller.dart';

/// Logically separate history and games share one atomic persistence envelope.
final class LocalStateTransaction {
  LocalStateTransaction({
    required this.storage,
    required this.cards,
    required this.shared,
    required this.history,
    required this.catalogSignature,
    UtcClock? clock,
  }) : clock = clock ?? (() => DateTime.now().toUtc());
  final AtomicStateStorage storage;
  final LocalSessionController cards;
  final SharedPhoneController shared;
  final ContentHistoryStore history;
  final String catalogSignature;
  final UtcClock clock;
  String? error;
  bool restored = false;
  bool needsReset = false;
  String? _lastValid;
  Future<void> _pending = Future.value();

  ContentHistory _recent(ContentHistory source) {
    final cutoff = clock().toUtc().subtract(const Duration(hours: 6));
    return ContentHistory(
      source.entries.where((e) => e.timestampUtc.isAfter(cutoff)),
    );
  }

  Future<void> load() async {
    error = null;
    needsReset = false;
    restored = false;
    try {
      final candidates = await storage.readCandidates();
      for (var index = 0; index < candidates.length; index++) {
        try {
          final json = jsonDecode(candidates[index]) as Map<String, dynamic>;
          if (json['formatVersion'] is! int || json['formatVersion'] != 1) {
            throw const FormatException('Version');
          }
          final storedHistory = ContentHistory(
            (json['history'] as List).map(
              (e) => decodeHistoryEntry(e as Map<String, dynamic>),
            ),
          );
          final recent = _recent(storedHistory);
          if (json['catalogSignature'] != catalogSignature) {
            history.merge(recent);
            needsReset = true;
            error = 'Die gespeicherte Partie passt nicht zum aktuellen Fragen-/Regelkatalog. Bitte verwerfen und neu starten.';
            continue;
          }
          // A recent committed draw must exist in both logical halves of the
          // envelope. Reject a corrupted half-state before installing either.
          final cutoff = clock().toUtc().subtract(const Duration(hours: 6));
          for (final game in [json['cards'], json['shared']]) {
            if (game == null) continue;
            for (final assignment in game['rules']['assignments'] as List) {
              final event = decodeHistoryEntry(
                assignment['event'] as Map<String, dynamic>,
              );
              if (event.timestampUtc.isAfter(cutoff) &&
                  !recent.entries.any(
                    (e) =>
                        e.eventId == event.eventId &&
                        e.kind == event.kind &&
                        e.contentId == event.contentId &&
                        e.timestampUtc == event.timestampUtc,
                  )) {
                throw const FormatException(
                  'Ziehereignis ohne gemeinsame Historie',
                );
              }
            }
          }
          final card = cards.validateSnapshot(
            json['cards'] as Map<String, dynamic>?,
            recent,
          );
          final phone = shared.validateSnapshot(
            json['shared'] as Map<String, dynamic>?,
            recent,
          );
          // All validation succeeded before replacing any live state.
          history.restore(recent);
          cards.restoreValidated(card);
          shared.restoreValidated(phone);
          _lastValid = candidates[index];
          needsReset = false;
          restored = card != null || phone != null;
          error = index > 0
              ? 'Der letzte Schreibstand war beschädigt. Der vorherige gültige Stand wurde wiederhergestellt.'
              : null;
          return;
        } on Object {
          needsReset = true;
        }
      }
      if (candidates.isNotEmpty && error == null) error = 'Die gespeicherte Partie ist beschädigt. Verwirf sie, um neu anzufangen.';
    } on Object {
      error = 'Lokaler Speicher ist nicht verfügbar. Spielen ist möglich, Wiederaufnahme nach Schließen jedoch nicht gesichert.';
    }
  }

  Future<void> save() async {
    await _commit();
  }

  Future<bool> _commit({bool resetBackup = false}) {
    // Capture synchronously, queue writes in order. UI updates need not wait for IO.
    final recent = _recent(history.history);
    final envelope = jsonEncode({
      'formatVersion': 1,
      'catalogSignature': catalogSignature,
      'history': recent.entries.map(encodeHistoryEntry).toList(),
      'cards': cards.toSnapshot(),
      'shared': shared.toSnapshot(),
    });
    final completer = Completer<bool>();
    _pending = _pending.then((_) async {
      try {
        await storage.commit(
          envelope,
          previousValid: _lastValid,
          resetBackup: resetBackup,
        );
        _lastValid = envelope;
        error = null;
        needsReset = false;
        completer.complete(true);
      } on Object {
        error = resetBackup
            ? 'Die lokalen Partien konnten nicht vollständig gelöscht werden. Bitte erneut versuchen.'
            : 'Der Spielstand konnte nicht gespeichert werden. Du kannst weiterspielen; nach Schließen kann Fortschritt fehlen.';
        completer.complete(false);
      }
    });
    return completer.future;
  }

  Future<void> discardGames() async {
    await deleteGames();
  }

  Future<bool> deleteGames() {
    cards.abort(confirmed: true);
    shared.abort(confirmed: true);
    restored = false;
    return _commit(resetBackup: true);
  }

  Future<bool> resetGame({required bool cardMode}) async {
    final previousCard = cards.state;
    final previousPhone = cardMode
        ? null
        : shared.validateSnapshot(
            shared.toSnapshot()?.cast<String, dynamic>(),
            history.history,
          );
    if (cardMode) {
      cards.abort(confirmed: true);
    } else {
      shared.abort(confirmed: true);
    }
    restored = cards.state != null || shared.view != null;
    final success = await _commit(resetBackup: true);
    if (!success) {
      if (cardMode) {
        cards.restoreValidated(previousCard);
      } else {
        shared.restoreValidated(previousPhone);
      }
      restored = cards.state != null || shared.view != null;
    }
    return success;
  }
}
