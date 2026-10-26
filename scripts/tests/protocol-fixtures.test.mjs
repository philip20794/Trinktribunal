import assert from 'node:assert/strict';
import { readdirSync, readFileSync } from 'node:fs';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { test } from 'node:test';

// Fachliche Oracle-Checks für TT-003: kein Ersatz für Dart-/Worker-Tests.
const root = fileURLToPath(new URL('../../packages/protocol/fixtures/', import.meta.url));
const fixtures = new Map();
const files = [];

for (const category of ['rules', 'transitions']) {
  for (const file of readdirSync(join(root, category)).filter(name => name.endsWith('.json'))) {
    const path = join(root, category, file);
    files.push(path);
    const data = JSON.parse(readFileSync(path, 'utf8'));
    assert.match(data.fixtureId, /^TT003-[A-Z0-9-]+$/);
    assert.ok(!fixtures.has(data.fixtureId), 'Duplicate fixtureId: ' + data.fixtureId);
    assert.ok(Array.isArray(data.decisionRefs) && data.decisionRefs.length);
    assert.ok(data.decisionRefs.every(ref => /^D-\d{2}$/.test(ref)));
    assert.equal(typeof data.operation, 'string');
    assert.ok(data.input && typeof data.input === 'object');
    assert.ok(data.expected && typeof data.expected === 'object');
    fixtures.set(data.fixtureId, data);
  }
}
function get(id) {
  assert.ok(fixtures.has(id), 'Missing required fixture ' + id);
  return fixtures.get(id);
}
function range(limit) {
  return Array.from({ length: limit }, (_, i) => i);
}
function errors(truth, proposed) {
  assert.equal(truth.length, proposed.length);
  assert.deepEqual([...truth].sort(), [...proposed].sort(), 'Not a permutation');
  return range(truth.length).filter(i => truth[i] !== proposed[i]).length;
}
function numberLimit(n, tenths) {
  return Math.floor((n * tenths + 9) / 10);
}
function nextJudge(oldRoster, oldJudgeId, newRoster) {
  if (newRoster.includes(oldJudgeId)) {
    return newRoster[(newRoster.indexOf(oldJudgeId) + 1) % newRoster.length];
  }
  const index = oldRoster.indexOf(oldJudgeId);
  for (let offset = 1; offset <= oldRoster.length; offset++) {
    const candidate = oldRoster[(index + offset) % oldRoster.length];
    if (newRoster.includes(candidate)) return candidate;
  }
  return newRoster[0] ?? null;
}

test('TT-003 Fixtures: Struktur und Eindeutigkeit', () => {
  assert.ok(files.length >= 15, 'Expected all TT-003 fixture categories');
  assert.equal(fixtures.size, files.length);
});

test('D-02/D-10: Zahlen- und Konfigurationsgrenzen', () => {
  const regular = get('TT003-CONFIG-DEFAULT');
  assert.equal(numberLimit(regular.input.playerCount, regular.input.factorTenths),
    regular.expected.maxSecretNumber);
  assert.equal(regular.input.playerCount - 1, regular.expected.numberRecipients);
  assert.equal(Math.min(regular.input.requestedRuleEvents, regular.input.targetCases - 1),
    regular.expected.scheduledRuleEventCount);
  const max = get('TT003-NUMBER-BOUNDS');
  assert.deepEqual(max.input.factorTenths.map(f => numberLimit(max.input.playerCount, f)),
    max.expected.maxSecretNumbers);
  assert.equal(max.input.playerCount, max.expected.allJudgesRecipientCount);
  const bounds = get('TT003-CONFIG-BOUNDARIES');
  for (const [i, c] of bounds.input.cases.entries()) {
    const exp = bounds.expected.cases[i];
    const allowed = c.playerCount >= 3 && c.playerCount <= 20 &&
      c.targetCases >= 1 && c.targetCases <= c.eligibleQuestions &&
      c.requestedRuleEvents >= 0 && c.requestedRuleEvents <= c.eligibleRules &&
      c.factorTenths >= 10 && c.factorTenths <= 30 &&
      !(c.mode !== 'multiplayer' && c.allJudges);
    assert.equal(exp.valid, allowed);
    if (allowed) {
      assert.equal(numberLimit(c.playerCount, c.factorTenths), exp.maxSecretNumber);
      assert.equal(c.playerCount - (c.allJudges ? 0 : 1), exp.numberRecipients);
    }
  }
});

