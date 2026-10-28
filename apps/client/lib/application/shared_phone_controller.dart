import '../data/catalogs/catalog.dart';
import '../domain/bench_order.dart';
import '../domain/config/game_config.dart';
import '../domain/event_schedule.dart';
import '../domain/judge_rotation.dart';
import '../domain/models/domain_error.dart';
import '../domain/models/content_history.dart';
import '../domain/models/game_mode.dart';
import '../domain/models/ids.dart';
import '../domain/models/person_selection_counts.dart';
import '../domain/number_assignment.dart';
import '../domain/question_deck.dart';
import '../domain/question_draws.dart';
import '../domain/shared_handoff.dart';
import '../domain/rules/drinking_rules.dart';
import '../domain/selection/content_selection.dart';
import '../domain/selection/random_source.dart';
import '../domain/user_profile.dart';
import '../domain/verdict.dart';
import '../domain/snapshot_codec.dart';
import 'content_history_store.dart';

enum SharedNumberStage {
  caseFile,
  recipientHandoff,
  recipientNumber,
  judgeHandoff,
}

/// UI projection deliberately excludes concealed numbers and future verdicts.
final class SharedGameView {
  SharedGameView._(SharedPhoneController session)
    : phase = session._phase,
      config = session._config!,
      gameId = session._gameId!,
      roundId = session._roundId,
      completedCases = session._completed,
      roster = List.unmodifiable(session._roster),
      pendingRoster = session._pending == null
          ? null
          : List.unmodifiable(session._pending!),
      profiles = Map.unmodifiable(session._profiles),
      judge = session._judge,
      question = session._question,
      numberStage = session._phase == GamePhase.numbers
          ? session._numberStage
          : null,
      recipient =
          session._phase == GamePhase.numbers &&
              [
                SharedNumberStage.recipientHandoff,
                SharedNumberStage.recipientNumber,
              ].contains(session._numberStage)
          ? session._recipients[session._handoffIndex]
          : null,
      visibleSecret =
          session._phase == GamePhase.numbers &&
              session._numberStage == SharedNumberStage.recipientNumber &&
              session._visible
          ? session._numbers!.numbers[session._recipients[session
                ._handoffIndex]]
          : null,
      order = List.unmodifiable(session._order),
      revealCursor = session._revealCursor,
      revealedNumbers = Map.unmodifiable({
        for (final id in session._order.take(session._revealCursor))
          id: session._numbers!.numbers[id]!,
      }),
      incorrectRevealed = Set.unmodifiable(
        session._verdict?.incorrect.where(
              (id) => session._order.take(session._revealCursor).contains(id),
            ) ??
            <PlayerId>[],
      ),
      verdict = session._phase == GamePhase.judged ? session._verdict : null,
      activeRules = List.unmodifiable(session._rules!.active),
      newRule = session._phase == GamePhase.ruleEvent
          ? session._rules!.activations[session._ruleEventId]
          : null,
      skippedRules = session._rules!.skippedEvents.length,
      pauseReason = session._pauseReason;
  final GamePhase phase;
  final GameConfig config;
  final GameId gameId;
  final String roundId;
  final int completedCases;
  final List<UserProfile> roster;
  final Map<PlayerId, UserProfile> profiles;
  final List<UserProfile>? pendingRoster;
  final PlayerId? judge;
  final ContentAssignment? question;
  final SharedNumberStage? numberStage;
  final PlayerId? recipient;
  final int? visibleSecret;
  final List<PlayerId> order;
  final int revealCursor;
  final Map<PlayerId, int> revealedNumbers;
  final Set<PlayerId> incorrectRevealed;
  final Verdict? verdict;
  final List<ContentAssignment> activeRules;
  final ContentAssignment? newRule;
  final int skippedRules;
  final String? pauseReason;
  String name(PlayerId id) => profiles[id]!.player.name;
  Map<PlayerId, String> get names => {
    for (final p in profiles.values) p.player.id: p.player.name,
  };
}

