import 'package:flutter_test/flutter_test.dart';
import 'package:trinktribunal/data/offline_policy.dart';
import 'package:trinktribunal/data/offline_status_stub.dart';
import 'package:trinktribunal/domain/models/game_mode.dart';

void main() {
  test(
    'every running or paused local phase prevents replacing offline assets',
    () {
      for (final phase in GamePhase.values.where(
        (p) => p != GamePhase.finished,
      )) {
        expect(
          canReplaceOfflineVersion(phase, null),
          isFalse,
          reason: '$phase',
        );
        expect(canReplaceOfflineVersion(GamePhase.finished, phase), isFalse);
      }
      expect(canReplaceOfflineVersion(null, null), isTrue);
      expect(
        canReplaceOfflineVersion(GamePhase.finished, GamePhase.finished),
        isTrue,
      );
    },
  );
  test('native platforms do not promise a web cache', () async {
    expect(await offlineAction('prepare'), {'state': 'unavailable'});
  });
}
