import 'room_message.dart';

SnapshotMessage applyRoomDelta(SnapshotMessage base, DeltaMessage delta) {
  if (base.roomId != delta.roomId ||
      base.you != delta.you ||
      base.revision != delta.baseRevision ||
      delta.revision <= base.revision) {
    throw const ProtocolDecodeException('STALE_REVISION');
  }
  return SnapshotMessage.fromJson({
    ...base.toJson(),
    'revision': delta.revision,
    'public': {...base.public.toJson(), ...delta.publicChanges.toJson()},
    // A full replacement clears values that ceased to be private/assigned.
    'private': delta.private.toJson(),
  });
}
