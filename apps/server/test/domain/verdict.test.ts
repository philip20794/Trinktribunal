import { describe, expect, it } from 'vitest';
import fixture from '../../../../packages/protocol/fixtures/transitions/verdict-normal.json';
import personalFixture from '../../../../packages/protocol/fixtures/transitions/verdict-all-judges.json';
import { normalVerdict, allJudgesVerdict } from '../../src/domain/verdict';
import { RoomIds } from '../../src/protocol/room_message';

describe('normal server verdict', () => {
  it('executes the preserved TT-003 personal fixture with no additional co-drinking', () => {
    const { input, expected } = personalFixture;
    const result = allJudgesVerdict(
      input.trueAscendingIds.map((id, index) => ({
        playerId: RoomIds.player(id),
        number: index + 1,
      })),
      Object.entries(input.privateProposals).map(([id, order]) => ({
        playerId: RoomIds.player(id),
        order: order.map(RoomIds.player),
      })),
    );
    expect(result).toEqual(expected.privateErrors);
    expect(result).toEqual(expected.privateSipCounts);
    expect(Object.isFrozen(result)).toBe(true);
  });
  it('requires exactly one complete immutable proposal per number recipient', () => {
    const a = RoomIds.player('A'),
      b = RoomIds.player('B'),
      numbers = [
        { playerId: a, number: 1 },
        { playerId: b, number: 3 },
      ],
      orders = [
        { playerId: a, order: [a, b] },
        { playerId: b, order: [b, a] },
      ];
    for (const bad of [
      orders.slice(0, 1),
      [orders[0]!, orders[0]!],
      [orders[0]!, { playerId: RoomIds.player('C'), order: [a, b] }],
      [orders[0]!, { playerId: b, order: [a, a] }],
    ])
      expect(() => allJudgesVerdict(numbers, bad)).toThrow();
    expect(() =>
      allJudgesVerdict(
        [
          { playerId: a, number: 1 },
          { playerId: b, number: 1 },
        ],
        orders,
      ),
    ).toThrow();
    expect(() =>
      allJudgesVerdict(
        [
          { playerId: a, number: 1 },
          { playerId: b, number: 61 },
        ],
        orders,
      ),
    ).toThrow();
  });
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
