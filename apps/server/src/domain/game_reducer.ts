import { createHash } from 'node:crypto';
import { canonicalJson } from '../../../../packages/protocol/schema-validation.mjs';
import {
  decodeRoomMessage,
  ProtocolDecodeException,
  RoomIds,
  type ProtocolErrorCode,
} from '../protocol/room_message';
import {
  protocolMetadata,
  type Assignment,
  type Config,
  type PlayerId,
  type RoomMessage,
} from '../protocol/room_message.generated';
import {
  immutable,
  type GamePorts,
  type GameState,
  type MutableGameState,
  type Phase,
  type Score,
} from './game_state';

export const gameActions = [
  'setConfig',
  'startGame',
  'restartGame',
  'acknowledgeNumber',
  'readyForOrdering',
  'beginOrdering',
  'submitOrder',
  'revealNext',
  'completeCase',
  'completeWithoutVerdict',
  'continueRule',
  'resumePaused',
] as const;
type GameAction = Extract<RoomMessage, { type: (typeof gameActions)[number] }>;
type ActionResult =
  | { ok: true; state: GameState; duplicate: boolean }
  | { ok: false; state: GameState; code: ProtocolErrorCode };
class Rejected extends Error {
  constructor(readonly code: ProtocolErrorCode) {
    super(code);
  }
}
function reject(code: ProtocolErrorCode): never {
  throw new Rejected(code);
}
function identifiers(ids: readonly PlayerId[], minimum = 0): void {
  if (
    ids.length < minimum ||
    ids.length > 20 ||
    new Set(ids).size !== ids.length ||
    ids.some((id) => !/^[A-Za-z0-9_-]{1,64}$/.test(id))
  )
    reject('INVALID_CONFIG');
}
function sameSet(a: readonly PlayerId[], b: readonly PlayerId[]): boolean {
  return a.length === b.length && new Set(a).size === a.length && a.every((id) => b.includes(id));
}
function nextRole(
  old: readonly PlayerId[],
  previous: PlayerId | null,
  current: readonly PlayerId[],
): PlayerId | null {
  if (!current.length) return null;
  if (previous && current.includes(previous))
    return current[(current.indexOf(previous) + 1) % current.length]!;
  const index = previous ? old.indexOf(previous) : -1;
  if (index >= 0)
    for (let offset = 1; offset <= old.length; offset++) {
      const candidate = old[(index + offset) % old.length]!;
      if (current.includes(candidate)) return candidate;
    }
  return current[0]!;
}
function configValid(config: Config): void {
  // Reuse the shared strict config decoder, including immutable integral values.
  decodeRoomMessage(
    JSON.stringify({
      type: 'setConfig',
      protocolVersion: 1,
      actionId: 'validate',
      expectedRevision: 0,
      config,
    }),
    { direction: 'client' },
  );
}
function clearPause(state: MutableGameState): void {
  delete state.pausedFrom;
  delete state.pauseReason;
}
function restoreHostPause(state: MutableGameState): void {
  const previous = state.hostPauseState;
  if (!previous) return;
  state.phase = previous.phase;
  clearPause(state);
  if (previous.pausedFrom !== undefined) state.pausedFrom = previous.pausedFrom;
  if (previous.pauseReason !== undefined) state.pauseReason = previous.pauseReason;
  delete state.hostPauseState;
}
function pauseBoundary(
  state: MutableGameState,
  reason: 'insufficient_players' | 'content_exhausted',
): void {
  state.phase = 'paused';
  state.pausedFrom = 'case_boundary';
  state.pauseReason = reason;
  state.round = null;
}
function safeTime(ports: GamePorts): number {
  const now = ports.now();
  if (!Number.isSafeInteger(now) || Number.isNaN(new Date(now).getTime()))
    reject('ROOM_UNAVAILABLE');
  return now;
}
function newId(ports: GamePorts, kind: 'game' | 'round' | 'event'): string {
  const id = ports.newId(kind);
  if (!/^[A-Za-z0-9_-]{1,64}$/.test(id)) reject('ROOM_UNAVAILABLE');
  return id;
}
function random(ports: GamePorts): (bound: number) => number {
  return (bound) => {
    const value = ports.randomIndex(bound);
    if (
      !Number.isSafeInteger(bound) ||
      bound < 1 ||
      !Number.isSafeInteger(value) ||
      value < 0 ||
      value >= bound
    )
      reject('ROOM_UNAVAILABLE');
    return value;
  };
}
function selected(
  state: MutableGameState,
  assignment: Assignment,
  kind: 'question' | 'rule',
  ports: GamePorts,
  now: number,
): void {
  if (
    !/^[A-Za-z0-9_-]{1,64}$/.test(assignment.contentId) ||
    Object.entries(assignment.bindings).some(
      ([role, id]) => !/^player[1-9][0-9]*$/.test(role) || !state.effectiveRoster.includes(id),
    )
  )
    reject('ROOM_UNAVAILABLE');
  for (const id of new Set(Object.values(assignment.bindings))) {
    const count = state.personCounts.find((entry) => entry.playerId === id);
    if (!count || count.count >= Number.MAX_SAFE_INTEGER) reject('ROOM_UNAVAILABLE');
    count.count++;
  }
  const eventId = newId(ports, 'event');
  if (state.history.some((event) => event.eventId === eventId)) reject('ROOM_UNAVAILABLE');
  state.history.push({
    eventId,
    kind,
    contentId: assignment.contentId,
    timestampUtc: new Date(now).toISOString(),
  });
}
function applyBoundaryRoster(state: MutableGameState): void {
  if (!state.pendingRoster) return;
  const active = state.effectiveRoster,
    maximum = Math.max(
      0,
      ...state.personCounts
        .filter(
          (entry) =>
            active.includes(entry.playerId) && state.pendingRoster!.includes(entry.playerId),
        )
        .map((entry) => entry.count),
    );
  for (const id of state.pendingRoster)
    if (!active.includes(id)) {
      if (state.personCounts.some((entry) => entry.playerId === id)) reject('CREDENTIAL_INVALID');
      state.personCounts.push({ playerId: id, count: maximum });
    }
  state.effectiveRoster = [...state.pendingRoster];
  state.pendingRoster = null;
}
function beginCase(state: MutableGameState, ports: GamePorts, now: number): void {
  clearPause(state);
  if (state.effectiveRoster.length < 3) {
    pauseBoundary(state, 'insufficient_players');
    return;
  }
  const recipients = state.config.allJudges
    ? [...state.effectiveRoster]
    : state.effectiveRoster.filter((id) => id !== state.judgeId);
  const prepared = ports.prepareCase(immutable(structuredClone(state)), random(ports), now);
  if (!prepared) {
    pauseBoundary(state, 'content_exhausted');
    return;
  }
  const max = Math.floor((state.effectiveRoster.length * state.config.factorTenths + 9) / 10);
  if (
    state.drawnQuestionIds.includes(prepared.question.contentId) ||
    !sameSet(
      prepared.numbers.map((entry) => entry.playerId),
      recipients,
    ) ||
    new Set(prepared.numbers.map((entry) => entry.number)).size !== recipients.length ||
    prepared.numbers.some(
      (entry) => !Number.isSafeInteger(entry.number) || entry.number < 1 || entry.number > max,
    )
  )
    reject('ROOM_UNAVAILABLE');
  const id = RoomIds.round(newId(ports, 'round'));
  if (state.completedRoundIds.includes(id)) reject('ROOM_UNAVAILABLE');
  selected(state, prepared.question, 'question', ports, now);
  state.drawnQuestionIds.push(prepared.question.contentId);
  state.round = {
    id,
    question: structuredClone(prepared.question),
    roster: [...state.effectiveRoster],
    recipients,
    numbers: structuredClone(prepared.numbers),
    acknowledged: [],
    answerReady: [],
    orders: [],
    revealOrder: [],
    revealCursor: 0,
    score: null,
  };
  state.phase = 'numbers';
}
function boundary(state: MutableGameState, ports: GamePorts, now: number): void {
  clearPause(state);
  if (state.completedCases === state.config.targetCases) {
    state.phase = 'finished';
    return;
  }
  if (state.effectiveRoster.length < 3) {
    pauseBoundary(state, 'insufficient_players');
    return;
  }
  const rebound = ports.rebindRules(immutable(structuredClone(state)), random(ports));
  state.activeRules = structuredClone(rebound.activeRules);
  state.personCounts = structuredClone(rebound.personCounts);
  const slot = state.ruleSlots.find(
    (slot) => slot.afterCase === state.completedCases && slot.status === 'pending',
  );
  if (slot) {
    const assignment = ports.activateRule(immutable(structuredClone(state)), random(ports), now);
    if (assignment) {
      if (state.drawnRuleIds.includes(assignment.contentId)) reject('ROOM_UNAVAILABLE');
      selected(state, assignment, 'rule', ports, now);
      state.drawnRuleIds.push(assignment.contentId);
      state.activeRules.push(structuredClone(assignment));
      slot.status = 'activated';
      slot.ruleId = assignment.contentId;
      state.phase = 'rule_event';
      return;
    }
    slot.status = 'skipped';
  }
  beginCase(state, ports, now);
}
function requireHost(state: MutableGameState, actor: PlayerId): void {
  if (state.hostId !== actor) reject('UNAUTHORIZED_ACTION');
}
function requirePhase(state: MutableGameState, ...phases: Phase[]): void {
  if (!phases.includes(state.phase)) reject('INVALID_PHASE');
}
function scoreValid(score: Score, state: MutableGameState): void {
  const round = state.round!;
  if (state.config.allJudges) {
    if (
      score.kind !== 'all_judges' ||
      !sameSet(
        score.results.map((result) => result.playerId),
        round.recipients,
      ) ||
      score.results.some(
        (result) =>
          !Number.isSafeInteger(result.errors) ||
          result.errors < 0 ||
          result.errors === 1 ||
          result.errors > round.recipients.length ||
          result.errors !== result.sips,
      )
    )
      reject('ROOM_UNAVAILABLE');
  } else if (
    score.kind !== 'normal' ||
    !Number.isSafeInteger(score.errors) ||
    score.errors < 0 ||
    score.errors === 1 ||
    score.errors > round.recipients.length ||
    !sameSet(
      score.penalties.map((entry) => entry.playerId),
      round.roster,
    ) ||
    score.penalties.some((entry) => entry.sips !== 0 && entry.sips !== score.errors) ||
    score.penalties.find((entry) => entry.playerId === state.judgeId)?.sips !== score.errors
  )
    reject('ROOM_UNAVAILABLE');
}
function complete(
  state: MutableGameState,
  withoutVerdict: boolean,
  ports: GamePorts,
  now: number,
): void {
  const round = state.round;
  if (!round || state.completedRoundIds.includes(round.id)) reject('STALE_ROUND');
  if (withoutVerdict)
    requirePhase(state, 'numbers', 'answers', 'ordering', 'revealing', 'judged', 'paused');
  else requirePhase(state, 'judged');
  const hasJudgment = round.score !== null && round.revealCursor === round.recipients.length;
  if (!withoutVerdict && !hasJudgment) reject('INVALID_PHASE');
  state.lastCompletion = {
    roundId: round.id,
    questionId: round.question.contentId,
    kind: hasJudgment ? 'judged' : 'completed_without_verdict',
    score: hasJudgment ? structuredClone(round.score) : null,
  };
  state.completedRoundIds.push(round.id);
  state.completedCases++;
  const old = state.effectiveRoster,
    previous = state.config.allJudges ? state.readerId : state.judgeId;
  applyBoundaryRoster(state);
  const next = nextRole(old, previous, state.effectiveRoster);
  if (state.config.allJudges) {
    state.readerId = next;
    state.judgeId = null;
  } else state.judgeId = next;
  state.round = null;
  boundary(state, ports, now);
}
function start(state: MutableGameState, config: Config, ports: GamePorts, now: number): void {
  configValid(config);
  identifiers(state.roster, 3);
  const gameId = RoomIds.game(newId(ports, 'game'));
  if (gameId === state.gameId) reject('ROOM_UNAVAILABLE');
  const slots = ports.planSlots(config, random(ports));
  if (
    slots.length !== Math.min(config.requestedRuleEvents, config.targetCases - 1) ||
    new Set(slots).size !== slots.length ||
    slots.some(
      (slot, index) =>
        !Number.isSafeInteger(slot) ||
        slot < 1 ||
        slot >= config.targetCases ||
        (index > 0 &&
          slot - slots[index - 1]! < (config.targetCases - 1 >= 2 * slots.length - 1 ? 2 : 1)),
    )
  )
    reject('ROOM_UNAVAILABLE');
  let segmentStart = 1;
  for (let index = 0; index < slots.length; index++) {
    const size =
      Math.floor((config.targetCases - 1) / slots.length) +
      (index < (config.targetCases - 1) % slots.length ? 1 : 0);
    if (slots[index]! < segmentStart || slots[index]! >= segmentStart + size)
      reject('ROOM_UNAVAILABLE');
    segmentStart += size;
  }
  state.gameId = gameId;
  state.config = structuredClone(config);
  state.completedCases = 0;
  state.effectiveRoster = [...state.roster];
  state.pendingRoster = null;
  state.judgeId = config.allJudges ? null : state.roster[0]!;
  state.readerId = config.allJudges ? state.roster[0]! : null;
  state.completedRoundIds = [];
  state.drawnQuestionIds = [];
  state.drawnRuleIds = [];
  state.activeRules = [];
  state.ruleSlots = slots.map((afterCase) => ({ afterCase, status: 'pending' }));
  state.personCounts = state.roster.map((playerId) => ({ playerId, count: 0 }));
  state.round = null;
  state.lastCompletion = null;
  delete state.hostPauseState;
  beginCase(state, ports, now);
}

