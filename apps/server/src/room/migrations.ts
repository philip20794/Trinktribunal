import wire from '../../../../packages/protocol/schemas/room-message.schema.json';
import {
  assertJsonDepth,
  canonicalJson,
  validateSchema,
} from '../../../../packages/protocol/schema-validation.mjs';
import { immutable } from '../domain/game_state';
import { protocolMetadata } from '../protocol/room_message.generated';
import type { RoomState } from './repository';

type Schema = Record<string, unknown>;
const questionIds = new Set<string>(protocolMetadata.questionIds),
  ruleIds = new Set<string>(protocolMetadata.ruleIds);
const ref = (name: string): Schema => ({ $ref: `#/$defs/${name}` });
const integer = (minimum = 0, maximum = Number.MAX_SAFE_INTEGER): Schema => ({
  type: 'integer',
  minimum,
  maximum,
});
const nullable = (schema: Schema): Schema => ({ oneOf: [schema, { const: null }] });
const array = (items: Schema, maxItems = 16384, uniqueItems = false): Schema => ({
  type: 'array',
  items,
  maxItems,
  uniqueItems,
});
const object = (properties: Record<string, Schema>, optional: string[] = []): Schema => ({
  type: 'object',
  properties,
  required: Object.keys(properties).filter((key) => !optional.includes(key)),
  additionalProperties: false,
});
const boolean: Schema = { type: 'boolean' },
  id = ref('id'),
  hash = ref('hash'),
  ids = array(id, 16384, true),
  seats = array(id, 20, true);
const phase: Schema = {
  enum: [
    'lobby',
    'numbers',
    'answers',
    'ordering',
    'revealing',
    'judged',
    'rule_event',
    'paused',
    'finished',
  ],
};
const pause: Schema = { enum: ['insufficient_players', 'content_exhausted', 'host_unavailable'] };
const pausedFrom: Schema = {
  enum: [
    'lobby',
    'case_boundary',
    'numbers',
    'answers',
    'ordering',
    'revealing',
    'judged',
    'rule_event',
    'finished',
  ],
};
const dictionary = (values: Schema): Schema => ({
  type: 'object',
  maxProperties: 32768,
  propertyNames: id,
  additionalProperties: values,
});
const score: Schema = {
  oneOf: [
    object({
      kind: { const: 'normal' },
      errors: integer(0, 20),
      penalties: array(ref('penalty'), 20),
    }),
    object({
      kind: { const: 'all_judges' },
      results: array(object({ playerId: id, errors: integer(0, 20), sips: integer(0, 20) }), 20),
    }),
  ],
};
const definitions: Record<string, Schema> = {
  ...wire.$defs,
  storedMember: object(
    {
      playerId: id,
      profile: ref('profile'),
      verifier: hash,
      joinedAt: integer(),
      joinedSequence: integer(),
      generation: integer(),
      selectionCount: integer(),
      revoked: boolean,
      leaveActionId: id,
      leaveRevision: integer(),
    },
    ['profile', 'joinedSequence', 'leaveActionId', 'leaveRevision'],
  ),
  storedReceipt: object({
    actionId: id,
    actorId: id,
    fingerprint: hash,
    revision: integer(),
    gameId: nullable(id),
  }),
  storedLobbyReceipt: object({
    actionId: id,
    playerId: id,
    fingerprint: hash,
    revision: integer(),
  }),
  storedRound: object({
    id,
    question: ref('assignment'),
    roster: seats,
    recipients: seats,
    numbers: array(ref('revealed'), 20),
    acknowledged: seats,
    answerReady: seats,
    orders: array(object({ playerId: id, order: seats }), 20),
    revealOrder: seats,
    revealCursor: integer(0, 20),
    score: nullable(score),
  }),
  storedGame: object(
    {
      formatVersion: { const: 1 },
      gameId: nullable(id),
      revision: integer(),
      config: ref('config'),
      phase,
      pausedFrom,
      pauseReason: pause,
      hostId: id,
      hostRevision: integer(),
      hostDisconnectedAt: nullable(integer()),
      hostPauseState: object({ phase, pausedFrom, pauseReason: pause }, [
        'pausedFrom',
        'pauseReason',
      ]),
      roster: seats,
      effectiveRoster: seats,
      pendingRoster: nullable(seats),
      joinOrder: ids,
      connected: seats,
      judgeId: nullable(id),
      readerId: nullable(id),
      completedCases: integer(0, 491),
      round: nullable(ref('storedRound')),
      lastCompletion: nullable(
        object({
          roundId: id,
          questionId: id,
          kind: { enum: ['judged', 'completed_without_verdict'] },
          score: nullable(score),
        }),
      ),
      completedRoundIds: array(id, 491, true),
      drawnQuestionIds: array(id, 491, true),
      drawnRuleIds: array(id, 25, true),
      ruleSlots: array(
        object(
          {
            afterCase: integer(1, 490),
            status: { enum: ['pending', 'activated', 'skipped'] },
            ruleId: id,
          },
          ['ruleId'],
        ),
        25,
      ),
      activeRules: array(ref('assignment'), 25),
      personCounts: array(object({ playerId: id, count: integer() })),
      history: array(ref('historyEvent'), 32768),
      lastDomainActivity: integer(),
      receipts: array(ref('storedReceipt')),
    },
    ['pausedFrom', 'pauseReason', 'hostPauseState'],
  ),
  storedImport: object({
    ownerId: id,
    offer: ref('historyOffer'),
    createdAt: integer(),
    status: { enum: ['receiving', 'committed', 'cancelled'] },
    pages: array(array(ref('historyEvent'), 64), 64),
    receivedPages: array(integer(0, 63), 64, true),
    receivedEvents: integer(0, 4096),
    bytes: integer(0, 1048576),
  }),
  storedExport: object({
    cursor: id,
    ownerId: id,
    previous: nullable(id),
    eventIds: array(id, 64, true),
    received: boolean,
    hasMore: boolean,
  }),
  storedRoom: object(
    {
      formatVersion: { const: 1 },
      roomId: id,
      code: ref('roomCode'),
      hostId: id,
      revision: integer(),
      createdAt: integer(),
      lastDomainActivity: integer(),
      phase,
      config: ref('config'),
      historyOffer: ref('historyOffer'),
      members: array(ref('storedMember')),
      lobbyReceipts: array(ref('storedLobbyReceipt')),
      game: ref('storedGame'),
      historyImport: ref('storedImport'),
      historyOwners: dictionary(id),
      historyExports: array(ref('storedExport')),
      historyPageHashes: dictionary(hash),
    },
    [
      'historyOffer',
      'lobbyReceipts',
      'game',
      'historyImport',
      'historyOwners',
      'historyExports',
      'historyPageHashes',
    ],
  ),
};
const schema = { $defs: definitions, $ref: '#/$defs/storedRoom' };
const record = (value: unknown): value is Record<string, unknown> =>
  value !== null && typeof value === 'object' && !Array.isArray(value);
