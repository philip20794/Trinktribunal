import '../data/catalogs/catalog.dart';
import 'models/content_history.dart';
import 'models/game_mode.dart';
import 'models/ids.dart';
import 'selection/content_selection.dart';
import 'selection/person_assignment.dart';
import 'selection/random_source.dart';

final class QuestionDeck {
  QuestionDeck({
    required Iterable<Question> questions,
    required this.mode,
    required this.random,
    required this.clock,
  }) : questions = List.unmodifiable(questions);
  final List<Question> questions;
  final GameMode mode;
  final RandomSource random;
  final UtcClock clock;

  SelectionState draw({
    required SelectionState state,
    required String eventId,
    required List<PlayerId> activePlayers,
  }) {
    if (state.alreadyCommitted(eventId, ContentKind.question)) return state;
    final drawn = state.drawnIds(ContentKind.question);
    final candidates = questions
        .where(
          (question) =>
              !drawn.contains(question.id) &&
              (mode.hasPlayerRegistry || question.players.isEmpty) &&
              PersonAssignment(
                roles: question.players,
                activePlayers: activePlayers,
                counts: state.counts,
              ).isPossible,
        )
        .toList();
    final now = clock().toUtc();
    final question = selectContent(
      candidates: candidates,
      kind: ContentKind.question,
      history: state.history,
      nowUtc: now,
      random: random,
    );
    final bindings = PersonAssignment(
      roles: question.players,
      activePlayers: activePlayers,
      counts: state.counts,
    ).bind(random)!;
    return state.commit(
      ContentAssignment(
        entry: question,
        bindings: bindings,
        event: ContentHistoryEntry(
          eventId: eventId,
          kind: ContentKind.question,
          contentId: question.id,
          timestampUtc: now,
        ),
      ),
    );
  }
}
