import { describe, expect, it } from 'vitest';
import fixture from '../../../../packages/protocol/fixtures/transitions/core/reroll-v1.json';
import {
  initialGameState,
  rerollCurrentQuestion,
  stageRoster,
  transition,
} from '../../src/domain/game_reducer';
import { gamePorts } from '../../src/domain/game_ports';
import { scoreRound } from '../../src/domain/verdict';
import type { GamePorts, GameState, MutableGameState } from '../../src/domain/game_state';
import { RoomIds } from '../../src/protocol/room_message';

const players = fixture.players.map(RoomIds.player);
let actionId = 0;
function command(
  state: GameState,
  type = 'rerollCurrentQuestion',
  extra: Record<string, unknown> = {},
) {
  return {
    type,
    protocolVersion: 1,
    actionId: `reroll_${actionId++}`,
    expectedRevision: state.revision,
    ...(type !== 'startGame' ? { gameId: state.gameId, roundId: state.round?.id } : {}),
    ...extra,
  };
}
function dependencies(): GamePorts {
  let serial = 0;
  return gamePorts(scoreRound, {
    now: () => 1000,
    newId: (kind) => `${kind}_${serial++}`,
    randomIndex: () => 0,
  });
}
function start(ports: GamePorts, allJudges = false) {
  const lobby = initialGameState({
    hostId: players[0]!,
    roster: players,
    config: {
      targetCases: 3,
      requestedRuleEvents: 2,
      factorTenths: 15,
      contentLanguage: 'de',
      allJudges,
    },
  });
  const result = transition(lobby, players[0]!, command(lobby, 'startGame'), ports);
  if (!result.ok) throw new Error(result.code);
  return result.state;
}
function draw(state: GameState, ports: GamePorts, actor = state.judgeId ?? state.readerId!) {
  const result = rerollCurrentQuestion(state, actor, command(state), ports);
  expect(result).toMatchObject({ ok: true, duplicate: false });
  return result.state;
}

