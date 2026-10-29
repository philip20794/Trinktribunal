import { describe, expect, it } from 'vitest';
import suite from '../../../../packages/protocol/fixtures/transitions/core/v1.json';
import {
  hostDeadline,
  initialGameState,
  presenceChanged,
  stageRoster,
  transition,
} from '../../src/domain/game_reducer';
import type { GamePorts, GameState, MutableGameState, Phase } from '../../src/domain/game_state';
import { RoomIds } from '../../src/protocol/room_message';
import type { Config, PlayerId } from '../../src/protocol/room_message.generated';

const ids = ['A', 'B', 'C'].map(RoomIds.player);
const config: Config = {
  targetCases: 3,
  requestedRuleEvents: 0,
  factorTenths: 15,
  allJudges: false,
  contentLanguage: 'de',
};

for (const allJudges of [false, true]) {
  it(`rotating case guide can advance the round without host privileges: allJudges=${allJudges}`, () => {
    const dependencies = ports([1]);
    let state = apply(lobby({ allJudges, requestedRuleEvents: 1 }), 'startGame', dependencies);
    state = apply(state, 'completeWithoutVerdict', dependencies);
    const guide = ids[1]!,
      other = ids[2]!;
    expect(state.config.allJudges ? state.readerId : state.judgeId).toBe(guide);
    expect(state.phase).toBe('rule_event');
    expect(
      transition(state, other, command(state, 'continueRule', { afterCase: 1 }), dependencies),
    ).toMatchObject({ ok: false, code: 'UNAUTHORIZED_ACTION' });
    state = apply(state, 'continueRule', dependencies, { afterCase: 1 }, guide);
    for (const recipient of state.round!.recipients)
      state = apply(state, 'acknowledgeNumber', dependencies, {}, recipient);
    for (const participant of state.round!.roster)
      state = apply(state, 'readyForOrdering', dependencies, {}, participant);
    expect(transition(state, other, command(state, 'beginOrdering'), dependencies)).toMatchObject({
      ok: false,
      code: 'UNAUTHORIZED_ACTION',
    });
    state = apply(state, 'beginOrdering', dependencies, {}, guide);
    const order = [...state.round!.recipients];
    for (const participant of allJudges ? order : [guide])
      state = apply(state, 'submitOrder', dependencies, { order }, participant);
    expect(state.phase).toBe('revealing');
    expect(
      transition(state, other, command(state, 'revealNext', { expectedCursor: 0 }), dependencies),
    ).toMatchObject({ ok: false, code: 'UNAUTHORIZED_ACTION' });
    while (state.phase === 'revealing')
      state = apply(
        state,
        'revealNext',
        dependencies,
        { expectedCursor: state.round!.revealCursor },
        guide,
      );
    expect(transition(state, other, command(state, 'completeCase'), dependencies)).toMatchObject({
      ok: false,
      code: 'UNAUTHORIZED_ACTION',
    });
    expect(
      transition(state, guide, command(state, 'completeWithoutVerdict'), dependencies),
    ).toMatchObject(allJudges ? { ok: false, code: 'UNAUTHORIZED_ACTION' } : { ok: true });
    state = apply(state, 'completeCase', dependencies, {}, guide);
    expect(state.completedCases).toBe(2);
    expect(state.config.allJudges ? state.readerId : state.judgeId).toBe(other);
  });
}
function ports(slots: number[] = [], exclude = false): GamePorts {
  let serial = 0;
  return {
    now: () => 1000,
    newId: (kind) => `${kind}_${serial++}`,
    randomIndex: () => 0,
    rebindRules: (state) => ({
      activeRules: structuredClone(state.activeRules) as MutableGameState['activeRules'],
      personCounts: structuredClone(state.personCounts) as MutableGameState['personCounts'],
    }),
    planSlots: () => slots,
    prepareCase: (state) => {
      const contentId = suite.questions.find((id) => !state.drawnQuestionIds.includes(id));
      return contentId
        ? {
            question: { contentId, bindings: {} },
            numbers: state.effectiveRoster
              .filter((id) => state.config.allJudges || id !== state.judgeId)
              .map((playerId, index) => ({ playerId, number: index + 1 })),
          }
        : null;
    },
    activateRule: (state) => {
      const contentId =
        exclude && state.drawnRuleIds.length
          ? undefined
          : suite.rules.find((id) => !state.drawnRuleIds.includes(id));
      return contentId ? { contentId, bindings: {} } : null;
    },
    scoreRound: (state) =>
      state.config.allJudges
        ? {
            kind: 'all_judges',
            results: state.round!.recipients.map((playerId) => ({ playerId, errors: 0, sips: 0 })),
          }
        : {
            kind: 'normal',
            errors: 0,
            penalties: state.round!.roster.map((playerId) => ({ playerId, sips: 0 })),
          },
  };
}
let serial = 0;
function command(state: GameState, type: string, extra: Record<string, unknown> = {}) {
  return {
    type,
    protocolVersion: 2,
    actionId: `action_${serial++}`,
    expectedRevision: state.revision,
    ...(!['startGame', 'setConfig'].includes(type) ? { gameId: state.gameId } : {}),
    ...([
      'acknowledgeNumber',
      'readyForOrdering',
      'beginOrdering',
      'submitOrder',
      'revealNext',
      'completeCase',
      'completeWithoutVerdict',
    ].includes(type)
      ? { roundId: state.round?.id }
      : {}),
    ...(['restartGame', 'submitOrder', 'completeWithoutVerdict'].includes(type)
      ? { confirmed: true }
      : {}),
    ...extra,
  };
}
function apply(
  state: GameState,
  type: string,
  dependencies: GamePorts,
  extra: Record<string, unknown> = {},
  actor = state.hostId,
): GameState {
  const result = transition(state, actor, command(state, type, extra), dependencies);
  expect(result, type).toMatchObject({ ok: true });
  return result.state;
}
function lobby(overrides: Partial<Config> = {}, hostId = ids[0]!) {
  return initialGameState({ hostId, roster: ids, config: { ...config, ...overrides } });
}
function normalize(state: GameState) {
  return {
    phase: state.phase,
    completed: state.completedCases,
    judge: state.judgeId,
    question: state.round?.question.contentId ?? state.lastCompletion?.questionId,
    drawn: state.drawnQuestionIds.length,
    rules: state.activeRules.length,
    skippedRules: state.ruleSlots.filter((slot) => slot.status === 'skipped').length,
    roster: state.effectiveRoster,
  };
}

