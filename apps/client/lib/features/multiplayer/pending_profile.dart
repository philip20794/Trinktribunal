/// Shared on-wire placeholder for a QR invitation before a player supplies a name.
/// The room server rejects game starts while any active member uses this name.
const pendingRoomProfileName = '[name pending]';

bool needsRoomName(String name) =>
    name.trim().isEmpty || name == pendingRoomProfileName;
