import { createRoomMessage, RoomIds } from '../protocol/room_message';
import type {
  Config,
  PlayerId,
  Profile,
  RoomId,
  SnapshotMessage,
} from '../protocol/room_message.generated';

// Explicit lobby allowlist. Never spread persisted members/state into a wire payload.
export function lobbySnapshot(
  state: {
    roomId: RoomId;
    revision: number;
    hostId: PlayerId;
    config: Config;
    members: ReadonlyArray<{ playerId: PlayerId; profile?: Profile; revoked: boolean }>;
  },
  you: PlayerId,
  connected: ReadonlySet<PlayerId>,
  expiresAt: number,
): SnapshotMessage {
  return createRoomMessage('snapshot', {
    requestId: RoomIds.request(crypto.randomUUID()),
    roomId: state.roomId,
    revision: state.revision,
    you,
    public: {
      phase: 'lobby',
      hostId: state.hostId,
      hostRevision: 0,
      config: state.config,
      players: state.members
        .filter((m) => !m.revoked && m.profile)
        .map((m) => ({
          playerId: m.playerId,
          profile: m.profile!,
          connected: connected.has(m.playerId),
          ready: false,
          orderSubmitted: false,
        })),
      frozenRoster: [],
      pendingRoster: [],
      gameId: null,
      roundId: null,
      judgeId: null,
      readerId: null,
      question: null,
      activeRules: [],
      completedCases: 0,
      revealCursor: 0,
      revealed: [],
      expiresAtUtc: new Date(expiresAt).toISOString(),
    },
    private: {},
  });
}
