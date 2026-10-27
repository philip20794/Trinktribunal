import 'dart:async';
import 'dart:math';

import '../data/protocol/room_message.dart';
import '../data/room_credential_store.dart';
import '../data/room_transport.dart';
import '../domain/models/ids.dart';

enum RoomConnectionStatus { connecting, online, reconnecting, closed, error }

final class RoomSessionState {
  const RoomSessionState({
    this.status = RoomConnectionStatus.closed,
    this.snapshot,
    this.errorCode,
  });
  final RoomConnectionStatus status;
  final SnapshotMessage? snapshot;
  final String? errorCode;
  // A fresh server view never automatically opens the private-number UI.
  bool get ownNumberRevealed => false;
}

final class RoomController {
  RoomController({
    required this.transport,
    required this.credentials,
    double Function()? jitter,
    String Function()? newId,
  }) : _jitter = jitter ?? Random.secure().nextDouble,
       _newId = newId ?? newRoomRequestId;
  final RoomTransport transport;
  final RoomCredentialStore credentials;
  final double Function() _jitter;
  final String Function() _newId;
  final _changes = StreamController<RoomSessionState>.broadcast(sync: true);
  RoomSessionState state = const RoomSessionState();
  Stream<RoomSessionState> get states => Stream.multi((sink) {
    final subscription = _changes.stream.listen(sink.add, onDone: sink.close);
    sink.add(state);
    sink.onCancel = subscription.cancel;
  });
  RoomCredential? _credential;
  RoomSocket? _socket;
  StreamSubscription<Object?>? _subscription;
  Timer? _retry, _authTimeout;
  int _session = 0, _attempt = 0, _retries = 0;
  bool _authenticated = false, _busy = false, _disposed = false;
  String? _serverError;
  final Map<String, RoomMessage> _pending = {};

  void _set(RoomSessionState value) {
    if (_disposed) return;
    state = value;
    _changes.add(value);
  }

  Future<void> _closeNetwork() async {
    _attempt++;
    _retry?.cancel();
    _authTimeout?.cancel();
    _retry = null;
    _authTimeout = null;
    final socket = _socket;
    _socket = null;
    final subscription = _subscription;
    _subscription = null;
    // Detach immediately. A network close/cancel completion must never hold the
    // connection state or next reconnect hostage; epoch checks reject late events.
    if (subscription != null) {
      unawaited(subscription.cancel().catchError((Object _) {}));
    }
    if (socket != null) unawaited(socket.close().catchError((Object _) {}));
  }

  Future<bool> create(Profile profile) =>
      _enter(() => transport.create(profile));
  Future<bool> join(String code, Profile profile) =>
      _enter(() => transport.join(code, profile));
  Future<bool> _enter(Future<CredentialMessage> Function() entry) async {
    if (_busy || _disposed) return false;
    _busy = true;
    final session = ++_session;
    await _closeNetwork();
    _pending.clear();
    _credential = null;
    _set(const RoomSessionState(status: RoomConnectionStatus.connecting));
    try {
      final message = await entry();
      if (session != _session || _disposed) return false;
      final credential = RoomCredential(
        serverOrigin: transport.serverOrigin,
        message: message,
      );
      _credential = credential;
      await credentials.save(credential);
      if (session != _session || _disposed) return false;
      _retries = 0;
      unawaited(_open(session));
      return true;
    } on Object catch (error) {
      if (session == _session) {
        _set(
          RoomSessionState(
            status: RoomConnectionStatus.error,
            errorCode: _code(error),
          ),
        );
      }
      return false;
    } finally {
      _busy = false;
    }
  }

  Future<void> resume(RoomCredential credential) async {
    if (_disposed) return;
    final session = ++_session;
    await _closeNetwork();
    _pending.clear();
    _credential = credential;
    _retries = 0;
    if (credential.serverOrigin != transport.serverOrigin) {
      _set(
        const RoomSessionState(
          status: RoomConnectionStatus.error,
          errorCode: 'WRONG_SERVER',
        ),
      );
      return;
    }
    if (credential.pendingLeaveActionId != null) {
      await leave();
      return;
    }
    _set(const RoomSessionState(status: RoomConnectionStatus.connecting));
    unawaited(_open(session));
  }

  Future<bool> retrySavingCredential() async {
    final credential = _credential;
    if (credential == null) return false;
    try {
      await credentials.save(credential);
      await resume(credential);
      return true;
    } on Object {
      _set(
        const RoomSessionState(
          status: RoomConnectionStatus.error,
          errorCode: 'CREDENTIAL_STORAGE_UNAVAILABLE',
        ),
      );
      return false;
    }
  }

