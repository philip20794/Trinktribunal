import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/room_providers.dart';
import '../../application/room_controller.dart';
import '../../data/protocol/room_message.dart';
import '../../data/room_transport.dart';
import '../../domain/models/ids.dart';
import '../../l10n/app_strings.dart';
import '../../design/court_scene.dart';
import '../../design/status_notice.dart';
import 'invitation.dart';

class RoomGameSettings extends ConsumerStatefulWidget {
  const RoomGameSettings({required this.snapshot, this.session, super.key});
  final SnapshotMessage snapshot;
  final RoomSessionState? session;
  @override
  ConsumerState<RoomGameSettings> createState() => _RoomGameSettingsState();
}

class _RoomGameSettingsState extends ConsumerState<RoomGameSettings> {
  late Config _draft;
  bool _pending = false;
  @override
  void initState() {
    super.initState();
    _draft = widget.snapshot.public.config;
  }

  @override
  void didUpdateWidget(RoomGameSettings oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!mapEquals(
      oldWidget.snapshot.public.config.toJson(),
      widget.snapshot.public.config.toJson(),
    )) {
      _draft = widget.snapshot.public.config;
    }
    if (oldWidget.snapshot.revision != widget.snapshot.revision) {
      _pending = false;
    }
    if (oldWidget.session != widget.session &&
        widget.session?.errorCode != null) {
      _pending = false;
    }
  }

  void change(String field, Object value) => setState(
    () => _draft = Config.fromJson({..._draft.toJson(), field: value}),
  );
  bool get dirty =>
      !mapEquals(_draft.toJson(), widget.snapshot.public.config.toJson());
  Widget slider(
    String key,
    int value,
    int min,
    int max,
    ValueChanged<int> changed,
  ) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(context.tr(key, {'count': value})),
      Slider(
        value: value.toDouble(),
        min: min.toDouble(),
        max: max.toDouble(),
        divisions: max - min,
        onChanged: _pending ? null : (n) => changed(n.round()),
      ),
    ],
  );
  @override
  Widget build(BuildContext context) {
    ref.listen(roomSessionProvider, (_, next) {
      if (next.asData?.value.errorCode != null && mounted && _pending) {
        setState(() => _pending = false);
      }
    });
    final view = widget.snapshot, isHost = view.you == view.public.hostId;
    if (view.public.phase != 'lobby') return const TText('rosterFrozen');
    final controller = ref.read(roomControllerProvider),
        editor = ref.watch(onlineProfileProvider);
    return CourtPaper(
      child: Material(
        type: MaterialType.transparency,
        child: Padding(
          padding: const EdgeInsets.all(0),
          child: ListenableBuilder(
            listenable: editor,
            builder: (context, _) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TText(
                  'onlineSettings',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                if (isHost) ...[
                  const TText('localCasesHelp'),
                  slider(
                    'casesCount',
                    _draft.targetCases,
                    1,
                    491,
                    (n) => change('targetCases', n),
                  ),
                  const TText('localRulesHelp'),
                  slider(
                    'rulesCount',
                    _draft.requestedRuleEvents,
                    0,
                    25,
                    (n) => change('requestedRuleEvents', n),
                  ),
                  Text(
                    context.tr('factor', {
                      'value': (_draft.factorTenths / 10).toStringAsFixed(1),
                    }),
                  ),
                  const TText('localFactorHelp'),
                  Slider(
                    value: _draft.factorTenths.toDouble(),
                    min: 10,
                    max: 30,
                    divisions: 20,
                    onChanged: _pending
                        ? null
                        : (n) => change('factorTenths', n.round()),
                  ),
                  SwitchListTile(
                    title: const TText('onlineAllJudges'),
                    value: _draft.allJudges,
                    onChanged: _pending
                        ? null
                        : (value) => change('allJudges', value),
                  ),
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    key: ValueKey('online-language-${_draft.contentLanguage}'),
                    initialValue: _draft.contentLanguage,
                    decoration: InputDecoration(
                      labelText: context.tr('onlineContentLanguage'),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'de', child: Text('Deutsch')),
                      DropdownMenuItem(value: 'en', child: Text('English')),
                    ],
                    onChanged: _pending
                        ? null
                        : (value) {
                            if (value != null) change('contentLanguage', value);
                          },
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed:
                        dirty && !_pending && !editor.dirty && !editor.saving
                        ? () {
                            if (_pending) return;
                            final latest = controller.state.snapshot;
                            if (latest == null ||
                                latest.public.phase != 'lobby') {
                              return;
                            }
                            final sent = controller.sendAction(
                              SetConfigMessage.create(
                                actionId: ActionId(newRoomRequestId()),
                                expectedRevision: latest.revision,
                                config: _draft,
                              ),
                            );
                            if (sent) setState(() => _pending = true);
                          }
                        : null,
                    child: const TText('onlineSaveSettings'),
                  ),
                  if (editor.dirty || editor.saving)
                    const TText('roomProfilePending'),
                ] else ...[
                  TText(
                    view.public.config.allJudges
                        ? 'onlineAllJudges'
                        : 'onlineNormalMode',
                  ),
                  Text(
                    context.tr('casesCount', {
                      'count': view.public.config.targetCases,
                    }),
                  ),
                  Text(
                    context.tr('rulesCount', {
                      'count': view.public.config.requestedRuleEvents,
                    }),
                  ),
                  Text(
                    context.tr('factor', {
                      'value': (view.public.config.factorTenths / 10)
                          .toStringAsFixed(1),
                    }),
                  ),
                  Text(
                    context.tr('onlineLanguageValue', {
                      'language': view.public.config.contentLanguage == 'de'
                          ? 'Deutsch'
                          : 'English',
                    }),
                  ),
                  const TText('onlineHostStarts'),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class RoomSettingsScreen extends ConsumerWidget {
  const RoomSettingsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state =
        ref.watch(roomSessionProvider).asData?.value ??
        ref.read(roomControllerProvider).state;
    return CourtScaffold(
      title: const TText('localGameOptions'),
      body: state.snapshot == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (state.errorCode != null)
                  StatusNotice(context.tr(roomErrorKey(state.errorCode)))
                else
                  const SizedBox.shrink(),
                RoomGameSettings(
                  key: const ValueKey('room-settings-editor'),
                  snapshot: state.snapshot!,
                  session: state,
                ),
              ],
            ),
    );
  }
}

class RoomStartAction extends ConsumerStatefulWidget {
  const RoomStartAction({required this.snapshot, this.session, super.key});
  final SnapshotMessage snapshot;
  final RoomSessionState? session;
  @override
  ConsumerState<RoomStartAction> createState() => _RoomStartActionState();
}

class _RoomStartActionState extends ConsumerState<RoomStartAction> {
  bool _pending = false;
  @override
  void didUpdateWidget(RoomStartAction oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.snapshot.revision != widget.snapshot.revision) {
      _pending = false;
    }
    if (oldWidget.session != widget.session &&
        widget.session?.errorCode != null) {
      _pending = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(roomSessionProvider, (_, next) {
      if (next.asData?.value.errorCode != null && mounted && _pending) {
        setState(() => _pending = false);
      }
    });
    final view = widget.snapshot;
    if (view.public.phase != 'lobby' || view.you != view.public.hostId) {
      return const SizedBox.shrink();
    }
    final editor = ref.watch(onlineProfileProvider);
    return ListenableBuilder(
      listenable: editor,
      builder: (context, _) => FilledButton(
        onPressed:
            !_pending &&
                view.public.players.length >= 3 &&
                !editor.dirty &&
                !editor.saving
            ? () {
                if (_pending) return;
                final controller = ref.read(roomControllerProvider),
                    latest = ref.read(roomControllerProvider).state.snapshot;
                if (latest == null ||
                    latest.public.phase != 'lobby' ||
                    latest.you != latest.public.hostId) {
                  return;
                }
                if (controller.sendAction(
                  StartGameMessage.create(
                    actionId: ActionId(newRoomRequestId()),
                    expectedRevision: latest.revision,
                  ),
                )) {
                  setState(() => _pending = true);
                }
              }
            : null,
        child: const TText('startHearing'),
      ),
    );
  }
}
