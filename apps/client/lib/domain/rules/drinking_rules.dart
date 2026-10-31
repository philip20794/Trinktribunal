import '../../data/catalogs/catalog.dart';
import '../models/content_history.dart';
import '../models/domain_error.dart';
import '../models/game_mode.dart';
import '../models/ids.dart';
import '../selection/content_selection.dart';
import '../selection/person_assignment.dart';
import '../selection/random_source.dart';
import '../selection/rule_category_selection.dart';

bool rulesConflict(DrinkingRule a, DrinkingRule b) =>
    a.excludes.contains(b.id) || b.excludes.contains(a.id);

final class RuleState {
  RuleState({
    required this.selection,
    Map<String, ContentAssignment> activations = const {},
    Set<String> inactiveIds = const {},
    Set<String> skippedEvents = const {},
  }) : activations = Map.unmodifiable(activations),
       inactiveIds = Set.unmodifiable(inactiveIds),
       skippedEvents = Set.unmodifiable(skippedEvents);

  final SelectionState selection;
  final Map<String, ContentAssignment> activations;
  final Set<String> inactiveIds;
  final Set<String> skippedEvents;
  List<ContentAssignment> get active => List.unmodifiable(
    activations.values.where((a) => !inactiveIds.contains(a.entry.id)),
  );

  RuleState withSelection(SelectionState selection) => RuleState(
    selection: selection,
    activations: activations,
    inactiveIds: inactiveIds,
    skippedEvents: skippedEvents,
  );

  RuleState deactivate(String id) {
    if (!activations.values.any((a) => a.entry.id == id)) {
      throw const DomainException(
        DomainErrorCode.invalidState,
        'Unbekannte aktive Regel.',
      );
    }
    return RuleState(
      selection: selection,
      activations: activations,
      inactiveIds: {...inactiveIds, id},
      skippedEvents: skippedEvents,
    );
  }
}

final class DrinkingRules {
  DrinkingRules({
    required Iterable<DrinkingRule> rules,
    required this.mode,
    required this.random,
    required this.clock,
  }) : rules = List.unmodifiable(rules);
  final List<DrinkingRule> rules;
  final GameMode mode;
  final RandomSource random;
  final UtcClock clock;

  RuleState activate({
    required RuleState state,
    required String eventId,
    required List<PlayerId> activePlayers,
    int plannedRuleEvents = 0,
  }) {
    if (state.skippedEvents.contains(eventId)) return state;
    if (state.selection.alreadyCommitted(eventId, ContentKind.rule)) {
      return state;
    }
    final drawn = state.selection.drawnIds(ContentKind.rule);
    final candidates = rules
        .where(
          (rule) =>
              !drawn.contains(rule.id) &&
              (mode.hasPlayerRegistry || rule.players.isEmpty) &&
              !state.active.any(
                (active) => rulesConflict(rule, active.entry as DrinkingRule),
              ) &&
              PersonAssignment(
                roles: rule.players,
                activePlayers: activePlayers,
                counts: state.selection.counts,
              ).isPossible,
        )
        .toList();
    if (candidates.isEmpty) {
      return RuleState(
        selection: state.selection,
        activations: state.activations,
        inactiveIds: state.inactiveIds,
        skippedEvents: {...state.skippedEvents, eventId},
      );
    }
    final now = clock().toUtc();
    final rule = selectCategorizedRule(
      catalog: rules,
      candidates: candidates,
      drawnIds: drawn,
      history: state.selection.history,
      nowUtc: now,
      random: random,
      plannedRuleEvents: plannedRuleEvents,
    );
    final bindings = PersonAssignment(
      roles: rule.players,
      activePlayers: activePlayers,
      counts: state.selection.counts,
    ).bind(random)!;
    final assignment = ContentAssignment(
      entry: rule,
      bindings: bindings,
      event: ContentHistoryEntry(
        eventId: eventId,
        kind: ContentKind.rule,
        contentId: rule.id,
        timestampUtc: now,
      ),
    );
    return RuleState(
      selection: state.selection.commit(assignment),
      activations: {...state.activations, eventId: assignment},
      inactiveIds: state.inactiveIds,
      skippedEvents: state.skippedEvents,
    );
  }

  /// At a roster boundary retain existing valid roles; count only new bindings.
  RuleState rebind({
    required RuleState state,
    required List<PlayerId> activePlayers,
  }) {
    var selection = state.selection;
    final activations = Map<String, ContentAssignment>.of(state.activations);
    final inactive = Set<String>.of(state.inactiveIds);
    for (final entry in state.activations.entries) {
      if (inactive.contains(entry.value.entry.id)) continue;
      final assignment = entry.value;
      final fixed = {
        for (final binding in assignment.bindings.entries)
          if (activePlayers.contains(binding.value)) binding.key: binding.value,
      };
      if (fixed.length == assignment.bindings.length) continue;
      final bound = PersonAssignment(
        roles: assignment.entry.players,
        activePlayers: activePlayers,
        counts: selection.counts,
        fixedBindings: fixed,
      ).bind(random);
      if (bound == null) {
        inactive.add(assignment.entry.id);
        continue;
      }
      selection = SelectionState(
        history: selection.history,
        counts: selection.counts.record(
          bound.entries
              .where((e) => !fixed.containsKey(e.key))
              .map((e) => e.value),
        ),
        assignments: selection.assignments,
      );
      activations[entry.key] = ContentAssignment(
        entry: assignment.entry,
        bindings: bound,
        event: assignment.event,
      );
    }
    return RuleState(
      selection: selection,
      activations: activations,
      inactiveIds: inactive,
      skippedEvents: state.skippedEvents,
    );
  }
}
