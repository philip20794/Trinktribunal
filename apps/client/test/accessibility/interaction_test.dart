import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trinktribunal/application/local_data_providers.dart';
import 'package:trinktribunal/application/settings_controller.dart';
import 'package:trinktribunal/features/settings/settings_screen.dart';
import 'package:trinktribunal/design/private_number.dart';
import 'package:trinktribunal/design/status_notice.dart';
import 'package:trinktribunal/domain/avatar_config.dart';
import 'package:trinktribunal/domain/bench_order.dart';
import 'package:trinktribunal/domain/models/ids.dart';
import 'package:trinktribunal/domain/models/player.dart';
import 'package:trinktribunal/domain/user_profile.dart';
import 'package:trinktribunal/features/bench/bench_view.dart';
import 'package:trinktribunal/features/multiplayer/invitation.dart';
import 'package:trinktribunal/features/multiplayer/join.dart';
import 'package:trinktribunal/l10n/app_strings.dart';
import 'package:trinktribunal/data/protocol/room_message.dart';

import '../data/room_test_support.dart';
import '../support/memory_string_store.dart';
import '../features/online_order_test.dart' as online;
import 'screen_matrix_test.dart' show accessibilityHost;

void main() {
  testWidgets(
    'Escape cancels order confirmation and restores the keyboard trigger without a frame',
    (tester) async {
      final socket = await online.pump(tester);
      final trigger = find.text(AppStrings('de').get('phoneConfirmOrder'));
      await tester.ensureVisible(trigger);
      await tester.pumpAndSettle();
      final focus = Focus.of(tester.element(trigger));
      focus.requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(focus.hasFocus, isTrue);
      expect(socket.sent.whereType<SubmitOrderMessage>(), isEmpty);
    },
  );
  testWidgets(
    'settings load failure announces safe feedback and retry recovers',
    (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        var attempts = 0;
        await tester.pumpWidget(
          accessibilityHost(
            ProviderScope(
              overrides: [
                settingsProvider.overrideWith((ref) async {
                  if (++attempts == 1) {
                    throw StateError('PRIVATE_STORAGE_MARKER');
                  }
                  final controller = SettingsController(MemoryStringStore());
                  ref.onDispose(controller.dispose);
                  await controller.load();
                  return controller;
                }),
              ],
              child: const SettingsScreen(),
            ),
            language: 'en',
          ),
        );
        await tester.pumpAndSettle();
        expect(find.textContaining('PRIVATE_STORAGE_MARKER'), findsNothing);
        expect(find.byType(CircularProgressIndicator), findsNothing);
        expect(
          tester.getSemantics(find.byType(StatusNotice)),
          matchesSemantics(
            label: AppStrings('en').get('settingsLoadFailed'),
            isLiveRegion: true,
          ),
        );
        await tester.tap(find.text('Try again'));
        await tester.pumpAndSettle();
        expect(attempts, 2);
        expect(
          find.text(AppStrings('en').get('generalSettings')),
          findsOneWidget,
        );
        expect(find.byType(StatusNotice), findsNothing);
      } finally {
        semantics.dispose();
      }
    },
  );
  for (final confirm in [false, true]) {
    testWidgets(
      'private number keyboard focus and hidden semantics, confirmation=$confirm',
      (tester) async {
        final semantics = tester.ensureSemantics();
        try {
          int? number;
          await tester.pumpWidget(
            accessibilityHost(
              Scaffold(
                body: StatefulBuilder(
                  builder: (context, update) => PrivateNumber(
                    number: number,
                    onReveal: () => update(() => number = 23),
                    onHide: () => update(() => number = null),
                    onConfirm: confirm
                        ? () => update(() => number = null)
                        : null,
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.bySemanticsLabel(RegExp('23')), findsNothing);
          tester
              .widget<FilledButton>(find.byType(FilledButton).first)
              .focusNode!
              .requestFocus();
          await tester.pump();
          await tester.sendKeyEvent(LogicalKeyboardKey.space);
          await tester.pumpAndSettle();
          expect(find.text('23'), findsOneWidget);
          expect(find.bySemanticsLabel(RegExp('23')), findsOneWidget);
          expect(
            FocusManager.instance.primaryFocus!.debugLabel,
            confirm ? 'confirm-private-number' : 'hide-private-number',
          );
          await tester.sendKeyEvent(LogicalKeyboardKey.space);
          await tester.pumpAndSettle();
          expect(find.text('23'), findsNothing);
          expect(find.bySemanticsLabel(RegExp('23')), findsNothing);
          expect(
            FocusManager.instance.primaryFocus!.debugLabel,
            'reveal-private-number',
          );
        } finally {
          semantics.dispose();
        }
      },
    );
  }

  testWidgets(
    'Alt arrows reorder across bank rows while focus follows the same person',
    (tester) async {
      var order = [PlayerId('a'), PlayerId('b'), PlayerId('c')];
      final profiles = {
        for (final entry in {
          order[0]: 'Alex',
          order[1]: 'Bea',
          order[2]: 'Cleo',
        }.entries)
          entry.key: UserProfile(
            player: Player(id: entry.key, name: entry.value),
            avatar: AvatarConfig(),
          ),
      };
      await tester.pumpWidget(
        accessibilityHost(
          Scaffold(
            body: StatefulBuilder(
              builder: (context, update) => BenchView(
                order: order,
                profiles: profiles,
                onMove: (from, to) =>
                    update(() => order = insertPlayer(order, from, to)),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final target = find.ancestor(
        of: find.textContaining('Alex'),
        matching: find.byType(DragTarget<PlayerId>),
      );
      final focus = find
          .descendant(
            of: target,
            matching: find.byWidgetPredicate(
              (widget) => widget is Focus && widget.onKeyEvent != null,
            ),
          )
          .first;
      tester.widget<Focus>(focus).focusNode!.requestFocus();
      await tester.pump();
      for (var position = 1; position <= 2; position++) {
        await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
        await tester.pumpAndSettle();
        expect(order[position], PlayerId('a'));
        expect(
          FocusManager.instance.primaryFocus!.context!
              .findAncestorWidgetOfExactType<DragTarget<PlayerId>>(),
          same(tester.widget<DragTarget<PlayerId>>(target)),
        );
        expect(tester.takeException(), isNull);
      }
    },
  );

  testWidgets(
    'join form supports Next/Done and focuses invalid fields without a network request',
    (tester) async {
      final transport = FakeRoomTransport()..entryError = 'RATE_LIMITED';
      await tester.pumpWidget(
        accessibilityHost(const JoinRoomScreen(), transport: transport),
      );
      await tester.pumpAndSettle();
      final name = find.byKey(const ValueKey('room-name')),
          code = find.byKey(const ValueKey('room-code'));
      await tester.ensureVisible(name);
      await tester.tap(name);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(name).focusNode!.hasFocus, isTrue);
      expect(transport.joins, 0);
      await tester.enterText(name, 'Alex');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(code).focusNode!.hasFocus, isTrue);
      await tester.enterText(code, 'ABCD2345');
      await tester.testTextInput.receiveAction(TextInputAction.next);
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(name).focusNode!.hasFocus, isTrue);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(transport.joins, 1);
      expect(find.text(AppStrings('de').get('roomErrorRate')), findsOneWidget);
    },
  );

  for (final language in ['de', 'en']) {
    for (final code in [
      'CATALOG_MISMATCH',
      'NETWORK_UNAVAILABLE',
      'CREDENTIAL_STORAGE_UNAVAILABLE',
      'RATE_LIMITED',
      'ROOM_UNAVAILABLE',
      'UNAUTHORIZED_ACTION',
      'INVALID_MESSAGE',
    ]) {
      testWidgets(
        '$code is localized, announced and retryable in $language at 200 percent',
        (tester) async {
          await tester.binding.setSurfaceSize(const Size(360, 800));
          addTearDown(() => tester.binding.setSurfaceSize(null));
          final semantics = tester.ensureSemantics();
          try {
            final transport = FakeRoomTransport()..entryError = code;
            await tester.pumpWidget(
              accessibilityHost(
                const JoinRoomScreen(initialCode: 'ABCD2345'),
                language: language,
                transport: transport,
              ),
            );
            await tester.pumpAndSettle();
            await tester.enterText(
              find.byKey(const ValueKey('room-name')),
              'Alex',
            );
            final submit = find.byKey(const ValueKey('room-submit'));
            await tester.ensureVisible(submit);
            await tester.tap(submit);
            await tester.pumpAndSettle();
            final message = AppStrings(language).get(roomErrorKey(code));
            expect(find.text(message), findsOneWidget);
            final notice = find.byType(StatusNotice);
            await tester.ensureVisible(notice);
            await tester.pumpAndSettle();
            expect(
              tester.getSemantics(notice),
              matchesSemantics(label: message, isLiveRegion: true),
            );
            expect(tester.widget<FilledButton>(submit).onPressed, isNotNull);
            expect(
              find.textContaining('private-platform-detail'),
              findsNothing,
            );
            expect(tester.takeException(), isNull);
          } finally {
            semantics.dispose();
          }
        },
      );
    }
  }
}
