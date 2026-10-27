import type {
  Assignment,
  Config,
  GameId,
  PlayerId,
  RoundId,
} from '../protocol/room_message.generated';

export type Phase =
  | 'lobby'
  | 'numbers'
  | 'answers'
  | 'ordering'
  | 'revealing'
  | 'judged'
  | 'rule_event'
  | 'paused'
  | 'finished';
export type PauseReason = 'insufficient_players' | 'content_exhausted' | 'host_unavailable';
export interface UsageEvent {
  eventId: string;
  kind: 'question' | 'rule';
  contentId: string;
  timestampUtc: string;
}
export interface RuleSlot {
  afterCase: number;
  status: 'pending' | 'activated' | 'skipped';
  ruleId?: string;
}
export interface NormalScore {
  kind: 'normal';
  errors: number;
  penalties: Array<{ playerId: PlayerId; sips: number }>;
}
export interface PersonalScores {
  kind: 'all_judges';
  results: Array<{ playerId: PlayerId; errors: number; sips: number }>;
}
export type Score = NormalScore | PersonalScores;
export interface RoundState {
  id: RoundId;
  question: Assignment;
  roster: PlayerId[];
  recipients: PlayerId[];
  numbers: Array<{ playerId: PlayerId; number: number }>;
  acknowledged: PlayerId[];
  orders: Array<{ playerId: PlayerId; order: PlayerId[] }>;
  revealOrder: PlayerId[];
  revealCursor: number;
  score: Score | null;
}
export interface Completion {
  roundId: RoundId;
  questionId: string;
  kind: 'judged' | 'completed_without_verdict';
  score: Score | null;
}
export interface CoreReceipt {
  actionId: string;
  actorId: PlayerId;
  fingerprint: string;
  revision: number;
}
export interface MutableGameState {
  formatVersion: 1;
  gameId: GameId | null;
  revision: number;
  config: Config;
  phase: Phase;
  pausedFrom?: Exclude<Phase, 'paused' | 'finished'> | 'case_boundary';
  pauseReason?: PauseReason;
  hostId: PlayerId;
  hostRevision: number;
  hostDisconnectedAt: number | null;
  hostPauseState?: {
    phase: Phase;
    pausedFrom?: Exclude<Phase, 'paused' | 'finished'> | 'case_boundary';
    pauseReason?: PauseReason;
  };
  /** Room membership and stable join order are separate from seating/frozen rounds. */
  roster: PlayerId[];
  effectiveRoster: PlayerId[];
  pendingRoster: PlayerId[] | null;
  joinOrder: PlayerId[];
  connected: PlayerId[];
  judgeId: PlayerId | null;
  readerId: PlayerId | null;
  completedCases: number;
  round: RoundState | null;
  lastCompletion: Completion | null;
  completedRoundIds: RoundId[];
  drawnQuestionIds: string[];
  drawnRuleIds: string[];
  ruleSlots: RuleSlot[];
  activeRules: Assignment[];
  personCounts: Array<{ playerId: PlayerId; count: number }>;
  /** Room-scoped six-hour usage survives a game restart. */
  history: UsageEvent[];
  lastDomainActivity: number;
  receipts: CoreReceipt[];
}
export type DeepReadonly<T> = T extends string | number | boolean | null | undefined
  ? T
  : T extends object
    ? { readonly [P in keyof T]: DeepReadonly<T[P]> }
    : T;
export type GameState = DeepReadonly<MutableGameState>;
export interface PreparedCase {
  question: Assignment;
  numbers: Array<{ playerId: PlayerId; number: number }>;
}
export interface GamePorts {
  now(): number;
  newId(kind: 'game' | 'round' | 'event'): string;
  randomIndex(upperBound: number): number;
  /** Selection/number algorithms are injected here by TT-044; never supplied by a client action. */
  planSlots(config: Config, randomIndex: (bound: number) => number): number[];
  prepareCase(
    state: GameState,
    randomIndex: (bound: number) => number,
    now: number,
  ): PreparedCase | null;
  activateRule(
    state: GameState,
    randomIndex: (bound: number) => number,
    now: number,
  ): Assignment | null;
  /** The scoring implementation is attached in TT-049/052, outside client authority. */
  scoreRound(state: GameState): Score;
}
export function immutable<T>(value: T): DeepReadonly<T> {
  if (value && typeof value === 'object') {
    for (const child of Object.values(value)) immutable(child);
    Object.freeze(value);
  }
  return value as DeepReadonly<T>;
}
