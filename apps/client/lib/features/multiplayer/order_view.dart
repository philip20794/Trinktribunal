import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/room_providers.dart';
import '../../data/protocol/room_message.dart';
import '../../domain/avatar_config.dart';
import '../../domain/models/player.dart';
import '../../domain/models/ids.dart';
import '../../domain/user_profile.dart';
import '../../l10n/app_strings.dart';
import '../bench/bench_view.dart';
import '../bench/placement_bank.dart';

class OnlineOrderView extends ConsumerWidget {
  const OnlineOrderView({
    required this.snapshot,
    this.showActions = true,
    super.key,
  });
  final SnapshotMessage snapshot;
  final bool showActions;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.watch(onlineOrderProvider), view = snapshot.public;
    final ownsOrder =
        view.frozenRoster.contains(snapshot.you) &&
        (view.config.allJudges || snapshot.you == view.judgeId);
    final profiles = {
      for (final player in view.players)
        player.playerId: UserProfile(
          player: Player(id: player.playerId, name: player.profile.name),
          avatar: AvatarConfig.fromJson(player.profile.avatar.toJson()),
        ),
    };
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final order = ownsOrder
            ? snapshot.private.ownOrder ?? controller.order
            : view.judgeOrder ??
                  view.frozenRoster
                      .where(
                        (id) => view.config.allJudges || id != view.judgeId,
                      )
                      .toList();
        final revealed = {
          for (final entry in view.revealed) entry.playerId: entry.number,
        };
        // A position is known only after every number is public. Never infer
        // unrevealed numbers or another participant's private order.
        final truth = revealed.keys.toList()
          ..sort((a, b) => revealed[a]!.compareTo(revealed[b]!));
        final pending = <PlayerId>{
          if (view.config.allJudges &&
              ['numbers', 'answers', 'ordering'].contains(view.phase))
            for (final player in view.players)
              if (view.frozenRoster.contains(player.playerId) &&
                  !player.orderSubmitted)
                player.playerId,
        };
        if (order.any((id) => !profiles.containsKey(id))) {
          return const TText('onlineOrderMissing');
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!ownsOrder && !view.config.allJudges)
              TText(
                view.players.any(
                      (player) =>
                          player.playerId == view.judgeId &&
                          player.orderSubmitted,
                    )
                    ? 'onlineJudgeOrderConfirmed'
                    : 'onlineOrderWaiting',
              ),
            if (controller.pending) const TText('onlineOrderSending'),
            if (!view.config.allJudges && ownsOrder && controller.confirmed)
              const TText('onlineOrderConfirmed'),
            if (view.config.allJudges &&
                ['numbers', 'answers', 'ordering'].contains(view.phase) &&
                ownsOrder &&
                !controller.confirmed)
              PlacementBank(
                pending: pending,
                slots: controller.slots,
                unplaced: controller.unplaced,
                profiles: profiles,
                onPlace: controller.canEdit ? controller.place : null,
                onRemove: controller.unplace,
              )
            else
              BenchView(
                pending: pending,
                order: order,
                profiles: profiles,
                revealedNumbers: {
                  for (final entry in view.revealed)
                    entry.playerId: entry.number,
                },
                showPositionResult:
                    view.phase == 'judged' &&
                    (!view.config.allJudges ||
                        ownsOrder && snapshot.private.ownOrder != null),
                incorrect: {
                  if (view.phase == 'judged' &&
                      view.config.allJudges &&
                      ownsOrder)
                    for (var i = 0; i < order.length; i++)
                      if (i < truth.length && order[i] != truth[i]) order[i],
                  if (view.phase == 'judged' && view.result != null)
                    for (final penalty in view.result!.penalties)
                      if (penalty.sips > 0 && penalty.playerId != view.judgeId)
                        penalty.playerId,
                },
                onMove: ownsOrder && controller.canEdit
                    ? controller.move
                    : null,
              ),
            if (showActions) OnlineOrderAction(snapshot: snapshot),
          ],
        );
      },
    );
  }
}

class OnlineOrderAction extends ConsumerWidget {
  const OnlineOrderAction({required this.snapshot, super.key});
  final SnapshotMessage snapshot;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.watch(onlineOrderProvider), view = snapshot.public;
    final ownsOrder =
        view.frozenRoster.contains(snapshot.you) &&
        (view.config.allJudges || snapshot.you == view.judgeId);
    if (!ownsOrder || view.phase != 'ordering') return const SizedBox.shrink();
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) =>
          view.config.allJudges &&
              (!controller.complete || controller.confirmed)
          ? const SizedBox.shrink()
          : FilledButton(
              onPressed:
                  controller.canEdit &&
                      (!view.config.allJudges || controller.complete)
                  ? () async {
                      final gameId = view.gameId, roundId = view.roundId;
                      if (gameId == null || roundId == null) return;
                      ref.read(onlineGameProvider).hideSecret();
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const TText('confirmOrderTitle'),
                          content: const TText('confirmOrderHelp'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const TText('cancel'),
                            ),
                            FilledButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: const TText('phoneConfirmOrder'),
                            ),
                          ],
                        ),
                      );
                      if (context.mounted && confirmed == true) {
                        controller.confirm(
                          gameId: gameId,
                          roundId: roundId,
                          confirmed: true,
                        );
                      }
                    }
                  : null,
              child: const TText('phoneConfirmOrder'),
            ),
    );
  }
}
