import '../data/catalogs/catalog.dart';
import 'config/game_config.dart';
import 'event_schedule.dart';
import 'models/content_history.dart';
import 'models/domain_error.dart';
import 'models/game_mode.dart';
import 'models/ids.dart';
import 'models/person_selection_counts.dart';
import 'question_deck.dart';
import 'rules/drinking_rules.dart';
import 'selection/content_selection.dart';
import 'selection/random_source.dart';

enum CaseCompletion { judged, withoutVerdict }

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
  }) : completedEventIds = Set.unmodifiable(completedEventIds);

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
  int get caseNumber =>
      completedCases + (phase == GamePhase.casePresented ? 1 : 0);
  int get effectiveRuleTarget =>
      schedule.slots.length - rules.skippedEvents.length;
  ContentAssignment? get newRule => rules.activations[currentEventId];
}

/// Physical cards stay outside the app: every verdict is explicitly manual.
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
  }) {
    if (!confirmed) return state;
    if (state.completedEventIds.contains(roundId)) return state;
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
      completedEventIds: {...state.completedEventIds, roundId},
      lastCompletion: manualErrors == null
          ? CaseCompletion.withoutVerdict
          : CaseCompletion.judged,
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
  );
}

Never _invalid(String message) =>
    throw DomainException(DomainErrorCode.invalidState, message);