final class SharedPhoneController {
  SharedPhoneController({
    required List<Question> questions,
    required List<DrinkingRule> rules,
    RandomSource? random,
    UtcClock? clock,
    this.newId,
    ContentHistoryStore? historyStore,
  }) : _questions = List.unmodifiable(questions),
       _catalogRules = List.unmodifiable(rules),
       _random = random ?? SecureRandomSource(),
       _clock = clock ?? (() => DateTime.now().toUtc()),
       _historyStore = historyStore ?? ContentHistoryStore();

  final List<Question> _questions;
  final List<DrinkingRule> _catalogRules;
  final RandomSource _random;
  final UtcClock _clock;
  final String Function()? newId;
  final ContentHistoryStore _historyStore;
  GameConfig? _config;
  GameId? _gameId;
  List<UserProfile> _roster = [];
  Map<PlayerId, UserProfile> _profiles = {};
  List<UserProfile>? _pending;
  GamePhase _phase = GamePhase.lobby;
  RuleState? _rules;
  EventSchedule? _schedule;
  PlayerId? _judge;
  ContentAssignment? _question;
  NumberAssignment? _numbers;
  List<PlayerId> _recipients = [];
  int _handoffIndex = 0;
  SharedNumberStage _numberStage = SharedNumberStage.caseFile;
  PlayerId? _previousJudge;
  bool _legacyHandoffOrder = false;
  bool _visible = false;
  int _completed = 0;
  String _roundId = '';
  String _ruleEventId = '';
  List<PlayerId> _order = [];
  int _revealCursor = 0;
  Verdict? _verdict;
  final Set<String> _completedRounds = {};
  final Set<int> _processedSlots = {};
  Map<String, List<String>> _questionDraws = const {};
  String? _pauseReason;
  SharedGameView? get view => _config == null ? null : SharedGameView._(this);
  PersonSelectionCounts get personCounts => _rules!.selection.counts;

  GameConfig configure({
    required int playerCount,
    int targetCases = 50,
    int requestedRuleEvents = 7,
    int factorTenths = 15,
  }) => GameConfig(
    mode: GameMode.sharedPhone,
    playerCount: playerCount,
    targetCases: targetCases,
    requestedRuleEvents: requestedRuleEvents,
    factorTenths: factorTenths,
    capacity: CatalogCapacity(
      questions: _questions.length,
      rules: _catalogRules.length,
    ),
  );

  DrinkingRules get _ruleEngine => DrinkingRules(
    rules: _catalogRules,
    mode: GameMode.sharedPhone,
    random: _random,
    clock: _clock,
  );
  List<PlayerId> get _ids => _roster.map((p) => p.player.id).toList();

  void start({
    required GameConfig config,
    required List<UserProfile> roster,
    bool confirmedRestart = false,
  }) {
    if (_config != null && !confirmedRestart) {
      _invalid('Neustart muss bestätigt werden.');
    }
    if (config.mode != GameMode.sharedPhone ||
        config.contentLanguage != 'de' ||
        roster.length != config.playerCount ||
        roster.map((p) => p.player.id).toSet().length != roster.length) {
      _invalid('Konfiguration und Gruppe stimmen nicht überein.');
    }
    final validated = GameConfig.fromJson(
      config.toJson(),
      capacity: CatalogCapacity(
        questions: _questions.length,
        rules: _catalogRules.length,
      ),
    );
    final schedule = EventSchedule.plan(
      targetCases: config.targetCases,
      requestedRuleEvents: config.requestedRuleEvents,
      random: _random,
    );
    _config = validated;
    _gameId = GameId(
      newId?.call() ??
          List.generate(
            32,
            (_) => _random.nextInt(16).toRadixString(16),
          ).join(),
    );
    _roster = List.of(roster);
    _pending = null;
    _judge = roster.first.player.id;
    _previousJudge = null;
    _legacyHandoffOrder = false;
    _profiles = {for (final p in roster) p.player.id: p};
    _rules = RuleState(
      selection: SelectionState(
        history: _historyStore.history,
        counts: PersonSelectionCounts.initial(_ids),
      ),
    );
    _schedule = schedule;
    _completed = 0;
    _completedRounds.clear();
    _processedSlots.clear();
    _questionDraws = const {};
    _question = null;
    _numbers = null;
    _order = [];
    _revealCursor = 0;
    _verdict = null;
    _visible = false;
    _beginCase();
  }

