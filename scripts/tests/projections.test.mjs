import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { test } from 'node:test';

const fixture = JSON.parse(readFileSync(new URL('../../packages/protocol/fixtures/transitions/projection-private.json', import.meta.url), 'utf8'));
const { roomState } = fixture.input;
const { expected } = fixture;

// Reference projection used only to assert TT-003 permissions, not Worker production code.
function projectPublic(state) {
  return {
    gameId: state.gameId,
    phase: state.phase,
    questionId: state.questionId,
    readyPlayerIds: [...state.readyPlayerIds],
  };
}
function projectOwn(state, playerId) {
  if (!Object.hasOwn(state.privateNumbers, playerId)) return null;
  return {
    ownNumber: state.privateNumbers[playerId],
    ownOrder: state.privateOrders[playerId],
    ownSipCount: state.privateSipCounts[playerId],
  };
}

test('D-09: public room snapshot contains no private values or orders', () => {
  assert.deepEqual(projectPublic(roomState), expected.publicProjection);
  for (const key of ['privateNumbers', 'privateOrders', 'privateSipCounts', 'hostId']) {
    assert.equal(Object.hasOwn(projectPublic(roomState), key), false);
  }
});

test('D-09: host and players receive only their own private data', () => {
  for (const [id, own] of Object.entries(expected.ownPrivateByPlayer)) {
    const projected = projectOwn(roomState, id);
    assert.deepEqual(projected, own);
    assert.equal(Object.hasOwn(projected, 'privateNumbers'), false);
    assert.equal(Object.hasOwn(projected, 'privateOrders'), false);
  }
  assert.equal(expected.hostMayInspectOtherPlayers, false);
  assert.deepEqual(Object.keys(projectOwn(roomState, roomState.hostId)), ['ownNumber', 'ownOrder', 'ownSipCount']);
});

test('D-09: unknown player identity never receives a private snapshot', () => {
  assert.equal(projectOwn(roomState, 'unknown'), null);
  assert.equal(expected.unauthenticatedGetsPrivateProjection, false);
});
