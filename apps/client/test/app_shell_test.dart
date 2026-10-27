import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trinktribunal/app/trinktribunal_app.dart';
import 'package:trinktribunal/data/catalogs/catalog_repository.dart';
import 'package:trinktribunal/application/local_data_providers.dart';

import 'support/memory_string_store.dart';
import 'support/memory_atomic_state_storage.dart';

void main() {
  Widget createApp() => ProviderScope(
    overrides: [
      stringStoreProvider.overrideWithValue(MemoryStringStore()),
      atomicStateStorageProvider.overrideWithValue(MemoryAtomicStateStorage()),
      catalogRepositoryProvider.overrideWithValue(
        CatalogRepository(read: (path) async => File(path).readAsStringSync()),
      ),
    ],
    child: const TrinktribunalApp(),
  );

  testWidgets('Alle drei Einstiege erlauben Zurück zur Auswahl', (
    tester,
  ) async {
    await tester.pumpWidget(createApp());

    for (final title in ['Handy + Karten', 'Ein Handy', 'Jeder ein Handy']) {
      final entry = find.text(title);
      expect(entry, findsOneWidget);
      await tester.ensureVisible(entry);
      await tester.tap(entry);
      await tester.pumpAndSettle();
      expect(find.text(title), findsAtLeastNWidgets(1));
      if (title == 'Handy + Karten') {
        expect(find.text('Eure nächste Verhandlung'), findsOneWidget);
      }
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Der Gerichtssaal wartet.'), findsOneWidget);
    }
  });

  testWidgets('Profil und Einstellungen sind erreichbar', (tester) async {
    await tester.pumpWidget(createApp());

    await tester.tap(find.byTooltip('Profil öffnen'));
    await tester.pumpAndSettle();
    expect(find.text('Mein Profil'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Einstellungen öffnen'));
    await tester.pumpAndSettle();
    expect(find.text('Allgemeine Einstellungen'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Handy + Karten'), findsOneWidget);
  });

  for (final size in [const Size(360, 800), const Size(1440, 900)]) {
    testWidgets('Start bei ${size.width} x ${size.height} ohne Layoutfehler', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createApp());
      expect(find.text('Handy + Karten'), findsOneWidget);
      expect(find.text('Ein Handy'), findsOneWidget);
      expect(find.text('Jeder ein Handy'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