describe('question-instance reroll core (D-19)', () => {
  it('executes the same ten-reroll fixture as Dart; completion counts one case/slot', () => {
    const ports = dependencies();
    const question = (state: GameState) => {
      const contentId = fixture.questions.find((id) => !state.drawnQuestionIds.includes(id));
      return contentId ? { contentId, bindings: {} } : null;
    };
    ports.prepareQuestion = question;
    ports.prepareCase = (state) => ({
      question: question(state)!,
      numbers: players.slice(1).map((playerId, i) => ({ playerId, number: i + 1 })),
    });
    let state = start(ports);
    const first = state,
      numbers = state.round!.numbers;
    for (let i = 0; i < fixture.rerolls; i++) {
      const intent = command(state),
        previous = state;
      const result = rerollCurrentQuestion(state, players[0]!, intent, ports);
      expect(result).toMatchObject({ ok: true, duplicate: false });
      state = result.state;
      expect(state.round!.id).not.toBe(previous.round!.id);
      expect(state.round!.numbers).toEqual(numbers);
      expect(state.ruleSlots).toEqual(first.ruleSlots);
      expect(rerollCurrentQuestion(state, players[0]!, intent, ports)).toMatchObject({
        ok: true,
        duplicate: true,
        state,
      });
      expect(
        rerollCurrentQuestion(
          state,
          players[0]!,
          { ...intent, expectedRevision: state.revision },
          ports,
        ),
      ).toMatchObject({ ok: false, code: 'ACTION_ID_CONFLICT' });
      expect(
        rerollCurrentQuestion(
          state,
          players[0]!,
          { ...intent, actionId: `concurrent_${i}` },
          ports,
        ),
      ).toMatchObject({ ok: false, code: 'STALE_REVISION' });
      expect(
        rerollCurrentQuestion(
          state,
          players[0]!,
          command(state, undefined, { roundId: previous.round!.id }),
          ports,
        ),
      ).toMatchObject({ ok: false, code: 'STALE_ROUND' });
    }
    expect({
      phase: state.phase,
      completed: state.completedCases,
      judge: state.judgeId,
      question: state.round!.question.contentId,
      drawn: state.drawnQuestionIds.length,
      history: state.history.length,
      slots: state.ruleSlots.map((s) => s.afterCase),
      numbers: Object.fromEntries(state.round!.numbers.map((n) => [n.playerId, n.number])),
    }).toEqual(fixture.expected);
    expect(new Set(state.questionDraws.map((d) => d.roundId)).size).toBe(11);
    const completion = command(state, 'completeWithoutVerdict', { confirmed: true });
    const done = transition(state, state.hostId, completion, ports);
    expect(done).toMatchObject({ ok: true, state: { completedCases: 1, phase: 'rule_event' } });
    expect(done.state.ruleSlots.filter((s) => s.status === 'activated')).toHaveLength(1);
    expect(transition(done.state, state.hostId, completion, ports)).toMatchObject({
      ok: true,
      duplicate: true,
    });
  });

  for (const allJudges of [false, true]) {
    it(`keeps numbers/frozen roster and resets drafts in both modes (${allJudges})`, () => {
      const ports = dependencies(),
        first = start(ports, allJudges);
      for (const phase of ['numbers', 'answers', 'ordering', 'revealing'] as const) {
        const state = structuredClone(first) as MutableGameState;
        state.phase = phase;
        state.round!.acknowledged = [...state.round!.recipients];
        state.round!.answerReady = [...players];
        state.round!.orders = [{ playerId: players[0]!, order: [...state.round!.recipients] }];
        state.round!.revealOrder = [...state.round!.recipients];
        const next = draw(state, ports);
        expect(next.round).toMatchObject({
          numbers: first.round!.numbers,
          roster: first.round!.roster,
          acknowledged: [],
          answerReady: [],
          orders: [],
          revealOrder: [],
          revealCursor: 0,
          score: null,
        });
        expect(next.phase).toBe('numbers');
      }
    });
    it(`rejects host privilege without current judge/reader authority (${allJudges})`, () => {
      const ports = dependencies(),
        state = structuredClone(start(ports, allJudges)) as MutableGameState;
      if (allJudges) state.readerId = players[1]!;
      else state.judgeId = players[1]!;
      expect(rerollCurrentQuestion(state, state.hostId, command(state), ports)).toMatchObject({
        ok: false,
        code: 'UNAUTHORIZED_ACTION',
      });
      expect(draw(state, ports, players[1]!).completedCases).toBe(0);
    });
  }
  it('rejects public reveal, inactive phases, exhausted catalog and reused instance IDs without mutation', () => {
    const ports = dependencies(),
      initial = start(ports);
    for (const phase of ['revealing', 'judged', 'rule_event', 'paused', 'finished'] as const) {
      const state = structuredClone(initial) as MutableGameState;
      state.phase = phase;
      if (phase === 'revealing') state.round!.revealCursor = 1;
      const result = rerollCurrentQuestion(state, players[0]!, command(state), ports);
      expect(result).toMatchObject({ ok: false, code: 'INVALID_PHASE' });
      expect(result.state).toBe(state);
    }
    const exhausted = rerollCurrentQuestion(initial, players[0]!, command(initial), {
      ...ports,
      prepareQuestion: () => null,
    });
    expect(exhausted).toMatchObject({ ok: false, code: 'CONTENT_EXHAUSTED' });
    expect(exhausted.state).toBe(initial);
    expect(
      rerollCurrentQuestion(initial, players[0]!, command(initial), {
        ...ports,
        newId: () => initial.round!.id,
      }),
    ).toMatchObject({ ok: false, code: 'ROOM_UNAVAILABLE' });
  });
  it('excludes departed and pending new people from replacement bindings; consumes fairness/history once', () => {
    const ports = dependencies();
    let state = start(ports);
    const selectedCounts: Record<string, number> = {};
    const record = () => {
      for (const id of new Set(Object.values(state.round!.question.bindings)))
        selectedCounts[id] = (selectedCounts[id] ?? 0) + 1;
    };
    record();
    state = stageRoster(state, [...players.slice(0, 3), RoomIds.player('E')], 1000);
    for (let i = 0; i < 50; i++) {
      state = draw(state, ports);
      record();
      expect(
        Object.values(state.round!.question.bindings).every((id) =>
          players.slice(0, 3).includes(id),
        ),
      ).toBe(true);
    }
    const totals = Object.fromEntries(state.personCounts.map((p) => [p.playerId, p.count]));
    for (const id of players.slice(0, 3)) expect(totals[id]).toBe(selectedCounts[id] ?? 0);
    expect(state.history).toHaveLength(51);
    expect(totals.E ?? 0).toBe(0);
    expect(
      Math.max(...players.slice(0, 3).map((id) => totals[id]!)) -
        Math.min(...players.slice(0, 3).map((id) => totals[id]!)),
    ).toBeLessThanOrEqual(1);
  });
});
