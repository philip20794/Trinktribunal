import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/preferences_string_store.dart';
import '../data/profile_store.dart';
import '../data/string_store.dart';
import 'profile_controller.dart';
import 'roster_controller.dart';
import 'content_history_store.dart';
import 'shared_phone_controller.dart';
import '../data/catalogs/catalog_repository.dart';

final stringStoreProvider = Provider<StringStore>(
  (ref) => PreferencesStringStore(),
);
final contentHistoryStoreProvider = Provider<ContentHistoryStore>(
  (ref) => ContentHistoryStore(),
);
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