  void _syncHistory() {
    final selection = _rules!.selection;
    _rules = _rules!.withSelection(
      SelectionState(
        history: _historyStore.history,
        counts: selection.counts,
        assignments: selection.assignments,
      ),
    );
  }

  void _beginCase() {
    hideSecret();
    _pauseReason = null;
    if (_pending != null) {
      final oldIds = _ids;
      final oldJudge = _judge;
      _applyPending();
      if (!_ids.contains(_judge)) {
        _judge = nextJudge(
          oldRoster: oldIds,
          previous: oldJudge,
          newRoster: _ids,
        );
      }
      _rules = _ruleEngine.rebind(state: _rules!, activePlayers: _ids);
    }
    if (_roster.length < 3) {
      _phase = GamePhase.paused;
      _pauseReason =
          'Mindestens drei Personen werden für den nächsten Fall benötigt.';
      return;
    }
    _syncHistory();
    final id = '${_gameId!.value}:case:${_completed + 1}';
    try {
      final selected = QuestionDeck(
        questions: _questions,
        mode: GameMode.sharedPhone,
        random: _random,
        clock: _clock,
      ).draw(state: _rules!.selection, eventId: id, activePlayers: _ids);
      final numbers = NumberAssignment.draw(
        roundId: RoundId(id),
        roster: _ids,
        judgeId: _judge!,
        maxSecretNumber: (_roster.length * _config!.factorTenths + 9) ~/ 10,
        allJudges: false,
        random: _random,
      );
      _rules = _rules!.withSelection(selected);
      _historyStore.merge(selected.history);
      _question = selected.assignments[id];
      _numbers = numbers;
      _roundId = id;
      _questionDraws = appendQuestionDraw(_questionDraws, id, id);
      _recipients = handoffRecipients(
        roster: _ids,
        judge: _judge!,
        previousJudge: _previousJudge,
      );
      _handoffIndex = 0;
      _numberStage = SharedNumberStage.caseFile;
      _legacyHandoffOrder = false;
      _phase = GamePhase.numbers;
      _order = [];
      _revealCursor = 0;
      _verdict = null;
    } on DomainException catch (error) {
      if (error.code != DomainErrorCode.contentExhausted) rethrow;
      _phase = GamePhase.paused;
      _pauseReason = 'Keine weitere geeignete Frage verfügbar. Es wird kein Fall erfunden.';
    }
  }

  void revealOwnNumber({required String roundId, required PlayerId player}) {
    _checkRound(roundId);
    if (_phase != GamePhase.numbers ||
        _numberStage != SharedNumberStage.recipientNumber ||
        _recipients[_handoffIndex] != player) {
      _invalid('Diese Zahlenübergabe ist nicht aktiv.');
    }
    _visible = true;
  }

  void hideSecret() {
    _visible = false;
  }

  void interruptPrivateHandoff() {
    hideSecret();
    if (_phase == GamePhase.numbers &&
        _numberStage == SharedNumberStage.recipientNumber) {
      _numberStage = SharedNumberStage.recipientHandoff;
    }
  }

  bool beginNumberHandoff(String roundId) {
    _checkRound(roundId);
    if (_phase != GamePhase.numbers ||
        _numberStage != SharedNumberStage.caseFile) {
      return false;
    }
    hideSecret();
    _numberStage = SharedNumberStage.recipientHandoff;
    return true;
  }

  bool confirmRecipient({required String roundId, required PlayerId player}) {
    _checkRound(roundId);
    if (_phase != GamePhase.numbers ||
        _numberStage != SharedNumberStage.recipientHandoff ||
        _recipients[_handoffIndex] != player) {
      return false;
    }
    hideSecret();
    _numberStage = SharedNumberStage.recipientNumber;
    return true;
  }

  bool confirmJudge({required String roundId, required PlayerId judge}) {
    _checkRound(roundId);
    if (_phase != GamePhase.numbers ||
        _numberStage != SharedNumberStage.judgeHandoff ||
        judge != _judge) {
      return false;
    }
    hideSecret();
    _phase = GamePhase.answers;
    return true;
  }

