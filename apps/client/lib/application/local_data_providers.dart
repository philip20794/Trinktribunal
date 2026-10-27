import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/preferences_string_store.dart';
import '../data/profile_store.dart';
import '../data/string_store.dart';
import 'profile_controller.dart';
import 'roster_controller.dart';

final stringStoreProvider = Provider<StringStore>(
  (ref) => PreferencesStringStore(),
);
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
