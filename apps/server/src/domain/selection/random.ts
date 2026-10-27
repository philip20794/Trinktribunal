import { randomInt } from 'node:crypto';

export type RandomIndex = (upperBound: number) => number;
/** Unbiased CSPRNG; never persist a public seed or expose a future draw. */
export const secureRandomIndex: RandomIndex = (bound) => randomInt(bound);
export function choose<T>(values: readonly T[], random: RandomIndex): T {
  if (!values.length) throw new Error('CONTENT_EXHAUSTED');
  const index = random(values.length);
  if (!Number.isSafeInteger(index) || index < 0 || index >= values.length)
    throw new Error('INVALID_RANDOM');
  return values[index]!;
}
