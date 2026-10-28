import '../data/catalogs/catalog.dart';
import 'config/game_config.dart';
import 'event_schedule.dart';
import 'models/content_history.dart';
import 'models/domain_error.dart';
import 'models/game_mode.dart';
import 'models/ids.dart';
import 'models/person_selection_counts.dart';
import 'question_deck.dart';
import 'question_draws.dart';
import 'rules/drinking_rules.dart';
import 'selection/content_selection.dart';
import 'selection/random_source.dart';
import 'snapshot_codec.dart';

enum CaseCompletion { judged, withoutVerdict, playedWithoutRecordedVerdict }

final class CardGameState {
  CardGameState._({
    required this.id,
    required this.config,
    required this.schedule,
    required this.rules,
    required this.phase,
    required this.completedCases,
    required this.currentEventId,
    required this.currentQuestion,
    required Set<String> completedEventIds,
    this.lastCompletion,
    this.manualErrors,
    this.pauseReason,
    Map<String, List<String>> questionDraws = const {},
  }) : completedEventIds = Set.unmodifiable(completedEventIds),
       questionDraws = freezeQuestionDraws(questionDraws);

  final GameId id;
  final GameConfig config;
  final EventSchedule schedule;
  final RuleState rules;
  final GamePhase phase;
  final int completedCases;
  final String currentEventId;
  final ContentAssignment? currentQuestion;
  final Set<String> completedEventIds;
  final CaseCompletion? lastCompletion;
  final int? manualErrors;
  final String? pauseReason;
  final Map<String, List<String>> questionDraws;
  int get caseNumber =>
      completedCases + (phase == GamePhase.casePresented ? 1 : 0);
  int get effectiveRuleTarget =>
      schedule.slots.length - rules.skippedEvents.length;
  ContentAssignment? get newRule => rules.activations[currentEventId];

  Map<String, Object?> toSnapshot() => {
    'id': id.value,
    'config': config.toJson(),
    'slots': schedule.slots,
    'rules': encodeRuleState(rules),
    'phase': phase.name,
    'completedCases': completedCases,
    'currentEventId': currentEventId,
    'questionEventId': currentQuestion?.event.eventId,
    'questionDraws': questionDraws,
    'completedEventIds': completedEventIds.toList(),
    'lastCompletion':
        lastCompletion == CaseCompletion.playedWithoutRecordedVerdict
        ? 'played_without_recorded_verdict'
        : lastCompletion?.name,
    'manualErrors': manualErrors,
    'pauseReason': pauseReason,
  };
}

/// Physical numbers/verdicts stay at the table; normal Next records a played case.
final class LocalGameReducer {
  LocalGameReducer({
    required this.questions,
    required this.drinkingRules,
    required this.random,
    required this.clock,
  });
  final List<Question> questions;
  final List<DrinkingRule> drinkingRules;
  final RandomSource random;
  final UtcClock clock;

  QuestionDeck get _deck => QuestionDeck(
    questions: questions,
    mode: GameMode.physicalCards,
    random: random,
    clock: clock,
  );
  DrinkingRules get _rules => DrinkingRules(
    rules: drinkingRules,
    mode: GameMode.physicalCards,
    random: random,
    clock: clock,
  );

  CardGameState withHistory(CardGameState state, ContentHistory history) {
    if (identical(state.rules.selection.history, history)) return state;
    return _copy(
      state,
      rules: state.rules.withSelection(
        SelectionState(
          history: history,
          counts: state.rules.selection.counts,
          assignments: state.rules.selection.assignments,
        ),
      ),
    );
  }

