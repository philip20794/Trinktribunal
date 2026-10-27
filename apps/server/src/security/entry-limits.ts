// Persisted fixed windows, intentionally conservative until the TT-059 abuse audit.
import { protocolMetadata } from '../protocol/room_message.generated';
export const ENTRY_LIMITS = Object.freeze({
  windowMs: 60_000,
  createPerAddress: 5,
  joinPerAddress: 30,
  leavePerAddress: 60,
  joinsPerRoom: 60,
  maxMembers: 20,
});

export function consumeAction(sql: SqlStorage, key: string, now: number): boolean {
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
    protocolMetadata.limits.actionBurst,
    (row?.tokens ?? protocolMetadata.limits.actionBurst) +
      (Math.max(0, now - (row?.updated ?? now)) * protocolMetadata.limits.actionsPerSecond) / 1000,
  );
  if (tokens < 1) return false;
  sql.exec(
    'INSERT OR REPLACE INTO action_limits (key, tokens, updated) VALUES (?, ?, ?)',
    key,
    tokens - 1,
    now,
  );
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
