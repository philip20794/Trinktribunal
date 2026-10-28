import type { RoomMessage } from '../protocol/room_message.generated';

/** Local opt-in counters only: no identifiers, payloads, timers, SQL or public endpoint. */
export interface RoomMetrics {
  incomingFrames: number;
  incomingBytes: number;
  outgoingFrames: number;
  outgoingBytes: number;
  maxFrameBytes: number;
  projections: number;
  maxProjectionBytes: number;
  actions: number;
  acknowledgements: number;
  errors: number;
  authentications: number;
  reconnects: number;
  sqlCalls: number;
  sqlFailures: number;
  sqlRowsRead: number;
  sqlRowsWritten: number;
  roomWrites: number;
  serializedStateBytes: number;
  maxStateBytes: number;
  alarmInvocations: number;
  alarmWrites: number;
}
const counters = new WeakMap<DurableObjectStorage, RoomMetrics>();
const queries = new WeakMap<DurableObjectStorage, SqlStorage>();
const sockets = new WeakMap<WebSocket, RoomMetrics>();
export function enableLocalMetrics(storage: DurableObjectStorage, peers: WebSocket[] = []): void {
  const metrics: RoomMetrics = {
    incomingFrames: 0,
    incomingBytes: 0,
    outgoingFrames: 0,
    outgoingBytes: 0,
    maxFrameBytes: 0,
    projections: 0,
    maxProjectionBytes: 0,
    actions: 0,
    acknowledgements: 0,
    errors: 0,
    authentications: 0,
    reconnects: 0,
    sqlCalls: 0,
    sqlFailures: 0,
    sqlRowsRead: 0,
    sqlRowsWritten: 0,
    roomWrites: 0,
    serializedStateBytes: 0,
    maxStateBytes: 0,
    alarmInvocations: 0,
    alarmWrites: 0,
  };
  counters.set(storage, metrics);
  queries.delete(storage);
  for (const peer of peers) sockets.set(peer, metrics);
}
export function localMetrics(storage: DurableObjectStorage): RoomMetrics | null {
  const metrics = counters.get(storage);
  return metrics ? { ...metrics } : null;
}
export function countLocal(
  storage: DurableObjectStorage,
  key: 'actions' | 'authentications' | 'reconnects' | 'alarmInvocations' | 'alarmWrites',
): void {
  const metrics = counters.get(storage);
  if (metrics) metrics[key]++;
}
export function bindLocalSocket(socket: WebSocket, storage: DurableObjectStorage): void {
  const metrics = counters.get(storage);
  if (metrics) sockets.set(socket, metrics);
}
export function incomingLocal(socket: WebSocket, raw: string | ArrayBuffer): void {
  const metrics = sockets.get(socket);
  if (!metrics) return;
  metrics.incomingFrames++;
  metrics.incomingBytes +=
    typeof raw === 'string' ? new TextEncoder().encode(raw).length : raw.byteLength;
}
export function outgoingLocal(socket: WebSocket, raw: string, type: RoomMessage['type']): void {
  const metrics = sockets.get(socket);
  if (!metrics) return;
  const bytes = new TextEncoder().encode(raw).length;
  metrics.outgoingFrames++;
  metrics.outgoingBytes += bytes;
  metrics.maxFrameBytes = Math.max(metrics.maxFrameBytes, bytes);
  if (type === 'ack') metrics.acknowledgements++;
  if (type === 'error') metrics.errors++;
}
export function projectionLocal(socket: WebSocket, bytes: number): void {
  const metrics = sockets.get(socket);
  if (metrics) {
    metrics.projections++;
    metrics.maxProjectionBytes = Math.max(metrics.maxProjectionBytes, bytes);
  }
}
export function stateWriteLocal(storage: DurableObjectStorage, raw: string): void {
  const metrics = counters.get(storage);
  if (!metrics) return;
  const bytes = new TextEncoder().encode(raw).length;
  metrics.roomWrites++;
  metrics.serializedStateBytes += bytes;
  metrics.maxStateBytes = Math.max(metrics.maxStateBytes, bytes);
}

/** Preserve native cursor laziness/iteration and count deltas as rows are consumed. */
export function roomSql(storage: DurableObjectStorage): SqlStorage {
  const metrics = counters.get(storage);
  if (!metrics) return storage.sql;
  const cached = queries.get(storage);
  if (cached) return cached;
  const sql = new Proxy(storage.sql, {
    get(target, key) {
      if (key !== 'exec') return Reflect.get(target, key, target);
      return (query: string, ...bindings: SqlStorageValue[]) => {
        metrics.sqlCalls++;
        let cursor: SqlStorageCursor<Record<string, SqlStorageValue>>;
        try {
          cursor = target.exec(query, ...bindings);
        } catch (error) {
          metrics.sqlFailures++;
          throw error;
        }
        let reads = 0,
          writes = 0;
        const capture = () => {
          metrics.sqlRowsRead += cursor.rowsRead - reads;
          metrics.sqlRowsWritten += cursor.rowsWritten - writes;
          reads = cursor.rowsRead;
          writes = cursor.rowsWritten;
        };
        const wrap = (value: object): object =>
          new Proxy(value, {
            get(object, property) {
              const result = Reflect.get(object, property, object);
              if (typeof result !== 'function') return result;
              return (...args: unknown[]) => {
                try {
                  const returned = Reflect.apply(result, object, args);
                  return returned &&
                    typeof returned === 'object' &&
                    'next' in returned &&
                    typeof returned.next === 'function'
                    ? wrap(returned)
                    : returned;
                } finally {
                  capture();
                }
              };
            },
          });
        capture();
        return wrap(cursor);
      };
    },
  });
  queries.set(storage, sql);
  return sql;
}