test('D-01: Rule gaps always occur only between cases', () => {
  const edge = get('TT003-SCHEDULE-EDGE');
  for (const [i, c] of edge.input.cases.entries()) {
    const exp = edge.expected.cases[i];
    assert.equal(exp.slots.length, Math.min(c.requestedRuleEvents, c.targetCases - 1));
    assert.equal(exp.effectiveRuleSlots, exp.slots.length);
    assert.ok(exp.slots.every(slot => slot >= 1 && slot < c.targetCases));
  }
  const strat = get('TT003-SCHEDULE-STRATIFIED');
  const slots = strat.input.injectedChosenSlots;
  assert.deepEqual(slots, strat.expected.slots);
  assert.equal(slots.length, strat.expected.effectiveRuleSlots);
  for (const [i, slot] of slots.entries()) {
    assert.ok(strat.input.segments[i].includes(slot));
    if (i > 0) assert.ok(slot - slots[i - 1] > 1);
  }
});

test('D-01: six-hour cutoff and per-game exclusion', () => {
  const cutoff = get('TT003-HISTORY-CUTOFF');
  const threshold = Date.parse(cutoff.input.nowUtc) - 6 * 60 * 60 * 1000;
  const occurrences = cutoff.input.previousUtc.map(ts => Date.parse(ts) > threshold);
  assert.deepEqual(occurrences, cutoff.expected.activeOccurrences);
  const counts = {};
  for (let i = 0; i < occurrences.length; i++) {
    const id = cutoff.input.ids[i];
    counts[id] = (counts[id] ?? 0) + Number(occurrences[i]);
  }
  assert.deepEqual(counts, cutoff.expected.recentCounts);
  const min = get('TT003-HISTORY-MINIMUM');
  const remaining = min.input.candidateIds.filter(
    id => !min.input.alreadyDrawnInGame.includes(id));
  assert.deepEqual(remaining, min.expected.validCandidateIds);
  const fewest = Math.min(...remaining.map(id => min.input.recentCounts[id] ?? 0));
  assert.equal(fewest, min.expected.leastRecentCount);
  assert.deepEqual(remaining.filter(id => min.input.recentCounts[id] === fewest),
    min.expected.eligiblePreferredIds);
});

test('D-05: fair selection, distinct player counting and joining', () => {
  const sample = get('TT003-PERSON-ONE-EACH');
  const counts = { ...sample.input.initialCounters };
  for (const id of sample.input.injectedChoices) {
    assert.ok(counts[id] === Math.min(...sample.input.activePlayerIds.map(p => counts[p])));
    counts[id] += 1;
  }
  assert.deepEqual(counts, sample.expected.finalCounters);
  const join = get('TT003-PERSON-JOIN-MAX');
  assert.equal(Math.max(...Object.values(join.input.activeCounters)), join.expected.newCounter);
  assert.deepEqual(Object.keys(join.input.activeCounters)
    .filter(id => join.input.activeCounters[id] < join.expected.newCounter),
    join.expected.subsequentMinimumCandidateIds);
  const binding = get('TT003-PERSON-DISTINCT-BINDINGS');
  const selected = [...new Set(Object.values(binding.input.injectedValidBinding))];
  assert.deepEqual(selected, binding.expected.distinctBoundPlayerIds);
  const after = { ...binding.input.countersBefore };
  for (const id of selected) after[id] += 1;
  assert.deepEqual(after, binding.expected.countersAfter);
  assert.notEqual(binding.expected.binding.player1, binding.expected.binding.player2);
  const again = get('TT003-PERSON-REACTIVATION');
  assert.equal(again.expected.localSameId.newCounter,
    Math.max(again.input.previousLocalPlayer.count, ...Object.values(again.input.activeCounters)));
  assert.notEqual(again.expected.onlineNewJoin.playerId, again.input.oldOnlinePlayerId);
});

test('D-06: judge successor follows the correct roster order', () => {
  for (const id of ['TT003-JUDGE-REMOVED', 'TT003-JUDGE-ACTIVE']) {
    const { input, expected } = get(id);
    assert.equal(nextJudge(input.previousRosterIds, input.previousJudgeId,
      input.newEffectiveRosterIds), expected.nextJudgeId);
    assert.equal(expected.ruleEventCausesAdditionalRotation, false);
  }
});

