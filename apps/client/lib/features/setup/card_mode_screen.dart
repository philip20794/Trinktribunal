import '../../design/court_scene.dart';
import '../../design/status_notice.dart';

import 'dart:math' as math;

import '../../l10n/app_strings.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/local_session_controller.dart';
import '../../application/local_data_providers.dart';
import '../../data/catalogs/catalog.dart';
import '../../data/catalogs/catalog_repository.dart';
import '../../data/catalogs/localized_catalog.dart';
import '../../design/case_file.dart';
import '../../domain/local_game_reducer.dart';
import '../../domain/models/domain_error.dart';
import '../../domain/models/game_mode.dart';
import '../rules/active_rules_sheet.dart';
import '../rules/game_rules_screen.dart';

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
  String? _storageWarning;

  void _act(VoidCallback action) {
    try {
      action();
      setState(() => _error = null);
      final transaction = ref.read(localStateTransactionProvider);
      transaction.save().then((_) {
        if (mounted) setState(() => _storageWarning = transaction.error);
      });
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
                  child: const TText('cancel'),
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
      context.tr('skipCaseTitle'),
      context.tr('skipCaseHelp'),
      context.tr('finishCase'),
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

  Future<void> _restart(
    LocalSessionController controller,
    CardGameState state,
  ) async {
    final confirmed = await _confirm(
      context.tr('restartTitle'),
      context.tr('restartHelp'),
      context.tr('restartAction'),
    );
    if (mounted && confirmed) {
      _act(() => controller.start(state.config, confirmedRestart: true));
    }
  }

  Future<void> _abort(LocalSessionController controller) async {
    final confirmed = await _confirm(
      context.tr('endGameTitle'),
      context.tr('endGameHelp'),
      context.tr('endGameAction'),
    );
    if (mounted && confirmed) _act(() => controller.abort(confirmed: true));
  }

  @override
  Widget build(BuildContext context) {
    final catalogs = ref.watch(catalogsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const TText('modeCards'),
        actions: const [GameRulesButton()],
      ),
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
                const TText('cardLoadError'),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => ref.invalidate(catalogsProvider),
                  child: const TText('reload'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const TText('backToSelection'),
                ),
              ],
            ),
          ),
        ),
        data: (_) {
          final resume = ref.watch(localResumeProvider);
          if (resume.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          final controller = ref.watch(localSessionProvider);
          final state = controller.state;
          return Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  if (_storageWarning != null)
                    StatusNotice(context.feedback(_storageWarning!)),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: StatusNotice(context.feedback(_error!)),
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
                          ? context.tr('backToSelection')
                          : context.tr('backToSelectionKeepGame'),
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
      return [const TText('cardNoQuestions')];
    }
    final cases = math.min(_cases, maxCases);
    final rules = math.min(_rules, maxRules);
    return [
      CourtPaper(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TText(
              'nextHearing',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 12),
            const TText('cardIntro'),
            const SizedBox(height: 12),
            _slider('Spieler', _players, 3, 20, (n) => _players = n),
            _slider(context.tr('cases'), cases, 1, maxCases, (n) {
              _cases = n;
              _rules = math.min(_rules, n - 1);
            }),
            _slider(
              context.tr('additionalRules'),
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
              context.tr('cardsPrepare', {
                'max': (_players * _factor + 9) ~/ 10,
                'count': _players - 1,
              }),
            ),
            const SizedBox(height: 12),
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
              label: const TText('startHearing'),
            ),
          ],
        ),
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
    final originalQuestion = state.currentQuestion?.entry as Question?;
    final question = originalQuestion == null
        ? null
        : localizedQuestion(
            ref.read(catalogsProvider).requireValue,
            AppLanguageScope.of(context).language,
            originalQuestion,
          );
    return [
      Row(
        children: [
          Expanded(
            child: Text(
              context.tr('casesCompleted', {
                'done': state.completedCases,
                'total': config.targetCases,
              }),
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          IconButton(
            tooltip: context.tr('activeRules'),
            onPressed: () => showActiveRules(
              context,
              state,
              ref.read(catalogsProvider).requireValue,
            ),
            icon: Badge(
              label: Text('${state.rules.active.length}'),
              child: const Icon(Icons.menu_book_outlined),
            ),
          ),
        ],
      ),
      LinearProgressIndicator(
        value: state.completedCases / config.targetCases,
        semanticsLabel: context.tr('completedCases'),
      ),
      const SizedBox(height: 24),
      if (state.lastCompletion != null) ...[
        Text(switch (state.lastCompletion!) {
          CaseCompletion.withoutVerdict => context.tr('lastNoVerdict'),
          CaseCompletion.playedWithoutRecordedVerdict => context.tr(
            'lastPlayedCase',
          ),
          CaseCompletion.judged => context.tr('manualVerdictSummary', {
            'count': state.manualErrors,
          }),
        }),
        const SizedBox(height: 16),
      ],
      if (state.phase == GamePhase.casePresented && question != null) ...[
        Text(
          context.tr('caseNumber', {'number': state.caseNumber}),
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 16),
        CaseFile(
          animationKey: state.currentEventId,
          showRefresh: true,
          onRefresh: () => _act(
            () => controller.rerollCurrentQuestion(state.currentEventId),
          ),
          label: context.tr('caseProgress', {
            'number': state.caseNumber,
            'total': config.targetCases,
          }),
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
          context.tr('cardsDistribution', {
            'count': config.numberRecipients,
            'max': config.maxSecretNumber,
          }),
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: () =>
              _act(() => controller.advancePlayedCase(state.currentEventId)),
          child: const TText('nextCase'),
        ),
        OutlinedButton(
          onPressed: () => _skip(controller, state),
          child: const TText('withoutVerdict'),
        ),
      ],
      if (state.phase == GamePhase.ruleEvent) ...[
        Text(
          context.tr(
            state.newRule == null ? 'ruleGoalReduced' : 'newDrinkingRule',
          ),
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              (state.newRule == null
                      ? null
                      : localizedRule(
                          ref.read(catalogsProvider).requireValue,
                          AppLanguageScope.of(context).language,
                          state.newRule!.entry as DrinkingRule,
                        ).text) ??
                  context.tr('cardNoRule', {
                    'count': state.effectiveRuleTarget,
                  }),
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
        ),
        const SizedBox(height: 16),
        const TText('ruleEventHelp'),
        FilledButton(
          onPressed: () =>
              _act(() => controller.continueAfterRule(state.currentEventId)),
          child: const TText('nextCase'),
        ),
      ],
      if (state.phase == GamePhase.finished) ...[
        TText('endHearing', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 12),
        Text(
          context.tr('cardFinished', {
            'count': config.targetCases,
            'rules': state.rules.active.length,
          }),
        ),
      ],
      if (state.phase == GamePhase.paused)
        Text(
          state.pauseReason == null
              ? context.tr('gamePaused')
              : context.feedback(state.pauseReason!),
        ),
      if (state.completedCases > 0 && state.phase != GamePhase.finished) ...[
        const SizedBox(height: 16),
        const TText('cardRotateHelp'),
      ],
      const SizedBox(height: 24),
      OutlinedButton(
        onPressed: () => _restart(controller, state),
        child: const TText('restartGame'),
      ),
      TextButton(
        onPressed: () => _abort(controller),
        child: const TText('cardRestartSetup'),
      ),
    ];
  }
}
