import '../support/action_text.dart';

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trinktribunal/data/catalogs/catalog_repository.dart';
import 'package:trinktribunal/data/protocol/room_message.dart';
import 'package:trinktribunal/l10n/app_strings.dart';

import 'online_numbers_test.dart' as numbers;

SnapshotMessage boundary(
  SnapshotMessage base, {
  String phase = 'rule_event',
  int revision = 2,
  String? gameId,
}) => SnapshotMessage.fromJson({
  ...base.toJson(),
  'revision': revision,
  'public': {
    ...base.public.toJson(),
    'phase': phase,
    'gameId': gameId ?? base.public.gameId!.value,
    'roundId': null,
    'question': null,
    'frozenRoster': [],
    'completedCases': phase == 'finished' ? base.public.config.targetCases : 1,
    'activeRules': [
      {
        'contentId': numbers
            .catalogs
            .rules[base.public.config.contentLanguage]!
            .withoutPlayers
            .first
            .id,
        'bindings': <String, String>{},
      },
    ],
  },
  'private': <String, Object?>{},
});

void main() {
  setUpAll(() async {
    numbers.catalogs = await CatalogRepository(
      read: (path) => File(path).readAsString(),
    ).load();
  });

  testWidgets(
    'rule event uses host content language, continues once, and finished restart requires confirmation',
    (tester) async {
      final fixture = await numbers.pump(
            tester,
            host: true,
            own: false,
            contentLanguage: 'en',
          ),
          socket = fixture.transport.sockets.last,
          base = fixture.room.state.snapshot!;
      socket.receive(boundary(base));
      await tester.pumpAndSettle();
      final rule = numbers.catalogs.rules['en']!.withoutPlayers.first;
      expect(actionText(rule.text), findsOneWidget);
      expect(find.textContaining('{player'), findsNothing);
      await numbers.tapText(tester, AppStrings('de').get('ruleUnderstood'));
      expect(socket.sent.whereType<ContinueRuleMessage>().single.afterCase, 1);
      expect(fixture.room.state.snapshot!.public.phase, 'rule_event');
      final continueButton = tester.widget<FilledButton>(
        widgetWithActionText(
          FilledButton,
          AppStrings('de').get('ruleUnderstood'),
        ),
      );
      expect(continueButton.onPressed, isNull);
      socket.receive(boundary(base, phase: 'finished', revision: 3));
      await tester.pumpAndSettle();
      expect(actionText(AppStrings('de').get('endHearing')), findsOneWidget);
      await numbers.tapText(tester, AppStrings('de').get('restartGame'));
      await tester.tap(find.byKey(const ValueKey('court-dialog-close')));
      await tester.pumpAndSettle();
      expect(socket.sent.whereType<RestartGameMessage>(), isEmpty);
      await numbers.tapText(tester, AppStrings('de').get('restartGame'));
      await tester.tap(actionText(AppStrings('de').get('restartAction')));
      await tester.pumpAndSettle();
      final restart = socket.sent.whereType<RestartGameMessage>().single;
      expect(restart.confirmed, isTrue);
      expect(restart.gameId, base.public.gameId);
      expect(restart.expectedRevision, 3);
      expect(fixture.room.state.snapshot!.public.phase, 'finished');
    },
  );

  testWidgets(
    'restart dialog cannot target a later game and non-host has no progression controls',
    (tester) async {
      final fixture = await numbers.pump(tester, host: true, own: false),
          socket = fixture.transport.sockets.last,
          base = fixture.room.state.snapshot!;
      socket.receive(boundary(base, phase: 'finished'));
      await tester.pumpAndSettle();
      await numbers.tapText(tester, AppStrings('de').get('restartGame'));
      socket.receive(
        boundary(base, phase: 'finished', revision: 3, gameId: 'later_game'),
      );
      await tester.pumpAndSettle();
      await tester.tap(actionText(AppStrings('de').get('restartAction')));
      await tester.pumpAndSettle();
      expect(socket.sent.whereType<RestartGameMessage>(), isEmpty);
      final nonHost = boundary(base, revision: 4);
      socket.receive(
        SnapshotMessage.fromJson({
          ...nonHost.toJson(),
          'public': {
            ...nonHost.public.toJson(),
            'hostId': 'p2',
            'judgeId': 'p2',
          },
        }),
      );
      await tester.pumpAndSettle();
      expect(actionText(AppStrings('de').get('restartGame')), findsNothing);
      expect(actionText(AppStrings('de').get('ruleUnderstood')), findsNothing);
    },
  );

  testWidgets('judged case has a regular host completion scoped to its round', (
    tester,
  ) async {
    final fixture = await numbers.pump(tester, host: true, own: false),
        socket = fixture.transport.sockets.last,
        base = fixture.room.state.snapshot!;
    socket.receive(
      SnapshotMessage.fromJson({
        ...base.toJson(),
        'revision': 2,
        'public': {
          ...base.public.toJson(),
          'phase': 'judged',
          'judgeOrder': ['p2', 'p3'],
          'revealCursor': 2,
          'revealed': [
            {'playerId': 'p2', 'number': 2},
            {'playerId': 'p3', 'number': 3},
          ],
          'result': {
            'errors': 0,
            'penalties': [
              for (final id in ['p1', 'p2', 'p3']) {'playerId': id, 'sips': 0},
            ],
          },
        },
      }),
    );
    await tester.pumpAndSettle();
    await numbers.tapText(tester, AppStrings('de').get('nextJudge'));
    final completion = socket.sent.whereType<CompleteCaseMessage>().single;
    expect(completion.roundId, base.public.roundId);
    expect(completion.gameId, base.public.gameId);
    expect(completion.expectedRevision, 2);
    expect(
      fixture.room.state.snapshot!.public.completedCases,
      base.public.completedCases,
    );
  });
}