test('Normal and all-judge verdict: mismatched positions, no extra penalties', () => {
  const normal = get('TT003-VERDICT-NORMAL-FOUR');
  const wrong = errors(normal.input.trueAscendingIds, normal.input.proposedAscendingIds);
  assert.equal(wrong, normal.expected.wrongPositionCount);
  assert.equal(normal.expected.sipCounts[normal.input.judgeId], wrong);
  assert.ok(normal.expected.misplacedPlayerIds.every(id => normal.expected.sipCounts[id] === wrong));
  const all = get('TT003-VERDICT-ALL-JUDGES');
  for (const [id, proposal] of Object.entries(all.input.privateProposals)) {
    const personal = errors(all.input.trueAscendingIds, proposal);
    assert.equal(personal, all.expected.privateErrors[id]);
    assert.equal(personal, all.expected.privateSipCounts[id]);
  }
  assert.equal(all.expected.additionalSipsFromOtherPlayers, 0);
  assert.equal(all.expected.publicResultContainsPersonalCounts, false);
});

test('D-07: counted skip, no fabricated result and single case completion', () => {
  const skip = get('TT003-SKIP-COUNTED-CASE');
  assert.equal(skip.expected.completedCases, skip.input.completedCases + 1);
  assert.equal(skip.expected.caseCompletion, 'completed_without_verdict');
  assert.equal(skip.expected.wrongPositionCount, null);
  assert.equal(skip.expected.automaticSipCounts, null);
  assert.deepEqual(skip.expected.drawnQuestionIds, skip.input.drawnQuestionIds);
  assert.deepEqual(skip.expected.selectedPersonCounters, skip.input.selectedPersonCounters);
  assert.equal(skip.expected.repeatedActionCountChange, 0);
  const last = get('TT003-SKIP-FINAL');
  assert.equal(last.expected.completedCases, last.input.targetCases);
  assert.equal(last.expected.phase, 'finished');
  assert.equal(last.expected.ruleEventAfterLastCase, false);
});


test('D-17: move an item by insertion, never exchange positions', () => {
  const { input, expected } = get('TT003-REORDER-D17');
  const next = [...input.before];
  const [id] = next.splice(input.fromIndex, 1);
  next.splice(input.toIndex, 0, id);
  assert.deepEqual(next, expected.after);
  assert.equal(new Set(next).size, input.before.length);
  assert.deepEqual([...next].sort(), [...input.before].sort());
  assert.notDeepEqual(next, ['A', 'D', 'C', 'B'], 'A swap is not a move');
});

test('D-02/D-07: paused roster retains the planned rule slot', () => {
  const { input, expected } = get('TT003-PAUSE-D02');
  const active = input.activeBefore.filter(id => !input.departing.includes(id));
  assert.deepEqual(active, expected.activeAfter);
  assert.ok(active.length < 3);
  assert.equal(expected.phase, 'paused');
  assert.equal(expected.error, 'INSUFFICIENT_PLAYERS');
  assert.equal(input.slotStatusBefore, expected.slotStatusAfter);
  assert.equal(expected.drawNextCase, false);
});

test('D-07/D-13: duplicate action does not increment any counters twice', () => {
  const { input, expected } = get('TT003-IDEMPOTENT-D07');
  const actionIds = new Set(input.appliedActionIds);
  let completed = input.completedBefore;
  let successful = 0;
  for (let i = 0; i < input.repeatCount; i++) {
    if (actionIds.has(input.actionId)) continue;
    actionIds.add(input.actionId);
    completed++;
    successful++;
  }
  assert.equal(completed, expected.completedAfter);
  assert.equal(successful, expected.successfulApplications);
  assert.deepEqual([...actionIds], expected.persistedActionIds);
  assert.equal(expected.judgeRotations, successful);
  assert.equal(expected.newRoleSelectionEvents, 0);
  assert.equal(expected.newHistoryEvents, 0);
});

