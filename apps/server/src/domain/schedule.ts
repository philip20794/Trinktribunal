import { choose, type RandomIndex } from './selection/random';

export function planSlots(
  targetCases: number,
  requestedRuleEvents: number,
  random: RandomIndex,
): number[] {
  if (
    !Number.isInteger(targetCases) ||
    targetCases < 1 ||
    targetCases > 491 ||
    !Number.isInteger(requestedRuleEvents) ||
    requestedRuleEvents < 0 ||
    requestedRuleEvents > 25
  )
    throw new Error('INVALID_CONFIG');
  const gaps = targetCases - 1,
    count = Math.min(requestedRuleEvents, gaps);
  if (!count) return [];
  let start = 1;
  const segments = Array.from({ length: count }, (_, index) => {
    const size = Math.floor(gaps / count) + (index < gaps % count ? 1 : 0);
    const segment = Array.from({ length: size }, (_, offset) => start + offset);
    start += size;
    return segment;
  });
  const spacing = gaps >= 2 * count - 1 ? 2 : 1;
  const canComplete = (index: number, previous: number) => {
    for (let next = index; next < segments.length; next++) {
      previous = Math.max(segments[next]![0]!, previous + spacing);
      if (previous > segments[next]!.at(-1)!) return false;
    }
    return true;
  };
  const slots: number[] = [];
  segments.forEach((segment, index) =>
    slots.push(
      choose(
        segment.filter(
          (slot) =>
            (!slots.length || slot - slots.at(-1)! >= spacing) && canComplete(index + 1, slot),
        ),
        random,
      ),
    ),
  );
  return slots;
}
