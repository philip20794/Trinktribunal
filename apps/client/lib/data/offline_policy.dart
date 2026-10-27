import '../domain/models/game_mode.dart';

/// Updates and cache removal reload resources and must wait for both local modes.
bool canReplaceOfflineVersion(GamePhase? cards, GamePhase? shared) => [
  cards,
  shared,
].every((phase) => phase == null || phase == GamePhase.finished);
