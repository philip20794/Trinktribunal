// Persisted limits; the room bucket also bounds aggregate load across identities.
import { protocolMetadata } from '../protocol/room_message.generated';
export const ENTRY_LIMITS = Object.freeze({
  windowMs: 60_000,
  createPerAddress: 5,
  joinPerAddress: 30,
  leavePerAddress: 60,
  joinsPerRoom: 60,
  maxMembers: 20,
});
export const ROOM_ACTION_LIMITS = Object.freeze({ perSecond: 50, burst: 200 });
const roomActionKey = '@room'; // Cannot collide with a protocol-valid playerId.
type Budget = { key: string; tokens: number; updated: number };

function actionBudget(
  sql: SqlStorage,
  key: string,
  now: number,
  limits = {
    perSecond: protocolMetadata.limits.actionsPerSecond as number,
    burst: protocolMetadata.limits.actionBurst as number,
  },
): Budget {
  sql.exec(
    'CREATE TABLE IF NOT EXISTS action_limits (key TEXT PRIMARY KEY, tokens REAL NOT NULL, updated INTEGER NOT NULL)',
  );
  const row = sql
    .exec<{ tokens: number; updated: number }>(
      'SELECT tokens, updated FROM action_limits WHERE key = ?',
      key,
    )
    .toArray()[0];
  const tokens = Math.min(
    limits.burst,
    (row?.tokens ?? limits.burst) +
      (Math.max(0, now - (row?.updated ?? now)) * limits.perSecond) / 1000,
  );
  return { key, tokens, updated: Math.max(now, row?.updated ?? now) };
}
function spend(sql: SqlStorage, budget: Budget): void {
  sql.exec(
    'INSERT OR REPLACE INTO action_limits (key, tokens, updated) VALUES (?, ?, ?)',
    budget.key,
    budget.tokens - 1,
    budget.updated,
  );
}
export function consumeAction(sql: SqlStorage, key: string, now: number): boolean {
  const budget = actionBudget(sql, key, now);
  if (budget.tokens < 1) return false;
  spend(sql, budget);
  return true;
}
/** Caller owns the storage transaction; a rejected pair spends neither bucket. */
export function consumeAuthenticatedAction(
  sql: SqlStorage,
  playerId: string,
  now: number,
): boolean {
  const player = actionBudget(sql, playerId, now);
  const room = actionBudget(sql, roomActionKey, now, ROOM_ACTION_LIMITS);
  if (player.tokens < 1 || room.tokens < 1) return false;
  spend(sql, player);
  spend(sql, room);
  return true;
}

export function consumeWindow(sql: SqlStorage, key: string, limit: number, now: number): boolean {
  sql.exec(
    'CREATE TABLE IF NOT EXISTS entry_limits (key TEXT PRIMARY KEY, start INTEGER NOT NULL, used INTEGER NOT NULL)',
  );
  const row = sql
    .exec<{ start: number; used: number }>(
      'SELECT start, used FROM entry_limits WHERE key = ?',
      key,
    )
    .toArray()[0];
  const start = !row || now >= row.start + ENTRY_LIMITS.windowMs ? now : row.start;
  const used = !row || start !== row.start ? 0 : row.used;
  if (used >= limit) return false;
  sql.exec(
    'INSERT OR REPLACE INTO entry_limits (key, start, used) VALUES (?, ?, ?)',
    key,
    start,
    used + 1,
  );
  return true;
}
