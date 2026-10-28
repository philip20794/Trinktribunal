import {test} from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';

const contract=JSON.parse(readFileSync(new URL('../../docs/contracts/fixtures/gameplay-flow-d19.json',import.meta.url)));

test('D-19 reference matrix is explicitly prospective and covers the requested modes/roles',()=>{
  assert.equal(contract.status,'SPECIFICATION_ONLY');
  assert.equal(contract.decision,'D-19');
  assert.deepEqual(contract.implementationTasks,['TT-080','TT-081','TT-082','TT-083','TT-084']);
  const all=[...contract.rerolls,...contract.advances];
  assert.equal(new Set(all.map(row=>row.id)).size,all.length);
  assert.deepEqual([...new Set(contract.rerolls.map(row=>row.mode))].sort(),['multiplayer','physical_cards','shared_phone']);
  assert.ok(contract.rerolls.some(row=>row.allJudges&&row.actor==='reader'&&row.outcome==='accepted'));
  assert.equal(contract.rerolls.find(row=>row.id==='host-not-judge').outcome,'rejected');
});

test('D-19 reroll examples preserve the case and numbers, and never retract publicly revealed knowledge',()=>{
  for(const row of contract.rerolls) {
    assert.equal(row.expected.completedCasesDelta,0,row.id);
    assert.equal(row.expected.rotationDelta,0,row.id);
    assert.equal(row.expected.ruleActivationsDelta,0,row.id);
    assert.equal(row.expected.numbersPreserved,true,row.id);
    assert.equal(row.expected.secretVisible,false,row.id);
    if(row.outcome==='accepted') {
      assert.equal(row.revealCursor,0,row.id);
      assert.equal(row.expected.historyDrawDelta,1,row.id);
      assert.equal(row.expected.newQuestionInstance,true,row.id);
      assert.equal(row.expected.clearsDrafts,true,row.id);
    } else {
      assert.equal(row.expected.historyDrawDelta,0,row.id);
      assert.equal(row.expected.newQuestionInstance,false,row.id);
      assert.equal(row.nextPhase,row.phase,row.id);
    }
  }
  assert.equal(contract.rerolls.find(row=>row.id==='public-number').outcome,'rejected');
  assert.equal(contract.rerolls.find(row=>row.id==='empty-candidates').outcome,'no_candidate');
});

test('D-19 normal next, within-case next and explicit D-07 completion have distinct expected effects',()=>{
  for(const row of contract.advances) {
    assert.equal(row.manualPenaltyDialog,false);
    if(row.intent==='normal_next') {
      assert.equal(row.confirmation,false);assert.equal(row.completedCasesDelta,1);
    }
    if(row.intent==='within_case_next'||row.intent==='cancel_abort_dialog') assert.equal(row.completedCasesDelta,0);
    if(row.intent==='abort_without_verdict') {
      assert.equal(row.confirmation,true);assert.equal(row.completedCasesDelta,1);assert.equal(row.score,null);
    }
  }
  assert.equal(contract.advances.find(row=>row.id==='played-physical').completion,'played_without_recorded_verdict');
  assert.equal(contract.advances.find(row=>row.id==='explicit-d07').completion,'completed_without_verdict');
});

test('D-19 handoff examples cover 3–20 people, prior-judge removal and secret-safe restoration',()=>{
  for(const row of contract.handoffOrderExamples) {
    assert.equal(row.expected.length,row.seats.length-1,row.id);
    assert.equal(new Set(row.expected).size,row.expected.length,row.id);
    assert.ok(!row.expected.includes(row.judge),row.id);
    assert.deepEqual([...row.expected].sort(),row.seats.filter(id=>id!==row.judge).sort(),row.id);
    if(row.previousJudge&&row.seats.includes(row.previousJudge)) assert.equal(row.expected[0],row.previousJudge,row.id);
  }
  assert.deepEqual(contract.handoffOrderExamples.find(row=>row.id==='old-judge-first').expected,['a','c','d']);
  assert.equal(contract.privatePage.containsQuestion,false);
  assert.equal(contract.privatePage.persistVisibleFlag,false);
  assert.equal(contract.privatePage.restoreStage,'recipient_handoff_same_person');
  for(const trigger of ['holdUp','pointerCancel','focusLost','background','resume','newQuestionInstance']) assert.ok(contract.privatePage.hiddenOn.includes(trigger));
});
