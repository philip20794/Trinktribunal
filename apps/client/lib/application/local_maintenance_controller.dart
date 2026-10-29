import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'local_data_providers.dart';

enum LocalDeletion { profile, games }

class LocalMaintenanceState {
  const LocalMaintenanceState({this.busy = false, this.feedback});
  final bool busy;
  final String? feedback;
}

final localMaintenanceProvider =
    NotifierProvider<LocalMaintenanceController, LocalMaintenanceState>(
      LocalMaintenanceController.new,
    );

/// App-scoped operation: leaving the settings widget cannot drop its completion.
class LocalMaintenanceController extends Notifier<LocalMaintenanceState> {
  bool _disposed = false;
  @override
  LocalMaintenanceState build() {
    ref.onDispose(() => _disposed = true);
    return const LocalMaintenanceState();
  }

  Future<bool> delete(LocalDeletion target) async {
    if (state.busy) return false;
    state = const LocalMaintenanceState(busy: true);
    var deleted = false;
    try {
      switch (target) {
        case LocalDeletion.profile:
          final profile = await ref.read(profileProvider.future);
          deleted = await profile.delete();
          if (!_disposed && deleted) ref.invalidate(profileProvider);
        case LocalDeletion.games:
          await ref.read(localResumeProvider.future);
          if (_disposed) return false;
          deleted = await ref.read(localStateTransactionProvider).deleteGames();
      }
    } on Object {
      deleted = false;
    }
    if (!_disposed) {
      state = LocalMaintenanceState(
        feedback: deleted
            ? target == LocalDeletion.profile
                  ? 'maintenanceProfileDeleted'
                  : 'maintenanceGamesDeleted'
            : 'maintenanceFailed',
      );
    }
    return deleted;
  }

  Future<bool> resetGame({required bool cardMode}) async {
    if (state.busy) return false;
    state = const LocalMaintenanceState(busy: true);
    var success = false;
    try {
      await ref.read(localResumeProvider.future);
      if (_disposed) return false;
      success = await ref
          .read(localStateTransactionProvider)
          .resetGame(cardMode: cardMode);
    } on Object {
      success = false;
    }
    if (!_disposed) {
      state = LocalMaintenanceState(
        feedback: success ? null : 'maintenanceFailed',
      );
    }
    return success;
  }
}
