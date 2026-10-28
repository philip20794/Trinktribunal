import 'package:flutter/material.dart';

import '../../data/protocol/room_message.dart';
import '../../l10n/app_strings.dart';

/// Server presence/revision only; no polling or local failover timer.
class OnlineHostStatus extends StatelessWidget {
  const OnlineHostStatus({required this.snapshot, super.key});
  final SnapshotMessage snapshot;
  @override
  Widget build(BuildContext context) {
    final view = snapshot.public,
        hosts = view.players.where((p) => p.playerId == view.hostId);
    if (hosts.isEmpty) return const SizedBox.shrink();
    final host = hosts.single;
    if (!host.connected) {
      return TText(
        view.pauseReason == 'host_unavailable'
            ? 'onlineHostWaiting'
            : 'onlineHostGrace',
      );
    }
    if (view.hostRevision > 0) {
      return Text(
        context.tr(
          snapshot.you == view.hostId ? 'onlineHostYou' : 'onlineHostChanged',
          {'name': host.profile.name},
        ),
      );
    }
    return const SizedBox.shrink();
  }
}
