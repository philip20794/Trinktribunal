import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/game_parity.dart';

void main() {
  for (final c in loadParity()) {
    test('shared selection: ${c['id']}', () => verifyParity(c));
  }
  test('changed fixture expectation is rejected by actual Dart algorithm', () {
    final c = loadParity().first;
    c['expected'] = {'invalid': true};
    expect(() => verifyParity(c), throwsStateError);
  });
  test('existing TT-003 person binding fixture is executed by Dart', () {
    final fixture = jsonDecode(
      File('../../packages/protocol/fixtures/rules/person-binding.json')
          .readAsStringSync(),
    ) as Map<String, dynamic>;
    final input = fixture['input'] as Map<String, dynamic>,
        expected = fixture['expected'] as Map<String, dynamic>;
    verifyParity({
      'id': fixture['fixtureId'],
      'operation': 'bind',
      'players': input['activePlayerIds'],
      'counts': input['countersBefore'],
      'roles': input['roles'],
      'indices': <int>[],
      'expected': {
        'bindings': expected['binding'],
        'counts': expected['countersAfter'],
      },
    });
  });
}