export function initialGameState({
  hostId,
  roster,
  config,
  now = 0,
}: {
  hostId: PlayerId;
  roster: PlayerId[];
  config: Config;
  now?: number;
}): GameState {
  identifiers(roster, 1);
  configValid(config);
  if (!roster.includes(hostId)) reject('INVALID_CONFIG');
  return immutable({
    formatVersion: 1,
    gameId: null,
    revision: 0,
    config: structuredClone(config),
    phase: 'lobby',
    hostId,
    hostRevision: 0,
    hostDisconnectedAt: null,
    roster: [...roster],
    effectiveRoster: [...roster],
    pendingRoster: null,
    joinOrder: [...roster],
    connected: [...roster],
    judgeId: null,
    readerId: null,
    completedCases: 0,
    round: null,
    lastCompletion: null,
    completedRoundIds: [],
    drawnQuestionIds: [],
    drawnRuleIds: [],
    ruleSlots: [],
    activeRules: [],
    personCounts: roster.map((playerId) => ({ playerId, count: 0 })),
    history: [],
    lastDomainActivity: now,
    receipts: [],
  } satisfies MutableGameState);
}
export function transition(
  state: GameState,
  actor: PlayerId,
  input: unknown,
  ports: GamePorts,
): ActionResult {
  try {
    const command = decodeRoomMessage(JSON.stringify(input), {
      direction: 'client',
      allowedTypes: gameActions,
    }) as GameAction;
    if (!state.roster.includes(actor) || !state.connected.includes(actor))
      reject('CREDENTIAL_INVALID');
    const fingerprint = createHash('sha256').update(canonicalJson(command)).digest('hex'),
      receipt = state.receipts.find((receipt) => receipt.actionId === command.actionId);
    if (receipt) {
      if (receipt.actorId !== actor || receipt.fingerprint !== fingerprint)
        reject('ACTION_ID_CONFLICT');
      if (receipt.gameId !== state.gameId) reject('STALE_ROUND');
      return { ok: true, state, duplicate: true };
    }
    if (command.expectedRevision !== state.revision) reject('STALE_REVISION');
    if (state.receipts.length >= protocolMetadata.limits.actionJournalEntries)
      reject('RATE_LIMITED');
    const next = structuredClone(state) as MutableGameState,
      now = safeTime(ports);
    if ('gameId' in command && command.gameId !== state.gameId) reject('STALE_ROUND');
    if ('roundId' in command && command.roundId !== state.round?.id) reject('STALE_ROUND');
    switch (command.type) {
      case 'setConfig':
        requireHost(next, actor);
        requirePhase(next, 'lobby');
        configValid(command.config);
        next.config = structuredClone(command.config);
        break;
      case 'startGame':
        requireHost(next, actor);
        requirePhase(next, 'lobby');
        start(next, next.config, ports, now);
        break;
      case 'restartGame':
        requireHost(next, actor);
        start(next, command.config, ports, now);
        break;
      case 'acknowledgeNumber': {
        requirePhase(next, 'numbers');
        const round = next.round!;
        if (!round.recipients.includes(actor)) reject('UNAUTHORIZED_ACTION');
        if (round.acknowledged.includes(actor)) reject('INVALID_PHASE');
        round.acknowledged.push(actor);
        if (round.acknowledged.length === round.recipients.length) next.phase = 'answers';
        break;
      }
      case 'readyForOrdering': {
        requirePhase(next, 'answers');
        const round = next.round!;
        if (!round.roster.includes(actor)) reject('UNAUTHORIZED_ACTION');
        if (round.answerReady.includes(actor)) reject('INVALID_PHASE');
        round.answerReady.push(actor);
        break;
      }
      case 'beginOrdering':
        requireHost(next, actor);
        requirePhase(next, 'answers');
        if (
          next.round!.roster.some(
            (id) =>
              !next.roster.includes(id) ||
              !next.connected.includes(id) ||
              !next.round!.answerReady.includes(id),
          )
        )
          reject('INVALID_PHASE');
        next.phase = 'ordering';
        break;
      case 'submitOrder': {
        requirePhase(next, 'ordering');
        const round = next.round!;
        if (next.config.allJudges ? !round.recipients.includes(actor) : next.judgeId !== actor)
          reject('UNAUTHORIZED_ACTION');
        if (round.orders.some((order) => order.playerId === actor)) reject('INVALID_PHASE');
        if (!sameSet(command.order, round.recipients)) reject('INVALID_PERMUTATION');
        round.orders.push({ playerId: actor, order: [...command.order] });
        if (!next.config.allJudges || round.orders.length === round.recipients.length) {
          round.revealOrder = next.config.allJudges ? [...round.recipients] : [...command.order];
          next.phase = 'revealing';
        }
        break;
      }
      case 'revealNext': {
        requireHost(next, actor);
        requirePhase(next, 'revealing');
        const round = next.round!;
        if (command.expectedCursor !== round.revealCursor) reject('STALE_REVISION');
        round.revealCursor++;
        if (round.revealCursor === round.recipients.length) {
          const score = ports.scoreRound(immutable(structuredClone(next)));
          scoreValid(score, next);
          round.score = structuredClone(score);
          next.phase = 'judged';
        }
        break;
      }
      case 'completeCase':
        requireHost(next, actor);
        complete(next, false, ports, now);
        break;
      case 'completeWithoutVerdict':
        requireHost(next, actor);
        complete(next, true, ports, now);
        break;
      case 'continueRule':
        requireHost(next, actor);
        requirePhase(next, 'rule_event');
        if (command.afterCase !== next.completedCases) reject('STALE_ROUND');
        if (next.pendingRoster) {
          const old = [...next.effectiveRoster],
            role = next.config.allJudges ? next.readerId : next.judgeId;
          applyBoundaryRoster(next);
          if (role && !next.effectiveRoster.includes(role)) {
            const replacement = nextRole(old, role, next.effectiveRoster);
            if (next.config.allJudges) next.readerId = replacement;
            else next.judgeId = replacement;
          }
          const rebound = ports.rebindRules(immutable(structuredClone(next)), random(ports));
          next.activeRules = structuredClone(rebound.activeRules);
          next.personCounts = structuredClone(rebound.personCounts);
        }
        beginCase(next, ports, now);
        break;
      case 'resumePaused': {
        requireHost(next, actor);
        requirePhase(next, 'paused');
        if (next.pausedFrom === 'case_boundary') {
          applyBoundaryRoster(next);
          if (next.config.allJudges) {
            if (!next.effectiveRoster.includes(next.readerId!))
              next.readerId = next.effectiveRoster[0] ?? null;
          } else if (!next.effectiveRoster.includes(next.judgeId!))
            next.judgeId = next.effectiveRoster[0] ?? null;
          boundary(next, ports, now);
        } else {
          const phase = next.pausedFrom;
          if (!phase) reject('INVALID_PHASE');
          next.phase = phase;
          clearPause(next);
        }
        break;
      }
    }
    next.revision++;
    next.lastDomainActivity = now;
    next.receipts.push({
      actionId: command.actionId,
      actorId: actor,
      fingerprint,
      revision: next.revision,
      gameId: next.gameId,
    });
    return { ok: true, state: immutable(next), duplicate: false };
  } catch (error) {
    return {
      ok: false,
      state,
      code:
        error instanceof Rejected
          ? error.code
          : error instanceof ProtocolDecodeException && error.code !== 'INVALID_JSON'
            ? error.code
            : 'ROOM_UNAVAILABLE',
    };
  }
}