describe('shared Dart/TypeScript transition fixtures', () => {
  it('new participant uses the maximum of surviving active identities rather than a departed counter', () => {
    const dependencies = ports();
    let state = apply(lobby(), 'startGame', dependencies);
    const changed = structuredClone(state) as MutableGameState;
    changed.personCounts = [
      { playerId: ids[0]!, count: 7 },
      { playerId: ids[1]!, count: 19 },
      { playerId: ids[2]!, count: 7 },
    ];
    state = stageRoster(changed, [ids[0]!, ids[2]!, RoomIds.player('D')], 2000);
    state = apply(state, 'completeWithoutVerdict', dependencies);
    expect(state.personCounts.find((p) => p.playerId === 'D')?.count).toBe(7);
    expect(state.personCounts.find((p) => p.playerId === ids[1])?.count).toBe(19);
  });
  for (const scenario of suite.scenarios)
    it(scenario.id, () => {
      const dependencies = ports(scenario.ruleSlots, scenario.excludeRules);
      let state = lobby({
        targetCases: scenario.targetCases,
        requestedRuleEvents: scenario.ruleSlots.length,
      });
      for (const step of scenario.steps) {
        if (step.action === 'roster')
          state = stageRoster(
            state,
            ('roster' in step ? step.roster! : []).map(RoomIds.player),
            1000,
          );
        else {
          const type = (
            {
              start: 'startGame',
              skip: 'completeWithoutVerdict',
              skipUnconfirmed: 'completeWithoutVerdict',
              continueRule: 'continueRule',
              resume: 'resumePaused',
            } as Record<string, string>
          )[step.action]!;
          const action = command(
            state,
            type,
            step.action === 'continueRule'
              ? { afterCase: state.completedCases }
              : step.action === 'skipUnconfirmed'
                ? { confirmed: false }
                : {},
          );
          const result = transition(state, ids[0]!, action, dependencies);
          if (step.action === 'skipUnconfirmed') {
            expect(result.ok).toBe(false);
            expect(result.state).toBe(state);
          } else {
            expect(result, step.action).toMatchObject({ ok: true });
            state = result.state;
          }
          if ('repeat' in step && step.repeat) {
            const repeated = transition(state, ids[0]!, action, dependencies);
            expect(repeated).toMatchObject({ ok: true, duplicate: true });
            expect(repeated.state).toBe(state);
          }
        }
        expect(normalize(state)).toEqual(step.expected);
      }
    });
});

