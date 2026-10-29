import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:trinktribunal/data/catalogs/catalog_repository.dart';
import 'package:trinktribunal/data/catalogs/localized_catalog.dart';
import 'package:trinktribunal/data/protocol/room_message.dart';

import '../data/room_test_support.dart';

/// Opt-in CPU microbenchmarks, not device frame-rate or heap measurements.
void main() {
  test(
    'repeatable room projection and localized catalog CPU samples',
    () async {
      final base = roomFixture('snapshot') as SnapshotMessage;
      final snapshot = SnapshotMessage.fromJson({
        ...base.toJson(),
        'public': {
          ...base.public.toJson(),
          'players': [
            for (var i = 1; i <= 20; i++)
              {...base.public.players.first.toJson(), 'playerId': 'p$i'},
          ],
          'frozenRoster': [for (var i = 1; i <= 20; i++) 'p$i'],
        },
      });
      final catalogs = await CatalogRepository(
        read: (path) => File(path).readAsString(),
      ).load();
      final question = catalogs.questions['de']!.entries.last;
      int roomWork() {
        var checksum = 0;
        for (var i = 0; i < 2000; i++) {
          final view = snapshot.public;
          checksum += view.players.length + view.frozenRoster.length;
          for (final player in view.players) {
            checksum +=
                player.profile.name.length +
                player.profile.avatar.selections.length;
          }
        }
        return checksum;
      }

      int catalogWork() {
        var checksum = 0;
        for (var i = 0; i < 20000; i++) {
          checksum += localizedQuestion(catalogs, 'en', question).text.length;
        }
        return checksum;
      }

      final report = <String, Object>{};
      for (final entry in {
        'roomReads': roomWork,
        'catalogLookup': catalogWork,
      }.entries) {
        final checksum = entry.value();
        final samples = <int>[];
        for (var i = 0; i < 5; i++) {
          final watch = Stopwatch()..start();
          expect(entry.value(), checksum);
          watch.stop();
          samples.add(watch.elapsedMicroseconds);
        }
        samples.sort();
        report[entry.key] = {
          'medianUs': samples[2],
          'samplesUs': samples,
          'checksum': checksum,
        };
      }
      // Printed only in this opt-in test. No player data or credentials.
      // ignore: avoid_print
      print('RUNTIME_BENCHMARK ${jsonEncode(report)}');
    },
    skip: !const bool.fromEnvironment('TT_MEASURE_PERFORMANCE'),
  );
}
