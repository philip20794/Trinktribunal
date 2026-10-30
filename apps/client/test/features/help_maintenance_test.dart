import '../support/action_text.dart';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trinktribunal/application/local_data_providers.dart';
import 'package:trinktribunal/application/local_maintenance_controller.dart';
import 'package:trinktribunal/data/profile_store.dart';
import 'package:trinktribunal/domain/avatar_config.dart';
import 'package:trinktribunal/features/help/help_screen.dart';
import 'package:trinktribunal/features/home/home_screen.dart';
import 'package:trinktribunal/features/rules/game_rules_screen.dart';
import 'package:trinktribunal/features/settings/settings_screen.dart';
import 'package:trinktribunal/l10n/app_strings.dart';

import '../data/local_state_transaction_test.dart' show Harness;
import '../support/memory_atomic_state_storage.dart';
import '../support/memory_string_store.dart';
import 'home_profile_settings_test.dart' show host, tapVisible;

void main() {
  for (final language in ['de', 'en']) {
    for (final size in [const Size(320, 640), const Size(1440, 900)]) {
      for (final privacy in [false, true]) {
        testWidgets('help/privacy $privacy, $language, $size, 200 percent', (
          tester,
        ) async {
          final strings = AppStrings(language);
          await host(
            tester,
            HelpScreen(privacy: privacy),
            language,
            size: size,
            scale: 2,
          );
          final semantics = tester.ensureSemantics();

          if (privacy) {
            expect(
              find.textContaining(strings.get('privacyNoServer')),
              findsOneWidget,
            );
          }
          for (final section in privacy ? privacySections : helpSections) {
            final prefix = privacy ? 'privacy' : 'help';
            final title = strings.get('$prefix${section}Title');
            final body = strings.get('$prefix${section}Body');
            expect(title, isNot('$prefix${section}Title'));
            expect(body, isNot('$prefix${section}Body'));
            await tester.scrollUntilVisible(
              actionText(title),
              220,
              scrollable: find.byType(Scrollable).first,
            );
            await tester.pumpAndSettle();
            expect(actionText(title), findsOneWidget);
            expect(actionText(body), findsOneWidget);
            expect(tester.takeException(), isNull);
          }
          await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
          semantics.dispose();
        });
      }
    }
    testWidgets(
      'settings links reach help, real game rules and privacy, $language',
      (tester) async {
        final strings = AppStrings(language);
        await host(tester, const HomeScreen(), language);
        await tester.tap(find.byTooltip(strings.get('openSettings')));
        await tester.pumpAndSettle();
        await tapVisible(tester, actionText(strings.get('helpTitle')));
        expect(find.byType(HelpScreen), findsOneWidget);
        await tapVisible(tester, actionText(strings.get('gameRules')));
        expect(find.byType(GameRulesScreen), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('rules-back')));
        await tester.pumpAndSettle();
        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();
        await tapVisible(tester, actionText(strings.get('privacyTitle')));
        expect(
          tester.widget<HelpScreen>(find.byType(HelpScreen)).privacy,
          isTrue,
        );
        expect(tester.takeException(), isNull);
      },
    );
    testWidgets(
      'profile deletion requires confirmation, reports failure and permits retry, $language',
      (tester) async {
        final strings = AppStrings(language);
        await host(
          tester,
          const SettingsScreen(),
          language,
          size: const Size(320, 640),
          scale: 2,
        );
        final container = ProviderScope.containerOf(
          tester.element(find.byType(SettingsScreen)),
        );
        final profile = await container.read(profileProvider.future);
        await profile.save(name: 'Alex', avatar: AvatarConfig());
        final storage =
            container.read(stringStoreProvider) as MemoryStringStore;
        storage.values['unrelated'] = 'keep';
        final action = actionText(strings.get('maintenanceProfile'));
        await tapVisible(tester, action);
        await tapVisible(
          tester,
          find.byKey(const ValueKey('court-dialog-close')),
        );
        expect(storage.values.containsKey(ProfileStore.key), isTrue);
        storage.failWrite = true;
        await tapVisible(tester, action);
        await tapVisible(tester, actionText(strings.get('maintenanceDelete')));
        expect(actionText(strings.get('maintenanceFailed')), findsOneWidget);
        expect(storage.values.containsKey(ProfileStore.key), isTrue);
        storage.failWrite = false;
        await tapVisible(tester, action);
        await tapVisible(tester, actionText(strings.get('maintenanceDelete')));
        expect(
          actionText(strings.get('maintenanceProfileDeleted')),
          findsOneWidget,
        );
        expect(storage.values.containsKey(ProfileStore.key), isFalse);
        expect(storage.values['unrelated'], 'keep');
        expect((await container.read(profileProvider.future)).profile, isNull);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('settings waits in place until deletion is persisted', (
    tester,
  ) async {
    final strings = AppStrings('de');
    await host(tester, const HomeScreen(), 'de');
    await tester.tap(find.byTooltip(strings.get('openSettings')));
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(SettingsScreen)),
    );
    final profile = await container.read(profileProvider.future);
    await profile.save(name: 'Alex', avatar: AvatarConfig());
    final storage = container.read(stringStoreProvider) as MemoryStringStore;
    final entered = Completer<void>(), release = Completer<void>();
    storage.beforeWrite = () async {
      entered.complete();
      await release.future;
    };
    await tapVisible(tester, actionText(strings.get('maintenanceProfile')));
    await tester.tap(actionText(strings.get('maintenanceDelete')));
    await tester.pump();
    await entered.future;
    await tester.pump(const Duration(milliseconds: 400));
    expect(container.read(localMaintenanceProvider).busy, isTrue);
    final navigator = tester.state<NavigatorState>(
      find.byType(Navigator).first,
    );
    await navigator.maybePop();
    await tester.pump();
    expect(find.byType(SettingsScreen), findsOneWidget);
    final deleteButton = tester.widget<OutlinedButton>(
      find.ancestor(
        of: actionText(strings.get('maintenanceProfile')),
        matching: find.byType(OutlinedButton),
      ),
    );
    expect(deleteButton.onPressed, isNull);
    release.complete();
    await tester.pumpAndSettle();
    expect(
      actionText(strings.get('maintenanceProfileDeleted')),
      findsOneWidget,
    );
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsOneWidget);
  });

  testWidgets('game deletion can be cancelled and confirms sanitized copies', (
    tester,
  ) async {
    final strings = AppStrings('en');
    await host(tester, const SettingsScreen(), 'en');
    final container = ProviderScope.containerOf(
      tester.element(find.byType(SettingsScreen)),
    );
    await container.read(localResumeProvider.future);
    final cards = container.read(localSessionProvider);
    cards.start(
      cards.configure(playerCount: 4, targetCases: 3, requestedRuleEvents: 0),
    );
    await container.read(localStateTransactionProvider).save();
    final storage =
        container.read(atomicStateStorageProvider) as MemoryAtomicStateStorage;
    final original = storage.primary;
    await tapVisible(tester, actionText(strings.get('maintenanceGames')));
    await tapVisible(tester, find.byKey(const ValueKey('court-dialog-close')));
    expect(storage.primary, original);
    expect(cards.state, isNotNull);
    await tapVisible(tester, actionText(strings.get('maintenanceGames')));
    await tapVisible(tester, actionText(strings.get('maintenanceDelete')));
    expect(cards.state, isNull);
    expect(storage.primary, storage.backup);
    expect(actionText(strings.get('maintenanceGamesDeleted')), findsOneWidget);
  });

  test('app-scoped deletion rejects duplicate operations and waits for durable storage', () async {
    final entered = Completer<void>(), release = Completer<void>();
    final storage = MemoryStringStore();
    final container = ProviderContainer(
      overrides: [stringStoreProvider.overrideWithValue(storage)],
    );
    addTearDown(container.dispose);
    final profile = await container.read(profileProvider.future);
    await profile.save(name: 'Alex', avatar: AvatarConfig());
    storage.beforeWrite = () async {
      entered.complete();
      await release.future;
    };
    final controller = container.read(localMaintenanceProvider.notifier);
    final pending = controller.delete(LocalDeletion.profile);
    await entered.future;
    expect(container.read(localMaintenanceProvider).busy, isTrue);
    expect(await controller.delete(LocalDeletion.games), isFalse);
    expect(storage.values.containsKey(ProfileStore.key), isTrue);
    release.complete();
    expect(await pending, isTrue);
    expect(container.read(localMaintenanceProvider).busy, isFalse);
    expect(
      container.read(localMaintenanceProvider).feedback,
      'maintenanceProfileDeleted',
    );
  });

  test(
    'game deletion waits for restoration and preserves the independent profile',
    () async {
      final storage = MemoryAtomicStateStorage(), h = Harness(storage);
      h.startCards();
      h.startPhone();
      await h.transaction.save();
      final strings = MemoryStringStore()..values['profile-untouched'] = 'keep';
      final restored = Completer<void>();
      final container = ProviderContainer(
        overrides: [
          stringStoreProvider.overrideWithValue(strings),
          localStateTransactionProvider.overrideWithValue(h.transaction),
          localResumeProvider.overrideWith((ref) => restored.future),
        ],
      );
      addTearDown(container.dispose);
      final pending = container
          .read(localMaintenanceProvider.notifier)
          .delete(LocalDeletion.games);
      await Future<void>.delayed(Duration.zero);
      expect(h.cards.state, isNotNull);
      restored.complete();
      expect(await pending, isTrue);
      expect(h.cards.state, isNull);
      expect(h.phone.view, isNull);
      expect(storage.primary, storage.backup);
      expect(strings.values, {'profile-untouched': 'keep'});
      expect(
        container.read(localMaintenanceProvider).feedback,
        'maintenanceGamesDeleted',
      );
    },
  );
}