  CardGameState restore(Map<String, dynamic> json, ContentHistory history) {
    final config = GameConfig.fromJson(
      (json['config'] as Map<String, dynamic>).cast<String, Object?>(),
      capacity: CatalogCapacity(
        questions: questions.where((q) => q.players.isEmpty).length,
        rules: drinkingRules.where((r) => r.players.isEmpty).length,
      ),
    );
    if (config.mode != GameMode.physicalCards) {
      throw const FormatException('Falscher Modus');
    }
    final id = GameId(json['id'] as String);
    final schedule = EventSchedule.restore(
      slots: (json['slots'] as List).cast<int>(),
      targetCases: config.targetCases,
      requestedRuleEvents: config.requestedRuleEvents,
    );
    final rules = decodeRuleState(
      json['rules'] as Map<String, dynamic>,
      questions: questions,
      rules: drinkingRules,
      history: history,
    );
    final completed = json['completedCases'] as int;
    final phase = GamePhase.values.byName(json['phase'] as String);
    final events = (json['completedEventIds'] as List).cast<String>().toSet();
    if (completed < 0 ||
        completed > config.targetCases ||
        (phase == GamePhase.finished) != (completed == config.targetCases) ||
        ![
          GamePhase.casePresented,
          GamePhase.ruleEvent,
          GamePhase.paused,
          GamePhase.finished,
        ].contains(phase) ||
        rules.selection.counts.values.isNotEmpty) {
      throw const FormatException('Ungültiger Fallzustand');
    }
    for (var i = 1; i <= completed; i++) {
      if (!events.contains('${id.value}:case:$i')) {
        throw const FormatException('Abschlussmarker fehlt');
      }
    }
    final question = rules.selection.assignments[json['questionEventId']];
    final questionDraws = decodeQuestionDraws(
      json['questionDraws'],
      gameId: id.value,
      completedCases: completed,
      activeCase: phase == GamePhase.casePresented,
      selection: rules.selection,
    );
    final currentEvent = json['currentEventId'] as String;
    if (question == null ||
        question.event.kind != ContentKind.question ||
        (phase == GamePhase.casePresented &&
            (currentEvent != question.event.eventId ||
                questionDraws['${id.value}:case:${completed + 1}']!.last !=
                    currentEvent ||
                events.contains(currentEvent)))) {
      throw const FormatException('Fallakte fehlt');
    }
    if (rules.selection.assignments.values.any((a) => a.bindings.isNotEmpty)) {
      throw const FormatException('Rollen im Kartenmodus');
    }
    if (phase == GamePhase.ruleEvent &&
        (!schedule.slots.contains(completed) ||
            (!rules.activations.containsKey(currentEvent) &&
                !rules.skippedEvents.contains(currentEvent)))) {
      throw const FormatException('Regelslot fehlt');
    }
    final completion = switch (json['lastCompletion']) {
      null => null,
      'judged' => CaseCompletion.judged,
      'withoutVerdict' => CaseCompletion.withoutVerdict,
      'played_without_recorded_verdict' =>
        CaseCompletion.playedWithoutRecordedVerdict,
      _ => throw const FormatException('Unbekannter Fallabschluss'),
    };
    final errors = json['manualErrors'] as int?;
    if ((completion != CaseCompletion.judged && errors != null) ||
        (completion == CaseCompletion.judged &&
            (errors == null ||
                errors < 0 ||
                errors == 1 ||
                errors > config.playerCount - 1))) {
      throw const FormatException('Ungültige manuelle Wertung');
    }
    return CardGameState._(
      id: id,
      config: config,
      schedule: schedule,
      rules: rules,
      phase: phase,
      completedCases: completed,
      currentEventId: currentEvent,
      currentQuestion: question,
      completedEventIds: events,
      lastCompletion: completion,
      manualErrors: errors,
      pauseReason: json['pauseReason'] as String?,
      questionDraws: questionDraws,
    );
  }

  CardGameState start({
    required GameId id,
    required GameConfig config,
    required ContentHistory history,
  }) {
    if (config.mode != GameMode.physicalCards) {
      _invalid('Dieser Ablauf benötigt den Kartenmodus.');
    }
    final schedule = EventSchedule.plan(
      targetCases: config.targetCases,
      requestedRuleEvents: config.requestedRuleEvents,
      random: random,
    );
    final initial = CardGameState._(
      id: id,
      config: config,
      schedule: schedule,
      rules: RuleState(
        selection: SelectionState(
          history: history,
          counts: PersonSelectionCounts({}),
        ),
      ),
      phase: GamePhase.lobby,
      completedCases: 0,
      currentEventId: '',
      currentQuestion: null,
      completedEventIds: {},
    );
    return _nextQuestion(initial);
  }

  CardGameState completeCase(
    CardGameState state, {
    required String roundId,
    required bool confirmed,
    int? manualErrors,
    bool fullOrderConfirmed = false,
  }) => _completeCase(
    state,
    roundId: roundId,
    confirmed: confirmed,
    manualErrors: manualErrors,
    fullOrderConfirmed: fullOrderConfirmed,
  );

  CardGameState advancePlayedCase(
    CardGameState state, {
    required String roundId,
  }) => _completeCase(
    state,
    roundId: roundId,
    confirmed: true,
    completion: CaseCompletion.playedWithoutRecordedVerdict,
  );

