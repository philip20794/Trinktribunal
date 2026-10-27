import { describe, expect, it } from 'vitest';
import bounds from '../../../../packages/protocol/fixtures/rules/secret-number-bounds.json';
import binding from '../../../../packages/protocol/fixtures/rules/person-binding.json';
import historyFixture from '../../../../packages/protocol/fixtures/rules/history-window.json';
import { canonicalJson } from '../../../../packages/protocol/schema-validation.mjs';
import { catalogs, catalogHash, type ContentEntry } from '../../src/domain/catalogs';
import { activateRule, rebindRules } from '../../src/domain/drinking_rules';
import { assignNumbers, numberLimit } from '../../src/domain/numbers';
import { assignContent, type SelectionInput } from '../../src/domain/question_assignment';
import { planSlots } from '../../src/domain/schedule';
import { recentCount } from '../../src/domain/selection/content_selection';
import {
  personAssignment,
  recordPersons,
  withParticipant,
} from '../../src/domain/selection/person_assignment';
import { secureRandomIndex } from '../../src/domain/selection/random';
import type { Assignment, PlayerId } from '../../src/protocol/room_message.generated';
import type { UsageEvent } from '../../src/domain/game_state';
import { gamePorts } from '../../src/domain/game_ports';
import { initialGameState, transition } from '../../src/domain/game_reducer';
import { RoomIds, currentProtocolCatalogHash } from '../../src/protocol/room_message';

declare const __TT_PARITY_FIXTURE__: string;
const suite = JSON.parse(__TT_PARITY_FIXTURE__);
// Fixture DTOs are test-only; both runners compare actual domain results to the same JSON.
function evaluate(c: Record<string, any>): unknown {
  const indices: number[] = [...(c.indices ?? [])];
  const random = (bound: number) => {
    const index = indices.shift() ?? 0;
    if (index >= bound) throw new Error('INVALID_FIXTURE_RANDOM');
    return index;
  };
  const players = (c.players ?? []).map(RoomIds.player) as PlayerId[];
  const entries = (list: Record<string, any>[]): ContentEntry[] =>
    list.map((entry) => ({
      id: entry.id,
      text: entry.id,
      players: entry.roles,
      excludes: entry.excludes ?? [],
    }));
  switch (c.operation) {
    case 'cycle': {
      let counts = { ...c.counts };
      const chosen: PlayerId[] = [];
      for (let index = 0; index < c.entries; index++) {
        const binding = personAssignment(
          { player1: { selection: 'random' } },
          players,
          counts,
        ).bind(random)!;
        chosen.push(binding.player1!);
        counts = recordPersons(counts, Object.values(binding));
      }
      return { chosen, counts };
    }
    case 'numbers': {
      const max = numberLimit(players.length, c.factorTenths);
      return {
        max,
        numbers: Object.fromEntries(
          assignNumbers(players, RoomIds.player(c.judge), max, c.allJudges, random).map((entry) => [
            entry.playerId,
            entry.number,
          ]),
        ),
      };
    }
    case 'schedule':
      return planSlots(c.targetCases, c.requestedRuleEvents, random);
    case 'bind': {
      const bindings = personAssignment(c.roles, players, c.counts).bind(random);
      return {
        bindings,
        counts: bindings ? recordPersons(c.counts, Object.values(bindings)) : c.counts,
      };
    }
    case 'join':
      return (c.newPlayers as string[]).reduce(
        (counts, id) => withParticipant(counts, RoomIds.player(id), players),
        c.counts,
      );
    case 'history':
      return Object.fromEntries(
        ['001-a', '001-b'].map((id) => [
          id,
          recentCount(c.events, 'question', id, Date.parse(c.nowUtc)),
        ]),
      );
    case 'sequence': {
      const questions = entries(c.questions),
        rules = entries(c.rules),
        history: UsageEvent[] = structuredClone(c.history ?? []),
        drawn: { question: string[]; rule: string[] } = { question: [], rule: [] },
        active: Assignment[] = [],
        assignments: Array<Assignment | null> = [];
      let counts = { ...c.counts };
      for (const kind of c.actions as Array<'question' | 'rule'>) {
        const input: SelectionInput = {
          players,
          counts,
          history,
          drawn: drawn[kind],
          now: Date.parse(c.nowUtc),
        };
        const assignment =
          kind === 'question'
            ? assignContent(questions, kind, input, random)
            : activateRule(rules, active, input, random);
        assignments.push(assignment);
        if (!assignment) continue;
        counts = recordPersons(counts, Object.values(assignment.bindings));
        drawn[kind].push(assignment.contentId);
        history.push({
          eventId: `event_${history.length}`,
          kind,
          contentId: assignment.contentId,
          timestampUtc: c.nowUtc,
        });
        if (kind === 'rule') active.push(assignment);
      }
      return { assignments, counts, historyLength: history.length };
    }
    case 'rebind': {
      const result = rebindRules(
        entries(c.rules),
        c.active,
        { players, counts: c.counts, history: [], drawn: [], now: 0 },
        random,
      );
      return {
        activeRules: result.activeRules,
        counts: Object.fromEntries(
          result.personCounts.map((entry) => [entry.playerId, entry.count]),
        ),
      };
    }
    default:
      throw new Error('UNKNOWN_FIXTURE');
  }
}
describe('canonical Dart/TypeScript selection parity', () => {
  for (const c of suite.cases)
    it(c.id, () => expect(canonicalJson(evaluate(c))).toBe(canonicalJson(c.expected)));
  it('does not silently accept a changed expected value', () => {
    const c = structuredClone(suite.cases[0]);
    c.expected = { invalid: true };
    expect(() => expect(canonicalJson(evaluate(c))).toBe(canonicalJson(c.expected))).toThrow();
  });
});

