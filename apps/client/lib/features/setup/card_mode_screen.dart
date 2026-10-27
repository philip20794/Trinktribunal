import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/local_session_controller.dart';
import '../../application/local_data_providers.dart';
import '../../data/catalogs/catalog.dart';
import '../../data/catalogs/catalog_repository.dart';
import '../../design/case_file.dart';
import '../../domain/local_game_reducer.dart';
import '../../domain/models/domain_error.dart';
import '../../domain/models/game_mode.dart';
import '../rules/active_rules_sheet.dart';

final localSessionProvider = Provider<LocalSessionController>((ref) {
  final catalogs = ref.watch(catalogsProvider).requireValue;
  return LocalSessionController(
    historyStore: ref.watch(contentHistoryStoreProvider),
    questions: catalogs.questions['de']!.entries,
    rules: catalogs.rules['de']!.entries,
  );
});

class CardModeScreen extends ConsumerStatefulWidget {
  const CardModeScreen({super.key});

  @override
  ConsumerState<CardModeScreen> createState() => _CardModeScreenState();
}

class _CardModeScreenState extends ConsumerState<CardModeScreen> {
  int _players = 8;
  int _cases = 50;
  int _rules = 7;
  int _factor = 15;
  bool _dialogOpen = false;
  String? _error;

  void _act(VoidCallback action) {
    try {
      action();
      setState(() => _error = null);
    } on DomainException catch (error) {
      setState(() => _error = error.message);
    }
  }

