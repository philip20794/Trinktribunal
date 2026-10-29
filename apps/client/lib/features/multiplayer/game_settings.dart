import 'package:flutter/material.dart';
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
import 'pending_profile.dart';

class RoomGameSettings extends ConsumerWidget {
  const RoomGameSettings({required this.snapshot, this.session, super.key});
  final SnapshotMessage snapshot;
  final RoomSessionState? session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (snapshot.public.phase != 'lobby') return const TText('rosterFrozen');
    final settings = ref.watch(onlineSettingsProvider);
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) {
        final config = settings.config ?? snapshot.public.config;
        final enabled = settings.editable;
        Widget slider(
          String label,
          int value,
          int min,
          int max,
          String field,
        ) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(context.tr(label, {'count': value})),
            Slider(
              value: value.toDouble(),
              min: min.toDouble(),
              max: max.toDouble(),
              divisions: max - min,
              onChanged: enabled
                  ? (n) => settings.change(field, n.round())
                  : null,
              onChangeEnd: enabled ? (_) => settings.flush() : null,
            ),
          ],
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const TText('localCasesHelp'),
            slider('casesCount', config.targetCases, 1, 491, 'targetCases'),
            const TText('localRulesHelp'),
            slider(
              'rulesCount',
              config.requestedRuleEvents,
              0,
              25,
              'requestedRuleEvents',
            ),
            Text(
              context.tr('factor', {
                'value': (config.factorTenths / 10).toStringAsFixed(1),
              }),
            ),
            const TText('localFactorHelp'),
            Slider(
              value: config.factorTenths.toDouble(),
              min: 10,
              max: 30,
              divisions: 20,
              onChanged: enabled
                  ? (n) => settings.change('factorTenths', n.round())
                  : null,
              onChangeEnd: enabled ? (_) => settings.flush() : null,
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const TText('onlineAllJudges'),
              value: config.allJudges,
              onChanged: enabled
                  ? (value) => settings.change('allJudges', value)
                  : null,
            ),
            DropdownButtonFormField<String>(
              isExpanded: true,
              key: ValueKey('online-language-${config.contentLanguage}'),
              initialValue: config.contentLanguage,
              decoration: InputDecoration(
                labelText: context.tr('onlineContentLanguage'),
              ),
              items: const [
                DropdownMenuItem(value: 'de', child: Text('Deutsch')),
                DropdownMenuItem(value: 'en', child: Text('English')),
              ],
              onChanged: enabled
                  ? (value) {
                      if (value != null) {
                        settings.change('contentLanguage', value);
                      }
                    }
                  : null,
            ),
            const SizedBox(height: 12),
            if (settings.errorCode != null) ...[
              StatusNotice(context.tr(roomErrorKey(settings.errorCode))),
              TextButton(
                onPressed: settings.retry,
                child: const TText('retry'),
              ),
            ] else
              TText(
                settings.dirty || settings.saving
                    ? 'roomSettingsSaving'
                    : 'roomSettingsAutoSave',
              ),
          ],
        );
      },
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
    final settings = ref.watch(onlineSettingsProvider);
    final demos = ref.watch(demoPlayersProvider);
    final missingNames = view.public.players
        .where(
          (player) =>
              player.active != false && needsRoomName(player.profile.name),
        )
        .length;
    return ListenableBuilder(
      listenable: Listenable.merge([editor, settings, demos]),
      builder: (context, _) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (missingNames > 0)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: StatusNotice(
                context.tr('roomStartPendingNames', {'count': missingNames}),
              ),
            ),
          FilledButton(
            onPressed:
                !_pending &&
                    view.public.players.length >= 3 &&
                    !editor.dirty &&
                    !editor.saving &&
                    !settings.dirty &&
                    !settings.saving &&
                    !demos.adding
                ? () {
                    final controller = ref.read(roomControllerProvider);
                    final latest = controller.state.snapshot;
                    if (_pending ||
                        settings.dirty ||
                        settings.saving ||
                        demos.adding ||
                        latest == null ||
                        latest.public.phase != 'lobby' ||
                        latest.you != latest.public.hostId) {
                      return;
                    }
                    final incomplete = latest.public.players
                        .where(
                          (player) =>
                              player.active != false &&
                              needsRoomName(player.profile.name),
                        )
                        .length;
                    if (incomplete > 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            context.tr('roomStartPendingNames', {
                              'count': incomplete,
                            }),
                          ),
                        ),
                      );
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
        ],
      ),
    );
  }
}
