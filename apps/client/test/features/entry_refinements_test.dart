import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:trinktribunal/features/multiplayer/join.dart';
import 'package:trinktribunal/features/multiplayer/invitation.dart';
import 'package:trinktribunal/design/hold_action_button.dart';
import 'package:trinktribunal/design/avatar_view.dart';
import 'package:trinktribunal/design/private_number.dart';
import 'package:trinktribunal/design/case_stage.dart';
import 'package:trinktribunal/design/case_file.dart';
import 'package:trinktribunal/design/illustrated_paper.dart';
import 'package:trinktribunal/application/roster_controller.dart';
import 'package:trinktribunal/domain/avatar_config.dart';
import 'package:trinktribunal/domain/user_profile.dart';
import 'package:trinktribunal/domain/models/player.dart';
import 'package:trinktribunal/domain/models/ids.dart';

import '../support/memory_string_store.dart';
import '../data/room_test_support.dart';
import '../accessibility/screen_matrix_test.dart' show accessibilityHost;

class _Camera extends MobileScannerPlatform {
  final frames = StreamController<BarcodeCapture?>.broadcast();
  int stops = 0, disposals = 0;
  @override
  Stream<BarcodeCapture?> get barcodesStream => frames.stream;
  @override
  Stream<TorchState> get torchStateStream => const Stream.empty();
  @override
  Stream<double> get zoomScaleStateStream => const Stream.empty();
  @override
  Widget buildCameraView() => const ColoredBox(
    key: ValueKey('embedded-camera-view'),
    color: Colors.black,
  );
  @override
  Future<MobileScannerViewAttributes> start(StartOptions options) async =>
      const MobileScannerViewAttributes(
        cameraDirection: CameraFacing.back,
        currentTorchMode: TorchState.off,
        size: Size(640, 480),
      );
  @override
  Future<void> stop() async {
    stops++;
  }

  @override
  Future<void> dispose() async {
    disposals++;
  }
}

void main() {
  testWidgets('new questions rest underneath the slowly receding old sheet', (
    tester,
  ) async {
    late StateSetter change;
    var question = 'Kurz';
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 600,
            child: StatefulBuilder(
              builder: (context, update) {
                change = update;
                return CaseStage(
                  rules: 0,
                  onRules: () {},
                  child: CourtQuestion(
                    animationKey: 'same-round',
                    label: 'Fall 1',
                    text: question,
                    green: 'Wenig',
                    connector: '',
                    red: 'Viel',
                    maximum: 5,
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final before = tester.getRect(find.byType(IllustratedPaper));
    change(
      () => question = List.filled(15, 'Eine laengere Fallfrage.').join(' '),
    );
    await tester.pump();
    final switcher = tester.widget<AnimatedSwitcher>(
      find.byType(AnimatedSwitcher),
    );
    expect(switcher.duration, const Duration(milliseconds: 650));
    expect(find.byType(IllustratedPaper), findsNWidgets(2));
    await tester.pump(const Duration(milliseconds: 325));
    expect(find.byType(IllustratedPaper), findsNWidgets(2));
    await tester.pumpAndSettle();
    expect(tester.getRect(find.byType(IllustratedPaper)), before);
  });
  test(
    'a scan accepts only a valid room code or a link to the configured client',
    () {
      final base = Uri.parse('https://trinktribunal.pages.dev');
      expect(codeFromScannedInvite('abcd-2345', base), 'ABCD2345');
      expect(
        codeFromScannedInvite('$base/join?room=ABCD2345', base),
        'ABCD2345',
      );
      for (final raw in [
        'ABC234',
        'https://foreign.example/join?room=ABCD2345',
        '$base/join?room=ABCD2345&token=secret',
        '$base/join?room=ABCD2345#extra',
      ]) {
        expect(codeFromScannedInvite(raw, base), isNull);
      }
    },
  );
  test('the local owner survives attempted removal, reload and profile changes exactly once', () async {
    final storage = MemoryStringStore(),
        roster = RosterController(MemoryStringStore());
    final owner = UserProfile(
      player: Player(id: PlayerId('self'), name: 'Alex'),
      avatar: AvatarConfig(),
    );
    final persisted = RosterController(storage);
    expect(await persisted.ensureOwner(owner), isTrue);
    await persisted.add('Bea');
    await persisted.add('Cleo');
    expect(await persisted.remove(owner.player.id), isFalse);
    expect(persisted.members, hasLength(3));
    final restored = RosterController(storage);
    await restored.load();
    await restored.ensureOwner(owner);
    expect(restored.members, hasLength(3));
    expect(restored.isOwner(owner.player.id), isTrue);
    expect(roster.members, isEmpty);
  });
  testWidgets(
    'the camera is embedded and scanning a code joins once without another click',
    (tester) async {
      final previous = MobileScannerPlatform.instance,
          camera = _Camera(),
          transport = FakeRoomTransport()..entryError = 'ROOM_FULL';
      MobileScannerPlatform.instance = camera;
      addTearDown(() async {
        MobileScannerPlatform.instance = previous;
        await camera.frames.close();
      });
      await tester.pumpWidget(
        accessibilityHost(const JoinRoomScreen(), transport: transport),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('room-name')), findsNothing);
      expect(find.byKey(const ValueKey('room-submit')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('open-room-camera')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('embedded-camera-view')),
        findsOneWidget,
      );
      camera.frames.add(
        BarcodeCapture(
          barcodes: [
            const Barcode(rawValue: 'ABCD2345', format: BarcodeFormat.qrCode),
          ],
        ),
      );
      camera.frames.add(
        BarcodeCapture(
          barcodes: [
            const Barcode(rawValue: 'ABCD2345', format: BarcodeFormat.qrCode),
          ],
        ),
      );
      await tester.pumpAndSettle();
      expect(transport.joins, 1);
      expect(camera.disposals, greaterThan(0));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );
  testWidgets(
    'shared secret flips from its owner label and hides immediately on release after a 600 ms hold',
    (tester) async {
      int? number;
      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, update) => HeldPrivateNumber(
              fullScreen: true,
              ownerName: 'Alex',
              ownerAvatar: AvatarConfig(),
              number: number,
              onReveal: () => update(() => number = 37),
              onHide: () => update(() => number = null),
              onDone: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Zahl von Alex'), findsNothing);
      expect(
        tester.widget<AvatarView>(find.byType(AvatarView)).showBackdrop,
        isFalse,
      );
      final button = find.byType(HoldActionButton);
      expect(
        tester.widget<HoldActionButton>(button).duration,
        const Duration(milliseconds: 600),
      );
      final hold = await tester.startGesture(tester.getCenter(button));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();
      expect(find.text('37'), findsOneWidget);
      await hold.up();
      await tester.pump();
      expect(find.text('37'), findsNothing);
      await tester.pumpAndSettle();
      expect(find.text('Zahl von Alex'), findsNothing);
      expect(
        tester.widget<AvatarView>(find.byType(AvatarView)).playerName,
        'Alex',
      );
    },
  );
}
