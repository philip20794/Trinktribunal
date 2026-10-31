import { describe, expect, it } from 'vitest';
import { catalogs, type ContentEntry, type RuleCategory } from '../../src/domain/catalogs';
import { activateRule } from '../../src/domain/drinking_rules';
import type { UsageEvent } from '../../src/domain/game_state';
import type { SelectionInput } from '../../src/domain/question_assignment';
import { selectCategorizedRule } from '../../src/domain/selection/rule_category_selection';

const now = Date.parse('2026-10-31T12:00:00.000Z');
const categories = ['drinking_ritual', 'speech', 'behavior'] as const;
const samples: ContentEntry[] = [
  ...Array.from({ length: 15 }, (_, i) => ({ id: `r${i}`, text: 'r', category: 'drinking_ritual' as const })),
  ...Array.from({ length: 7 }, (_, i) => ({ id: `s${i}`, text: 's', category: 'speech' as const })),
  ...Array.from({ length: 3 }, (_, i) => ({ id: `b${i}`, text: 'b', category: 'behavior' as const })),
];
const event = (id: string, index = 0, timestamp = now): UsageEvent => ({
  eventId: `e_${id}_${index}`, contentId: id,
  kind: 'rule', timestampUtc: new Date(timestamp).toISOString(),
});
function input(
  drawn: readonly string[] = [],
  history: readonly UsageEvent[] = [],
  plannedRuleEvents = 9,
): SelectionInput {
  return { players: [], counts: {}, history, drawn, now, plannedRuleEvents };
}
function pick(
  catalog: readonly ContentEntry[], drawn: readonly string[] = [],
  history: readonly UsageEvent[] = [], random: (bound: number) => number = () => 0,
  planned = 9,
): ContentEntry {
  const candidates = catalog.filter((entry) => !drawn.includes(entry.id));
  return selectCategorizedRule(catalog, candidates, input(drawn, history, planned), random);
}

describe('weighted categories for drinking rules', () => {
  it('keeps the production assignments identical in DE and EN', () => {
    const de = catalogs.de.rules, en = catalogs.en.rules;
    expect(de.map(({ id, category }) => [id, category])).toEqual(
      en.map(({ id, category }) => [id, category]),
    );
    for (const [category, count] of [
      ['drinking_ritual', 15], ['speech', 7], ['behavior', 3],
    ] as const) expect(de.filter((rule) => rule.category === category)).toHaveLength(count);
  });

  it('limits a nine-rule party to seven per category, without requiring all three', () => {
    let history: UsageEvent[] = [];
    const drawn: string[] = [];
    for (let i = 0; i < 9; i++) {
      const selected = pick(samples, drawn, history, () => 0);
      expect(drawn).not.toContain(selected.id);
      drawn.push(selected.id);
      history = [...history, event(selected.id, i)];
    }
    const counts = categories.map((category) =>
      samples.filter((rule) => rule.category === category && drawn.includes(rule.id)).length,
    );
    expect(counts).toEqual([7, 2, 0]);
  });

  it('does not impose category diversity for only two planned rules', () => {
    const first = pick(samples, [], [], () => 0, 2);
    const second = pick(samples, [first.id], [], () => 0, 2);
    expect([first.category, second.category]).toEqual(['drinking_ritual', 'drinking_ritual']);
  });

  it('keeps the existing minimum six-hour counter within the selected category', () => {
    const catalog: ContentEntry[] = [
      { id: 'old', text: 'old', category: 'drinking_ritual' },
      { id: 'fresh', text: 'fresh', category: 'drinking_ritual' },
      { id: 'spoken', text: 'spoken', category: 'speech' },
    ];
    expect(pick(catalog, [], [event('old')], () => 0).id).toBe('fresh');
  });

  it('penalizes high historical category use, but ignores expired uses', () => {
    const catalog: ContentEntry[] = [
      { id: 'r', text: 'r', category: 'drinking_ritual' },
      { id: 's', text: 's', category: 'speech' },
    ];
    const random = (bound: number) => bound > 1 ? 300 : 0;
    expect(pick(catalog, [], [], random).id).toBe('r');
    const recent = [event('r', 1), event('r', 2), event('r', 3)];
    expect(pick(catalog, [], recent, random).id).toBe('s');
    const expired = [event('r', 4, now - 6 * 60 * 60 * 1000)];
    expect(pick(catalog, [], expired, random).id).toBe('r');
  });

  it('honors conflict and role feasibility filters before category choice', () => {
    const catalog: ContentEntry[] = [
      { id: 'r1', text: 'r1', category: 'drinking_ritual', excludes: ['r2'] },
      { id: 'r2', text: 'r2', category: 'drinking_ritual', excludes: ['r1'] },
      { id: 's1', text: 's1', category: 'speech' },
      { id: 'b1', text: '{player1}', category: 'behavior',
        players: { player1: { selection: 'random' } } },
    ];
    const first = activateRule(catalog, [], input(), () => 0)!;
    expect(first.contentId).toBe('r1');
    const second = activateRule(catalog, [first], input(['r1']), () => 0)!;
    expect(second.contentId).toBe('s1');
    expect(activateRule(catalog, [first, second], input(['r1', 's1']), () => 0)).toBeNull();
  });

  it('falls back to the only feasible category instead of dropping a slot', () => {
    const catalog = samples.filter((rule) => rule.category === 'drinking_ritual');
    const drawn = catalog.slice(0, 2).map((rule) => rule.id);
    expect(pick(catalog, drawn, [], () => 0, 3).category).toBe('drinking_ritual');
  });

  it('keeps category-free old fixtures on the original minimum-counter logic', () => {
    const catalog: ContentEntry[] = [{ id: 'used', text: 'used' }, { id: 'new', text: 'new' }];
    expect(pick(catalog, [], [event('used')], () => 0).id).toBe('new');
  });

  it('varies category mixes across seeded games, and rarely uses the smallest category', () => {
    let seed = 704;
    const random = (bound: number) => {
      seed = (Math.imul(seed, 1664525) + 1013904223) >>> 0;
      return seed % bound;
    };
    const counts: Record<RuleCategory, number> = {
      drinking_ritual: 0, speech: 0, behavior: 0,
    };
    let withoutBehavior = 0;
    let withBehavior = 0;
    for (let game = 0; game < 250; game++) {
      const drawn: string[] = [];
      for (let index = 0; index < 9; index++) {
        const rule = pick(samples, drawn, [], random);
        drawn.push(rule.id);
        counts[rule.category!]++;
      }
      const categoryCounts = categories.map((category) =>
        samples.filter((rule) => rule.category === category && drawn.includes(rule.id)).length,
      );
      expect(Math.max(...categoryCounts)).toBeLessThanOrEqual(7);
      if (categoryCounts[2] === 0) withoutBehavior++;
      else withBehavior++;
    }
    expect(counts.drinking_ritual).toBeGreaterThan(counts.speech);
    expect(counts.speech).toBeGreaterThan(counts.behavior);
    expect(withBehavior).toBeGreaterThan(100);
    expect(withBehavior).toBeLessThan(200);
    expect(withoutBehavior).toBeGreaterThan(0);
  });

  it('rejects an invalid injected category random index', () => {
    expect(() => pick(samples, [], [], (bound) => bound)).toThrow('INVALID_RANDOM');
  });
});