export class StoredStateInvalid extends Error {
  constructor() {
    super('ROOM_UNAVAILABLE');
  }
}
function requireState(value: boolean): void {
  if (!value) throw new StoredStateInvalid();
}
function unique(values: readonly string[]): boolean {
  return new Set(values).size === values.length;
}
function sameIds(a: readonly string[], b: readonly string[]): boolean {
  return a.length === b.length && unique(a) && unique(b) && a.every((id) => b.includes(id));
}

/** No clock, randomness, selection or socket effects. Only known additive v1 upgrades. */
export function migrateRoomState(raw: string): { state: RoomState; migrated: boolean } {
  try {
    requireState(new TextEncoder().encode(raw).byteLength <= 64 * 1024 * 1024);
    assertJsonDepth(raw, 32);
    const value: unknown = JSON.parse(raw);
    requireState(record(value) && value.formatVersion === 1);
    const root = value as Record<string, unknown>,
      game = root.game;
    let migrated = false;
    if (record(game) && game.formatVersion === 1) {
      if (record(game.round) && !Object.hasOwn(game.round, 'answerReady')) {
        game.round.answerReady = [];
        migrated = true;
      }
      if (
        game.phase === 'paused' &&
        game.pauseReason === 'host_unavailable' &&
        game.pausedFrom === 'case_boundary' &&
        record(game.hostPauseState) &&
        game.hostPauseState.phase === 'finished'
      ) {
        game.pausedFrom = 'finished';
        migrated = true;
      }
    }
    validateSchema(value, schema);
    const state = value as RoomState,
      memberIds = state.members.map((member) => member.playerId),
      known = new Set(memberIds);
    requireState(unique(memberIds) && state.members.length > 0 && known.has(state.hostId));
    requireState(state.createdAt <= state.lastDomainActivity);
    requireState(state.members.every((member) => member.revoked || !!member.profile));
    requireState(unique((state.lobbyReceipts ?? []).map((r) => r.actionId)));
    requireState(
      (state.lobbyReceipts ?? []).every(
        (receipt) => known.has(receipt.playerId) && receipt.revision <= state.revision,
      ),
    );
    if (state.game) {
      const g = state.game,
        r = g.round;
      requireState(
        g.revision <= state.revision &&
          g.hostId === state.hostId &&
          g.phase === state.phase &&
          canonicalJson(g.config) === canonicalJson(state.config),
      );
      requireState(
        [...g.roster, ...g.effectiveRoster, ...(g.pendingRoster ?? []), ...g.joinOrder].every(
          (id) => known.has(id),
        ),
      );
      requireState(
        g.connected.every((id) => g.roster.includes(id)) &&
          unique(g.personCounts.map((p) => p.playerId)) &&
          g.personCounts.every((p) => known.has(p.playerId)),
      );
      requireState(
        g.completedCases <= g.config.targetCases && g.completedRoundIds.length === g.completedCases,
      );
      requireState(
        g.receipts.every(
          (receipt) => known.has(receipt.actorId) && receipt.revision <= state.revision,
        ),
      );
      requireState(
        unique(g.receipts.map((receipt) => receipt.actionId)) &&
          unique((state.lobbyReceipts ?? []).map((receipt) => receipt.actionId)),
      );
      requireState(
        g.drawnQuestionIds.every((id) => questionIds.has(id)) &&
          g.drawnRuleIds.every((id) => ruleIds.has(id)),
      );
      const effectivePhase = g.phase === 'paused' ? g.pausedFrom : g.phase;
      requireState(effectivePhase !== undefined);
      requireState((effectivePhase === 'lobby') === (g.gameId === null));
      requireState((effectivePhase === 'finished') === (g.completedCases === g.config.targetCases));
      requireState(
        ['numbers', 'answers', 'ordering', 'revealing', 'judged'].includes(effectivePhase!)
          ? r !== null
          : r === null,
      );
      requireState(
        g.activeRules.every(
          (rule) =>
            ruleIds.has(rule.contentId) &&
            Object.values(rule.bindings).every((id) => known.has(id)),
        ),
      );
      requireState(
        unique(g.activeRules.map((rule) => rule.contentId)) &&
          unique(g.history.map((event) => event.eventId)),
      );
      requireState(
        g.history.every(
          (event) =>
            (event.kind === 'question' ? questionIds : ruleIds).has(event.contentId) &&
            Number.isFinite(Date.parse(event.timestampUtc)),
        ),
      );
      if (r) {
        requireState(
          r.roster.length >= 3 &&
            r.roster.every((id) => known.has(id)) &&
            r.recipients.every((id) => r.roster.includes(id)),
        );
        requireState(sameIds(r.roster, g.effectiveRoster));
        requireState(
          g.config.allJudges
            ? g.judgeId === null &&
                r.roster.includes(g.readerId!) &&
                sameIds(r.recipients, r.roster)
            : g.readerId === null &&
                r.roster.includes(g.judgeId!) &&
                sameIds(
                  r.recipients,
                  r.roster.filter((id) => id !== g.judgeId),
                ),
        );
        requireState(Object.values(r.question.bindings).every((id) => r.roster.includes(id)));
        requireState(
          unique(r.numbers.map((n) => n.playerId)) &&
            unique(r.numbers.map((n) => String(n.number))) &&
            r.numbers.length === r.recipients.length &&
            r.numbers.every(
              (n) =>
                r.recipients.includes(n.playerId) &&
                n.number <= Math.ceil((r.roster.length * g.config.factorTenths) / 10),
            ),
        );
        requireState(
          r.acknowledged.every((id) => r.recipients.includes(id)) &&
            r.answerReady.every((id) => r.roster.includes(id)),
        );
        requireState(
          unique(r.orders.map((o) => o.playerId)) &&
            r.orders.every(
              (o) =>
                r.roster.includes(o.playerId) &&
                (g.config.allJudges || o.playerId === g.judgeId) &&
                o.order.length === r.recipients.length &&
                o.order.every((id) => r.recipients.includes(id)),
            ),
        );
        if (['revealing', 'judged'].includes(effectivePhase!))
          requireState(
            sameIds(r.revealOrder, r.recipients) &&
              r.orders.length === (g.config.allJudges ? r.recipients.length : 1),
          );
        requireState((effectivePhase === 'judged') === (r.score !== null));
        const score = r.score;
        if (score) {
          requireState(r.revealCursor === r.recipients.length);
          if (score.kind === 'all_judges')
            requireState(
              g.config.allJudges &&
                sameIds(
                  score.results.map((result) => result.playerId),
                  r.roster,
                ) &&
                score.results.every(
                  (result) =>
                    result.errors !== 1 &&
                    result.errors <= r.recipients.length &&
                    result.errors === result.sips,
                ),
            );
          else
            requireState(
              !g.config.allJudges &&
                score.errors !== 1 &&
                score.errors <= r.recipients.length &&
                sameIds(
                  score.penalties.map((p) => p.playerId),
                  r.roster,
                ) &&
                score.penalties.every((p) => p.sips === 0 || p.sips === score.errors) &&
                score.penalties.find((p) => p.playerId === g.judgeId)?.sips === score.errors,
            );
        }
        requireState(
          r.revealCursor <= r.revealOrder.length &&
            r.revealOrder.every((id) => r.recipients.includes(id)),
        );
        requireState(!g.completedRoundIds.includes(r.id) && questionIds.has(r.question.contentId));
      }
      state.game = immutable(g);
    } else requireState(state.phase === 'lobby');
    return { state, migrated };
  } catch {
    throw new StoredStateInvalid();
  }
}
