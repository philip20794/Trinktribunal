import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trinktribunal/app/trinktribunal_app.dart';

// Dies ersetzt bewusst den von "flutter create" sonst erzeugten MyApp-Test.
// Die Startanwendung heißt TrinktribunalApp, nicht MyApp.
void main() {
  testWidgets('Flutter-Projektgerüst startet die tatsächliche App-Shell', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(child: TrinktribunalApp()),
    );
    expect(find.text('Trinktribunal'), findsOneWidget);
    expect(find.text('Der Gerichtssaal wartet.'), findsOneWidget);
    expect(find.byType(Scaffold), findsOneWidget);
  });
}
