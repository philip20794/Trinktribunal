import '../../design/court_scene.dart';
import '../../design/status_notice.dart';
import '../../design/setting_label.dart';

import 'package:flutter/material.dart';

import '../../l10n/app_strings.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/local_data_providers.dart';
import '../../application/roster_controller.dart';
import '../../domain/avatar_config.dart';
import '../../domain/selection/random_source.dart';
import '../../domain/user_profile.dart';
import '../profile/avatar_editor.dart';
import '../../data/catalogs/catalog_repository.dart';
import '../handoff/shared_game_screen.dart';
import 'card_mode_screen.dart';
import '../profile/profile_screen.dart';
import '../bench/roster_grid.dart';

/// Reuses the profile editor while keeping local player IDs unchanged.
Future<List<UserProfile>?> editLocalPerson(
  BuildContext context,
  WidgetRef ref,
  UserProfile member,
) async {
  final controller = await ref.read(rosterProvider.future);
  if (!context.mounted) return null;
  if (controller.isOwner(member.player.id)) {
    await Navigator.of(context)
        .push<void>(MaterialPageRoute(builder: (_) => const ProfileScreen()));
    if (!context.mounted) return null;
    ref.invalidate(rosterProvider);
    return List.of((await ref.read(rosterProvider.future)).members);
  }
  final result = await Navigator.of(context)
      .push<({String name, AvatarConfig avatar})>(
        MaterialPageRoute(builder: (_) => _RosterEditDialog(member: member)),
      );
  if (!context.mounted || result == null) return null;
  if (!await controller.update(member.player.id, result.name, result.avatar)) {
    if (context.mounted && controller.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.feedback(controller.error!))),
      );
    }
    return null;
  }
  return List.of(controller.members);
}

class PlayerRosterScreen extends ConsumerStatefulWidget {
  const PlayerRosterScreen({
    this.allowStart = true,
    this.cardMode = false,
    super.key,
  });
  final bool allowStart;
  final bool cardMode;
  @override
  ConsumerState<PlayerRosterScreen> createState() => _PlayerRosterScreenState();
}

class _PlayerRosterScreenState extends ConsumerState<PlayerRosterScreen> {
  final _name = TextEditingController();
  final _nameFocus = FocusNode();
  bool _busy = false;
  int _cases = 50, _rules = 7, _factor = 15;
  ScaffoldFeatureController<SnackBar, SnackBarClosedReason>? _undo;
  @override
  void dispose() {
    _undo?.close();
    _name.dispose();
    _nameFocus.dispose();
    super.dispose();
  }

  Future<bool> _act(Future<bool> Function() action) async {
    if (_busy || !mounted) return false;
    setState(() => _busy = true);
    try {
      return await action();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _add(RosterController controller) async {
    if (await _act(() => controller.add(_name.text))) {
      if (!mounted) return;
      _name.clear();
      if (mounted) _nameFocus.requestFocus();
    }
  }

  Future<void> _edit(RosterController controller, UserProfile member) async {
    if (controller.isOwner(member.player.id)) {
      await Navigator.of(context)
          .push<void>(MaterialPageRoute(builder: (_) => const ProfileScreen()));
      if (mounted) ref.invalidate(rosterProvider);
      return;
    }
    final result = await Navigator.of(context)
        .push<({String name, AvatarConfig avatar})>(
          MaterialPageRoute(builder: (_) => _RosterEditDialog(member: member)),
        );
    if (mounted && result != null) {
      await _act(
        () => controller.update(member.player.id, result.name, result.avatar),
      );
    }
  }

  Future<bool> _remove(
    RosterController controller,
    UserProfile member,
    int index,
  ) async {
    final removed = await _act(() => controller.remove(member.player.id));
    if (!mounted || !removed) return false;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    _undo = ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        persist: false,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.fromLTRB(16, 0, 16, widget.allowStart ? 90 : 16),
        content: Text(member.player.name, style: const TextStyle(fontSize: 13)),
        action: SnackBarAction(
          label: context.tr('undo'),
          onPressed: () => _act(() => controller.restore(member, index)),
        ),
      ),
    );
    final shown = _undo;
    shown!.closed.then((_) {
      if (identical(_undo, shown)) _undo = null;
    });
    return true;
  }

