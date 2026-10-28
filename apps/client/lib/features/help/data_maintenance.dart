import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/local_maintenance_controller.dart';
import '../../design/court_scene.dart';
import '../../design/status_notice.dart';
import '../../l10n/app_strings.dart';
import '../setup/player_roster.dart';

class DataMaintenance extends ConsumerStatefulWidget {
  const DataMaintenance({super.key});
  @override
  ConsumerState<DataMaintenance> createState() => _DataMaintenanceState();
}

class _DataMaintenanceState extends ConsumerState<DataMaintenance> {
  bool _dialogOpen = false;
  Future<void> _delete(LocalDeletion target) async {
    if (_dialogOpen || ref.read(localMaintenanceProvider).busy) return;
    setState(() => _dialogOpen = true);
    bool? confirmed;
    try {
      confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          scrollable: true,
          title: TText(
            target == LocalDeletion.profile
                ? 'maintenanceProfile'
                : 'maintenanceGames',
          ),
          content: TText(
            target == LocalDeletion.profile
                ? 'maintenanceProfileConfirm'
                : 'maintenanceGamesConfirm',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const TText('cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const TText('maintenanceDelete'),
            ),
          ],
        ),
      );
    } finally {
      if (mounted) setState(() => _dialogOpen = false);
    }
    if (!mounted || confirmed != true) return;
    await ref.read(localMaintenanceProvider.notifier).delete(target);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(localMaintenanceProvider);
    return CourtPaper(
      padding: const EdgeInsets.all(16),
      child: Builder(
        builder: (context) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TText(
              'maintenanceTitle',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            const TText('maintenanceHelp'),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: state.busy || _dialogOpen
                  ? null
                  : () => _delete(LocalDeletion.profile),
              child: const TText('maintenanceProfile'),
            ),
            OutlinedButton(
              onPressed: state.busy || _dialogOpen
                  ? null
                  : () => _delete(LocalDeletion.games),
              child: const TText('maintenanceGames'),
            ),
            TextButton(
              onPressed: state.busy
                  ? null
                  : () => Navigator.push<void>(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            const PlayerRosterScreen(allowStart: false),
                      ),
                    ),
              child: const TText('maintenancePeople'),
            ),
            if (state.busy) const LinearProgressIndicator(),
            if (state.feedback case final String key)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: StatusNotice(context.tr(key)),
              ),
          ],
        ),
      ),
    );
  }
}
