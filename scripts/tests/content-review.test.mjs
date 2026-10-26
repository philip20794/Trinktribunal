import { test } from 'node:test';
import assert from 'node:assert/strict';
import { loadSources } from '../lib/catalogs.mjs';

const sources = loadSources();
for (const language of ['de', 'en']) {
  test(`editorial anchors and scale roles remain intact (${language})`, () => {
    const questions = sources.find(e => e.kind === 'questions' && e.catalog.language === language).catalog.questions;
    const get = id => questions.find(q => q.id === id);
    assert.match(get('051-a').text, /Captain Hook/); assert.equal(get('051-a').players, undefined);
    for (const id of ['052-b', '110-a']) {
      const q = get(id); assert.deepEqual(Object.keys(q.players), ['player1']);
      for (const text of [q.text, q.scale.green, q.scale.red]) assert.ok(text.includes('{player1}'));
    }
    assert.equal(questions.filter(q => q.players).length, 60);
  });
  test(`D-04 production constraints have exactly the decided pairs (${language})`, () => {
    const rules = sources.find(e => e.kind === 'rules' && e.catalog.language === language).catalog.rules;
    const edges = rules.flatMap(rule => rule.excludes.map(other => `${rule.id}:${other}`)).sort();
    assert.deepEqual(edges, [
      'left_hand_drinking:two_hands_drinking', 'two_hands_drinking:left_hand_drinking',
      'two_hands_drinking:touch_player_while_drinking', 'touch_player_while_drinking:two_hands_drinking',
    ].sort());
    assert.equal(rules.find(rule => rule.id === 'imaginary_kobold').excludes.length, 0);
    assert.equal(rules.find(rule => rule.id === 'imaginary_fly').excludes.length, 0);
  });
}
test('English corrections preserve the German perspective and scale meanings', () => {
  const questions = sources.find(e => e.kind === 'questions' && e.catalog.language === 'en').catalog.questions;
  assert.match(questions.find(q => q.id === '009-a').text, /your crush/);
  assert.match(questions.find(q => q.id === '081-b').scale.red, /three-star/);
  assert.equal(questions.find(q => q.id === '195-b').scale.red, 'Incredibly impressive');
});