  Future<void> _options() async {
    final result = await Navigator.push<({int cases, int rules, int factor})>(
      context,
      MaterialPageRoute(
        builder: (_) => LocalGameOptionsScreen(
          maxCases: widget.cardMode ? 431 : 491,
          maxRules: widget.cardMode ? 22 : 25,
          cases: _cases,
          rules: _rules,
          factor: _factor,
        ),
      ),
    );
    if (mounted && result != null) {
      setState(() {
        _cases = result.cases;
        _rules = result.rules;
        _factor = result.factor;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final loaded = ref.watch(rosterProvider), controller = loaded.asData?.value;
    final catalogs = ref.watch(catalogsProvider);
    final session = catalogs.hasValue
        ? ref.watch(sharedPhoneControllerProvider)
        : null;
    final cardSession = catalogs.hasValue
        ? ref.watch(localSessionProvider)
        : null;
    final existing = widget.cardMode ? cardSession?.state : session?.view;
    return CourtScaffold(
      title: TText(widget.cardMode ? 'modeCards' : 'modePhone'),
      footer: widget.allowStart && controller != null && session != null
          ? CourtActionBar(
              primary: FilledButton(
                onPressed: !_busy && (existing != null || controller.canStart)
                    ? () {
                        _nameFocus.unfocus();
                        if (widget.cardMode) {
                          if (cardSession!.state == null) {
                            cardSession.start(
                              cardSession.configure(
                                playerCount: controller.members.length,
                                targetCases: _cases,
                                requestedRuleEvents: _rules,
                                factorTenths: _factor,
                              ),
                              roster: controller.members,
                            );
                          }
                          ref.read(localStateTransactionProvider).save();
                          Navigator.push<void>(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const CardModeScreen(),
                            ),
                          );
                          return;
                        }
                        final config =
                            session.view?.config ??
                            session.configure(
                              playerCount: controller.members.length,
                              targetCases: _cases,
                              requestedRuleEvents: _rules,
                              factorTenths: _factor,
                            );
                        Navigator.push<void>(
                          context,
                          MaterialPageRoute(
                            builder: (_) => SharedGameScreen(
                              config: config,
                              roster: controller.members,
                            ),
                          ),
                        );
                      }
                    : null,
                child: TText(existing == null ? 'startHearing' : 'resumeGame'),
              ),
            )
          : null,
      bodyBuilder: (context) => loaded.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => Center(
          child: FilledButton(
            onPressed: () => ref.invalidate(rosterProvider),
            child: const TText('rosterReload'),
          ),
        ),
        data: (controller) => CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.all(12),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (widget.allowStart && existing == null) ...[
                      OutlinedButton.icon(
                        onPressed: _busy ? null : _options,
                        icon: const Icon(Icons.tune),
                        label: const TText('localGameOptions'),
                      ),
                      const SizedBox(height: 20),
                    ],
                    Text(
                      context.tr('rosterCount', {
                        'count': controller.members.length,
                      }),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            key: const ValueKey('quick-player-name'),
                            controller: _name,
                            focusNode: _nameFocus,
                            enabled: !_busy && controller.members.length < 20,
                            textCapitalization: TextCapitalization.words,
                            textInputAction: TextInputAction.done,
                            decoration: InputDecoration(
                              labelText: context.tr('playerName'),
                            ),
                            onSubmitted: (_) => _add(controller),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton.filled(
                          tooltip: context.tr('rosterAdd'),
                          onPressed: !_busy && controller.members.length < 20
                              ? () => _add(controller)
                              : null,
                          icon: const Icon(Icons.add),
                        ),
                      ],
                    ),
                    if (controller.error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: StatusNotice(
                          context.feedback(controller.error!),
                        ),
                      ),
                    if (controller.members.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: TText('rosterEmpty'),
                      ),
                    if (catalogs.hasError)
                      TextButton(
                        onPressed: () => ref.invalidate(catalogsProvider),
                        child: const TText('retryCases'),
                      ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              sliver: RosterGrid(
                members: controller.members,
                enabled: !_busy,
                onMove: (from, to) => _act(() => controller.move(from, to)),
                onEdit: (member) => _edit(controller, member),
                onRemove: (member, index) => _remove(controller, member, index),
                isOwner: controller.isOwner,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class LocalGameOptionsScreen extends StatefulWidget {
  const LocalGameOptionsScreen({
    required this.cases,
    required this.rules,
    required this.factor,
    this.maxCases = 491,
    this.maxRules = 25,
    super.key,
  });
  final int cases, rules, factor, maxCases, maxRules;
  @override
  State<LocalGameOptionsScreen> createState() => _LocalGameOptionsScreenState();
}

class _LocalGameOptionsScreenState extends State<LocalGameOptionsScreen> {
  late int _cases = widget.cases,
      _rules = widget.rules,
      _factor = widget.factor;
  @override
  Widget build(BuildContext context) => CourtScaffold(
    title: const TText('localGameOptions'),
    footer: CourtActionBar(
      primary: FilledButton(
        onPressed: () => Navigator.pop(context, (
          cases: _cases,
          rules: _rules,
          factor: _factor,
        )),
        child: const TText('rosterApply'),
      ),
    ),
    bodyBuilder: (context) => ListView(
      padding: const EdgeInsets.all(16),
      children: [
        CourtPaper(
          child: Builder(
            builder: (context) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SettingLabel(
                  helpKey: 'localCasesHelp',
                  title: Text(
                    context.tr('casesCount', {'count': _cases}),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                Slider(
                  value: _cases.toDouble(),
                  min: 1,
                  max: widget.maxCases.toDouble(),
                  divisions: widget.maxCases - 1,
                  label: '$_cases',
                  onChanged: (v) => setState(() {
                    _cases = v.round();
                    if (_rules >= _cases) _rules = _cases - 1;
                  }),
                ),
                SettingLabel(
                  helpKey: 'localRulesHelp',
                  title: Text(
                    context.tr('rulesCount', {'count': _rules}),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                Slider(
                  value: _rules.toDouble(),
                  min: 0,
                  max: (_cases - 1).clamp(0, widget.maxRules).toDouble(),
                  divisions: _cases > 1
                      ? (_cases - 1).clamp(1, widget.maxRules)
                      : null,
                  label: '$_rules',
                  onChanged: _cases > 1
                      ? (v) => setState(() => _rules = v.round())
                      : null,
                ),
                SettingLabel(
                  helpKey: 'localFactorHelp',
                  title: Text(
                    context.tr('factor', {
                      'value': (_factor / 10).toStringAsFixed(1),
                    }),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                Slider(
                  value: _factor.toDouble(),
                  min: 10,
                  max: 30,
                  divisions: 20,
                  label: (_factor / 10).toStringAsFixed(1),
                  onChanged: (v) => setState(() => _factor = v.round()),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

class _RosterEditDialog extends StatefulWidget {
  const _RosterEditDialog({this.member});
  final UserProfile? member;
  @override
  State<_RosterEditDialog> createState() => _RosterEditDialogState();
}

class _RosterEditDialogState extends State<_RosterEditDialog> {
  late final TextEditingController _name = TextEditingController(
    text: widget.member?.player.name ?? '',
  );
  late AvatarConfig _avatar =
      widget.member?.avatar ?? AvatarConfig.random(SecureRandomSource());
  String? _error;
  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => CourtScaffold(
    title: Text(
      context.tr(widget.member == null ? 'rosterAdd' : 'rosterEditPerson'),
    ),
    body: AvatarEditor(
      config: _avatar,
      nameController: _name,
      onNameChanged: (_) => setState(() => _error = null),
      onChanged: (next) => setState(() => _avatar = next),
      onRandomize: () =>
          setState(() => _avatar = AvatarConfig.random(SecureRandomSource())),
      notice: _error == null ? null : StatusNotice(_error!),
    ),
    footer: CourtActionBar(
      secondary: TextButton(
        onPressed: () => Navigator.pop(context),
        child: const TText('cancel'),
      ),
      primary: FilledButton(
        onPressed: () {
          if (_name.text.trim().isEmpty) {
            setState(() => _error = context.tr('nameRequired'));
            return;
          }
          Navigator.pop(context, (name: _name.text, avatar: _avatar));
        },
        child: const TText('rosterApply'),
      ),
    ),
  );
}
