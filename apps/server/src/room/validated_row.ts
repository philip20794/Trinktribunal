// One checked byte sequence per live storage instance, never an authoritative
// mutable state. Every read still reads SQLite; eviction simply loses this hint.
const checkedRows = new WeakMap<DurableObjectStorage, string>();
export function isValidatedRow(storage: DurableObjectStorage, raw: string): boolean {
  return checkedRows.get(storage) === raw;
}
export function rememberValidatedRow(storage: DurableObjectStorage, raw: string): void {
  checkedRows.set(storage, raw);
}
export function forgetValidatedRow(storage: DurableObjectStorage): void {
  checkedRows.delete(storage);
}