test('D-04: only decided exclusions, manual penalty and no chain', () => {
  const { input, expected } = get('TT003-CONFLICTS-D04');
  assert.equal(input.incompatiblePairs.length, 2);
  assert.deepEqual(expected.incompatible, [true, true]);
  for (const [first, second] of input.incompatiblePairs) {
    assert.notEqual(first, second);
  }
  assert.deepEqual(input.compatiblePair, ['imaginary_kobold', 'imaginary_fly']);
  assert.equal(expected.compatible, true);
  assert.equal(expected.violationsManuallyEnforced, true);
  assert.equal(expected.penaltyPerIndependentViolation, 1);
  assert.equal(expected.penaltyChainsAllowed, false);
});

test('D-01: 50 cases with seven spaced rule slots', () => {
  const { input, expected } = get('TT003-SCHEDULE-50-7');
  const slots = input.chosenSlots;
  assert.equal(slots.length, expected.slotCount);
  assert.equal(new Set(slots).size, slots.length);
  assert.ok(slots.every(index => index >= 1 && index < input.targetCases));
  assert.ok(slots.every((index, i) => i === 0 || index - slots[i - 1] > 1));
  assert.ok(slots.every((index, i) => index >= i * 7 + 1 && index <= i * 7 + 7));
  assert.equal(expected.nonAdjacent, true);
  assert.equal(expected.allBetweenQuestions, true);
});


test('D-02: Unicode grapheme-cluster name length and trimming', () => {
  const { input, expected } = get('TT003-NAME-GRAPHEMES');
  const segmenter = new Intl.Segmenter('de', { granularity: 'grapheme' });
  const names = input.cases.map(c => c.raw.trim());
  assert.deepEqual(names, input.cases.map(c => c.expectedTrimmed));
  const lengths = names.map(name => [...segmenter.segment(name)].length);
  assert.deepEqual(lengths, expected.graphemeCounts);
  assert.deepEqual(lengths.map(n => n >= 1 && n <= 24), expected.valid);
  assert.equal(expected.errorForInvalid, 'INVALID_NAME');
});

test('D-17: incomplete, duplicated, or foreign roster orders are rejected', () => {
  const { input, expected } = get('TT003-ORDER-INVALID');
  const truth = [...input.rosterIds].sort();
  const valid = input.proposals.map(p =>
    p.length === truth.length && new Set(p).size === truth.length &&
    JSON.stringify([...p].sort()) === JSON.stringify(truth));
  assert.deepEqual(valid, expected.valid);
  assert.deepEqual(expected.errors,
    expected.valid.map(v => v ? null : 'INVALID_PERMUTATION'));
});

test('D-07: skip is reserved for host or local operator after confirmation', () => {
  const { input, expected } = get('TT003-SKIP-PERMISSIONS');
  const accepted = input.cases.map(c =>
    (c.mode === 'multiplayer' ? c.actor === 'host' : c.actor === 'local') &&
    c.confirmed && c.questionShown);
  assert.deepEqual(accepted, expected.accepted);
  for (const [i, c] of input.cases.entries()) {
    if (accepted[i]) assert.equal(expected.errors[i], null);
    else if (c.mode === 'multiplayer' && c.actor !== 'host')
      assert.equal(expected.errors[i], 'UNAUTHORIZED_ACTION');
    else assert.equal(expected.errors[i], 'INVALID_PHASE');
  }
});

test('D-01/D-05: a new game resets people but retains content history', () => {
  const { input, expected } = get('TT003-NEW-GAME-COUNTERS');
  assert.deepEqual(Object.fromEntries(
    Object.keys(input.personCounters).map(playerId => [playerId, 0])),
  expected.newPersonCounters);
  assert.deepEqual(input.historyEntries.map(e => e.eventId),
    expected.retainedHistoryEventIds);
  assert.equal(expected.newGameIdDifferent, true);
});

test('D-01: a skipped rule event is not a case or judge rotation', () => {
  const { input, expected } = get('TT003-RULE-SLOT-NOMATCH');
  assert.deepEqual(input.eligibleRuleIds, []);
  assert.equal(expected.slotStatus, 'skipped');
  assert.equal(expected.activatedRuleId, null);
  assert.equal(expected.completedCases, input.completedCases);
  assert.equal(expected.judgeId, input.judgeId);
  assert.equal(expected.additionalCaseCount, 0);
  assert.equal(expected.additionalJudgeRotations, 0);
});