  CardGameState _completeCase(
    CardGameState state, {
    required String roundId,
    required bool confirmed,
    int? manualErrors,
    bool fullOrderConfirmed = false,
    CaseCompletion? completion,
  }) {
    if (!confirmed) return state;
    if (isCompletedQuestion(
      state.questionDraws,
      state.completedEventIds,
      roundId,
    )) {
      return state;
    }
    if (state.phase != GamePhase.casePresented ||
        state.currentEventId != roundId) {
      _invalid('Der Fall ist nicht aktiv.');
    }
    if (manualErrors != null &&
        (!fullOrderConfirmed ||
            manualErrors < 0 ||
            manualErrors == 1 ||
            manualErrors > state.config.playerCount - 1)) {
      _invalid(
        'Manuelle Wertung benötigt eine vollständige Ordnung und 0 oder 2 bis N−1 Fehler.',
      );
    }
    final completed = state.completedCases + 1;
    final next = _copy(
      state,
      completedCases: completed,
      completedEventIds: {
        ...state.completedEventIds,
        '${state.id.value}:case:$completed',
      },
      lastCompletion:
          completion ??
          (manualErrors == null
              ? CaseCompletion.withoutVerdict
              : CaseCompletion.judged),
      manualErrors: manualErrors,
      phase: GamePhase.judged,
    );
    if (completed == state.config.targetCases) {
      return _copy(next, phase: GamePhase.finished);
    }
    if (state.schedule.slots.contains(completed)) {
      final eventId = '${state.id.value}:rule:$completed';
      final rules = _rules.activate(
        state: next.rules,
        eventId: eventId,
        activePlayers: [],
      );
      return _copy(
        next,
        phase: GamePhase.ruleEvent,
        currentEventId: eventId,
        rules: rules,
      );
    }
    return _nextQuestion(next);
  }

  CardGameState continueAfterRule(
    CardGameState state, {
    required String eventId,
  }) {
    if (state.completedEventIds.contains(eventId)) return state;
    if (state.phase != GamePhase.ruleEvent || state.currentEventId != eventId) {
      _invalid('Dieses Regelereignis ist nicht aktiv.');
    }
    return _nextQuestion(
      _copy(state, completedEventIds: {...state.completedEventIds, eventId}),
    );
  }

  CardGameState _nextQuestion(CardGameState state) {
    final eventId = '${state.id.value}:case:${state.completedCases + 1}';
    try {
      final selection = _deck.draw(
        state: state.rules.selection,
        eventId: eventId,
        activePlayers: [],
      );
      return _copy(
        state,
        phase: GamePhase.casePresented,
        currentEventId: eventId,
        rules: state.rules.withSelection(selection),
        currentQuestion: selection.assignments[eventId],
        questionDraws: appendQuestionDraw(
          state.questionDraws,
          eventId,
          eventId,
        ),
      );
    } on DomainException catch (error) {
      if (error.code != DomainErrorCode.contentExhausted) rethrow;
      return _copy(
        state,
        phase: GamePhase.paused,
        pauseReason: 'Keine weitere geeignete Frage verfügbar. Der Fallzähler bleibt erhalten.',
      );
    }
  }

  CardGameState _copy(
    CardGameState state, {
    GamePhase? phase,
    int? completedCases,
    String? currentEventId,
    RuleState? rules,
    ContentAssignment? currentQuestion,
    Set<String>? completedEventIds,
    CaseCompletion? lastCompletion,
    int? manualErrors,
    String? pauseReason,
    Map<String, List<String>>? questionDraws,
  }) => CardGameState._(
    id: state.id,
    config: state.config,
    schedule: state.schedule,
    rules: rules ?? state.rules,
    phase: phase ?? state.phase,
    completedCases: completedCases ?? state.completedCases,
    currentEventId: currentEventId ?? state.currentEventId,
    currentQuestion: currentQuestion ?? state.currentQuestion,
    completedEventIds: completedEventIds ?? state.completedEventIds,
    lastCompletion: lastCompletion ?? state.lastCompletion,
    manualErrors: lastCompletion != null ? manualErrors : state.manualErrors,
    pauseReason: pauseReason,
    questionDraws: questionDraws ?? state.questionDraws,
  );

  CardGameState rerollCurrentQuestion(
    CardGameState state, {
    required String roundId,
  }) {
    if (wasRerolled(state.questionDraws, roundId)) return state;
    if (state.phase != GamePhase.casePresented ||
        state.currentEventId != roundId) {
      _invalid('Diese Frage ist nicht mehr aktiv.');
    }
    final id =
        '${state.id.value}:q:${state.rules.selection.drawnIds(ContentKind.question).length + 1}';
    final selection = _deck.draw(
      state: state.rules.selection,
      eventId: id,
      activePlayers: [],
    );
    return _copy(
      state,
      currentEventId: id,
      currentQuestion: selection.assignments[id],
      rules: state.rules.withSelection(selection),
      questionDraws: appendQuestionDraw(
        state.questionDraws,
        '${state.id.value}:case:${state.completedCases + 1}',
        id,
      ),
    );
  }
}

Never _invalid(String message) =>
    throw DomainException(DomainErrorCode.invalidState, message);
