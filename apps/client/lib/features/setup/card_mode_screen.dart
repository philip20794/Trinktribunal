import '../../design/court_scene.dart';
import '../../design/status_notice.dart';

import '../../l10n/app_strings.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/local_session_controller.dart';
import '../../application/local_data_providers.dart';
import '../../data/catalogs/catalog.dart';
import '../../data/catalogs/catalog_repository.dart';
import '../../data/catalogs/localized_catalog.dart';
import '../../design/case_file.dart';
import '../../design/judge_plate.dart';
import '../../design/hold_action_button.dart';
import 'player_roster.dart';
import '../../design/case_stage.dart';
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
    if (loaded != null && current == null) {
      return const PlayerRosterScreen(cardMode: true);
    }
    return CourtScaffold(
      footer: next == null
          ? null
          : CourtActionBar(
              primary: current?.phase == GamePhase.casePresented
                  ? HoldActionButton(
                      icon: Icons.skip_next,
                      duration: const Duration(milliseconds: 500),
                      key: ValueKey('card-next-${current!.currentEventId}'),
                      label: context.tr('nextCase'),
                      onCompleted: next,
                    )
                  : FilledButton(
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
          if (state == null) return const SizedBox.shrink();
          final content = Column(
            mainAxisSize: MainAxisSize.min,
            children: _game(context, controller, state),
          );
          return CaseStage(
            judge: state.judge == null
                ? null
                : JudgePlate(
                    profile: state.judge!,
                    onTap: () async {
                      final profiles = await editLocalPerson(
                        context,
                        ref,
                        state.judge!,
                      );
                      if (mounted && profiles != null) {
                        _act(() => controller.updateProfiles(profiles));
                      }
                    },
                  ),
            rules: state.rules.active.length,
            onRules: () => showActiveRules(
              context,
              state,
              ref.read(catalogsProvider).requireValue,
            ),
            notice: _storageWarning == null && _error == null
                ? null
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_storageWarning != null)
                        StatusNotice(context.feedback(_storageWarning!)),
                      if (_error != null)
                        StatusNotice(context.feedback(_error!)),
                    ],
                  ),
            child: state.phase == GamePhase.finished
                ? SingleChildScrollView(child: content)
                : content,
          );
        },
      ),
    );
  }

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
