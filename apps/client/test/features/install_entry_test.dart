import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trinktribunal/app/entry_screen.dart';
import 'package:trinktribunal/app/router.dart';
import 'package:trinktribunal/application/install_controller.dart';
import 'package:trinktribunal/application/local_data_providers.dart';
import 'package:trinktribunal/application/room_providers.dart';
import 'package:trinktribunal/data/catalogs/catalog_repository.dart';
import 'package:trinktribunal/data/room_credential_store.dart';
import 'package:trinktribunal/design/court_dialog.dart';
import 'package:trinktribunal/design/court_theme.dart';
import 'package:trinktribunal/l10n/app_strings.dart';
import 'package:trinktribunal/features/multiplayer/invite.dart';

import '../data/room_test_support.dart';
import '../support/memory_string_store.dart';
import '../support/memory_atomic_state_storage.dart';
import '../design/court_scene_test.dart' show reviewImage;

class Installation {
  Installation({
    bool standalone = false,
    bool ios = false,
    bool promotion = true,
    String? pending,
  }) : state = {
         'web': true,
         'android': !ios,
         'ios': ios,
         'standalone': standalone,
         'showPromotion': promotion,
         'pending': pending,
       };
  final Map<String, dynamic> state;
  final actions = <String>[];
  Future<Map<String, dynamic>> action(
    String name, [
    String argument = '',
  ]) async {
    actions.add('$name:$argument');
    if (name == 'remember') state['pending'] = argument;
    if (name == 'clear' && state['pending'] == argument) {
      state['pending'] = null;
    }
    if (name == 'download') state['downloaded'] = true;
    return {...state};
  }
}

Future<FakeRoomTransport> mount(
  WidgetTester tester,
  Installation installation, {
  String? code,
  String? route,
}) async {
  final transport = FakeRoomTransport();
  final controller = InstallController(
    action: installation.action,
    listen: false,
  );
  addTearDown(controller.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        installControllerProvider.overrideWithValue(controller),
        roomTransportProvider.overrideWithValue(transport),
        roomCredentialStoreProvider.overrideWithValue(
          RoomCredentialStore(MemoryCredentialBackend()),
        ),
        stringStoreProvider.overrideWithValue(MemoryStringStore()),
        atomicStateStorageProvider.overrideWithValue(
          MemoryAtomicStateStorage(),
        ),
        catalogRepositoryProvider.overrideWithValue(
          CatalogRepository(
            read: (path) async => File(path).readAsStringSync(),
          ),
        ),
        publicClientBaseProvider.overrideWithValue(
          Uri.parse('https://trinktribunal.pages.dev'),
        ),
      ],
      child: RepaintBoundary(
        key: const ValueKey('scene-review'),
        child: MaterialApp(
          theme: courtTheme(),
          home: route == null ? AppEntryScreen(code: code) : null,
          initialRoute: route,
          onGenerateRoute: generateAppRoute,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return transport;
}

void main() {
  setUpAll(() async {
    if (const bool.fromEnvironment('TT_RENDER_REVIEW')) {
      final loader = FontLoader('CourtRoboto');
      for (final font in ['regular', 'medium', 'bold']) {
        loader.addFont(rootBundle.load('assets/fonts/roboto-$font.ttf'));
      }
      await loader.load();
    }
  });
  testWidgets(
    'QR browser gate ignores cooldown, preserves invite during APK download, and continues once',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final installation = Installation(promotion: false);
      final transport = await mount(tester, installation, code: 'ABCD2345');
      expect(find.byType(CourtDialog), findsOneWidget);
      await reviewImage(tester, 'install-qr-android');
      expect(transport.joins, 0);
      expect(installation.state['pending'], 'ABCD2345');
      await tester.tap(find.byKey(const ValueKey('install-apk')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('install-open-game')), findsOneWidget);
      expect(transport.joins, 0);
      await tester.tap(find.byKey(const ValueKey('install-continue-browser')));
      for (var i = 0; i < 20 && transport.connections == 0; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(transport.joins, 1);
      expect(installation.state['pending'], 'ABCD2345');
      transport.sockets.last.accepted();
      await tester.pumpAndSettle();
      expect(installation.state['pending'], isNull);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );
  for (final explicit in [true, false]) {
    testWidgets(
      'installed PWA automatically joins ${explicit ? 'direct' : 'stored'} invite without popup',
      (tester) async {
        final installation = Installation(
          standalone: true,
          pending: explicit ? null : 'ABCD2345',
        );
        final transport = await mount(
          tester,
          installation,
          code: explicit ? 'ABCD2345' : null,
        );
        expect(find.byType(CourtDialog), findsNothing);
        expect(transport.joins, 1);
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
      },
    );
  }
  testWidgets(
    'initial QR route with stored invite has only one joining entry',
    (tester) async {
      final installation = Installation(standalone: true, pending: 'ABCD2345');
      final transport = await mount(
        tester,
        installation,
        route: '/join?room=ABCD2345',
      );
      expect(transport.joins, 1);
      expect(find.byType(CourtDialog), findsNothing);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );
  testWidgets(
    'normal browser popup can be dismissed; cooldown suppresses next promotion',
    (tester) async {
      final installation = Installation();
      await mount(tester, installation);
      expect(find.byType(CourtDialog), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('court-dialog-close')));
      await tester.pumpAndSettle();
      expect(installation.actions, contains('dismiss:'));
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      await mount(tester, Installation(promotion: false));
      expect(find.byType(CourtDialog), findsNothing);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );
  testWidgets(
    'iOS explains installation and retains the room-code/browser fallback',
    (tester) async {
      final transport = await mount(
        tester,
        Installation(ios: true),
        code: 'ABCD2345',
      );
      expect(find.byKey(const ValueKey('install-apk')), findsNothing);
      await tester.ensureVisible(find.byKey(const ValueKey('install-pwa')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('install-pwa')));
      await tester.pumpAndSettle();
      expect(
        find.text(const AppStrings('de').get('installIosHelp')),
        findsOneWidget,
      );
      expect(find.textContaining('ABCD2345'), findsWidgets);
      expect(
        find.byKey(const ValueKey('install-continue-browser')),
        findsOneWidget,
      );
      expect(transport.joins, 0);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );
}
