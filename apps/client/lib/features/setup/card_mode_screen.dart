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
import '../../design/illustrated_paper.dart';
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

  @override
  Widget build(BuildContext context) {
    final catalogs = ref.watch(catalogsProvider);
    final loaded = catalogs.hasValue && ref.watch(localResumeProvider).hasValue
        ? ref.watch(localSessionProvider)
        : null;
    final current = loaded?.state;
    final VoidCallback? next = current?.phase == GamePhase.finished
        ? () => _act(() => loaded!.abort(confirmed: true))
        : current?.phase == GamePhase.casePresented
        ? () => _act(() => loaded!.advancePlayedCase(current!.currentEventId))
        : current?.phase == GamePhase.ruleEvent
        ? () => _act(() => loaded!.continueAfterRule(current!.currentEventId))
        : null;
    return CourtScaffold(
      footer: next == null
          ? null
          : CourtActionBar(
              primary: FilledButton(
                onPressed: next,
                child: TText(
                  current?.phase == GamePhase.finished
                      ? 'newGame'
                      : current?.phase == GamePhase.ruleEvent
                      ? 'ruleUnderstood'
                      : 'nextCase',
                ),
              ),
            ),
      title: const TText('modeCards'),
      actions: const [GameRulesButton()],
      bodyBuilder: (context) => catalogs.when(
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
                padding: const EdgeInsets.all(16),
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
                    ..._game(context, controller, state),
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
        child: Builder(
          builder: (context) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TText(
                'nextHearing',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 12),
              _slider(
                context,
                context.tr('playersLabel'),
                _players,
                3,
                20,
                (n) => _players = n,
              ),
              _slider(context, context.tr('cases'), cases, 1, maxCases, (n) {
                _cases = n;
                _rules = math.min(_rules, n - 1);
              }),
              _slider(
                context,
                context.tr('additionalRules'),
                rules,
                0,
                math.max(0, maxRules),
                (n) => _rules = n,
              ),
              _slider(
                context,
                context.tr('factorLabel'),
                _factor,
                10,
                30,
                (n) => _factor = n,
                display: AppLanguageScope.of(context).language == 'de'
                    ? (_factor / 10).toStringAsFixed(1).replaceAll('.', ',')
                    : (_factor / 10).toStringAsFixed(1),
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
      ),
    ];
  }

  Widget _slider(
    BuildContext context,
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
        semanticFormatterCallback: (v) => label == context.tr('factorLabel')
            ? (v / 10).toStringAsFixed(1)
            : '${v.round()}',
        onChanged: max > min ? (v) => setState(() => update(v.round())) : null,
      ),
    ],
  );

  List<Widget> _game(
    BuildContext context,
    LocalSessionController controller,
    CardGameState state,
  ) {
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
      CaseProgressHeader(
        completed: state.completedCases,
        total: config.targetCases,
        rules: state.rules.active.length,
        onRules: () => showActiveRules(
          context,
          state,
          ref.read(catalogsProvider).requireValue,
        ),
      ),
      const SizedBox(height: 24),
      if (state.phase == GamePhase.casePresented && question != null) ...[
        CourtQuestion(
          animationKey: state.currentEventId,
          showRefresh: true,
          onRefresh: () => _act(
            () => controller.rerollCurrentQuestion(state.currentEventId),
          ),
          label: context.tr('caseProgress', {
            'number': state.caseNumber,
            'total': config.targetCases,
          }),
          text: question.text,
          green: question.green,
          connector: question.connector,
          red: question.red,
          maximum: config.maxSecretNumber,
        ),
        const SizedBox(height: 16),
      ],
      if (state.phase == GamePhase.ruleEvent) ...[
        CourtRule(
          title: state.newRule == null
              ? context.tr('ruleGoalReduced')
              : context.tr('newRule'),
          animationKey: state.currentEventId,
          text:
              (state.newRule == null
                  ? null
                  : localizedRule(
                      ref.read(catalogsProvider).requireValue,
                      AppLanguageScope.of(context).language,
                      state.newRule!.entry as DrinkingRule,
                    ).text) ??
              context.tr('cardNoRule', {'count': state.effectiveRuleTarget}),
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
    ];
  }
}
