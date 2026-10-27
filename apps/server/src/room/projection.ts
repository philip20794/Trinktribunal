import { createRoomMessage, RoomIds } from '../protocol/room_message';
import { createHash } from 'node:crypto';
import { canonicalJson } from '../../../../packages/protocol/schema-validation.mjs';
import type { GameState } from '../domain/game_state';
import { readyInPhase } from './readiness';
import { ownConfirmedOrder } from './orders';
import type {
  Config,
  PlayerId,
  Profile,
  RoomId,
  SnapshotMessage,
  Participant,
} from '../protocol/room_message.generated';
export function playersHash(players: ReadonlyArray<Participant>): string {
  return createHash('sha256').update(canonicalJson(players)).digest('hex');
}

// Explicit public allowlist. Never spread persisted members/state into a wire payload.
// Only the recipient's own number crosses the private boundary (TT-046).
export function lobbySnapshot(
  state: {
    roomId: RoomId;
    revision: number;
    hostId: PlayerId;
    config: Config;
    members: ReadonlyArray<{ playerId: PlayerId; profile?: Profile; revoked: boolean }>;
    game?: GameState;
  },
  you: PlayerId,
  connected: ReadonlySet<PlayerId>,
  expiresAt: number,
): SnapshotMessage {
  const game = state.game,
    round = game?.round,
    order = ownConfirmedOrder(game, you);
  return createRoomMessage('snapshot', {
    requestId: RoomIds.request(crypto.randomUUID()),
    roomId: state.roomId,
    revision: state.revision,
    you,
    public: {
      phase: game?.phase ?? 'lobby',
      hostId: state.hostId,
      hostRevision: game?.hostRevision ?? 0,
      config: state.config,
      players: state.members
        .filter((m) => !m.revoked && m.profile)
        .map((m) => ({
          playerId: m.playerId,
          profile: m.profile!,
          connected: connected.has(m.playerId),
          ready: readyInPhase(game, m.playerId),
          orderSubmitted: round?.orders.some((order) => order.playerId === m.playerId) ?? false,
        })),
      frozenRoster: round?.roster ?? [],
      pendingRoster: game?.pendingRoster ?? [],
      gameId: game?.gameId ?? null,
      roundId: round?.id ?? null,
      judgeId: game?.judgeId ?? null,
      readerId: game?.readerId ?? null,
      question: round?.question ?? null,
      activeRules: game?.activeRules ?? [],
      completedCases: game?.completedCases ?? 0,
      revealCursor: round?.revealCursor ?? 0,
      revealed: (round?.revealOrder ?? []).slice(0, round?.revealCursor ?? 0).map((playerId) => ({
        playerId,
        number: round!.numbers.find((entry) => entry.playerId === playerId)!.number,
      })),
      ...(game?.pauseReason ? { pauseReason: game.pauseReason } : {}),
      ...(game?.pausedFrom ? { pausedFrom: game.pausedFrom } : {}),
      expiresAtUtc: new Date(expiresAt).toISOString(),
    },
    private:
      round && ['numbers', 'answers', 'ordering', 'revealing', 'judged'].includes(game!.phase)
        ? (() => {
            const own = round.numbers.find((entry) => entry.playerId === you);
            return {
              ...(own ? { ownNumber: own.number } : {}),
              ...(order ? { ownOrder: order } : {}),
            };
          })()
        : {},
  });
}
