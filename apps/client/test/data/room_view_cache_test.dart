import 'package:flutter_test/flutter_test.dart';
import 'package:trinktribunal/data/protocol/room_message.dart';

import 'room_test_support.dart';

void main() {
  test('immutable room views reuse nested objects and collections on repeated reads', () {
    final snapshot = roomFixture('snapshot') as SnapshotMessage;
    expect(snapshot.public, same(snapshot.public));
    final view = snapshot.public;
    expect(view.players, same(view.players));
    expect(view.frozenRoster, same(view.frozenRoster));
    expect(view.config, same(view.config));
    expect(view.players.first.profile, same(view.players.first.profile));
    final avatar = view.players.first.profile.avatar;
    expect(avatar.selections, same(avatar.selections));
    expect(() => view.players.clear(), throwsUnsupportedError);
    expect(() => avatar.selections.clear(), throwsUnsupportedError);
    final name = view.players.first.profile.name;
    final json = snapshot.toJson();
    ((((json['public'] as Map)['players'] as List).first as Map)['profile']
            as Map)['name'] =
        'Changed copy';
    expect(view.players.first.profile.name, name);
  });

  test(
    'cached private values stay scoped to one snapshot and one recipient',
    () {
      final base = roomFixture('snapshot') as SnapshotMessage;
      final originalNumber = base.private.ownNumber;
      final next = SnapshotMessage.fromJson({
        ...base.toJson(),
        'revision': base.revision + 1,
        'private': <String, Object?>{},
      });
      final other = SnapshotMessage.fromJson({
        ...base.toJson(),
        'you': base.public.players.last.playerId.value,
        'private': {'ownNumber': 42},
      });
      expect(next.private, isNot(same(base.private)));
      expect(next.private.ownNumber, isNull);
      expect(other.private, isNot(same(base.private)));
      expect(other.private.ownNumber, 42);
      expect(base.private.ownNumber, originalNumber);
    },
  );
}
