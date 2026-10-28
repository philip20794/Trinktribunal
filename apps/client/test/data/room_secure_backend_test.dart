import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trinktribunal/data/room_credential_backend_io.dart';
import 'package:trinktribunal/data/room_credential_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  final calls = <MethodCall>[];
  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    calls.clear();
  });
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test(
    'Android credentials use an isolated namespace without reset or backup',
    () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            return <String, String>{};
          });
      expect(
        (await RoomCredentialStore(
          SecureCredentialBackend(),
        ).load()).unavailable,
        isFalse,
      );
      final options = (calls.single.arguments as Map)['options'] as Map;
      expect(options['storageNamespace'], 'trinktribunal_room_credentials_v1');
      expect(options['resetOnError'], 'false');
      expect(options['migrateWithBackup'], 'false');
    },
  );

  test(
    'native key/storage failure stays visible and never requests deletion',
    () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            throw PlatformException(code: 'PRIVATE_KEYSTORE_DETAIL');
          });
      final store = RoomCredentialStore(SecureCredentialBackend());
      final loaded = await store.load();
      expect(loaded.unavailable, isTrue);
      expect(calls.map((call) => call.method), ['readAll']);
      expect(
        (calls.single.arguments as Map)['options']['resetOnError'],
        'false',
      );
      expect(
        const CredentialStorageException().toString(),
        'CREDENTIAL_STORAGE_UNAVAILABLE',
      );
    },
  );
}
