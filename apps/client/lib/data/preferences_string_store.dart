import 'package:shared_preferences/shared_preferences.dart';

import 'string_store.dart';

/// Noncritical profile/roster preferences, never room credentials or snapshots.
final class PreferencesStringStore implements StringStore {
  final SharedPreferencesAsync _preferences = SharedPreferencesAsync();
  @override
  Future<String?> read(String key) => _preferences.getString(key);
  @override
  Future<void> write(String key, String value) =>
      _preferences.setString(key, value);
  @override
  Future<void> remove(String key) => _preferences.remove(key);
}
