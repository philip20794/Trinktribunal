import '../data/catalogs/catalog.dart';
import '../domain/bench_order.dart';
import '../domain/config/game_config.dart';
import '../domain/event_schedule.dart';
import '../domain/judge_rotation.dart';
import '../domain/models/domain_error.dart';
import '../domain/models/game_mode.dart';
import '../domain/models/ids.dart';
import '../domain/models/person_selection_counts.dart';
import '../domain/number_assignment.dart';
import '../domain/question_deck.dart';
import '../domain/rules/drinking_rules.dart';
import '../domain/selection/content_selection.dart';
import '../domain/selection/random_source.dart';
import '../domain/user_profile.dart';
import '../domain/verdict.dart';
import 'content_history_store.dart';

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
      recipient = session._phase == GamePhase.numbers
          ? session._recipients[session._handoffIndex]
          : null,
      visibleSecret = session._phase == GamePhase.numbers && session._visible
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
  bool _visible = false;
  int _completed = 0;
  String _roundId = '';
  String _ruleEventId = '';
  List<PlayerId> _order = [];
  int _revealCursor = 0;
  Verdict? _verdict;
  final Set<String> _completedRounds = {};
  final Set<int> _processedSlots = {};
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
      _recipients = numbers.numbers.keys.toList();
      _handoffIndex = 0;
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
    if (_phase != GamePhase.numbers || _recipients[_handoffIndex] != player) {
      _invalid('Diese Zahlenübergabe ist nicht aktiv.');
    }
    _visible = true;
  }

  void hideSecret() {
    _visible = false;
  }

  void acknowledgeNumber({required String roundId, required PlayerId player}) {
    _checkRound(roundId);
    if (_phase != GamePhase.numbers) return;
    if (_recipients[_handoffIndex] != player &&
        _recipients.contains(player) &&
        _recipients.indexOf(player) < _handoffIndex) {
      return;
    }
    if (_recipients[_handoffIndex] != player || !_visible) {
      _invalid('Zahl zuerst bewusst öffnen und bestätigen.');
    }
    _visible = false;
    _handoffIndex++;
    if (_handoffIndex == _recipients.length) _phase = GamePhase.answers;
  }

  void beginOrdering(String roundId) {
    _checkRound(roundId);
    if (_phase != GamePhase.answers) {
      _invalid('Antwortphase ist nicht abgeschlossen.');
    }
    _order = List.of(_recipients);
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
    if (!confirmed || _completedRounds.contains(roundId)) return;
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
    _completedRounds.add(roundId);
    _completed++;
    final oldIds = _ids;
    final oldJudge = _judge;
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
    _pending = List.of(roster);
  }

  void _applyPending() {
    if (_pending == null) return;
    var counts = _rules!.selection.counts;
    final activeBefore = _ids;
    for (final member in _pending!) {
      if (!activeBefore.contains(member.player.id)) {
        counts = counts.withParticipant(
          member.player.id,
          previouslyActive: activeBefore,
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
}

Never _invalid(String message) =>
    throw DomainException(DomainErrorCode.invalidState, message);
