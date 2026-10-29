import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trinktribunal/application/local_data_providers.dart';
import 'package:trinktribunal/domain/avatar_config.dart';

Future<void> addTestPlayers(WidgetTester tester) async {
  final container = ProviderScope.containerOf(
    tester.element(find.byKey(const ValueKey('quick-player-name'))),
  );
  final profile = container.read(profileControllerProvider);
  await profile.save(
    name: 'Alex',
    avatar: profile.profile?.avatar ?? AvatarConfig(),
  );
  container.invalidate(profileProvider);
  await tester.pumpAndSettle();
  for (final name in ['Bea', 'Cleo']) {
    await tester.enterText(
      find.byKey(const ValueKey('quick-player-name')),
      name,
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
  }
  tester.testTextInput.hide();
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pumpAndSettle();
}
