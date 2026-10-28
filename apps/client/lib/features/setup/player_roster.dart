import '../../design/court_scene.dart';
import '../bench/bench_view.dart';
import '../../design/status_notice.dart';

import 'package:flutter/material.dart';

import '../../l10n/app_strings.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/local_data_providers.dart';
import '../../application/roster_controller.dart';
import '../../design/avatar_view.dart';
import '../../domain/avatar_config.dart';
import '../../domain/selection/random_source.dart';
import '../../domain/user_profile.dart';
import '../profile/avatar_options.dart';
import '../../data/catalogs/catalog_repository.dart';
import '../handoff/shared_game_screen.dart';

class PlayerRosterScreen extends ConsumerStatefulWidget {
  const PlayerRosterScreen({this.allowStart = true, super.key});
  final bool allowStart;
  @override
  ConsumerState<PlayerRosterScreen> createState() => _PlayerRosterScreenState();
}

class _PlayerRosterScreenState extends ConsumerState<PlayerRosterScreen> {
  bool _busy = false;
  int _cases = 50;
  int _rules = 7;
  int _factor = 15;
  Future<void> _act(Future<bool> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    await action();
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _edit(RosterController controller, [UserProfile? member]) async {
    final result = await showDialog<({String name, AvatarConfig avatar})>(
      context: context,
      builder: (context) => Theme(
        data: courtPaperTheme(),
        child: _RosterEditDialog(member: member),
      ),
    );
    if (!mounted || result == null) return;
    await _act(
      () => member == null
          ? controller.add(result.name, avatar: result.avatar)
          : controller.update(member.player.id, result.name, result.avatar),
    );
  }

  @override
  Widget build(BuildContext context) => CourtScaffold(
    title: const TText('modePhone'),
    bodyBuilder: (context) => ref
        .watch(rosterProvider)
        .when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => Center(
            child: FilledButton(
              onPressed: () => ref.invalidate(rosterProvider),
              child: const TText('rosterReload'),
            ),
          ),
          data: (controller) {
            final own = ref.watch(profileProvider).asData?.value.profile;
            final catalogs = ref.watch(catalogsProvider);
            final session = catalogs.hasValue
                ? ref.watch(sharedPhoneControllerProvider)
                : null;
            final existing = session?.view;
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    TText(
                      'rosterOrder',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      context.tr('rosterCount', {
                        'count': controller.members.length,
                      }),
                    ),
                    FilledButton(
                      onPressed: !_busy && controller.members.length < 20
                          ? () => _edit(controller)
                          : null,
                      child: const TText('rosterAdd'),
                    ),
                    if (own != null)
                      OutlinedButton(
                        onPressed: !_busy && controller.members.length < 20
                            ? () => _act(
                                () => controller.add(
                                  own.player.name,
                                  avatar: own.avatar,
                                ),
                              )
                            : null,
                        child: const TText('rosterImport'),
                      ),
                    ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      title: const TText('benchControls'),
                      children: const [
                        Padding(
                          padding: EdgeInsets.only(bottom: 12),
                          child: TText('rosterOrderHelp'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (controller.error != null)
                      StatusNotice(context.feedback(controller.error!)),
                    if (controller.members.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: TText('rosterEmpty'),
                      ),
                    if (controller.members.isNotEmpty)
                      BenchView(
                        order: [
                          for (final member in controller.members)
                            member.player.id,
                        ],
                        profiles: {
                          for (final member in controller.members)
                            member.player.id: member,
                        },
                        onMove: _busy
                            ? null
                            : (from, to) =>
                                  _act(() => controller.move(from, to)),
                        actionsBuilder: (context, member, index) =>
                            PopupMenuButton<String>(
                              tooltip:
                                  '${context.tr('rosterEditPerson')}: ${member.player.name} · ${index + 1}',
                              enabled: !_busy,
                              onSelected: (action) {
                                if (action == 'edit') {
                                  _edit(controller, member);
                                } else {
                                  _act(
                                    () => controller.remove(member.player.id),
                                  );
                                }
                              },
                              itemBuilder: (context) => [
                                PopupMenuItem(
                                  value: 'edit',
                                  child: const TText('rosterEdit'),
                                ),
                                PopupMenuItem(
                                  value: 'remove',
                                  child: const TText('rosterRemove'),
                                ),
                              ],
                              icon: const Icon(Icons.more_horiz),
                            ),
                      ),
                    const SizedBox(height: 16),
                    const SizedBox(height: 12),
                    if (controller.canStart) const TText('rosterReady'),
                    if (widget.allowStart && session != null) ...[
                      if (existing == null)
                        CourtPaper(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const SizedBox(height: 16),
                              Text(context.tr('casesCount', {'count': _cases})),
                              Slider(
                                value: _cases.toDouble(),
                                min: 1,
                                max: 491,
                                divisions: 490,
                                label: '$_cases',
                                onChanged: (v) => setState(() {
                                  _cases = v.round();
                                  if (_rules >= _cases) _rules = _cases - 1;
                                }),
                              ),
                              Text(context.tr('rulesCount', {'count': _rules})),
                              Slider(
                                value: _rules.toDouble(),
                                min: 0,
                                max: (_cases - 1).clamp(0, 25).toDouble(),
                                divisions: _cases > 1
                                    ? (_cases - 1).clamp(1, 25)
                                    : null,
                                label: '$_rules',
                                onChanged: _cases > 1
                                    ? (v) => setState(() => _rules = v.round())
                                    : null,
                              ),
                              Text(
                                context.tr('factor', {
                                  'value': (_factor / 10).toStringAsFixed(1),
                                }),
                              ),
                              Slider(
                                value: _factor.toDouble(),
                                min: 10,
                                max: 30,
                                divisions: 20,
                                label: (_factor / 10).toStringAsFixed(1),
                                onChanged: (v) =>
                                    setState(() => _factor = v.round()),
                              ),
                            ],
                          ),
                        )
                      else
                        const TText('rosterFrozen'),
                      FilledButton(
                        onPressed:
                            !_busy && (existing != null || controller.canStart)
                            ? () {
                                final config =
                                    existing?.config ??
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
                        child: Text(
                          existing == null
                              ? context.tr('startHearing')
                              : 'Verhandlung fortsetzen',
                        ),
                      ),
                    ],
                    if (widget.allowStart && catalogs.hasError)
                      TextButton(
                        onPressed: () => ref.invalidate(catalogsProvider),
                        child: const TText('retryCases'),
                      ),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const TText('backToSelection'),
                    ),
                  ],
                ),
              ),
            );
          },
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
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      context.tr(widget.member == null ? 'rosterAdd' : 'rosterEditPerson'),
    ),
    content: SizedBox(
      width: 480,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AvatarView(config: _avatar, size: 96),
            const SizedBox(height: 16),
            TextField(
              controller: _name,
              maxLength: 24,
              decoration: InputDecoration(
                labelText: context.tr('name'),
                errorText: _error,
              ),
            ),
            AvatarOptions(
              config: _avatar,
              onChanged: (next) => setState(() => _avatar = next),
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const TText('cancel'),
      ),
      FilledButton(
        onPressed: () {
          if (_name.text.trim().isEmpty) {
            setState(() => _error = context.tr('nameRequired'));
            return;
          }
          Navigator.pop(context, (name: _name.text, avatar: _avatar));
        },
        child: const TText('rosterApply'),
      ),
    ],
  );
}
