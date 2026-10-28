import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trinktribunal/app/trinktribunal_app.dart';
import 'package:trinktribunal/application/local_data_providers.dart';
import 'package:trinktribunal/application/room_providers.dart';
import 'package:trinktribunal/data/room_credential_store.dart';
import 'package:trinktribunal/features/home/home_screen.dart';

import 'data/room_test_support.dart';

import 'package:trinktribunal/data/catalogs/catalog_repository.dart';

import 'support/memory_string_store.dart';
import 'support/memory_atomic_state_storage.dart';

// Dies ersetzt bewusst den von "flutter create" sonst erzeugten MyApp-Test.
// Die Startanwendung heißt TrinktribunalApp, nicht MyApp.
void main() {
  testWidgets('Flutter-Projektgerüst startet die tatsächliche App-Shell', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
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
        ],
        child: const TrinktribunalApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Trinktribunal'), findsOneWidget);
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.text('Handy + Karten'), findsOneWidget);
    expect(find.text('Ein Handy'), findsOneWidget);
    expect(find.text('Jeder ein Handy'), findsOneWidget);
    expect(find.byType(Scaffold), findsOneWidget);
  });
}
