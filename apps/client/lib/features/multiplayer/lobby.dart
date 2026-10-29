import '../../design/status_notice.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/room_controller.dart';
import '../../data/protocol/room_message.dart';
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
import 'game_settings.dart';
import 'case_tab.dart';
import '../verdict/online_reveal.dart';
import '../rules/game_rules_screen.dart';

class RoomLobbyScreen extends ConsumerWidget {
  const RoomLobbyScreen({required this.state, super.key});
  final RoomSessionState state;
  @override
  Widget build(BuildContext context, WidgetRef ref) => DefaultTabController(
    length: 3,
    initialIndex:
        [
          'lobby',
          'ordering',
          'revealing',
        ].contains(state.snapshot!.public.phase)
        ? 1
        : 2,
    child: _CaseTabSync(
      snapshot: state.snapshot!,
      child: RoomGamePrivacy(
        child: CourtScaffold(
          title: const TText('roomTitle'),
          footer: _RoomPhaseFooter(state: state),
          actions: [
            RoomSkipMenu(snapshot: state.snapshot!),
            GameRulesButton(
              beforeOpen: ref.read(onlineGameProvider).hideSecret,
            ),
            if (state.snapshot!.you == state.snapshot!.public.hostId)
              IconButton(
                tooltip: context.tr('roomClose'),
                icon: const Icon(Icons.gavel),
                onPressed: () => confirmRoomClose(context, ref),
              ),
            if (state.snapshot!.public.phase != 'lobby')
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
                      content: SizedBox(
                        width: 360,
                        child: RoomInvite(code: code),
                      ),
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
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            onTap: (_) {
              ref.read(onlineGameProvider).hideSecret();
              ref.read(onlineProfileProvider).flush();
            },
            tabs: [
              Tab(text: context.tr('roomMeTab')),
              Tab(text: context.tr('roomTitle')),
              Tab(text: context.tr('caseTabTitle')),
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
                  child: StatusNotice(
                    context.tr(roomErrorKey(state.errorCode)),
                  ),
                ),
              Expanded(
                child: TabBarView(
                  children: [
                    const RoomMe(),
                    RoomCourtroom(
                      snapshot: state.snapshot!,
                      fixedActions: true,
                    ),
                    RoomCaseTab(snapshot: state.snapshot!),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _CaseTabSync extends StatefulWidget {
  const _CaseTabSync({required this.snapshot, required this.child});
  final SnapshotMessage snapshot;
  final Widget child;
  @override
  State<_CaseTabSync> createState() => _CaseTabSyncState();
}

class _CaseTabSyncState extends State<_CaseTabSync> {
  @override
  void didUpdateWidget(_CaseTabSync oldWidget) {
    super.didUpdateWidget(oldWidget);
    final old = oldWidget.snapshot.public, next = widget.snapshot.public;
    final oldGuide = old.config.allJudges ? old.readerId : old.judgeId;
    final nextGuide = next.config.allJudges ? next.readerId : next.judgeId;
    final newCase =
        next.gameId != null &&
        (old.gameId != next.gameId ||
            old.completedCases != next.completedCases ||
            oldGuide != nextGuide ||
            old.phase == 'rule_event' && next.phase != 'rule_event');
    final target = newCase || old.phase != next.phase && next.phase == 'judged'
        ? 2
        : old.phase != next.phase && next.phase == 'ordering'
        ? 1
        : null;
    if (target != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) DefaultTabController.of(context).animateTo(target);
      });
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _RoomPhaseFooter extends ConsumerWidget {
  const _RoomPhaseFooter({required this.state});
  final RoomSessionState state;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tabs = DefaultTabController.of(context),
        snapshot = state.snapshot!,
        view = state.snapshot!.public;
    final host = snapshot.you == view.hostId;
    return AnimatedBuilder(
      animation: tabs,
      builder: (context, _) {
        if (tabs.index == 0) return const SizedBox.shrink();
        final guide = ref.read(onlineGameProvider).canGuideRound;
        if (tabs.index == 2 && view.phase == 'ordering') {
          return CourtActionBar(
            primary: FilledButton.icon(
              onPressed: () => tabs.animateTo(1),
              icon: const Icon(Icons.sort),
              label: const TText('goToCourtroom'),
            ),
          );
        }
        final Widget? action = switch (view.phase) {
          'lobby' when host => RoomStartAction(
            snapshot: snapshot,
            session: state,
          ),
          'answers' when guide || view.frozenRoster.contains(snapshot.you) =>
            ReadinessActions(snapshot: snapshot),
          'ordering'
              when view.frozenRoster.contains(snapshot.you) &&
                  (view.config.allJudges || snapshot.you == view.judgeId) =>
            OnlineOrderAction(snapshot: snapshot),
          'revealing' when guide => OnlineRevealAction(snapshot: snapshot),
          'judged' ||
          'rule_event' ||
          'paused' when guide => OnlineProgressAction(snapshot: snapshot),
          _ => null,
        };
        return action == null
            ? const SizedBox.shrink()
            : CourtActionBar(primary: action);
      },
    );
  }
}