describe('authority, phase rights and atomic rejection', () => {
  const phases: Phase[] = [
    'lobby',
    'numbers',
    'answers',
    'ordering',
    'revealing',
    'judged',
    'rule_event',
    'paused',
    'finished',
  ];
  const rights: Record<string, Phase[]> = {
    setConfig: ['lobby'],
    startGame: ['lobby'],
    restartGame: phases,
    acknowledgeNumber: ['numbers'],
    readyForOrdering: ['answers'],
    beginOrdering: ['answers'],
    submitOrder: ['ordering'],
    revealNext: ['revealing'],
    completeCase: ['judged'],
    completeWithoutVerdict: ['numbers', 'answers', 'ordering', 'revealing', 'judged', 'paused'],
    continueRule: ['rule_event'],
    resumePaused: ['paused'],
  };
  for (const phase of phases)
    for (const [type, allowed] of Object.entries(rights))
      it(`${phase}/${type}`, () => {
        const dependencies = ports();
        const started = apply(lobby({}, ids[2]!), 'startGame', dependencies);
        const mutable = structuredClone(started) as MutableGameState;
        mutable.phase = phase;
        if (phase === 'rule_event') mutable.completedCases = 1;
        mutable.pausedFrom = 'numbers';
        mutable.round!.answerReady = type === 'readyForOrdering' ? [] : [...mutable.round!.roster];
        mutable.round!.acknowledged = phase === 'numbers' ? [] : [...mutable.round!.recipients];
        if (phase === 'judged') {
          mutable.round!.revealCursor = mutable.round!.recipients.length;
          mutable.round!.score = dependencies.scoreRound(mutable);
        }
        const state: GameState = mutable;
        const actor =
          type === 'acknowledgeNumber' ? ids[1]! : type === 'submitOrder' ? ids[0]! : ids[2]!;
        const extra =
          type === 'setConfig' || type === 'restartGame'
            ? { config }
            : type === 'submitOrder'
              ? { order: state.round!.recipients }
              : type === 'revealNext'
                ? { expectedCursor: 0 }
                : type === 'continueRule'
                  ? { afterCase: state.completedCases }
                  : {};
        const result = transition(state, actor, command(state, type, extra), dependencies);
        expect(result.ok).toBe(allowed.includes(phase));
        if (!result.ok) expect(result.state).toBe(state);
        if (allowed.includes(phase)) {
          const unauthorized =
            type === 'readyForOrdering'
              ? RoomIds.player('outsider')
              : type === 'acknowledgeNumber'
                ? ids[0]!
                : ids[1]!;
          const denied = transition(state, unauthorized, command(state, type, extra), dependencies);
          expect(denied).toMatchObject({
            ok: false,
            code: type === 'readyForOrdering' ? 'CREDENTIAL_INVALID' : 'UNAUTHORIZED_ACTION',
          });
          expect(denied.state).toBe(state);
        }
      });

  it('separates host from judge and rejects forged secrets, stale scopes and unauthorized restart', () => {
    const dependencies = ports();
    const state = apply(lobby({}, ids[2]!), 'startGame', dependencies);
    expect(state.judgeId).toBe(ids[0]);
    expect(state.hostId).toBe(ids[2]);
    for (const [actor, type, extra, code] of [
      [ids[0], 'restartGame', { config }, 'UNAUTHORIZED_ACTION'],
      [ids[1], 'completeWithoutVerdict', {}, 'UNAUTHORIZED_ACTION'],
      [ids[2], 'completeWithoutVerdict', { gameId: 'old_game' }, 'STALE_ROUND'],
      [ids[2], 'completeWithoutVerdict', { roundId: 'old_round' }, 'STALE_ROUND'],
      [ids[2], 'completeWithoutVerdict', { expectedRevision: 0 }, 'STALE_REVISION'],
      [ids[2], 'completeWithoutVerdict', { numbers: [1, 2] }, 'INVALID_MESSAGE'],
      [ids[2], 'completeWithoutVerdict', { verdict: { errors: 0 } }, 'INVALID_MESSAGE'],
    ] as const) {
      const result = transition(state, actor!, command(state, type, extra), dependencies);
      expect(result).toMatchObject({ ok: false, code });
      expect(result.state).toBe(state);
    }
    expect(Object.isFrozen(state)).toBe(true);
    expect(Object.isFrozen(state.round!.numbers)).toBe(true);
  });

  it('commits a verdict only after the last reveal and preserves it on counted completion', () => {
    const dependencies = ports();
    let scores = 0;
    const scorer = dependencies.scoreRound;
    dependencies.scoreRound = (state) => {
      scores++;
      return scorer(state);
    };
    let state = apply(lobby({}, ids[2]!), 'startGame', dependencies);
    for (const actor of state.round!.recipients)
      state = apply(state, 'acknowledgeNumber', dependencies, {}, actor);
    for (const actor of state.round!.roster)
      state = apply(state, 'readyForOrdering', dependencies, {}, actor);
    state = apply(state, 'beginOrdering', dependencies);
    state = apply(state, 'submitOrder', dependencies, { order: state.round!.recipients }, ids[0]!);
    state = apply(state, 'revealNext', dependencies, { expectedCursor: 0 });
    expect(scores).toBe(0);
    expect(state.round!.score).toBeNull();
    state = apply(state, 'revealNext', dependencies, { expectedCursor: 1 });
    expect(scores).toBe(1);
    expect(state.phase).toBe('judged');
    const score = state.round!.score;
    state = apply(state, 'completeWithoutVerdict', dependencies);
    expect(state.lastCompletion).toMatchObject({ kind: 'judged', score });
    expect(state.completedCases).toBe(1);
  });

  it('requires every all-judges order and never replaces a missing submission', () => {
    const dependencies = ports();
    let state = apply(lobby({ allJudges: true }), 'startGame', dependencies);
    expect(state.judgeId).toBeNull();
    expect(state.readerId).toBe(ids[0]);
    for (const actor of state.round!.recipients)
      state = apply(state, 'acknowledgeNumber', dependencies, {}, actor);
    for (const actor of state.round!.roster)
      state = apply(state, 'readyForOrdering', dependencies, {}, actor);
    state = apply(state, 'beginOrdering', dependencies);
    for (const actor of ids.slice(0, 2))
      state = apply(state, 'submitOrder', dependencies, { order: ids }, actor);
    state = presenceChanged(state, ids[2]!, false, 2000);
    expect(state.phase).toBe('ordering');
    expect(state.round!.orders).toHaveLength(2);
    expect(state.completedCases).toBe(0);
    state = presenceChanged(state, ids[2]!, true, 3000);
    state = apply(state, 'submitOrder', dependencies, { order: ids }, ids[2]!);
    expect(state.phase).toBe('revealing');
  });

  it('keeps a missing number acknowledgement pending, restarts without reusing game history', () => {
    const dependencies = ports();
    let state = apply(lobby(), 'startGame', dependencies);
    state = apply(state, 'acknowledgeNumber', dependencies, {}, ids[1]!);
    state = presenceChanged(state, ids[2]!, false, 2000);
    expect(state.phase).toBe('numbers');
    expect(state.completedCases).toBe(0);
    const history = state.history,
      game = state.gameId;
    state = apply(state, 'restartGame', dependencies, { config });
    expect(state.gameId).not.toBe(game);
    expect(state.completedCases).toBe(0);
    expect(state.history.slice(0, history.length)).toEqual(history);
    expect(state.drawnQuestionIds).toHaveLength(1);
  });

  it('rejects conflicting action reuse and invalid injected data without partial mutation', () => {
    const dependencies = ports();
    const state = lobby();
    const action = command(state, 'startGame');
    const started = transition(state, ids[0]!, action, dependencies).state;
    expect(
      transition(started, ids[0]!, { ...action, expectedRevision: 1 }, dependencies),
    ).toMatchObject({ ok: false, code: 'ACTION_ID_CONFLICT' });
    dependencies.prepareCase = () => ({
      question: { contentId: '001-a', bindings: {} },
      numbers: [
        { playerId: ids[1]!, number: 1 },
        { playerId: ids[2]!, number: 1 },
      ],
    });
    const rejected = transition(state, ids[0]!, command(state, 'startGame'), dependencies);
    expect(rejected).toMatchObject({ ok: false, code: 'ROOM_UNAVAILABLE' });
    expect(rejected.state).toBe(state);
    expect(state.history).toHaveLength(0);
  });
});

