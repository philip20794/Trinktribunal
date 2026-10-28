import '../../design/status_notice.dart';

import 'package:flutter/material.dart';

import '../../l10n/app_strings.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/local_data_providers.dart';
import '../../application/shared_phone_controller.dart';
import '../../data/catalogs/catalog.dart';
import '../../data/catalogs/localized_catalog.dart';
import '../../data/catalogs/catalog_repository.dart';
import '../../design/avatar_view.dart';
import '../../design/case_file.dart';
import '../../design/private_number.dart';
import '../../domain/config/game_config.dart';
import '../../domain/models/domain_error.dart';
import '../../domain/models/game_mode.dart';
import '../../domain/user_profile.dart';
import '../bench/bench_view.dart';
import '../setup/player_roster.dart';

class SharedGameScreen extends ConsumerStatefulWidget {
  const SharedGameScreen({
    required this.config,
    required this.roster,
    super.key,
  });
  final GameConfig config;
  final List<UserProfile> roster;
  @override
  ConsumerState<SharedGameScreen> createState() => _SharedGameScreenState();
}

class _SharedGameScreenState extends ConsumerState<SharedGameScreen>
    with WidgetsBindingObserver {
  late final SharedPhoneController _controller;
  String? _error;
  bool _dialogOpen = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller = ref.read(sharedPhoneControllerProvider);
    if (_controller.view == null) {
      _controller.start(config: widget.config, roster: widget.roster);
    } else {
      _controller.hideSecret();
      _controller.applyRoster(widget.roster);
    }
    _persist();
  }

  @override
  void dispose() {
    _controller.hideSecret();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed && mounted) {
      setState(_controller.hideSecret);
    }
  }

  void _act(VoidCallback action) {
    try {
      action();
      setState(() => _error = null);
      _persist();
    } on DomainException catch (error) {
      setState(() => _error = error.message);
    }
  }

  void _persist() {
    final transaction = ref.read(localStateTransactionProvider);
    transaction.save().then((_) {
      if (mounted && transaction.error != null) {
        setState(() => _error = transaction.error);
      }
    });
  }

  Future<bool> _confirm(String title, String description) async {
    if (_dialogOpen) return false;
    _dialogOpen = true;
    _act(_controller.hideSecret);
    try {
      return await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: Text(title),
              content: Text(description),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const TText('cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const TText('confirm'),
                ),
              ],
            ),
          ) ??
          false;
    } finally {
      _dialogOpen = false;
    }
  }

  Future<void> _group() async {
    _act(_controller.hideSecret);
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => const PlayerRosterScreen(allowStart: false),
      ),
    );
    if (mounted) {
      _act(
        () =>
            _controller.applyRoster(ref.read(rosterControllerProvider).members),
      );
    }
  }

  Future<void> _restart(SharedGameView view) async {
    final confirmed = await _confirm(
      context.tr('newHearingTitle'),
      context.tr('newHearingHelp'),
    );
    if (!mounted || !confirmed) return;
    _act(() {
      final roster = view.pendingRoster ?? view.roster;
      final config = _controller.configure(
        playerCount: roster.length,
        targetCases: view.config.targetCases,
        requestedRuleEvents: view.config.requestedRuleEvents,
        factorTenths: view.config.factorTenths,
      );
      _controller.start(config: config, roster: roster, confirmedRestart: true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final view = _controller.view!;
    final rendered = view.question == null
        ? null
        : localizedQuestion(
            ref.read(catalogsProvider).requireValue,
            AppLanguageScope.of(context).language,
            view.question!.entry as Question,
          ).renderFor(view.question!.names(view.names));
    final judge = view.judge == null ? null : view.profiles[view.judge];
    return PopScope(
      onPopInvokedWithResult: (didPop, result) {
        _controller.hideSecret();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const TText('phoneTitle'),
          actions: [
            IconButton(
              tooltip: context.tr('phoneManageRoster'),
              onPressed: _group,
              icon: const Icon(Icons.groups_outlined),
            ),
            IconButton(
              tooltip: context.tr('activeRules'),
              onPressed: () {
                _act(_controller.hideSecret);
                showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  showDragHandle: true,
                  builder: (context) => FractionallySizedBox(
                    heightFactor: 0.7,
                    child: ListView(
                      padding: const EdgeInsets.all(24),
                      children: [
                        Text(
                          context.tr('activeRulesCount', {
                            'count': view.activeRules.length,
                          }),
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const TText('phoneRuleHelp'),
                        for (final rule in view.activeRules)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Text(
                              localizedRule(
                                ref.read(catalogsProvider).requireValue,
                                AppLanguageScope.of(context).language,
                                rule.entry as DrinkingRule,
                              ).render(
                                localizedRule(
                                  ref.read(catalogsProvider).requireValue,
                                  AppLanguageScope.of(context).language,
                                  rule.entry as DrinkingRule,
                                ).text,
                                rule.names(view.names),
                              ),
                            ),
                          ),
                        if (view.activeRules.isEmpty)
                          const TText('phoneRulesEmpty'),
                      ],
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.menu_book_outlined),
            ),
          ],
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1000),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text(
                  context.tr('casesCompleted', {
                    'done': view.completedCases,
                    'total': view.config.targetCases,
                  }),
                ),
                LinearProgressIndicator(
                  value: view.completedCases / view.config.targetCases,
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: StatusNotice(context.feedback(_error!)),
                  ),
                if (view.pendingRoster != null)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: TText('phoneRosterNotice'),
                  ),
                if (judge != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Row(
                      children: [
                        AvatarView(config: judge.avatar, size: 48),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            context.tr('judge', {'name': judge.player.name}),
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                      ],
                    ),
                  ),
                if (view.phase == GamePhase.numbers) ...[
                  CourtSeal(
                    label: context.tr('passPhone', {
                      'name': view.name(view.recipient!),
                    }),
                    icon: Icons.lock_outline,
                  ),
                  const SizedBox(height: 16),
                  PrivateNumber(
                    number: view.visibleSecret,
                    onReveal: () => _act(
                      () => _controller.revealOwnNumber(
                        roundId: view.roundId,
                        player: view.recipient!,
                      ),
                    ),
                    onConfirm: () => _act(
                      () => _controller.acknowledgeNumber(
                        roundId: view.roundId,
                        player: view.recipient!,
                      ),
                    ),
                    onHide: () => _act(_controller.hideSecret),
                  ),
                ],
                if (rendered != null &&
                    ![
                      GamePhase.ruleEvent,
                      GamePhase.finished,
                      GamePhase.paused,
                    ].contains(view.phase)) ...[
                  const SizedBox(height: 16),
                  CaseFile(
                    animationKey: view.roundId,
                    showRefresh: true,
                    onRefresh:
                        [
                              GamePhase.numbers,
                              GamePhase.answers,
                              GamePhase.ordering,
                              GamePhase.revealing,
                            ].contains(view.phase) &&
                            view.revealCursor == 0
                        ? () => _act(
                            () => _controller.rerollCurrentQuestion(
                              roundId: view.roundId,
                            ),
                          )
                        : null,
                    label: context.tr('caseNumber', {
                      'number': view.completedCases + 1,
                    }),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          rendered.text,
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 16),
                        Text('1 · ${rendered.green}'),
                        Text(rendered.connector),
                        Text(
                          '${(view.roster.length * view.config.factorTenths + 9) ~/ 10} · ${rendered.red}',
                        ),
                      ],
                    ),
                  ),
                ],
                if (view.phase == GamePhase.answers) ...[
                  const SizedBox(height: 16),
                  const TText('phoneAnswersHelp'),
                  FilledButton(
                    onPressed: () =>
                        _act(() => _controller.beginOrdering(view.roundId)),
                    child: const TText('phoneBeginOrder'),
                  ),
                ],
                if ([
                  GamePhase.ordering,
                  GamePhase.revealing,
                  GamePhase.judged,
                ].contains(view.phase)) ...[
                  const SizedBox(height: 16),
                  if (view.phase == GamePhase.ordering)
                    const TText('phoneOrderHelp'),
                  BenchView(
                    order: view.order,
                    profiles: view.profiles,
                    revealedNumbers: view.revealedNumbers,
                    incorrect: view.incorrectRevealed,
                    onMove: view.phase == GamePhase.ordering
                        ? (from, to) => _act(
                            () => _controller.move(view.roundId, from, to),
                          )
                        : null,
                  ),
                  if (view.phase == GamePhase.ordering)
                    FilledButton(
                      onPressed: () async {
                        final confirmed = await _confirm(
                          context.tr('confirmOrderTitle'),
                          context.tr('confirmOrderHelp'),
                        );
                        if (mounted) {
                          _act(
                            () => _controller.confirmOrder(
                              view.roundId,
                              confirmed: confirmed,
                            ),
                          );
                        }
                      },
                      child: const TText('phoneConfirmOrder'),
                    ),
                  if (view.phase == GamePhase.revealing)
                    FilledButton(
                      onPressed: () => _act(
                        () => _controller.revealNext(
                          view.roundId,
                          expectedCursor: view.revealCursor,
                        ),
                      ),
                      child: const TText('phoneRevealNext'),
                    ),
                  if (view.verdict != null) ...[
                    CourtSeal(
                      label: context.tr('wrongPositionsCount', {
                        'count': view.verdict!.errors,
                      }),
                    ),
                    for (final entry in view.verdict!.sips.entries)
                      Text(
                        context.tr('sips', {
                          'name': view.name(entry.key),
                          'count': entry.value,
                        }),
                      ),
                    FilledButton(
                      onPressed: () => _act(
                        () => _controller.completeCase(
                          view.roundId,
                          confirmed: true,
                        ),
                      ),
                      child: const TText('phoneComplete'),
                    ),
                  ],
                ],
                if (view.phase == GamePhase.ruleEvent) ...[
                  CaseFile(
                    label: view.newRule == null
                        ? context.tr('ruleGoalReduced')
                        : context.tr('newRule'),
                    child: Text(
                      view.newRule == null
                          ? context.tr('phoneNoRule', {
                              'count':
                                  view.config.scheduledRuleEventCount -
                                  view.skippedRules,
                            })
                          : localizedRule(
                              ref.read(catalogsProvider).requireValue,
                              AppLanguageScope.of(context).language,
                              view.newRule!.entry as DrinkingRule,
                            ).render(
                              localizedRule(
                                ref.read(catalogsProvider).requireValue,
                                AppLanguageScope.of(context).language,
                                view.newRule!.entry as DrinkingRule,
                              ).text,
                              view.newRule!.names(view.names),
                            ),
                    ),
                  ),
                  const TText('phoneRuleEventHelp'),
                  FilledButton(
                    onPressed: () => _act(
                      () => _controller.continueRule(
                        afterCase: view.completedCases,
                      ),
                    ),
                    child: const TText('nextCase'),
                  ),
                ],
                if (view.phase == GamePhase.paused) ...[
                  Text(
                    view.pauseReason == null
                        ? context.tr('gamePaused')
                        : context.feedback(view.pauseReason!),
                  ),
                  FilledButton(
                    onPressed: () => _act(_controller.resumePaused),
                    child: const TText('phoneContinueRoster'),
                  ),
                ],
                if (view.phase == GamePhase.finished)
                  CourtSeal(label: context.tr('endHearing')),
                if (![
                  GamePhase.ruleEvent,
                  GamePhase.finished,
                  GamePhase.paused,
                ].contains(view.phase))
                  OutlinedButton(
                    onPressed: () async {
                      final confirmed = await _confirm(
                        context.tr('skipCaseTitle'),
                        context.tr('skipPhoneCaseHelp'),
                      );
                      if (mounted) {
                        _act(
                          () => _controller.completeCase(
                            view.roundId,
                            confirmed: confirmed,
                            withoutVerdict: true,
                          ),
                        );
                      }
                    },
                    child: const TText('withoutVerdict'),
                  ),
                const SizedBox(height: 24),
                OutlinedButton(
                  onPressed: () => _restart(view),
                  child: const TText('restartGame'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
