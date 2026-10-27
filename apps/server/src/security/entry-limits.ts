// Persisted fixed windows, intentionally conservative until the TT-059 abuse audit.
export const ENTRY_LIMITS = Object.freeze({
  windowMs: 60_000,
  createPerAddress: 5,
  joinPerAddress: 30,
  leavePerAddress: 60,
  joinsPerRoom: 60,
  maxMembers: 20,
});

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
