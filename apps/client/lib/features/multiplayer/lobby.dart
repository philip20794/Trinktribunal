import '../../design/status_notice.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/room_controller.dart';
import '../../application/room_providers.dart';
import '../../l10n/app_strings.dart';
import '../../design/court_scene.dart';
import 'courtroom.dart';
import 'me.dart';
import 'invite.dart';
import 'invitation.dart';
import 'room_actions.dart';
import 'game_privacy.dart';
import 'close_room.dart';
import 'readiness_view.dart';
import 'order_view.dart';
import 'game_progress.dart';
import '../verdict/online_reveal.dart';
import '../rules/game_rules_screen.dart';

class RoomLobbyScreen extends ConsumerWidget {
  const RoomLobbyScreen({required this.state, super.key});
  final RoomSessionState state;
  @override
  Widget build(BuildContext context, WidgetRef ref) => DefaultTabController(
    length: 2,
    initialIndex: 1,
    child: RoomGamePrivacy(
      child: CourtScaffold(
        title: const TText('roomTitle'),
        footer: _RoomPhaseFooter(state: state),
        actions: [
          GameRulesButton(beforeOpen: ref.read(onlineGameProvider).hideSecret),
          if (state.snapshot!.you == state.snapshot!.public.hostId)
            IconButton(
              tooltip: context.tr('roomClose'),
              icon: const Icon(Icons.gavel),
              onPressed: () => confirmRoomClose(context, ref),
            ),
          IconButton(
            tooltip: context.tr('roomInviteTitle'),
            icon: const Icon(Icons.qr_code),
            onPressed: () {
              ref.read(onlineGameProvider).hideSecret();
              final code = ref.read(roomControllerProvider).roomCode;
              if (code == null) return;
              showDialog<void>(
                context: context,
                builder: (_) => AlertDialog(
                  scrollable: true,
                  title: const TText('roomInviteTitle'),
                  content: SizedBox(width: 360, child: RoomInvite(code: code)),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const TText('back'),
                    ),
                  ],
                ),
              );
            },
          ),
          IconButton(
            tooltip: context.tr('roomLeave'),
            icon: const Icon(Icons.logout),
            onPressed: () {
              ref.read(onlineGameProvider).hideSecret();
              confirmRoomLeave(context, ref);
            },
          ),
        ],
        appBarBottom: TabBar(
          onTap: (_) {
            ref.read(onlineGameProvider).hideSecret();
            ref.read(onlineProfileProvider).flush();
          },
          tabs: [
            Tab(text: context.tr('roomMeTab')),
            Tab(text: context.tr('roomTitle')),
          ],
        ),
        bodyBuilder: (context) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: TText(
                'roomOnline',
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ),
            if (state.errorCode != null)
              Padding(
                padding: const EdgeInsets.all(12),
                child: StatusNotice(context.tr(roomErrorKey(state.errorCode))),
              ),
            Expanded(
              child: TabBarView(
                children: [
                  const RoomMe(),
                  RoomCourtroom(snapshot: state.snapshot!, fixedActions: true),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _RoomPhaseFooter extends StatelessWidget {
  const _RoomPhaseFooter({required this.state});
  final RoomSessionState state;
  @override
  Widget build(BuildContext context) {
    final tabs = DefaultTabController.of(context),
        snapshot = state.snapshot!,
        view = state.snapshot!.public;
    final host = snapshot.you == view.hostId;
    return AnimatedBuilder(
      animation: tabs,
      builder: (context, _) {
        if (tabs.index != 1) return const SizedBox.shrink();
        final Widget? action = switch (view.phase) {
          'answers' when host || view.frozenRoster.contains(snapshot.you) =>
            ReadinessActions(snapshot: snapshot),
          'ordering'
              when view.frozenRoster.contains(snapshot.you) &&
                  (view.config.allJudges || snapshot.you == view.judgeId) =>
            OnlineOrderAction(snapshot: snapshot),
          'revealing' when host => OnlineRevealAction(snapshot: snapshot),
          'judged' ||
          'rule_event' ||
          'paused' when host => OnlineProgressAction(snapshot: snapshot),
          _ => null,
        };
        return action == null
            ? const SizedBox.shrink()
            : CourtActionBar(primary: action);
      },
    );
  }
}
