import 'room_credential_store.dart';

CredentialBackend createCredentialBackend() => _Unsupported();

final class _Unsupported implements CredentialBackend {
  @override
  Future<Map<String, String>> readAll() async =>
      throw const CredentialStorageException();
  @override
  Future<void> write(String key, String value) async =>
      throw const CredentialStorageException();
  @override
  Future<void> remove(String key) async =>
      throw const CredentialStorageException();
}
