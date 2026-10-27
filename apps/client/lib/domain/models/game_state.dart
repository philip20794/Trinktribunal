import '../config/game_config.dart';
import 'domain_error.dart';
import 'game_mode.dart';
import 'ids.dart';
import 'person_selection_counts.dart';
import 'player.dart';

/// Initial immutable party state. Transitions will return new snapshots.
/// History is intentionally owned outside this state and survives new games.
final class GameState {
  factory GameState.initial({
    required GameId id,
    required GameConfig config,
    Iterable<Player> players = const [],
  }) {
    final roster = List<Player>.unmodifiable(players);
    if ((!config.mode.hasPlayerRegistry && roster.isNotEmpty) ||
        (config.mode.hasPlayerRegistry &&
            roster.length != config.playerCount) ||
        roster.map((player) => player.id).toSet().length != roster.length) {
      throw const DomainException(
        DomainErrorCode.invalidState,
        'Spielerregister passt nicht zur Konfiguration.',
      );
    }
    return GameState._(
      id,
      config,
      roster,
      PersonSelectionCounts.initial(roster.map((player) => player.id)),
    );
  }

  const GameState._(
    this.id,
    this.config,
    this.players,
    this.personSelectionCounts,
  );

  final GameId id;
  final GameConfig config;
  final List<Player> players;
  final PersonSelectionCounts personSelectionCounts;
  GamePhase get phase => GamePhase.lobby;
  int get completedCases => 0;
  int get revision => 0;
}
