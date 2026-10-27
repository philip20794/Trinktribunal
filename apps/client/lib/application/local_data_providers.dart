import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/preferences_string_store.dart';
import '../data/profile_store.dart';
import '../data/string_store.dart';
import 'profile_controller.dart';
import 'settings_controller.dart';
import 'roster_controller.dart';
import 'content_history_store.dart';
import 'shared_phone_controller.dart';
import '../data/catalogs/catalog_repository.dart';
import '../data/local_state_storage.dart';
import 'local_session_controller.dart';
import 'local_state_transaction.dart';

final stringStoreProvider = Provider<StringStore>(
  (ref) => PreferencesStringStore(),
);
final settingsControllerProvider = Provider<SettingsController>((ref) {
  final controller = SettingsController(ref.watch(stringStoreProvider));
  ref.onDispose(controller.dispose);
  return controller;
});
final settingsProvider = FutureProvider<SettingsController>((ref) async {
  final controller = ref.watch(settingsControllerProvider);
  await controller.load();
  return controller;
}, retry: (count, error) => null);
final contentHistoryStoreProvider = Provider<ContentHistoryStore>(
  (ref) => ContentHistoryStore(),
);
final localSessionProvider = Provider<LocalSessionController>((ref) {
  final catalogs = ref.watch(catalogsProvider).requireValue;
  return LocalSessionController(
    questions: catalogs.questions['de']!.entries,
    rules: catalogs.rules['de']!.entries,
    historyStore: ref.watch(contentHistoryStoreProvider),
  );
});
final atomicStateStorageProvider = Provider<AtomicStateStorage>(
  (ref) => createAtomicStateStorage(),
);
final localStateTransactionProvider = Provider<LocalStateTransaction>(
  (ref) => LocalStateTransaction(
    storage: ref.watch(atomicStateStorageProvider),
    cards: ref.watch(localSessionProvider),
    shared: ref.watch(sharedPhoneControllerProvider),
    history: ref.watch(contentHistoryStoreProvider),
    catalogSignature: ref.watch(catalogsProvider).requireValue.signature,
  ),
);
final localResumeProvider = FutureProvider<void>((ref) async {
  await ref.watch(catalogsProvider.future);
  await ref.read(localStateTransactionProvider).load();
}, retry: (count, error) => null);
final sharedPhoneControllerProvider = Provider<SharedPhoneController>((ref) {
  final catalogs = ref.watch(catalogsProvider).requireValue;
  return SharedPhoneController(
    questions: catalogs.questions['de']!.entries,
    rules: catalogs.rules['de']!.entries,
    historyStore: ref.watch(contentHistoryStoreProvider),
  );
});
final rosterControllerProvider = Provider<RosterController>(
  (ref) => RosterController(ref.watch(stringStoreProvider)),
);
final rosterProvider = FutureProvider<RosterController>((ref) async {
  final controller = ref.watch(rosterControllerProvider);
  await controller.load();
  return controller;
}, retry: (count, error) => null);
final profileControllerProvider = Provider<ProfileController>(
  (ref) => ProfileController(ProfileStore(ref.watch(stringStoreProvider))),
);
final profileProvider = FutureProvider<ProfileController>((ref) async {
  final controller = ref.watch(profileControllerProvider);
  await controller.load();
  return controller;
}, retry: (count, error) => null);
