import { describe, expect, it } from 'vitest';
import fixture from '../../../../packages/protocol/fixtures/transitions/verdict-normal.json';
import { normalVerdict } from '../../src/domain/verdict';
import { RoomIds } from '../../src/protocol/room_message';

describe('normal server verdict', () => {
  it('executes the existing shared TT-003 wrong-position fixture', () => {
    const { input, expected } = fixture;
    const verdict = normalVerdict(
      RoomIds.player(input.judgeId),
      input.trueAscendingIds.map((id, index) => ({
        playerId: RoomIds.player(id),
        number: index + 1,
      })),
      input.proposedAscendingIds.map(RoomIds.player),
    );
    expect(verdict.errors).toBe(expected.wrongPositionCount);
    expect(verdict.incorrect).toEqual(expected.misplacedPlayerIds);
    expect(verdict.sipCounts).toEqual(expected.sipCounts);
  });
  it('rejects incomplete, duplicate and foreign orders and nonunique numbers', () => {
    const judge = RoomIds.player('J'),
      a = RoomIds.player('A'),
      b = RoomIds.player('B'),
      numbers = [
        { playerId: a, number: 1 },
        { playerId: b, number: 5 },
      ];
    for (const proposed of [[a], [a, a], [a, RoomIds.player('C')]])
      expect(() => normalVerdict(judge, numbers, proposed)).toThrow();
    expect(() =>
      normalVerdict(judge, [...numbers, { playerId: judge, number: 9 }], [a, b, judge]),
    ).toThrow();
    expect(() => normalVerdict(judge, [numbers[0]!, { playerId: b, number: 1 }], [a, b])).toThrow();
    expect(() =>
      normalVerdict(judge, [numbers[0]!, { playerId: b, number: 61 }], [a, b]),
    ).toThrow();
  });
});
