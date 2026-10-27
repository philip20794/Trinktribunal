import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'room_credential_store.dart';

CredentialBackend createCredentialBackend() => IndexedDbCredentialBackend();

final class IndexedDbCredentialBackend implements CredentialBackend {
  static const databaseName = 'trinktribunal-room-credentials-v1';
  static const storeName = 'credentials';
  Future<web.IDBDatabase> _open() async {
    final done = Completer<web.IDBDatabase>();
    var abandoned = false;
    final request = web.window.indexedDB.open(databaseName, 1);
    request.onupgradeneeded = ((web.Event event) {
      (request.result as web.IDBDatabase).createObjectStore(storeName);
    }).toJS;
    request.onsuccess = ((web.Event event) {
      final database = request.result as web.IDBDatabase;
      if (done.isCompleted || abandoned) {
        database.close();
      } else {
        database.onversionchange = ((web.Event event) {
          database.close();
        }).toJS;
        done.complete(database);
      }
    }).toJS;
    request.onerror = ((web.Event event) {
      if (!done.isCompleted) {
        done.completeError(const CredentialStorageException());
      }
    }).toJS;
    request.onblocked = ((web.Event event) {
      if (!done.isCompleted) {
        done.completeError(const CredentialStorageException());
      }
    }).toJS;
    return done.future.timeout(
      const Duration(seconds: 5),
      onTimeout: () {
        abandoned = true;
        throw const CredentialStorageException();
      },
    );
  }

  Future<T> _transaction<T>(
    String mode,
    void Function(web.IDBObjectStore, void Function(T), void Function()) body,
  ) async {
    final database = await _open(), done = Completer<T>();
    T? result;
    var received = false;
    try {
      final transaction = database.transaction(storeName.toJS, mode);
      transaction.oncomplete = ((web.Event event) {
        if (!done.isCompleted) {
          if (received) {
            done.complete(result as T);
          } else {
            done.completeError(const CredentialStorageException());
          }
        }
      }).toJS;
      transaction.onabort = ((web.Event event) {
        if (!done.isCompleted) {
          done.completeError(const CredentialStorageException());
        }
      }).toJS;
      transaction.onerror = ((web.Event event) {
        if (!done.isCompleted) {
          done.completeError(const CredentialStorageException());
        }
      }).toJS;
      body(
        transaction.objectStore(storeName),
        (value) {
          result = value;
          received = true;
        },
        () {
          if (!done.isCompleted) {
            done.completeError(const CredentialStorageException());
          }
        },
      );
      return await done.future.timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          try {
            transaction.abort();
          } on Object {
            /* Transaction already settled. */
          }
          throw const CredentialStorageException();
        },
      );
    } finally {
      database.close();
    }
  }

  @override
  Future<Map<String, String>> readAll() =>
      _transaction('readonly', (store, success, failure) {
        final keys = store.getAllKeys(), values = store.getAll();
        List<JSAny?>? decodedKeys, decodedValues;
        void finish() {
          if (decodedKeys != null && decodedValues != null) {
            success({
              for (var i = 0; i < decodedKeys!.length; i++)
                (decodedKeys![i] as JSString).toDart:
                    (decodedValues![i] as JSString).toDart,
            });
          }
        }

        keys.onsuccess = ((web.Event event) {
          decodedKeys = (keys.result as JSArray).toDart;
          finish();
        }).toJS;
        values.onsuccess = ((web.Event event) {
          decodedValues = (values.result as JSArray).toDart;
          finish();
        }).toJS;
        keys.onerror = ((web.Event event) {
          failure();
        }).toJS;
        values.onerror = ((web.Event event) {
          failure();
        }).toJS;
      });
  @override
  Future<void> write(String key, String value) =>
      _transaction<bool>('readwrite', (store, success, failure) {
        final request = store.put(value.toJS, key.toJS);
        request.onsuccess = ((web.Event event) {
          success(true);
        }).toJS;
        request.onerror = ((web.Event event) {
          failure();
        }).toJS;
      }).then((_) {});
  @override
  Future<void> remove(String key) =>
      _transaction<bool>('readwrite', (store, success, failure) {
        final request = store.delete(key.toJS);
        request.onsuccess = ((web.Event event) {
          success(true);
        }).toJS;
        request.onerror = ((web.Event event) {
          failure();
        }).toJS;
      }).then((_) {});
}