  bool rerollCurrentQuestion({required String roundId}) {
    if (wasRerolled(_questionDraws, roundId)) return false;
    _checkRound(roundId);
    if (![
          GamePhase.numbers,
          GamePhase.answers,
          GamePhase.ordering,
          GamePhase.revealing,
        ].contains(_phase) ||
        _revealCursor != 0) {
      _invalid('Diese Frage kann nach der Aufdeckung nicht gewechselt werden.');
    }
    final selection = _rules!.selection;
    final id =
        '${_gameId!.value}:q:${selection.drawnIds(ContentKind.question).length + 1}';
    final selected =
        QuestionDeck(
          questions: _questions,
          mode: GameMode.sharedPhone,
          random: _random,
          clock: _clock,
        ).draw(
          state: SelectionState(
            history: _historyStore.history,
            counts: selection.counts,
            assignments: selection.assignments,
          ),
          eventId: id,
          activePlayers: _ids
              .where(
                (id) =>
                    _pending == null || _pending!.any((p) => p.player.id == id),
              )
              .toList(),
        );
    final numbers = NumberAssignment.restore(
      roundId: RoundId(id),
      numbers: _numbers!.numbers,
      roster: _ids,
      judgeId: _judge!,
      maxSecretNumber: (_roster.length * _config!.factorTenths + 9) ~/ 10,
    );
    final draws = appendQuestionDraw(
      _questionDraws,
      '${_gameId!.value}:case:${_completed + 1}',
      id,
    );
    _rules = _rules!.withSelection(selected);
    _historyStore.merge(selected.history);
    _questionDraws = draws;
    _question = selected.assignments[id];
    _numbers = numbers;
    _roundId = id;
    _phase = GamePhase.numbers;
    _handoffIndex = 0;
    _numberStage = SharedNumberStage.caseFile;
    _order = [];
    _revealCursor = 0;
    _verdict = null;
    hideSecret();
    return true;
  }

  void acknowledgeNumber({required String roundId, required PlayerId player}) {
    _checkRound(roundId);
    if (_phase != GamePhase.numbers) return;
    if (_recipients.contains(player) &&
        _recipients.indexOf(player) < _handoffIndex) {
      return;
    }
    if (_numberStage != SharedNumberStage.recipientNumber ||
        _handoffIndex >= _recipients.length ||
        _recipients[_handoffIndex] != player) {
      _invalid('Die Geräteübernahme muss zuerst bestätigt werden.');
    }
    _visible = false;
    _handoffIndex++;
    _numberStage = _handoffIndex == _recipients.length
        ? SharedNumberStage.judgeHandoff
        : SharedNumberStage.recipientHandoff;
  }

  void beginOrdering(String roundId) {
    _checkRound(roundId);
    if (_phase != GamePhase.answers) {
      _invalid('Antwortphase ist nicht abgeschlossen.');
    }
    _order = _ids.where((id) => id != _judge).toList();
    _phase = GamePhase.ordering;
  }

  void move(String roundId, int from, int to) {
    _checkRound(roundId);
    if (_phase != GamePhase.ordering) {
      _invalid('Die Ordnung ist bereits gesperrt.');
    }
    _order = insertPlayer(_order, from, to);
  }

  void confirmOrder(String roundId, {required bool confirmed}) {
    if (!confirmed) return;
    _checkRound(roundId);
    if (_phase == GamePhase.revealing || _phase == GamePhase.judged) return;
    if (_phase != GamePhase.ordering) _invalid('Keine bestätigbare Ordnung.');
    _verdict = normalVerdict(
      judge: _judge!,
      numbers: _numbers!.numbers,
      proposed: _order,
    );
    _phase = GamePhase.revealing;
    _revealCursor = 0;
  }

  void revealNext(String roundId, {required int expectedCursor}) {
    _checkRound(roundId);
    if (expectedCursor < _revealCursor) return;
    if (_phase != GamePhase.revealing || expectedCursor != _revealCursor) {
      _invalid('Ungültiger Aufdeckschritt.');
    }
    _revealCursor++;
    if (_revealCursor == _order.length) _phase = GamePhase.judged;
  }

