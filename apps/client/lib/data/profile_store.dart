import 'dart:convert';

import '../domain/user_profile.dart';
import 'string_store.dart';

final class ProfileStore {
  ProfileStore(this.storage);
  final StringStore storage;
  static const key = 'trinktribunal.profile.v1';
  Future<({UserProfile? profile, bool recovered})> load() async {
    final raw = await storage.read(key);
    if (raw == null) return (profile: null, recovered: false);
    try {
      final profile = UserProfile.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
      return (profile: profile, recovered: profile.avatar.isFallback);
    } on Object {
      return (profile: null, recovered: true);
    }
  }

  Future<void> save(UserProfile profile) =>
      storage.write(key, jsonEncode(profile.toJson()));
  Future<void> delete() => storage.remove(key);
}
