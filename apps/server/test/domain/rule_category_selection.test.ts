import { describe, expect, it } from 'vitest';
import { catalogs, type ContentEntry, type RuleCategory } from '../../src/domain/catalogs';
import { activateRule } from '../../src/domain/drinking_rules';
import type { UsageEvent } from '../../src/domain/game_state';
import type { SelectionInput } from '../../src/domain/question_assignment';
import { selectCategorizedRule } from '../../src/domain/selection/rule_category_selection';

const now = Date.parse('2026-10-31T12:00:00.000Z');
const categories = ['drinking_ritual', 'other', 'forbidden_words'] as const;
const samples: ContentEntry[] = [
  ...Array.from({ length: 16 }, (_, i) => ({
    id: `r${i}`,
    text: 'r',
    category: 'drinking_ritual' as const,
  })),
  ...Array.from({ length: 14 }, (_, i) => ({ id: `o${i}`, text: 'o', category: 'other' as const })),
  ...Array.from({ length: 20 }, (_, i) => ({
    id: `w${i}`,
    text: 'w',
    category: 'forbidden_words' as const,
  })),
];
const event = (id: string, index = 0, timestamp = now): UsageEvent => ({
  eventId: `e_${id}_${index}`,
  contentId: id,
  kind: 'rule',
  timestampUtc: new Date(timestamp).toISOString(),
});
function input(
  drawn: readonly string[] = [],
  history: readonly UsageEvent[] = [],
  plannedRuleEvents = 9,
): SelectionInput {
  return { players: [], counts: {}, history, drawn, now, plannedRuleEvents };
}
function pick(
  catalog: readonly ContentEntry[],
  drawn: readonly string[] = [],
  history: readonly UsageEvent[] = [],
  random: (bound: number) => number = () => 0,
  planned = 9,
): ContentEntry {
  const candidates = catalog.filter((entry) => !drawn.includes(entry.id));
  return selectCategorizedRule(catalog, candidates, input(drawn, history, planned), random);
}

describe('weighted categories for drinking rules', () => {
  it('keeps the production assignments identical in DE and EN', () => {
    const de = catalogs.de.rules,
      en = catalogs.en.rules;
    expect(de.map(({ id, category }) => [id, category])).toEqual(
      en.map(({ id, category }) => [id, category]),
    );
    for (const [category, count] of [
      ['drinking_ritual', 16],
      ['other', 12],
      ['forbidden_words', 11],
    ] as const)
      expect(de.filter((rule) => rule.category === category)).toHaveLength(count);
  });

  it('migrates previous speech and behavior rules into other', () => {
    const rules = catalogs.de.rules;
    expect(rules).toHaveLength(39);
    expect(rules.slice(30).map((rule) => rule.id)).toEqual([
      'forbid_und',
      'forbid_also',
      'forbid_halt',
      'forbid_irgendwie',
      'forbid_so',
      'thinking_long_pause',
      'thinking_stretch_word',
      'story_gesture',
      'thinking_noise',
    ]);
    for (const id of ['pointing_penalty', 'formal_address', 'motion_denied'])
      expect(rules.find((rule) => rule.id === id)?.category).toBe('other');
    for (const id of ['swear_penalty', 'no_drink_word', 'no_also_start', 'forbid_und'])
      expect(rules.find((rule) => rule.id === id)?.category).toBe('forbidden_words');
    expect(rules.every((rule) => categories.includes(rule.category as RuleCategory))).toBe(true);
  });

  it('limits a nine-rule party to five when three categories are feasible', () => {
    let history: UsageEvent[] = [];
    const drawn: string[] = [];
    for (let i = 0; i < 9; i++) {
      const selected = pick(samples, drawn, history, () => 0);
      expect(drawn).not.toContain(selected.id);
      drawn.push(selected.id);
      history = [...history, event(selected.id, i)];
    }
    const counts = categories.map(
      (category) =>
        samples.filter((rule) => rule.category === category && drawn.includes(rule.id)).length,
    );
    expect(Math.max(...counts)).toBeLessThanOrEqual(5);
    expect(counts.reduce((sum, count) => sum + count, 0)).toBe(9);
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
      { id: 'spoken', text: 'spoken', category: 'other' },
    ];
    expect(pick(catalog, [], [event('old')], () => 0).id).toBe('fresh');
  });

  it('penalizes high historical category use, but ignores expired uses', () => {
    const catalog: ContentEntry[] = [
      { id: 'r', text: 'r', category: 'drinking_ritual' },
      { id: 's', text: 's', category: 'other' },
    ];
    const random = (bound: number) => (bound > 1 ? 300 : 0);
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
      { id: 's1', text: 's1', category: 'other' },
      {
        id: 'b1',
        text: '{player1}',
        category: 'other',
        players: { player1: { selection: 'random' } },
      },
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
    const catalog: ContentEntry[] = [
      { id: 'used', text: 'used' },
      { id: 'new', text: 'new' },
    ];
    expect(pick(catalog, [], [event('used')], () => 0).id).toBe('new');
  });

  it('varies the mix across seeded games while respecting both category caps', () => {
    let seed = 704;
    const random = (bound: number) => {
      seed = (Math.imul(seed, 1664525) + 1013904223) >>> 0;
      return seed % bound;
    };
    const observedMixes = new Set<string>();
    const counts: Record<RuleCategory, number> = {
      drinking_ritual: 0,
      other: 0,
      forbidden_words: 0,
    };
    for (let game = 0; game < 250; game++) {
      const drawn: string[] = [];
      for (let index = 0; index < 9; index++) {
        const rule = pick(samples, drawn, [], random);
        drawn.push(rule.id);
        counts[rule.category!] += 1;
      }
      const categoryCounts = categories.map(
        (category) =>
          samples.filter((rule) => rule.category === category && drawn.includes(rule.id)).length,
      );
      expect(Math.max(...categoryCounts)).toBeLessThanOrEqual(5);
      observedMixes.add(categoryCounts.join(':'));
    }
    expect(counts.drinking_ritual).toBeGreaterThan(0);
    expect(counts.other).toBeGreaterThan(0);
    expect(counts.forbidden_words).toBeGreaterThan(0);
    expect(observedMixes.size).toBeGreaterThan(1);
  });

  it('rejects an invalid injected category random index', () => {
    expect(() => pick(samples, [], [], (bound) => bound)).toThrow('INVALID_RANDOM');
  });
});