  void completeCase(
    String roundId, {
    required bool confirmed,
    bool withoutVerdict = false,
  }) {
    if (!confirmed ||
        isCompletedQuestion(_questionDraws, _completedRounds, roundId)) {
      return;
    }
    _checkRound(roundId);
    if ([
          GamePhase.ruleEvent,
          GamePhase.paused,
          GamePhase.finished,
        ].contains(_phase) ||
        (!withoutVerdict && _phase != GamePhase.judged)) {
      _invalid('Der Fall kann noch nicht abgeschlossen werden.');
    }
    hideSecret();
    _completedRounds.add('${_gameId!.value}:case:${_completed + 1}');
    _completed++;
    _numbers = null;
    _recipients = [];
    _handoffIndex = 0;
    _order = [];
    _revealCursor = 0;
    _verdict = null;
    final oldIds = _ids;
    final oldJudge = _judge;
    _previousJudge = oldJudge;
    _legacyHandoffOrder = false;
    _applyPending();
    _judge = nextJudge(oldRoster: oldIds, previous: oldJudge, newRoster: _ids);
    if (_completed == _config!.targetCases) {
      _phase = GamePhase.finished;
      _numbers = null;
      _order = [];
      _revealCursor = 0;
      _verdict = null;
      return;
    }
    _boundary();
  }

  void _boundary() {
    if (_roster.length < 3) {
      _phase = GamePhase.paused;
      _pauseReason =
          'Mindestens drei Personen werden für den nächsten Fall benötigt.';
      return;
    }
    _rules = _ruleEngine.rebind(state: _rules!, activePlayers: _ids);
    if (_schedule!.slots.contains(_completed) &&
        !_processedSlots.contains(_completed)) {
      _syncHistory();
      _ruleEventId = '${_gameId!.value}:rule:$_completed';
      _rules = _ruleEngine.activate(
        state: _rules!,
        eventId: _ruleEventId,
        activePlayers: _ids,
      );
      _historyStore.merge(_rules!.selection.history);
      _processedSlots.add(_completed);
      if (_rules!.activations[_ruleEventId] == null) {
        _beginCase();
        return;
      }
      _phase = GamePhase.ruleEvent;
      _order = [];
      _revealCursor = 0;
      _verdict = null;
    } else {
      _beginCase();
    }
  }

  void continueRule({required int afterCase}) {
    if (_phase != GamePhase.ruleEvent || _completed != afterCase) return;
    _beginCase();
  }

  void applyRoster(List<UserProfile> roster) {
    if (roster.length > 20 ||
        roster.map((p) => p.player.id).toSet().length != roster.length) {
      _invalid('Ungültige Gruppe.');
    }
    hideSecret();
    final profiles = {for (final p in roster) p.player.id: p};
    _profiles.addAll(profiles);
    _roster = [for (final old in _roster) profiles[old.player.id] ?? old];
    final sameIds =
        roster.length == _roster.length &&
        List.generate(
          roster.length,
          (i) => roster[i].player.id == _roster[i].player.id,
        ).every((same) => same);
    _pending = sameIds ? null : List.of(roster);
  }

  void _applyPending() {
    if (_pending == null) return;
    var counts = _rules!.selection.counts;
    final activeBefore = _ids;
    final remaining = activeBefore
        .where((id) => _pending!.any((p) => p.player.id == id))
        .toList();
    for (final member in _pending!) {
      if (!activeBefore.contains(member.player.id)) {
        counts = counts.withParticipant(
          member.player.id,
          previouslyActive: remaining,
        );
      }
    }
    final selected = _rules!.selection;
    _rules = _rules!.withSelection(
      SelectionState(
        history: selected.history,
        counts: counts,
        assignments: selected.assignments,
      ),
    );
    _roster = _pending!;
    _pending = null;
  }

  void resumePaused() {
    if (_phase != GamePhase.paused) return;
    _applyPending();
    if (!_ids.contains(_judge) && _ids.isNotEmpty) _judge = _ids.first;
    _boundary();
  }

  void abort({required bool confirmed}) {
    hideSecret();
    if (confirmed) {
      _config = null;
      _numbers = null;
      _rules = null;
    }
  }

  void _checkRound(String roundId) {
    if (_roundId != roundId) _invalid('Dieser Fall ist nicht mehr aktiv.');
  }

