import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/local_data_providers.dart';
import '../../application/shared_phone_controller.dart';
import '../../data/catalogs/catalog.dart';
import '../../design/avatar_view.dart';
import '../../design/case_file.dart';
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
                  child: const Text('Abbrechen'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Bestätigen'),
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
      'Neue Verhandlung?',
      'Fallfortschritt, geheime Zahlen, Urteile und aktive Regeln werden verworfen. Gruppe und Ziehhistorie bleiben erhalten.',
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
    final rendered = (view.question?.entry as Question?)?.renderFor(
      view.question!.names(view.names),
    );
    final judge = view.judge == null ? null : view.profiles[view.judge];
    return PopScope(
      onPopInvokedWithResult: (didPop, result) {
        _controller.hideSecret();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Ein Handy · Verhandlung'),
          actions: [
            IconButton(
              tooltip: 'Gruppe verwalten',
              onPressed: _group,
              icon: const Icon(Icons.groups_outlined),
            ),
            IconButton(
              tooltip: 'Aktive Regeln',
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
                          'Aktive Regeln · ${view.activeRules.length}',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const Text(
                          'Ein Regelverstoß: ein manueller Strafschluck, keine Strafketten. Notwendiges Vorlesen und reguläres Zahlenaufdecken sind ausgenommen.',
                        ),
                        for (final rule in view.activeRules)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Text(
                              rule.entry.render(
                                rule.entry.text,
                                rule.names(view.names),
                              ),
                            ),
                          ),
                        if (view.activeRules.isEmpty)
                          const Text('Noch keine aktiven Regeln.'),
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
                  '${view.completedCases} / ${view.config.targetCases} Fälle abgeschlossen',
                ),
                LinearProgressIndicator(
                  value: view.completedCases / view.config.targetCases,
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                if (view.pendingRoster != null)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      'Besetzung und Sitzreihenfolge ändern sich ab dem nächsten Fall. Namen und Aussehen sind bereits aktualisiert.',
                    ),
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
                            'Richter: ${judge.player.name}',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                      ],
                    ),
                  ),
                if (view.phase == GamePhase.numbers) ...[
                  CourtSeal(
                    label: 'Gerät an ${view.name(view.recipient!)}',
                    icon: Icons.lock_outline,
                  ),
                  const SizedBox(height: 16),
                  if (view.visibleSecret == null)
                    FilledButton(
                      onPressed: () => _act(
                        () => _controller.revealOwnNumber(
                          roundId: view.roundId,
                          player: view.recipient!,
                        ),
                      ),
                      child: const Text('Meine Zahl bewusst öffnen'),
                    )
                  else ...[
                    Text(
                      '${view.visibleSecret}',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.displayLarge,
                      semanticsLabel:
                          'Deine geheime Zahl: ${view.visibleSecret}',
                    ),
                    FilledButton(
                      onPressed: () => _act(
                        () => _controller.acknowledgeNumber(
                          roundId: view.roundId,
                          player: view.recipient!,
                        ),
                      ),
                      child: const Text('Zahl merken · verbergen und weiter'),
                    ),
                    TextButton(
                      onPressed: () => _act(_controller.hideSecret),
                      child: const Text('Zahl wieder verbergen'),
                    ),
                  ],
                ],
                if (rendered != null &&
                    ![
                      GamePhase.ruleEvent,
                      GamePhase.finished,
                      GamePhase.paused,
                    ].contains(view.phase)) ...[
                  const SizedBox(height: 16),
                  CaseFile(
                    label: 'Fall ${view.completedCases + 1}',
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
                  const Text(
                    'Antwortet mündlich passend zu eurer Zahl. Der Richter hört zu und ordnet danach die Antworten von niedrig nach hoch.',
                  ),
                  FilledButton(
                    onPressed: () =>
                        _act(() => _controller.beginOrdering(view.roundId)),
                    child: const Text('Alle haben geantwortet · sortieren'),
                  ),
                ],
                if ([
                  GamePhase.ordering,
                  GamePhase.revealing,
                  GamePhase.judged,
                ].contains(view.phase)) ...[
                  const SizedBox(height: 16),
                  if (view.phase == GamePhase.ordering)
                    const Text(
                      'Figur lange greifen, Quelle und Ziel antippen oder mit den Pfeilen verschieben. Tastatur: Alt + Auf/Ab. Positionsnummern zeigen die vermutete Reihenfolge.',
                    ),
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
                          'Ordnung verbindlich bestätigen?',
                          'Danach ist die Reihenfolge gesperrt. Die Zahlen werden Schritt für Schritt aufgedeckt.',
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
                      child: const Text('Ordnung bestätigen'),
                    ),
                  if (view.phase == GamePhase.revealing)
                    FilledButton(
                      onPressed: () => _act(
                        () => _controller.revealNext(
                          view.roundId,
                          expectedCursor: view.revealCursor,
                        ),
                      ),
                      child: const Text('Nächste Zahl aufdecken'),
                    ),
                  if (view.verdict != null) ...[
                    CourtSeal(
                      label: '${view.verdict!.errors} falsche Positionen',
                    ),
                    for (final entry in view.verdict!.sips.entries)
                      Text('${view.name(entry.key)}: ${entry.value} Schlucke'),
                    FilledButton(
                      onPressed: () => _act(
                        () => _controller.completeCase(
                          view.roundId,
                          confirmed: true,
                        ),
                      ),
                      child: const Text('Fall abschließen · Richterwechsel'),
                    ),
                  ],
                ],
                if (view.phase == GamePhase.ruleEvent) ...[
                  CaseFile(
                    label: view.newRule == null
                        ? 'Regelziel reduziert'
                        : 'Neue Regel',
                    child: Text(
                      view.newRule == null
                          ? 'Keine weitere passende Regel. Höchstens ${view.config.scheduledRuleEventCount - view.skippedRules} Regeln sind jetzt geplant.'
                          : view.newRule!.entry.render(
                              view.newRule!.entry.text,
                              view.newRule!.names(view.names),
                            ),
                    ),
                  ),
                  const Text(
                    'Gilt sofort bis Partieende. Dieses Ereignis zählt keinen Fall und wechselt den Richter nicht erneut.',
                  ),
                  FilledButton(
                    onPressed: () => _act(
                      () => _controller.continueRule(
                        afterCase: view.completedCases,
                      ),
                    ),
                    child: const Text('Weiter zur nächsten Fallakte'),
                  ),
                ],
                if (view.phase == GamePhase.paused) ...[
                  Text(view.pauseReason ?? 'Die Verhandlung ist pausiert.'),
                  FilledButton(
                    onPressed: () => _act(_controller.resumePaused),
                    child: const Text('Mit aktueller Gruppe fortsetzen'),
                  ),
                ],
                if (view.phase == GamePhase.finished)
                  const CourtSeal(label: 'Verhandlung beendet'),
                if (![
                  GamePhase.ruleEvent,
                  GamePhase.finished,
                  GamePhase.paused,
                ].contains(view.phase))
                  OutlinedButton(
                    onPressed: () async {
                      final confirmed = await _confirm(
                        'Fall ohne Urteil abschließen?',
                        'Dieser Fall zählt einmal als abgeschlossen. Es werden keine Fehler oder Schlucke berechnet. Der Richter wechselt.',
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
                    child: const Text('Fall ohne Urteil abschließen'),
                  ),
                const SizedBox(height: 24),
                OutlinedButton(
                  onPressed: () => _restart(view),
                  child: const Text('Partie neu starten'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