  Future<void> _open(int session) async {
    final credential = _credential;
    if (credential == null || session != _session || _disposed) return;
    final attempt = ++_attempt;
    _authenticated = false;
    _serverError = null;
    try {
      final socket = await transport.connect(credential);
      if (session != _session || attempt != _attempt || _disposed) {
        await socket.close();
        return;
      }
      _socket = socket;
      _subscription = socket.messages.listen(
        (raw) {
          if (session == _session && attempt == _attempt) {
            _receive(raw, session, attempt);
          }
        },
        onError: (Object error) {
          if (session == _session && attempt == _attempt) {
            unawaited(_lost(session, attempt));
          }
        },
        onDone: () {
          if (session == _session && attempt == _attempt) {
            unawaited(_lost(session, attempt));
          }
        },
      );
      await socket.ready.timeout(const Duration(seconds: 10));
      if (session != _session || attempt != _attempt || _disposed) return;
      socket.send(
        AuthenticateMessage.create(
          requestId: RequestId(_newId()),
          resumeToken: credential.message.resumeToken,
          handshake: currentRoomHandshake,
        ),
      );
      _authTimeout = Timer(const Duration(seconds: 10), () {
        if (session == _session && attempt == _attempt) {
          unawaited(_lost(session, attempt));
        }
      });
    } on Object {
      if (session == _session && attempt == _attempt) {
        await _lost(session, attempt);
      }
    }
  }

  void _receive(Object? raw, int session, int attempt) {
    try {
      if (raw is! String) {
        throw const ProtocolDecodeException('INVALID_MESSAGE');
      }
      final message = decodeRoomMessage(raw, direction: 'server');
      final credential = _credential!;
      if (message is CredentialMessage ||
          (!_authenticated &&
              message is! AuthenticatedMessage &&
              message is! ErrorMessage)) {
        throw const ProtocolDecodeException('INVALID_MESSAGE');
      }
      if (message is AuthenticatedMessage) {
        if (_authenticated ||
            message.roomId != credential.message.roomId ||
            message.playerId != credential.message.playerId ||
            message.handshake.catalogHash != currentProtocolCatalogHash) {
          throw const ProtocolDecodeException('INVALID_MESSAGE');
        }
        _authenticated = true;
        return;
      }
      if (message is ErrorMessage) {
        _serverError = message.code;
        if (_authenticated &&
            ['CREDENTIAL_INVALID', 'ROOM_UNAVAILABLE'].contains(message.code)) {
          unawaited(_invalidate(message.code));
          return;
        }
        if ([
          'PROTOCOL_MISMATCH',
          'CATALOG_MISMATCH',
          'AVATAR_MISMATCH',
        ].contains(message.code)) {
          unawaited(_terminal(message.code));
        } else if (_authenticated) {
          _pending.clear();
          _set(
            RoomSessionState(
              status: state.status,
              snapshot: state.snapshot,
              errorCode: message.code,
            ),
          );
        }
        return;
      }
      if (message is SessionReplacedMessage) {
        unawaited(_terminal('SESSION_REPLACED', closed: true));
        return;
      }
      if (message is RoomClosedMessage) {
        unawaited(_invalidate('ROOM_UNAVAILABLE'));
        return;
      }
      if (!_authenticated) {
        throw const ProtocolDecodeException('INVALID_MESSAGE');
      }
      if (message is SnapshotMessage) {
        if (message.roomId != credential.message.roomId ||
            message.you != credential.message.playerId) {
          throw const ProtocolDecodeException('INVALID_MESSAGE');
        }
        if (state.snapshot != null &&
            message.revision < state.snapshot!.revision) {
          throw const ProtocolDecodeException('INVALID_MESSAGE');
        }
        final wasOnline = state.status == RoomConnectionStatus.online;
        _authTimeout?.cancel();
        _retries = 0;
        _set(
          RoomSessionState(
            status: RoomConnectionStatus.online,
            snapshot: message,
          ),
        );
        if (!wasOnline) {
          for (final pending in List<RoomMessage>.of(_pending.values)) {
            try {
              _socket!.send(pending);
            } on Object {
              unawaited(_lost(session, attempt));
              break;
            }
          }
        }
      } else if (message is AckMessage) {
        _pending.remove(message.actionId.value);
        if (['left', 'closed'].contains(message.outcome)) {
          unawaited(_invalidate('ROOM_UNAVAILABLE'));
        }
      } else if (message is DeltaMessage) {
        // Atomic delta application is TT-050. Until then request the authoritative full view.
        _socket!.send(
          RequestSnapshotMessage.create(requestId: RequestId(_newId())),
        );
      }
    } on Object {
      unawaited(_terminal('INVALID_RESPONSE'));
    }
  }