  Map<String, Object?>? toSnapshot() => _config == null
      ? null
      : {
          'id': _gameId!.value,
          'handoffVersion': 2,
          'numberStage': _phase == GamePhase.numbers
              ? (_numberStage == SharedNumberStage.recipientNumber
                        ? SharedNumberStage.recipientHandoff
                        : _numberStage)
                    .name
              : null,
          'previousJudge': _previousJudge?.value,
          'legacyHandoffOrder': _legacyHandoffOrder,
          'questionDraws': _questionDraws,
          'config': _config!.toJson(),
          'phase': _phase.name,
          'profiles': _profiles.values.map((p) => p.toJson()).toList(),
          'roster': _ids.map((id) => id.value).toList(),
          'pending': _pending?.map((p) => p.player.id.value).toList(),
          'judge': _judge?.value,
          'rules': encodeRuleState(_rules!),
          'slots': _schedule!.slots,
          'completed': _completed,
          'roundId': _roundId,
          'ruleEventId': _ruleEventId,
          'questionEventId': _question?.event.eventId,
          'numbers': _numbers == null
              ? null
              : {
                  for (final entry in _numbers!.numbers.entries)
                    entry.key.value: entry.value,
                },
          'recipients': _recipients.map((id) => id.value).toList(),
          'handoffIndex': _handoffIndex,
          'order': _order.map((id) => id.value).toList(),
          'revealCursor': _revealCursor,
          'completedRounds': _completedRounds.toList(),
          'processedSlots': _processedSlots.toList(),
          'pauseReason': _pauseReason,
        };

