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
import 'invitation.dart';
import 'game_privacy.dart';
import 'readiness_view.dart';
import 'order_view.dart';
import 'game_progress.dart';
import 'game_settings.dart';
import 'case_tab.dart';
import 'room_tools.dart';
import 'pending_profile.dart';
import '../../design/hold_action_button.dart';
import '../verdict/online_reveal.dart';
import '../rules/game_rules_screen.dart';

class RoomLobbyScreen extends ConsumerWidget {
  const RoomLobbyScreen({required this.state, this.newRoom = false, super.key});
  final bool newRoom;
  final RoomSessionState state;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshot = state.snapshot!;
    final requiresName = snapshot.public.players.any(
      (player) =>
          player.playerId == snapshot.you && needsRoomName(player.profile.name),
    );
    return DefaultTabController(
      key: ValueKey((
        state.snapshot!.public.config.allJudges,
        state.snapshot!.you == state.snapshot!.public.hostId,
      )),
      length:
          (state.snapshot!.public.config.allJudges ? 3 : 2) +
          (state.snapshot!.you == state.snapshot!.public.hostId ? 1 : 0),
      initialIndex: requiresName
          ? 0
          : state.snapshot!.public.phase == 'lobby'
          ? (state.snapshot!.you == state.snapshot!.public.hostId
                ? (state.snapshot!.public.config.allJudges ? 3 : 2)
                : 0)
          : (state.snapshot!.public.config.allJudges ? 2 : 1),
      child: Builder(
        builder: (tabContext) => _CaseTabSync(
          snapshot: state.snapshot!,
          child: RoomGamePrivacy(
            child: CourtScaffold(
              title: const TText('roomTitle'),
              footer: _RoomPhaseFooter(state: state),
              actions: [
                GameRulesButton(
                  beforeOpen: ref.read(onlineGameProvider).hideSecret,
                ),
              ],
              appBarBottom: TabBar(
                isScrollable: false,
                labelPadding: const EdgeInsets.symmetric(horizontal: 4),
                labelStyle: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
                onTap: (index) {
                  ref.read(onlineGameProvider).hideSecret();
                  ref.read(onlineProfileProvider).flush();
                  if (requiresName && index != 0) {
                    DefaultTabController.of(tabContext).animateTo(0);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: TText('roomNameRequired')),
                    );
                  }
                },
                tabs: [
                  Tab(
                    child: Text(
                      context.tr('roomMeTab'),
                      style: snapshot.public.phase == 'lobby'
                          ? null
                          : TextStyle(
                              color: CourtSceneTokens.cream.withValues(
                                alpha: .45,
                              ),
                            ),
                      maxLines: 2,
                      textAlign: TextAlign.center,
                    ),
                  ),
                  if (state.snapshot!.public.config.allJudges)
                    Tab(
                      child: Text(
                        context.tr('roomTitle'),
                        maxLines: 2,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  Tab(
                    child: Text(
                      context.tr('caseTabTitle'),
                      maxLines: 2,
                      textAlign: TextAlign.center,
                    ),
                  ),
                  if (state.snapshot!.you == state.snapshot!.public.hostId)
                    Tab(
                      child: Text(
                        context.tr('roomAdminTab'),
                        style: snapshot.public.phase == 'lobby'
                            ? null
                            : TextStyle(
                                color: CourtSceneTokens.cream.withValues(
                                  alpha: .45,
                                ),
                              ),
                        maxLines: 2,
                        textAlign: TextAlign.center,
                      ),
                    ),
                ],
              ),
              bodyBuilder: (context) => Column(
                children: [
                  if (state.errorCode != null)
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: StatusNotice(
                        context.tr(roomErrorKey(state.errorCode)),
                      ),
                    ),
                  Expanded(
                    child: _RoomTabPages(
                      requiresName: requiresName,
                      playing: snapshot.public.phase != 'lobby',
                      allJudges: snapshot.public.config.allJudges,
                      children: [
                        const RoomMe(),
                        if (state.snapshot!.public.config.allJudges)
                          Builder(
                            builder: (context) {
                              final tabs = DefaultTabController.of(context);
                              return AnimatedBuilder(
                                animation: tabs,
                                builder: (_, _) => RoomCourtroom(
                                  snapshot: state.snapshot!,
                                  active: tabs.index == 1,
                                  fixedActions: true,
                                ),
                              );
                            },
                          ),
                        RoomCaseTab(snapshot: state.snapshot!),
                        if (state.snapshot!.you ==
                            state.snapshot!.public.hostId)
                          ListView(
                            padding: const EdgeInsets.all(12),
                            children: [RoomTools(snapshot: state.snapshot!)],
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
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
    final wasPending = oldWidget.snapshot.public.players.any(
      (player) =>
          player.playerId == oldWidget.snapshot.you &&
          needsRoomName(player.profile.name),
    );
    final isPending = widget.snapshot.public.players.any(
      (player) =>
          player.playerId == widget.snapshot.you &&
          needsRoomName(player.profile.name),
    );
    final completedName = wasPending && !isPending && next.phase == 'lobby';
    final newCase =
        next.gameId != null &&
        (old.gameId != next.gameId ||
            old.roundId != next.roundId && next.phase == 'numbers' ||
            old.completedCases != next.completedCases ||
            oldGuide != nextGuide ||
            old.phase == 'rule_event' && next.phase != 'rule_event');
    final target = completedName && next.config.allJudges
        ? 1
        : next.config.allJudges &&
              old.phase != next.phase &&
              ['revealing', 'judged'].contains(next.phase)
        ? 1
        : newCase || old.phase != next.phase && next.phase == 'judged'
        ? (next.config.allJudges ? 2 : 1)
        : next.config.allJudges &&
              old.phase != next.phase &&
              next.phase == 'ordering'
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
        view = snapshot.public;
    final host = snapshot.you == view.hostId;
    final game = ref.watch(onlineGameProvider);
    return AnimatedBuilder(
      animation: Listenable.merge([tabs, game]),
      builder: (context, _) {
        final caseIndex = view.config.allJudges ? 2 : 1;
        if (host && tabs.index == caseIndex + 1) {
          return view.phase == 'lobby'
              ? CourtActionBar(
                  primary: RoomStartAction(snapshot: snapshot, session: state),
                )
              : const SizedBox.shrink();
        }
        if (tabs.index == 0) {
          final editor = ref.watch(onlineProfileProvider);
          return ListenableBuilder(
            listenable: editor,
            builder: (context, _) => CourtActionBar(
              primary: FilledButton(
                onPressed: editor.available && editor.dirty && !editor.saving
                    ? editor.flush
                    : null,
                child: TText(
                  editor.saving ? 'roomProfileSaving' : 'roomProfileFlush',
                ),
              ),
            ),
          );
        }
        final guide =
            snapshot.you ==
            (view.config.allJudges ? view.readerId : view.judgeId);
        Widget? action;
        if (tabs.index == caseIndex &&
            view.config.allJudges &&
            view.phase == 'ordering') {
          action = FilledButton.icon(
            onPressed: () => tabs.animateTo(1),
            icon: const Icon(Icons.sort),
            label: const TText('goToCourtroom'),
          );
        } else if (!view.config.allJudges &&
            guide &&
            [
              'numbers',
              'answers',
              'ordering',
              'revealing',
              'judged',
            ].contains(view.phase)) {
          action = OnlineNextCaseAction(snapshot: snapshot);
        } else {
          action = switch (view.phase) {
            'lobby' when host => RoomStartAction(
              snapshot: snapshot,
              session: state,
            ),
            'answers'
                when !view.config.allJudges &&
                    (guide || view.frozenRoster.contains(snapshot.you)) =>
              ReadinessActions(snapshot: snapshot),
            'ordering'
                when view.frozenRoster.contains(snapshot.you) &&
                    (view.config.allJudges || snapshot.you == view.judgeId) =>
              OnlineOrderAction(snapshot: snapshot),
            'revealing' when guide && !view.config.allJudges =>
              OnlineRevealAction(snapshot: snapshot),
            'judged' || 'rule_event' || 'paused'
                when guide &&
                    (!view.config.allJudges || tabs.index == caseIndex) =>
              OnlineProgressAction(snapshot: snapshot),
            _ => null,
          };
        }
        final showNumber =
            tabs.index == caseIndex &&
            snapshot.private.ownNumber != null &&
            !(view.config.allJudges && view.phase == 'judged');
        if (action == null && !showNumber) return const SizedBox.shrink();
        return CourtActionBar(
          primary: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (showNumber)
                Expanded(
                  child: HoldActionButton(
                    duration: const Duration(milliseconds: 600),
                    key: ValueKey(
                      'online-number-${snapshot.roomId}:${view.roundId}',
                    ),
                    icon: Icons.visibility_outlined,
                    label: context.tr('holdToReveal'),
                    onCompleted: game.revealOwnNumber,
                    onReleased: () {
                      if (!context.mounted) return;
                      if (game.snapshot?.public.roundId != view.roundId) return;
                      if (view.phase == 'numbers' &&
                          !game.acknowledged &&
                          !game.ackPending) {
                        game.acknowledgeNumber();
                      }
                      game.hideSecret();
                    },
                  ),
                ),
              if (showNumber && action != null) const SizedBox(width: 8),
              if (action != null) Expanded(child: action),
            ],
          ),
        );
      },
    );
  }
}

/// Only the two game pages participate in swiping during a running game.
class _RoomTabPages extends StatefulWidget {
  const _RoomTabPages({
    required this.requiresName,
    required this.playing,
    required this.allJudges,
    required this.children,
  });
  final bool requiresName, playing, allJudges;
  final List<Widget> children;
  @override
  State<_RoomTabPages> createState() => _RoomTabPagesState();
}

class _RoomTabPagesState extends State<_RoomTabPages> {
  double _drag = 0;
  @override
  Widget build(BuildContext context) {
    final pages = TabBarView(
      physics: widget.requiresName || widget.playing
          ? const NeverScrollableScrollPhysics()
          : null,
      children: widget.children,
    );
    if (!widget.playing || widget.requiresName || !widget.allJudges) {
      return pages;
    }
    return GestureDetector(
      onHorizontalDragStart: (_) => _drag = 0,
      onHorizontalDragUpdate: (details) => _drag += details.primaryDelta ?? 0,
      onHorizontalDragEnd: (details) {
        final tabs = DefaultTabController.of(context);
        final velocity = details.primaryVelocity ?? 0;
        if (_drag.abs() < 40 && velocity.abs() < 200) return;
        final left = velocity.abs() >= 200 ? velocity < 0 : _drag < 0;
        if (tabs.index == 1 && left) tabs.animateTo(2);
        if (tabs.index == 2 && !left) tabs.animateTo(1);
      },
      child: pages,
    );
  }
}