  Future<void> _lost(int session, int attempt) async {
    if (session != _session || attempt != _attempt || _disposed) return;
    final closeCode = _socket?.closeCode, error = _serverError;
    if (closeCode == 4409 || error == 'SESSION_REPLACED') {
      await _terminal('SESSION_REPLACED', closed: true);
      return;
    }
    if ((error == 'CREDENTIAL_INVALID' && closeCode != 4408) ||
        error == 'ROOM_UNAVAILABLE') {
      await _invalidate(error!);
      return;
    }
    await _closeNetwork();
    if (session != _session || _disposed) return;
    if (_retries >= 6) {
      _set(
        const RoomSessionState(
          status: RoomConnectionStatus.error,
          errorCode: 'RECONNECT_EXHAUSTED',
        ),
      );
      return;
    }
    final base = min(8000, 250 * (1 << _retries++));
    final delay = Duration(
      milliseconds: (base * (0.75 + 0.5 * _jitter())).round(),
    );
    _set(
      const RoomSessionState(
        status: RoomConnectionStatus.reconnecting,
        errorCode: 'NETWORK_UNAVAILABLE',
      ),
    );
    _retry = Timer(delay, () {
      if (session == _session && !_disposed) unawaited(_open(session));
    });
  }

  Future<void> _terminal(String code, {bool closed = false}) async {
    ++_session;
    _pending.clear();
    _set(
      RoomSessionState(
        status: closed
            ? RoomConnectionStatus.closed
            : RoomConnectionStatus.error,
        errorCode: code,
      ),
    );
    await _closeNetwork();
  }

  Future<void> _invalidate(String code) async {
    final credential = _credential;
    final closing = _terminal(code), session = _session;
    await closing;
    if (credential != null) {
      try {
        await credentials.remove(credential);
        if (identical(_credential, credential)) _credential = null;
      } on Object {
        if (session == _session) {
          _set(
            const RoomSessionState(
              status: RoomConnectionStatus.error,
              errorCode: 'CREDENTIAL_STORAGE_UNAVAILABLE',
            ),
          );
        }
      }
    }
  }

  bool sendAction(RoomMessage message) {
    if (state.status != RoomConnectionStatus.online || _socket == null) {
      return false;
    }
    // These committed intentions are protocol-idempotent. No reconnect retry for entry/auth/HTTP leave.
    const replayable = {
      'setConfig',
      'startGame',
      'restartGame',
      'editOwnProfile',
      'reorderRoster',
      'kick',
      'closeRoom',
      'acknowledgeNumber',
      'beginOrdering',
      'submitOrder',
      'revealNext',
      'completeCase',
      'completeWithoutVerdict',
      'continueRule',
      'resumePaused',
    };
    final id = message.toJson()['actionId'];
    if (!replayable.contains(message.type) ||
        id is! String ||
        _pending.length >= 20) {
      return false;
    }
    final existing = _pending[id];
    if (existing != null && existing.toWire() != message.toWire()) return false;
    _pending[id] = message;
    try {
      _socket!.send(message);
      return true;
    } on Object {
      unawaited(_lost(_session, _attempt));
      return false;
    }
  }

  Future<bool> leave() async {
    final credential = _credential;
    if (credential == null) return false;
    ++_session;
    await _closeNetwork();
    _pending.clear();
    final pending = credential.leaving(
      credential.pendingLeaveActionId ?? ActionId(_newId()),
    );
    _credential = pending;
    try {
      await credentials.save(pending);
      await transport.leave(pending, pending.pendingLeaveActionId!);
      await credentials.remove(pending);
      _credential = null;
      _set(const RoomSessionState());
      return true;
    } on RoomTransportException catch (error) {
      if (error.code == 'CREDENTIAL_INVALID' ||
          error.code == 'ROOM_UNAVAILABLE' && error.status == 410) {
        await _invalidate(error.code);
        return true;
      }
      _set(
        const RoomSessionState(
          status: RoomConnectionStatus.error,
          errorCode: 'LEAVE_PENDING',
        ),
      );
      return false;
    } on Object {
      _set(
        const RoomSessionState(
          status: RoomConnectionStatus.error,
          errorCode: 'CREDENTIAL_STORAGE_UNAVAILABLE',
        ),
      );
      return false;
    }
  }

  Future<void> forgetLocally(RoomCredential credential) async {
    await credentials.remove(credential);
    if (_credential?.key == credential.key) {
      await _terminal('FORGOTTEN_LOCALLY', closed: true);
      _credential = null;
    }
  }

  static String _code(Object error) => error is RoomTransportException
      ? error.code
      : error is CredentialStorageException
      ? 'CREDENTIAL_STORAGE_UNAVAILABLE'
      : error is ProtocolDecodeException
      ? error.code
      : 'NETWORK_UNAVAILABLE';
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    ++_session;
    await _closeNetwork();
    transport.dispose();
    await _changes.close();
  }
}