  /// Builds/validates a separate candidate; no active session is modified here.
  SharedPhoneController? validateSnapshot(
    Map<String, dynamic>? json,
    ContentHistory history,
  ) {
    if (json == null) return null;
    final candidate = SharedPhoneController(
      questions: _questions,
      rules: _catalogRules,
      random: _random,
      clock: _clock,
      newId: newId,
    );
    candidate._config = GameConfig.fromJson(
      (json['config'] as Map<String, dynamic>).cast<String, Object?>(),
      capacity: CatalogCapacity(
        questions: _questions.length,
        rules: _catalogRules.length,
      ),
    );
    if (candidate._config!.mode != GameMode.sharedPhone ||
        candidate._config!.contentLanguage != 'de') {
      throw const FormatException('Falscher lokaler Modus');
    }
    candidate._gameId = GameId(json['id'] as String);
    candidate._phase = GamePhase.values.byName(json['phase'] as String);
    final legacyHandoff = !json.containsKey('handoffVersion');
    if (legacyHandoff) {
      if ([
        'numberStage',
        'previousJudge',
        'legacyHandoffOrder',
      ].any(json.containsKey)) {
        throw const FormatException('Unbekanntes Übergabeformat');
      }
      candidate._legacyHandoffOrder = true;
      candidate._numberStage = SharedNumberStage.recipientHandoff;
    } else {
      if (json['handoffVersion'] != 2 ||
          json['legacyHandoffOrder'] is! bool ||
          ![
            'numberStage',
            'previousJudge',
            'legacyHandoffOrder',
          ].every(json.containsKey)) {
        throw const FormatException('Unbekannte Übergabeversion');
      }
      candidate._legacyHandoffOrder = json['legacyHandoffOrder'] as bool;
      candidate._previousJudge = json['previousJudge'] == null
          ? null
          : PlayerId(json['previousJudge'] as String);
      final stage = json['numberStage'];
      if (candidate._phase == GamePhase.numbers) {
        if (stage is! String ||
            !SharedNumberStage.values.any((value) => value.name == stage)) {
          throw const FormatException('Unbekannte Übergabeetappe');
        }
        candidate._numberStage = SharedNumberStage.values.byName(stage);
        if (candidate._numberStage == SharedNumberStage.recipientNumber) {
          throw const FormatException('Unsichere gespeicherte Geräteübernahme');
        }
      } else if (stage != null) {
        throw const FormatException('Vorzeitige Übergabeetappe');
      }
    }
    final profiles = (json['profiles'] as List)
        .map((p) => UserProfile.fromJson(p as Map<String, dynamic>))
        .toList();
    candidate._profiles = {for (final p in profiles) p.player.id: p};
    if (profiles.length != candidate._profiles.length) {
      throw const FormatException('Doppelte Profile');
    }
    if (candidate._previousJudge != null &&
        !candidate._profiles.containsKey(candidate._previousJudge)) {
      throw const FormatException('Unbekannter vorheriger Richter');
    }
    List<UserProfile> roster(Object? raw) {
      final ids = (raw as List).cast<String>().map(PlayerId.new).toList();
      if (ids.length > 20 ||
          ids.toSet().length != ids.length ||
          !candidate._profiles.keys.toSet().containsAll(ids)) {
        throw const FormatException('Ungültige gespeicherte Besetzung');
      }
      return ids.map((id) => candidate._profiles[id]!).toList();
    }

    candidate._roster = roster(json['roster']);
    candidate._pending = json['pending'] == null
        ? null
        : roster(json['pending']);
    candidate._judge = json['judge'] == null
        ? null
        : PlayerId(json['judge'] as String);
    candidate._rules = decodeRuleState(
      json['rules'] as Map<String, dynamic>,
      questions: _questions,
      rules: _catalogRules,
      history: history,
    );
    candidate._schedule = EventSchedule.restore(
      slots: (json['slots'] as List).cast<int>(),
      targetCases: candidate._config!.targetCases,
      requestedRuleEvents: candidate._config!.requestedRuleEvents,
    );
    candidate._completed = json['completed'] as int;
    candidate._roundId = json['roundId'] as String;
    candidate._ruleEventId = json['ruleEventId'] as String;
    candidate._question =
        candidate._rules!.selection.assignments[json['questionEventId']];
    candidate._order = (json['order'] as List)
        .cast<String>()
        .map(PlayerId.new)
        .toList();
    candidate._recipients = (json['recipients'] as List)
        .cast<String>()
        .map(PlayerId.new)
        .toList();
    candidate._handoffIndex = json['handoffIndex'] as int;
    candidate._revealCursor = json['revealCursor'] as int;
    candidate._completedRounds.addAll(
      (json['completedRounds'] as List).cast<String>(),
    );
    candidate._processedSlots.addAll(
      (json['processedSlots'] as List).cast<int>(),
    );
    candidate._pauseReason = json['pauseReason'] as String?;
    candidate._visible = false;
    final completed = candidate._completed;
    final phase = candidate._phase;
    final activeCase = [
      GamePhase.numbers,
      GamePhase.answers,
      GamePhase.ordering,
      GamePhase.revealing,
      GamePhase.judged,
    ].contains(phase);
    if (completed < 0 ||
        completed > candidate._config!.targetCases ||
        (phase == GamePhase.finished) !=
            (completed == candidate._config!.targetCases) ||
        (!activeCase &&
            ![
              GamePhase.ruleEvent,
              GamePhase.paused,
              GamePhase.finished,
            ].contains(phase))) {
      throw const FormatException('Ungültige gespeicherte Phase');
    }
    if (!candidate._rules!.selection.counts.values.keys.toSet().containsAll(
      candidate._ids,
    )) {
      throw const FormatException('Personenzähler fehlt');
    }
    final expectedRounds = {
      for (var i = 1; i <= completed; i++)
        '${candidate._gameId!.value}:case:$i',
    };
    if (candidate._completedRounds.length != completed ||
        !candidate._completedRounds.containsAll(expectedRounds)) {
      throw const FormatException('Abschlussmarker fehlen');
    }
    if (candidate._processedSlots.any(
      (s) => s > completed || !candidate._schedule!.slots.contains(s),
    )) {
      throw const FormatException('Ungültiger verbrauchter Slot');
    }
    candidate._questionDraws = decodeQuestionDraws(
      json['questionDraws'],
      gameId: candidate._gameId!.value,
      completedCases: completed,
      activeCase: activeCase,
      selection: candidate._rules!.selection,
    );
    if (activeCase) {
      if (candidate._roster.length < 3 ||
          candidate._judge == null ||
          candidate._question == null ||
          candidate._question!.event.eventId != candidate._roundId ||
          candidate
                  ._questionDraws['${candidate._gameId!.value}:case:${completed + 1}']!
                  .last !=
              candidate._roundId ||
          candidate._question!.event.kind != ContentKind.question) {
        throw const FormatException('Aktiver Fall unvollständig');
      }
      candidate._numbers = NumberAssignment.restore(
        roundId: RoundId(candidate._roundId),
        numbers: (json['numbers'] as Map<String, dynamic>).map(
          (k, v) => MapEntry(PlayerId(k), v as int),
        ),
        roster: candidate._ids,
        judgeId: candidate._judge!,
        maxSecretNumber:
            (candidate._roster.length * candidate._config!.factorTenths + 9) ~/
            10,
      );
      final recipients = candidate._legacyHandoffOrder
          ? candidate._ids.where((id) => id != candidate._judge).toList()
          : handoffRecipients(
              roster: candidate._ids,
              judge: candidate._judge!,
              previousJudge: candidate._previousJudge,
            );
      if (candidate._recipients.length != recipients.length ||
          List.generate(
            recipients.length,
            (i) => candidate._recipients[i] != recipients[i],
          ).any((v) => v)) {
        throw const FormatException('Ungültige Übergabereihenfolge');
      }
      if (phase == GamePhase.numbers) {
        if (candidate._handoffIndex < 0 ||
            candidate._handoffIndex > recipients.length ||
            (candidate._numberStage == SharedNumberStage.judgeHandoff) !=
                (candidate._handoffIndex == recipients.length) ||
            (candidate._numberStage == SharedNumberStage.caseFile &&
                candidate._handoffIndex != 0)) {
          throw const FormatException('Ungültiger Übergabecursor');
        }
      } else if (candidate._handoffIndex != recipients.length) {
        throw const FormatException('Zahlenübergabe unvollständig');
      }
      if ([
        GamePhase.ordering,
        GamePhase.revealing,
        GamePhase.judged,
      ].contains(phase)) {
        validateOrder(candidate._order, recipients);
      } else if (candidate._order.isNotEmpty) {
        throw const FormatException('Vorzeitige Ordnung');
      }
      if (phase == GamePhase.revealing || phase == GamePhase.judged) {
        if (candidate._revealCursor < 0 ||
            candidate._revealCursor > recipients.length ||
            (phase == GamePhase.judged) !=
                (candidate._revealCursor == recipients.length)) {
          throw const FormatException('Ungültiger Aufdeckcursor');
        }
        candidate._verdict = normalVerdict(
          judge: candidate._judge!,
          numbers: candidate._numbers!.numbers,
          proposed: candidate._order,
        );
      } else if (candidate._revealCursor != 0) {
        throw const FormatException('Vorzeitige Aufdeckung');
      }
    } else if (json['numbers'] != null ||
        candidate._order.isNotEmpty ||
        candidate._revealCursor != 0) {
      throw const FormatException('Überfällige Fallgeheimnisse');
    }
    return candidate;
  }

