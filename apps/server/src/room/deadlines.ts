export type Deadline = { id: string; kind: 'auth'; due: number };
function exists(sql: SqlStorage): boolean {
  return (
    sql.exec("SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'deadlines'").toArray()
      .length > 0
  );
}
export function putDeadline(sql: SqlStorage, deadline: Deadline): void {
  sql.exec(
    'CREATE TABLE IF NOT EXISTS deadlines (id TEXT PRIMARY KEY, kind TEXT NOT NULL, due INTEGER NOT NULL)',
  );
  sql.exec(
    'INSERT OR REPLACE INTO deadlines (id, kind, due) VALUES (?, ?, ?)',
    deadline.id,
    deadline.kind,
    deadline.due,
  );
}
export function removeDeadline(sql: SqlStorage, id: string): void {
  if (exists(sql)) sql.exec('DELETE FROM deadlines WHERE id = ?', id);
}
export function dueDeadlines(sql: SqlStorage, now: number): Deadline[] {
  return exists(sql)
    ? sql
        .exec<Deadline>('SELECT id, kind, due FROM deadlines WHERE due <= ? ORDER BY due, id', now)
        .toArray()
    : [];
}
export function nextDeadline(sql: SqlStorage, roomExpiry: number | null): number | null {
  const row = exists(sql)
    ? sql.exec<{ due: number | null }>('SELECT MIN(due) AS due FROM deadlines').one()
    : null;
  const due = row?.due ?? null;
  return due === null ? roomExpiry : roomExpiry === null ? due : Math.min(due, roomExpiry);
}
