import { RoomRepository, type RoomState } from './repository';
import { commitGameAction } from './actions';
import { putDeadline, removeDeadline } from './deadlines';
import type { PlayerId } from '../protocol/room_message.generated';

export function automaticRoundId(state: RoomState | null): string | null {
  const game = state?.game;
  return game?.config.allJudges && ['answers', 'revealing'].includes(game.phase) && game.round
    ? `game:${game.gameId}:${game.round.id}:${game.phase}`
    : null;
}
function automaticGuide(
  state: RoomState | null,
  connected: ReadonlySet<PlayerId>,
): PlayerId | undefined {
  return [state?.game?.readerId, state?.hostId].find(
    (id): id is PlayerId =>
      !!id && connected.has(id) && !!state?.members.some((m) => m.playerId === id && !m.revoked),
  );
}
/** Persist the cadence across hibernation. Presence frames never postpone a reveal. */
export function scheduleAutomaticRound(
  sql: SqlStorage,
  state: RoomState | null,
  now: number,
  connected: ReadonlySet<PlayerId> = new Set(state?.game?.connected ?? []),
): void {
  const game = state?.game;
  const guide = automaticGuide(state, connected);
  const available =
    guide && (game?.phase !== 'answers' || game.round!.roster.every((id) => connected.has(id)));
  const id = available ? automaticRoundId(state) : null;
  const exists =
    sql.exec("SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'deadlines'").toArray()
      .length > 0;
  const rows = exists
    ? sql.exec<{ id: string }>("SELECT id FROM deadlines WHERE kind = 'game'").toArray()
    : [];
  for (const row of rows) if (row.id !== id) removeDeadline(sql, row.id);
  if (id && !rows.some((row) => row.id === id))
    putDeadline(sql, {
      id,
      kind: 'game',
      due: now + 500,
    });
}
/** Only the room alarm calls this; every step uses the ordinary atomic reducer/journal. */
export function advanceAutomaticRound(
  repository: RoomRepository,
  connected: ReadonlySet<PlayerId>,
  deadlineId: string,
): void {
  let state = repository.read();
  if (!state || automaticRoundId(state) !== deadlineId) return;
  const guide = automaticGuide(state, connected);
  if (!guide) return;
  function send(type: string, actor: PlayerId, extra: Record<string, unknown> = {}): boolean {
    state = repository.read();
    const game = state?.game,
      member = state?.members.find((m) => m.playerId === actor && !m.revoked);
    if (!game?.round || !member) return false;
    return commitGameAction(
      repository,
      { playerId: actor, generation: member.generation },
      {
        type,
        protocolVersion: 2,
        actionId: crypto.randomUUID(),
        expectedRevision: state!.revision,
        gameId: game.gameId,
        roundId: game.round.id,
        ...extra,
      },
      connected,
    ).ok;
  }
  const game = state.game!;
  if (game.phase === 'answers') {
    for (const id of game.round!.roster)
      if (!game.round!.answerReady.includes(id) && !send('readyForOrdering', id)) return;
    send('beginOrdering', guide);
  } else if (game.phase === 'revealing') {
    send('revealNext', guide, { expectedCursor: game.round!.revealCursor });
  }
}
