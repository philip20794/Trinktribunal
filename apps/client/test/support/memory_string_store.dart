import 'package:trinktribunal/data/string_store.dart';

final class MemoryStringStore implements StringStore {
  final Map<String, String> values = {};
  bool failRead = false;
  bool failWrite = false;
  Future<void> Function()? beforeWrite;
  @override
  Future<String?> read(String key) async {
    if (failRead) throw StateError('synthetic read failure');
    return values[key];
  }

  @override
  Future<void> write(String key, String value) async {
    if (beforeWrite != null) await beforeWrite!();
    if (failWrite) throw StateError('synthetic write failure');
    values[key] = value;
  }
}
