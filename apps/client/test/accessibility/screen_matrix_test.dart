import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trinktribunal/application/local_data_providers.dart';
import 'package:trinktribunal/application/room_providers.dart';
import 'package:trinktribunal/data/catalogs/catalog_repository.dart';
import 'package:trinktribunal/data/room_credential_store.dart';
import 'package:trinktribunal/design/court_theme.dart';
import 'package:trinktribunal/features/home/home_screen.dart';
import 'package:trinktribunal/features/profile/profile_screen.dart';
import 'package:trinktribunal/features/settings/settings_screen.dart';
import 'package:trinktribunal/features/setup/card_mode_screen.dart';
import 'package:trinktribunal/features/setup/player_roster.dart';
import 'package:trinktribunal/features/multiplayer/create.dart';
import 'package:trinktribunal/features/multiplayer/join.dart';
import 'package:trinktribunal/l10n/app_strings.dart';
import 'package:trinktribunal/features/rules/game_rules_screen.dart';

import '../data/room_test_support.dart';
import '../support/memory_atomic_state_storage.dart';
import '../support/memory_string_store.dart';

Widget accessibilityHost(
  Widget screen, {
  String language = 'de',
  Size size = const Size(360, 800),
  FakeRoomTransport? transport,
}) => ProviderScope(
  overrides: [
    roomCredentialStoreProvider.overrideWithValue(
      RoomCredentialStore(MemoryCredentialBackend()),
    ),
    roomTransportProvider.overrideWithValue(transport ?? FakeRoomTransport()),
    stringStoreProvider.overrideWithValue(MemoryStringStore()),
    atomicStateStorageProvider.overrideWithValue(MemoryAtomicStateStorage()),
    catalogRepositoryProvider.overrideWithValue(
      CatalogRepository(read: (path) async => File(path).readAsStringSync()),
    ),
  ],
  child: AppLanguageScope(
    language: language,
    child: MaterialApp(
      theme: courtTheme(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          size: size,
          textScaler: const TextScaler.linear(2),
          disableAnimations: true,
        ),
        child: child!,
      ),
      home: screen,
    ),
  ),
);

void main() {
  const screens = <String, Widget>{
    'home': HomeScreen(),
    'game-rules': GameRulesScreen(),
    'profile': ProfileScreen(),
    'settings': SettingsScreen(),
    'card-setup': CardModeScreen(),
    'roster-empty': PlayerRosterScreen(),
    'multiplayer-empty': MultiplayerEntryScreen(),
    'create': CreateRoomScreen(),
    'join': JoinRoomScreen(initialCode: 'ABCD2345'),
  };
  for (final size in [const Size(360, 800), const Size(1440, 1000)]) {
    for (final language in ['de', 'en']) {
      for (final screen in screens.entries) {
        testWidgets(
          '${screen.key}, $language, $size, 200 percent: layout, labels and touch targets',
          (tester) async {
            await tester.binding.setSurfaceSize(size);
            addTearDown(() => tester.binding.setSurfaceSize(null));
            final semantics = tester.ensureSemantics();
            try {
              await tester.pumpWidget(
                accessibilityHost(screen.value, language: language, size: size),
              );
              await tester.pumpAndSettle();
              expect(tester.takeException(), isNull);
              expect(find.byType(CircularProgressIndicator), findsNothing);
              await expectLater(
                tester,
                meetsGuideline(labeledTapTargetGuideline),
              );
              await expectLater(
                tester,
                meetsGuideline(androidTapTargetGuideline),
              );
              final scrollables = find.byType(Scrollable).evaluate().toList();
              for (final element in scrollables) {
                if (!element.mounted) continue;
                final state =
                    (element as StatefulElement).state as ScrollableState;
                if (state.position.hasContentDimensions &&
                    state.position.maxScrollExtent > 0) {
                  state.position.jumpTo(state.position.maxScrollExtent);
                  await tester.pumpAndSettle();
                  expect(tester.takeException(), isNull);
                  await expectLater(
                    tester,
                    meetsGuideline(labeledTapTargetGuideline),
                  );
                  await expectLater(
                    tester,
                    meetsGuideline(androidTapTargetGuideline),
                  );
                }
              }
              await tester.pumpWidget(const SizedBox.shrink());
              await tester.pump();
            } finally {
              semantics.dispose();
            }
          },
        );
      }
    }
  }
}
