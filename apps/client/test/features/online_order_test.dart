import '../support/action_text.dart';

import 'package:trinktribunal/design/court_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trinktribunal/application/room_controller.dart';
import 'package:trinktribunal/application/room_providers.dart';
import 'package:trinktribunal/data/protocol/room_message.dart';
import 'package:trinktribunal/data/room_credential_store.dart';
import 'package:trinktribunal/features/bench/bench_view.dart';
import 'package:trinktribunal/features/multiplayer/order_view.dart';
import 'package:trinktribunal/l10n/app_strings.dart';

import '../data/room_test_support.dart';
import '../application/online_order_controller_test.dart' show orderingView;

class _Surface extends ConsumerWidget {
  const _Surface();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final view =
        ref.watch(roomSessionProvider).asData?.value.snapshot ??
        ref.read(roomControllerProvider).state.snapshot;
    return Scaffold(
      body: SingleChildScrollView(
        child: view == null
            ? const SizedBox()
            : OnlineOrderView(snapshot: view),
      ),
    );
  }
}

Future<FakeRoomSocket> pump(
  WidgetTester tester, {
  bool judge = true,
  SnapshotMessage? snapshot,
}) async {
  final transport = FakeRoomTransport(),
      store = RoomCredentialStore(MemoryCredentialBackend()),
      room = RoomController(transport: transport, credentials: store);
  addTearDown(room.dispose);
  await room.resume(testCredential());
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        roomControllerProvider.overrideWithValue(room),
        roomCredentialStoreProvider.overrideWithValue(store),
      ],
      child: MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        ),
        home: const _Surface(),
      ),
    ),
  );
  final socket = transport.sockets.single;
  socket.receive(roomFixture('authenticated'));
  socket.receive(snapshot ?? orderingView(judge: judge));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 350));
  return socket;
}

Future<void> tapText(WidgetTester tester, String text) async {
  final finder = actionText(text);
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'judge stays outside the editable bank; cancel sends nothing, confirm sends one order',
    (tester) async {
      final socket = await pump(tester),
          bank = tester.widget<BenchView>(find.byType(BenchView));
      expect(bank.order.map((id) => id.value), ['p1', 'p3', 'p4']);
      expect(bank.onMove, isNotNull);
      bank.onMove!(0, 2);
      await tester.pumpAndSettle();
      expect(socket.sent.whereType<SubmitOrderMessage>(), isEmpty);
      final confirm = AppStrings('de').get('phoneConfirmOrder');
      await tapText(tester, confirm);
      await tester.tap(find.byKey(const ValueKey('court-dialog-close')));
      await tester.pumpAndSettle();
      expect(socket.sent.whereType<SubmitOrderMessage>(), isEmpty);
      await tapText(tester, confirm);
      await tester.tap(
        find.descendant(
          of: find.byType(CourtDialog),
          matching: widgetWithActionText(FilledButton, confirm),
        ),
      );
      await tester.pumpAndSettle();
      final sent = socket.sent.whereType<SubmitOrderMessage>().single;
      expect(sent.order.map((id) => id.value), ['p3', 'p4', 'p1']);
      expect(tester.widget<BenchView>(find.byType(BenchView)).onMove, isNull);
      socket.receive(
        orderingView(
          phase: 'revealing',
          revision: 2,
          ownOrder: ['p3', 'p4', 'p1'],
        ),
      );
      await tester.pumpAndSettle();
      expect(
        actionText(AppStrings('de').get('onlineOrderConfirmed')),
        findsNothing,
      );
      expect(tester.widget<BenchView>(find.byType(BenchView)).onMove, isNull);
    },
  );
  testWidgets(
    'host without judge role sees only a read-only bank and waiting status',
    (tester) async {
      final socket = await pump(tester, judge: false),
          bank = tester.widget<BenchView>(find.byType(BenchView));
      expect(bank.onMove, isNull);
      expect(bank.order.map((id) => id.value), ['p2', 'p3', 'p4']);
      expect(
        actionText(AppStrings('de').get('phoneConfirmOrder')),
        findsNothing,
      );
      expect(socket.sent.whereType<SubmitOrderMessage>(), isEmpty);
    },
  );
}