  Future<bool> _confirm(String title, String message, String action) async {
    if (_dialogOpen) return false;
    _dialogOpen = true;
    try {
      return await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: Text(title),
              content: Text(message),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Abbrechen'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: Text(action),
                ),
              ],
            ),
          ) ??
          false;
    } finally {
      _dialogOpen = false;
    }
  }

  Future<void> _skip(
    LocalSessionController controller,
    CardGameState state,
  ) async {
    final confirmed = await _confirm(
      'Fall ohne Urteil abschließen?',
      'Dieser Fall zählt als abgeschlossen. Es werden keine Fehler oder Schlucke berechnet. Danach wechselt ihr den Richter am Tisch.',
      'Fall abschließen',
    );
    if (mounted) {
      _act(
        () => controller.completeCase(
          roundId: state.currentEventId,
          confirmed: confirmed,
        ),
      );
    }
  }

  Future<void> _manual(
    LocalSessionController controller,
    CardGameState state,
  ) async {
    if (_dialogOpen) return;
    _dialogOpen = true;
    int errors = 0;
    bool checked = false;
    int? result;
    try {
      result = await showDialog<int>(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, update) => AlertDialog(
            title: const Text('Urteil manuell eintragen'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Vergleicht die vollständige Reihenfolge mit euren echten Zahlenkarten. Zählt falsch besetzte Positionen, keine vertauschten Paare.',
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<int>(
                    initialValue: 0,
                    decoration: const InputDecoration(
                      labelText: 'Falsche Positionen',
                    ),
                    items:
                        [
                              0,
                              for (var i = 2; i < state.config.playerCount; i++)
                                i,
                            ]
                            .map(
                              (n) =>
                                  DropdownMenuItem(value: n, child: Text('$n')),
                            )
                            .toList(),
                    onChanged: (value) => update(() => errors = value ?? 0),
                  ),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: checked,
                    onChanged: (value) =>
                        update(() => checked = value ?? false),
                    title: const Text(
                      'Die vollständige Ordnung wurde geprüft.',
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Abbrechen'),
              ),
              FilledButton(
                onPressed: checked
                    ? () => Navigator.pop(context, errors)
                    : null,
                child: const Text('Urteil bestätigen'),
              ),
            ],
          ),
        ),
      );
    } finally {
      _dialogOpen = false;
    }
    if (!mounted || result == null) return;
    final verdict = result;
    _act(
      () => controller.completeCase(
        roundId: state.currentEventId,
        confirmed: true,
        manualErrors: verdict,
        fullOrderConfirmed: true,
      ),
    );
  }

  Future<void> _restart(
    LocalSessionController controller,
    CardGameState state,
  ) async {
    final confirmed = await _confirm(
      'Partie neu starten?',
      'Fälle und aktive Regeln werden zurückgesetzt. Die Ziehhistorie der letzten sechs Stunden bleibt erhalten.',
      'Neu starten',
    );
    if (mounted && confirmed) {
      _act(() => controller.start(state.config, confirmedRestart: true));
    }
  }

  Future<void> _abort(LocalSessionController controller) async {
    final confirmed = await _confirm(
      'Partie beenden?',
      'Der aktuelle Spielfortschritt wird verworfen. Danach könnt ihr eine neue Partie einrichten.',
      'Partie beenden',
    );
    if (mounted && confirmed) _act(() => controller.abort(confirmed: true));
  }

  @override
  Widget build(BuildContext context) {
    final catalogs = ref.watch(catalogsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Handy + Karten')),
      body: catalogs.when(
        loading: () => const Center(
          child: CircularProgressIndicator(
            semanticsLabel: 'Fallakten werden geladen',
          ),
        ),
        error: (error, stack) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Die Fallakten konnten nicht geladen werden. Bitte erneut versuchen.',
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => ref.invalidate(catalogsProvider),
                  child: const Text('Erneut laden'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Zurück zur Auswahl'),
                ),
              ],
            ),
          ),
        ),
        data: (_) {
          final controller = ref.watch(localSessionProvider);
          final state = controller.state;
          return Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Text(
                        _error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                        semanticsLabel: 'Fehler: $_error',
                      ),
                    ),
                  if (state == null)
                    ..._setup(controller)
                  else
                    ..._game(controller, state),
                  const SizedBox(height: 20),
                  TextButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back),
                    label: Text(
                      state == null
                          ? 'Zurück zur Auswahl'
                          : 'Zur Auswahl · Partie bleibt geöffnet',
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  List<Widget> _setup(LocalSessionController controller) {
    final maxCases = math.min(431, controller.capacity.questions);
    final maxRules = math.min(
      math.min(22, controller.capacity.rules),
      math.min(_cases, maxCases) - 1,
    );
    if (maxCases < 1) {
      return [
        const Text('Keine geeigneten Fragen für den Kartenmodus verfügbar.'),
      ];
    }
    final cases = math.min(_cases, maxCases);
    final rules = math.min(_rules, maxRules);
    return [
      Text(
        'Eure nächste Verhandlung',
        style: Theme.of(context).textTheme.headlineMedium,
      ),
      const SizedBox(height: 12),
      const Text(
        'Ihr braucht echte Zahlenkarten. Keine Namen und keine Profile nötig. Eine Person richtet, die anderen antworten mündlich.',
      ),
      const SizedBox(height: 24),
      _slider('Spieler', _players, 3, 20, (n) => _players = n),
      _slider('Fälle', cases, 1, maxCases, (n) {
        _cases = n;
        _rules = math.min(_rules, n - 1);
      }),
      _slider(
        'Zusätzliche Regeln',
        rules,
        0,
        math.max(0, maxRules),
        (n) => _rules = n,
      ),
      _slider(
        'Faktor',
        _factor,
        10,
        30,
        (n) => _factor = n,
        display: (_factor / 10).toStringAsFixed(1).replaceAll('.', ','),
      ),
      const SizedBox(height: 12),
      Text(
        'Zahlenkarten 1–${(_players * _factor + 9) ~/ 10} bereitlegen. Pro Fall erhalten ${_players - 1} Antwortende je eine Karte; der Richter erhält keine.',
      ),
      const SizedBox(height: 20),
      FilledButton.icon(
        onPressed: () => _act(
          () => controller.start(
            controller.configure(
              playerCount: _players,
              targetCases: cases,
              requestedRuleEvents: rules,
              factorTenths: _factor,
            ),
          ),
        ),
        icon: const Icon(Icons.gavel),
        label: const Text('Verhandlung starten'),
      ),
    ];
  }

  Widget _slider(
    String label,
    int value,
    int min,
    int max,
    void Function(int) update, {
    String? display,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        '$label: ${display ?? value}',
        style: Theme.of(context).textTheme.titleMedium,
      ),
      Slider(
        value: value.toDouble(),
        min: min.toDouble(),
        max: max.toDouble(),
        divisions: max > min ? max - min : null,
        label: display ?? '$value',
        semanticFormatterCallback: (v) =>
            label == 'Faktor' ? (v / 10).toStringAsFixed(1) : '${v.round()}',
        onChanged: max > min ? (v) => setState(() => update(v.round())) : null,
      ),
    ],
  );

  List<Widget> _game(LocalSessionController controller, CardGameState state) {
    final config = state.config;
    final question = state.currentQuestion?.entry as Question?;
    return [
      Row(
        children: [
          Expanded(
            child: Text(
              '${state.completedCases} von ${config.targetCases} Fällen abgeschlossen',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          IconButton(
            tooltip: 'Aktive Regeln',
            onPressed: () => showActiveRules(context, state),
            icon: Badge(
              label: Text('${state.rules.active.length}'),
              child: const Icon(Icons.menu_book_outlined),
            ),
          ),
        ],
      ),
      LinearProgressIndicator(
        value: state.completedCases / config.targetCases,
        semanticsLabel: 'Abgeschlossene Fälle',
      ),
      const SizedBox(height: 24),
      if (state.lastCompletion != null) ...[
        Text(
          state.lastCompletion == CaseCompletion.withoutVerdict
              ? 'Letzter Fall: ohne Urteil abgeschlossen. Keine Wertung.'
              : 'Manuelles Urteil: ${state.manualErrors} falsche Positionen. Richter und jede falsch platzierte Person: je ${state.manualErrors} Schlucke; richtig Platzierte: 0.',
        ),
        const SizedBox(height: 16),
      ],
      if (state.phase == GamePhase.casePresented && question != null) ...[
        Text(
          'Fallakte ${state.caseNumber}',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 16),
        CaseFile(
          label: 'Fall ${state.caseNumber} / ${config.targetCases}',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                question.text,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 24),
              Text(
                '1 · ${question.green}',
                style: const TextStyle(
                  color: Color(0xFF276044),
                  fontWeight: FontWeight.bold,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(question.connector),
              ),
              Text(
                '${config.maxSecretNumber} · ${question.red}',
                style: const TextStyle(
                  color: Color(0xFF874B49),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Verteilt ${config.numberRecipients} verschiedene Karten aus 1–${config.maxSecretNumber}. Antwortet passend zur eigenen Zahl. Der Richter ordnet eure Antworten von niedrig nach hoch.',
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: () => _manual(controller, state),
          child: const Text('Manuelles Urteil eintragen'),
        ),
        OutlinedButton(
          onPressed: () => _skip(controller, state),
          child: const Text('Fall ohne Urteil abschließen'),
        ),
      ],
      if (state.phase == GamePhase.ruleEvent) ...[
        Text(
          state.newRule == null ? 'Regelziel reduziert' : 'Neue Trinkregel',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              state.newRule?.entry.text ??
                  'Keine weitere passende Regel verfügbar. Geplant sind jetzt höchstens ${state.effectiveRuleTarget} Regeln.',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Regeln gelten sofort bis Partieende. Dieses Ereignis ist kein Fall: keine Zahlenkarten, kein Urteil und kein zusätzlicher Richterwechsel.',
        ),
        FilledButton(
          onPressed: () =>
              _act(() => controller.continueAfterRule(state.currentEventId)),
          child: const Text('Weiter zur nächsten Fallakte'),
        ),
      ],
      if (state.phase == GamePhase.finished) ...[
        Text(
          'Verhandlung beendet',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 12),
        Text(
          'Alle ${config.targetCases} Fälle sind abgeschlossen. ${state.rules.active.length} Regeln wurden aktiviert.',
        ),
      ],
      if (state.phase == GamePhase.paused)
        Text(state.pauseReason ?? 'Die Partie ist pausiert.'),
      if (state.completedCases > 0 && state.phase != GamePhase.finished) ...[
        const SizedBox(height: 16),
        const Text(
          'Richterwechsel am Tisch: Nach jedem abgeschlossenen Fall richtet die nächste Person in eurer Sitzreihenfolge.',
        ),
      ],
      const SizedBox(height: 24),
      OutlinedButton(
        onPressed: () => _restart(controller, state),
        child: const Text('Partie neu starten'),
      ),
      TextButton(
        onPressed: () => _abort(controller),
        child: const Text('Partie beenden und neu einrichten'),
      ),
    ];
  }
}
