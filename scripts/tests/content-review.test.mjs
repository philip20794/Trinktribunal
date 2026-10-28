import { test } from 'node:test';
import assert from 'node:assert/strict';
import { loadSources } from '../lib/catalogs.mjs';
import { readFileSync } from 'node:fs';
import { createHash } from 'node:crypto';
import { canonicalJson } from '../../packages/protocol/schema-validation.mjs';

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

test('final editorial ledger covers all 516 DE/EN pairs and becomes stale on any entry change', () => {
  const lines=readFileSync(new URL('../../docs/qa/content-review-ledger.tsv',import.meta.url),'utf8').trimEnd().split(/\r?\n/);
  assert.equal(lines.shift(),'kind\tid\tdeSha256\tenSha256\treviewDate\tresult\tnote');
  assert.equal(lines.length,516);
  const entries=new Map();
  for(const line of lines) {
    const fields=line.split('\t');assert.equal(fields.length,7);
    const [kind,id,de,en,date,result,note]=fields;
    assert.ok(['questions','rules'].includes(kind));
    assert.ok(['approved','corrected'].includes(result));
    assert.equal(date,'2026-10-28');assert.ok(note.length>0);
    const key=kind+':'+id;assert.ok(!entries.has(key));entries.set(key,{de,en,result});
  }
  const hash=entry=>createHash('sha256').update(canonicalJson(entry)).digest('hex');
  for(const kind of ['questions','rules']) {
    const de=sources.find(s=>s.kind===kind&&s.catalog.language==='de').catalog[kind];
    const en=new Map(sources.find(s=>s.kind===kind&&s.catalog.language==='en').catalog[kind].map(entry=>[entry.id,entry]));
    for(const entry of de) {
      const other=en.get(entry.id),review=entries.get(kind+':'+entry.id);
      assert.ok(review,entry.id);assert.ok(other,entry.id);
      assert.equal(review.de,hash(entry),kind+':'+entry.id+' DE review is stale');
      assert.equal(review.en,hash(other),kind+':'+entry.id+' EN review is stale');
      assert.notEqual(entry.text,other.text,entry.id+' must have a real English text');
      assert.deepEqual(entry.players??{},other.players??{});
      assert.deepEqual(entry.excludes??[],other.excludes??[]);
      if(kind==='questions') {assert.equal(entry.scale.connector,'bis');assert.equal(other.scale.connector,'to');}
    }
  }
  assert.equal([...entries.values()].filter(entry=>entry.result==='corrected').length,3);
});

test('final review preserves positive endpoints, minor-offense scope and German rule grammar',()=>{
  const en=sources.find(s=>s.kind==='questions'&&s.catalog.language==='en').catalog.questions;
  assert.equal(en.find(q=>q.id==='116-b').scale.red,'An unforgettably wonderful experience');
  assert.match(en.find(q=>q.id==='183-a').text,/minor misdeed/);
  const rules=sources.find(s=>s.kind==='rules'&&s.catalog.language==='de').catalog.rules;
  assert.match(rules.find(rule=>rule.id==='interrupting_penalty').text,/Wer jemandem ins Wort fällt/);
});