  void restoreValidated(SharedPhoneController? candidate) {
    if (candidate == null) {
      _config = null;
      _numbers = null;
      return;
    }
    _config = candidate._config;
    _gameId = candidate._gameId;
    _roster = candidate._roster;
    _profiles = candidate._profiles;
    _pending = candidate._pending;
    _phase = candidate._phase;
    _rules = candidate._rules;
    _schedule = candidate._schedule;
    _judge = candidate._judge;
    _question = candidate._question;
    _questionDraws = candidate._questionDraws;
    _numbers = candidate._numbers;
    _recipients = candidate._recipients;
    _handoffIndex = candidate._handoffIndex;
    _numberStage = candidate._numberStage;
    _previousJudge = candidate._previousJudge;
    _legacyHandoffOrder = candidate._legacyHandoffOrder;
    _visible = false;
    _completed = candidate._completed;
    _roundId = candidate._roundId;
    _ruleEventId = candidate._ruleEventId;
    _order = candidate._order;
    _revealCursor = candidate._revealCursor;
    _verdict = candidate._verdict;
    _completedRounds
      ..clear()
      ..addAll(candidate._completedRounds);
    _processedSlots
      ..clear()
      ..addAll(candidate._processedSlots);
    _pauseReason = candidate._pauseReason;
  }
}

Never _invalid(String message) =>
    throw DomainException(DomainErrorCode.invalidState, message);
