import '../data/catalogs/catalog.dart';
import '../domain/config/game_config.dart';
import '../domain/local_game_reducer.dart';
import '../domain/models/content_history.dart';
import '../domain/models/domain_error.dart';
import '../domain/models/game_mode.dart';
import '../domain/models/ids.dart';
import '../domain/selection/random_source.dart';
import 'content_history_store.dart';

/// IO-free coordinator. Device history survives navigation and new games.
final class LocalSessionController {
  LocalSessionController({
    required List<Question> questions,
    required List<DrinkingRule> rules,
    this.contentLanguage = 'de',
    RandomSource? random,
    UtcClock? clock,
    String Function()? newId,
    ContentHistoryStore? historyStore,
  }) : _questions = List.unmodifiable(questions),
       _rules = List.unmodifiable(rules),
       _reducer = LocalGameReducer(
         questions: List.unmodifiable(questions),
         drinkingRules: List.unmodifiable(rules),
         random: random ?? SecureRandomSource(),
         clock: clock ?? (() => DateTime.now().toUtc()),
       ),
       _newId = newId ?? _secureId,
       _historyStore = historyStore ?? ContentHistoryStore();

  final List<Question> _questions;
  final String contentLanguage;
  final List<DrinkingRule> _rules;
  final LocalGameReducer _reducer;
  final String Function() _newId;
  final ContentHistoryStore _historyStore;
  CardGameState? _state;
  CardGameState? get state => _state;
  ContentHistory get history => _historyStore.history;
  CatalogCapacity get capacity => CatalogCapacity(
    questions: _questions.where((q) => q.players.isEmpty).length,
    rules: _rules.where((r) => r.players.isEmpty).length,
  );

  GameConfig configure({
    required int playerCount,
    int targetCases = 50,
    int requestedRuleEvents = 7,
    int factorTenths = 15,
  }) => GameConfig(
    mode: GameMode.physicalCards,
    playerCount: playerCount,
    targetCases: targetCases,
    requestedRuleEvents: requestedRuleEvents,
    factorTenths: factorTenths,
    capacity: capacity,
    contentLanguage: contentLanguage,
  );

  void start(GameConfig config, {bool confirmedRestart = false}) {
    if (_state != null && !confirmedRestart) {
      throw const DomainException(
        DomainErrorCode.invalidState,
        'Eine neue Partie benötigt eine bestätigte Neustartaktion.',
      );
    }
    // Validate against this controller's actual catalogs, not a caller's capacity.
    final validated = GameConfig.fromJson(config.toJson(), capacity: capacity);
    if (validated.contentLanguage != contentLanguage) {
      throw const DomainException(
        DomainErrorCode.invalidConfig,
        'Inhaltssprache und geladener Katalog stimmen nicht überein.',
      );
    }
    _accept(
      _reducer.start(id: GameId(_newId()), config: validated, history: history),
    );
  }

  void completeCase({
    required String roundId,
    required bool confirmed,
    int? manualErrors,
    bool fullOrderConfirmed = false,
  }) {
    _accept(
      _reducer.completeCase(
        _reducer.withHistory(_requireState(), history),
        roundId: roundId,
        confirmed: confirmed,
        manualErrors: manualErrors,
        fullOrderConfirmed: fullOrderConfirmed,
      ),
    );
  }

  void continueAfterRule(String eventId) => _accept(
    _reducer.continueAfterRule(
      _reducer.withHistory(_requireState(), history),
      eventId: eventId,
    ),
  );

  void abort({required bool confirmed}) {
    if (confirmed) _state = null;
  }

  CardGameState _requireState() =>
      _state ??
      (throw const DomainException(
        DomainErrorCode.invalidState,
        'Keine aktive Partie.',
      ));
  void _accept(CardGameState next) {
    _state = next;
    _historyStore.merge(next.rules.selection.history);
  }

  static String _secureId() {
    final random = SecureRandomSource();
    return List.generate(
      32,
      (_) => random.nextInt(16).toRadixString(16),
    ).join();
  }
}