/** Trusted room events: no timeout ever submits an order or completes a case. */
export function presenceChanged(
  state: GameState,
  playerId: PlayerId,
  connected: boolean,
  now: number,
): GameState {
  if (!state.roster.includes(playerId) || state.connected.includes(playerId) === connected)
    return state;
  const next = structuredClone(state) as MutableGameState;
  next.connected = connected
    ? [...next.connected, playerId]
    : next.connected.filter((id) => id !== playerId);
  if (playerId === state.hostId) {
    next.hostDisconnectedAt = connected ? null : now;
    if (connected) restoreHostPause(next);
  }
  next.revision++;
  return immutable(next);
}
export function hostDeadline(state: GameState, now: number): GameState {
  if (
    state.hostDisconnectedAt === null ||
    state.connected.includes(state.hostId) ||
    now < state.hostDisconnectedAt + protocolMetadata.limits.hostGraceMs
  )
    return state;
  const next = structuredClone(state) as MutableGameState,
    candidate = next.joinOrder.find(
      (id) => next.roster.includes(id) && next.connected.includes(id),
    );
  if (candidate) {
    next.hostId = candidate;
    next.hostRevision++;
    next.hostDisconnectedAt = null;
    restoreHostPause(next);
  } else {
    if (next.phase === 'paused' && next.pauseReason === 'host_unavailable') return state;
    next.hostPauseState = {
      phase: next.phase,
      ...(next.pausedFrom ? { pausedFrom: next.pausedFrom } : {}),
      ...(next.pauseReason ? { pauseReason: next.pauseReason } : {}),
    };
    if (next.phase !== 'paused') next.pausedFrom = next.phase;
    next.phase = 'paused';
    next.pauseReason = 'host_unavailable';
  }
  next.revision++;
  return immutable(next);
}
export function stageRoster(state: GameState, roster: PlayerId[], now: number): GameState {
  identifiers(roster);
  if (roster.some((id) => !state.roster.includes(id) && state.joinOrder.includes(id)))
    reject('CREDENTIAL_INVALID');
  const next = structuredClone(state) as MutableGameState;
  next.roster = [...roster];
  next.connected = next.connected.filter((id) => roster.includes(id));
  if (!roster.includes(next.hostId) && next.hostDisconnectedAt === null)
    next.hostDisconnectedAt = now;
  for (const id of roster) if (!next.joinOrder.includes(id)) next.joinOrder.push(id);
  if (next.phase === 'lobby') {
    next.effectiveRoster = [...roster];
    next.personCounts = roster.map((playerId) => ({ playerId, count: 0 }));
  } else next.pendingRoster = [...roster];
  next.revision++;
  return immutable(next);
}
