import '../../data/room_transport.dart';

String? codeFromJoinRoute(String raw) {
  try {
    if (raw.length > 256) return null;
    final uri = Uri.parse(raw);
    if (uri.hasScheme ||
        uri.hasAuthority ||
        uri.hasFragment ||
        uri.path != '/join' ||
        uri.queryParametersAll.keys.length != 1 ||
        uri.queryParametersAll['room']?.length != 1) {
      return null;
    }
    return normalizedRoomCode(uri.queryParameters['room']!);
  } on Object {
    return null;
  }
}

Uri invitationUri(Uri publicClientBase, String code) {
  if (!['http', 'https'].contains(publicClientBase.scheme) ||
      publicClientBase.host.isEmpty ||
      publicClientBase.userInfo.isNotEmpty ||
      publicClientBase.hasQuery ||
      publicClientBase.hasFragment ||
      !['', '/'].contains(publicClientBase.path)) {
    throw const FormatException('INVALID_INVITE_BASE');
  }
  return Uri.parse(
    publicClientBase.origin,
  ).replace(path: '/join', queryParameters: {'room': normalizedRoomCode(code)});
}

String roomErrorKey(String? code) => switch (code) {
  'STALE_REVISION' => 'roomErrorStale',
  'UNAUTHORIZED_ACTION' => 'roomErrorAuthority',
  'ROOM_FULL' => 'roomErrorFull',
  'ROOM_UNAVAILABLE' || 'CREDENTIAL_INVALID' => 'roomErrorUnavailable',
  'RATE_LIMITED' => 'roomErrorRate',
  'INVALID_NAME' => 'roomErrorName',
  'INVALID_ROOM_CODE' => 'roomErrorCode',
  'CATALOG_MISMATCH' ||
  'PROTOCOL_MISMATCH' ||
  'AVATAR_MISMATCH' => 'roomErrorUpdate',
  'CREDENTIAL_STORAGE_UNAVAILABLE' => 'roomErrorStorage',
  'LEAVE_PENDING' => 'roomLeavePending',
  'SESSION_REPLACED' => 'roomReplaced',
  'NETWORK_UNAVAILABLE' || 'RECONNECT_EXHAUSTED' => 'roomErrorNetwork',
  'SERVER_NOT_CONFIGURED' || 'WRONG_SERVER' => 'roomErrorServer',
  _ => 'roomErrorGeneric',
};
