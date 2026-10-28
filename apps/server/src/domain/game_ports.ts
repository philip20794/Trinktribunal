import { randomUUID } from 'node:crypto';
import { catalogs } from './catalogs';
import { activateRule, rebindRules } from './drinking_rules';
import type { GamePorts, GameState } from './game_state';
import { assignNumbers, numberLimit } from './numbers';
import { assignContent, type SelectionInput } from './question_assignment';
import { planSlots } from './schedule';
import { secureRandomIndex } from './selection/random';

function input(state: GameState, now: number, drawn: readonly string[]): SelectionInput {
  return {
    players: state.effectiveRoster,
    counts: Object.fromEntries(state.personCounts.map((entry) => [entry.playerId, entry.count])),
    history: state.history,
    drawn,
    now,
  };
}
/** Scoring must be supplied by the server's TT-049/052 implementation. */
export function gamePorts(
  scoreRound: GamePorts['scoreRound'],
  overrides: Partial<Pick<GamePorts, 'now' | 'newId' | 'randomIndex'>> = {},
): GamePorts {
  return {
    now: () => Date.now(),
    newId: () => randomUUID(),
    randomIndex: secureRandomIndex,
    ...overrides,
    planSlots: (config, random) =>
      planSlots(config.targetCases, config.requestedRuleEvents, random),
    prepareQuestion: (state, random, now) =>
      assignContent(
        catalogs[state.config.contentLanguage].questions,
        'question',
        {
          ...input(state, now, state.drawnQuestionIds),
          players: state.round!.roster.filter((id) => state.roster.includes(id)),
        },
        random,
      ),
    prepareCase: (state, random, now) => {
      const question = assignContent(
        catalogs[state.config.contentLanguage].questions,
        'question',
        input(state, now, state.drawnQuestionIds),
        random,
      );
      if (!question) return null;
      return {
        question,
        numbers: assignNumbers(
          state.effectiveRoster,
          (state.config.allJudges ? state.readerId : state.judgeId)!,
          numberLimit(state.effectiveRoster.length, state.config.factorTenths),
          state.config.allJudges,
          random,
        ),
      };
    },
    activateRule: (state, random, now) =>
      activateRule(
        catalogs[state.config.contentLanguage].rules,
        state.activeRules,
        input(state, now, state.drawnRuleIds),
        random,
      ),
    rebindRules: (state, random) =>
      rebindRules(
        catalogs[state.config.contentLanguage].rules,
        state.activeRules,
        input(state, 0, state.drawnRuleIds),
        random,
      ),
    scoreRound,
  };
}