describe('existing TT-003/007/008 fixtures and production invariants', () => {
  it('uses the existing integer bounds fixture', () =>
    expect(
      bounds.input.factorTenths.map((factor) => numberLimit(bounds.input.playerCount, factor)),
    ).toEqual(bounds.expected.maxSecretNumbers));
  it('uses the existing binding fixture', () => {
    const actual = personAssignment(
      binding.input.roles,
      binding.input.activePlayerIds.map(RoomIds.player),
      binding.input.countersBefore,
    ).bind(() => 0)!;
    expect(actual).toEqual(binding.expected.binding);
    expect(recordPersons(binding.input.countersBefore, Object.values(actual))).toEqual(
      binding.expected.countersAfter,
    );
  });
  it('uses the existing six-hour cutoff fixture', () => {
    const history = historyFixture.input.ids.map((contentId, index) => ({
      contentId,
      eventId: `e${index}`,
      kind: 'question' as const,
      timestampUtc: historyFixture.input.previousUtc[index]!,
    }));
    expect(
      Object.fromEntries(
        Object.keys(historyFixture.expected.recentCounts).map((id) => [
          id,
          recentCount(history, 'question', id, Date.parse(historyFixture.input.nowUtc)),
        ]),
      ),
    ).toEqual(historyFixture.expected.recentCounts);
  });
  it('validates production hashes once and retains language-neutral IDs/constraints', () => {
    expect(catalogHash).toBe(currentProtocolCatalogHash);
    for (const language of ['de', 'en'] as const) {
      expect(catalogs[language].questions).toHaveLength(491);
      expect(catalogs[language].rules).toHaveLength(25);
      expect(Object.isFrozen(catalogs[language].questions)).toBe(true);
    }
    const signature = (language: 'de' | 'en') =>
      Object.values(catalogs[language]).map((entries) =>
        entries.map((entry: ContentEntry) => ({
          id: entry.id,
          roles: entry.players ?? {},
          excludes: entry.excludes ?? [],
        })),
      );
    expect(signature('en')).toEqual(signature('de'));
  });
  it('reproduces actual core draws across both content languages with injected choices', () => {
    const run = (language: 'de' | 'en') => {
      let id = 0;
      const ports = gamePorts(
        () => {
          throw new Error('SCORING_NOT_REQUESTED');
        },
        {
          newId: (kind) => `${kind}_${id++}`,
          now: () => Date.parse('2026-10-27T12:00:00Z'),
          randomIndex: () => 0,
        },
      );
      const state = initialGameState({
        hostId: RoomIds.player('C'),
        roster: ['A', 'B', 'C'].map(RoomIds.player),
        config: {
          targetCases: 3,
          requestedRuleEvents: 2,
          factorTenths: 15,
          allJudges: false,
          contentLanguage: language,
        },
      });
      const result = transition(
        state,
        state.hostId,
        { type: 'startGame', protocolVersion: 1, actionId: 'start', expectedRevision: 0 },
        ports,
      );
      expect(result.ok).toBe(true);
      return result.state;
    };
    const de = run('de'),
      en = run('en');
    expect(de.round).toEqual(en.round);
    expect(de.history).toEqual(en.history);
    expect(de.personCounts).toEqual(en.personCounts);
    expect(de.ruleSlots).toEqual(en.ruleSlots);
  });
  it('schedules every supported density with bounded draws and no rejection loop', () => {
    for (let f = 1; f <= 491; f++)
      for (const r of [0, 1, 7, 25]) {
        let calls = 0;
        const slots = planSlots(f, r, (bound) => {
          calls++;
          return bound - 1;
        });
        expect(calls).toBe(Math.min(r, f - 1));
        expect(new Set(slots).size).toBe(slots.length);
        if (f - 1 >= 2 * slots.length - 1)
          expect(slots.every((slot, index) => !index || slot - slots[index - 1]! >= 2)).toBe(true);
      }
  });
  it('draws unique numbers for every supported N and factor, including all judges', () => {
    for (let n = 3; n <= 20; n++)
      for (let factor = 10; factor <= 30; factor++)
        for (const all of [false, true]) {
          const players = Array.from({ length: n }, (_, i) => RoomIds.player(`p${i}`)),
            max = numberLimit(n, factor),
            numbers = assignNumbers(players, players[0]!, max, all, (bound) => bound - 1);
          expect(numbers).toHaveLength(all ? n : n - 1);
          expect(new Set(numbers.map((entry) => entry.number)).size).toBe(numbers.length);
          expect(numbers.every((entry) => entry.number >= 1 && entry.number <= max)).toBe(true);
        }
  });
  it('rejects invalid injected randomness and configurations; uses bounded crypto draws', () => {
    expect(() => planSlots(6, 2, () => -1)).toThrow();
    expect(() => planSlots(0, 2, () => 0)).toThrow();
    expect(() => numberLimit(3, 9)).toThrow();
    for (const bound of [1, 2, 20, 491])
      for (let i = 0; i < 8; i++) {
        const index = secureRandomIndex(bound);
        expect(index).toBeGreaterThanOrEqual(0);
        expect(index).toBeLessThan(bound);
      }
  });
});