describe('D-08 deterministic host lifecycle', () => {
  it('counts a shown case once without fabricating a verdict or recounting bindings', () => {
    const dependencies = ports();
    const prepare = dependencies.prepareCase;
    dependencies.prepareCase = (state, random, now) => {
      const result = prepare(state, random, now)!;
      result.question = { ...result.question, bindings: { player1: ids[1]!, player2: ids[1]! } };
      return result;
    };
    let state = apply(lobby({ targetCases: 1 }), 'startGame', dependencies);
    const counts = state.personCounts,
      history = state.history,
      roundId = state.round!.id;
    expect(counts.find((entry) => entry.playerId === ids[1])?.count).toBe(1);
    state = apply(state, 'completeWithoutVerdict', dependencies);
    expect(state.phase).toBe('finished');
    expect(state.completedCases).toBe(1);
    expect(state.lastCompletion).toMatchObject({ kind: 'completed_without_verdict', score: null });
    expect(state.personCounts).toEqual(counts);
    expect(state.history).toEqual(history);
    const stale = transition(
      state,
      ids[0]!,
      command(state, 'completeWithoutVerdict', { roundId }),
      dependencies,
    );
    expect(stale).toMatchObject({ ok: false, code: 'STALE_ROUND' });
    expect(stale.state).toBe(state);
  });

  it('restores the original host before the deadline without a takeover', () => {
    let state = presenceChanged(lobby(), ids[0]!, false, 1000);
    state = presenceChanged(state, ids[0]!, true, 90000);
    expect(hostDeadline(state, 92000)).toBe(state);
    expect(state.hostId).toBe(ids[0]);
    expect(state.hostRevision).toBe(0);
  });

  it('waits 90 seconds, uses stable join order and never changes case secrets or judge', () => {
    const dependencies = ports();
    let state = apply(lobby({}, ids[2]!), 'startGame', dependencies);
    const round = state.round;
    state = presenceChanged(state, ids[2]!, false, 1000);
    expect(hostDeadline(state, 90999)).toBe(state);
    state = hostDeadline(state, 91000);
    expect(state.hostId).toBe(ids[0]);
    expect(state.hostRevision).toBe(1);
    expect(state.round).toEqual(round);
    expect(state.completedCases).toBe(0);
    expect(state.judgeId).toBe(ids[0]);
    state = presenceChanged(state, ids[2]!, true, 92000);
    expect(state.hostId).toBe(ids[0]);
  });
  for (const phase of ['lobby', 'numbers', 'rule_event', 'finished', 'paused'] as const)
    it(`restores ${phase} after no-successor host pause`, () => {
      const dependencies = ports();
      const original = apply(lobby(), 'startGame', dependencies);
      const copy = structuredClone(original) as MutableGameState;
      copy.phase = phase;
      if (phase === 'paused') {
        copy.pausedFrom = 'case_boundary';
        copy.pauseReason = 'insufficient_players';
      }
      let state: GameState = copy;
      for (const id of ids) state = presenceChanged(state, id, false, 1000);
      state = hostDeadline(state, 91000);
      expect(state.phase).toBe('paused');
      expect(state.pauseReason).toBe('host_unavailable');
      expect(hostDeadline(state, 92000)).toBe(state);
      state = presenceChanged(state, ids[1]!, true, 93000);
      state = hostDeadline(state, 93000);
      expect(state.hostId).toBe(ids[1]);
      expect(state.phase).toBe(phase);
      expect(state.round).toEqual(original.round);
      if (phase === 'paused') expect(state.pauseReason).toBe('insufficient_players');
    });
});
