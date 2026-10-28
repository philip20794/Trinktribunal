import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'room_credential_store.dart';

CredentialBackend createCredentialBackend() => SecureCredentialBackend();

final class SecureCredentialBackend implements CredentialBackend {
  SecureCredentialBackend({FlutterSecureStorage? storage})
    : _storage =
          storage ??
          const FlutterSecureStorage(
            aOptions: AndroidOptions(
              storageNamespace: 'trinktribunal_room_credentials_v1',
              // Surface a recoverable storage error; never silently erase identities.
              resetOnError: false,
              migrateWithBackup: false,
            ),
          );
  final FlutterSecureStorage _storage;
  @override
  Future<Map<String, String>> readAll() => _storage.readAll();
  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);
  @override
  Future<void> remove(String key) => _storage.delete(key: key);
}
