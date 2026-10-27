import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/room_providers.dart';
import '../../data/protocol/room_message.dart';
import '../../domain/avatar_config.dart';
import '../../domain/models/player.dart';
import '../../domain/user_profile.dart';
import '../../l10n/app_strings.dart';
import '../bench/bench_view.dart';

class OnlineOrderView extends ConsumerWidget {
  const OnlineOrderView({required this.snapshot, super.key});
  final SnapshotMessage snapshot;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.watch(onlineOrderProvider), view = snapshot.public;
    final judge = snapshot.you == view.judgeId;
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
        final order = judge
            ? controller.order
            : view.judgeOrder ??
                  view.frozenRoster.where((id) => id != view.judgeId).toList();
        if (order.any((id) => !profiles.containsKey(id))) {
          return const TText('onlineOrderMissing');
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (judge && controller.canEdit) const TText('phoneOrderHelp'),
            if (!judge)
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
            if (judge && controller.confirmed)
              const TText('onlineOrderConfirmed'),
            BenchView(
              order: order,
              profiles: profiles,
              onMove: judge && controller.canEdit ? controller.move : null,
            ),
            if (judge && view.phase == 'ordering')
              FilledButton(
                onPressed: controller.canEdit
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
          ],
        );
      },
    );
  }
}
