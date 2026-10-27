import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {execFileSync} from 'node:child_process';
import {fileURLToPath} from 'node:url';
import {tmpdir} from 'node:os';
import {canonicalJson,validateSchema} from '../lib/catalogs.mjs';
import {roomMessageSchema,messagePolicies,ROOM_LIMITS} from '../../packages/protocol/room-contract.mjs';
import {normalizeRoomCode,resumeVerifier,parseRoomFrame,validateRoomMessage as validateMessage,validateHistoryImport as validateImport,assembleProjection,applyDelta,protocolCatalogHash} from '../lib/room-protocol.mjs';
const fixture=JSON.parse(readFileSync(new URL('../../packages/protocol/fixtures/messages/room-v1.json',import.meta.url),'utf8'));
const sample=type=>structuredClone(fixture.fixtures.find(f=>f.valid.type===type).valid);
const hash=value=>createHash('sha256').update(value).digest('hex');
const validateRoomMessage=(message,context={})=>validateMessage(message,{nowUtc:fixture.nowUtc,...context});
const validateHistoryImport=(pages,offer,context={})=>validateImport(pages,offer,{nowUtc:fixture.nowUtc,...context});

test('every wire type has independent positive/negative fixture, role, phase and size limit',()=>{
  assert.deepEqual(fixture.fixtures.map(f=>f.valid.type).sort(),Object.keys(messagePolicies).sort());
  assert.equal(new Set(fixture.fixtures.map(f=>f.fixtureId)).size,fixture.fixtures.length);
  for(const f of fixture.fixtures) {
    const policy=messagePolicies[f.valid.type];
    assert.doesNotThrow(()=>validateRoomMessage(f.valid,{roles:[f.role],phase:f.phase,nowUtc:fixture.nowUtc,direction:policy.direction,transport:policy.transports[0]}),f.fixtureId);
    assert.throws(()=>validateRoomMessage(f.invalid),undefined,f.fixtureId);
    assert.throws(()=>validateRoomMessage({...f.valid,protocolVersion:2}),undefined,f.fixtureId);
    assert.ok(messagePolicies[f.valid.type].maxBytes<=ROOM_LIMITS.projectionBytes);
  }
});
test('generated schema/policies stay synchronized from any working directory',()=>{
  execFileSync(process.execPath,[fileURLToPath(new URL('../generate-room-protocol.mjs',import.meta.url)),'--check'],{cwd:tmpdir(),stdio:'pipe'});
  assert.deepEqual(JSON.parse(readFileSync(new URL('../../packages/protocol/schemas/room-message.schema.json',import.meta.url),'utf8')),roomMessageSchema);
});
test('schema bounds, codepoint lengths, strict properties and exclusive alternatives fail closed',()=>{
  assert.doesNotThrow(()=>validateSchema('🙂',{type:'string',minLength:1,maxLength:1}));
  for(const [value,schema] of [[2,{maximum:1}],[[1,2],{maxItems:1}],[{a:1,b:2},{maxProperties:1}],['ab',{maxLength:1}],[1,{oneOf:[{type:'integer'},{minimum:0}]}]])assert.throws(()=>validateSchema(value,schema));
  assert.throws(()=>validateSchema(1,{oneOf:[{type:'integer'},{unsupported:true}]}),/unsupported/);
  assert.throws(()=>validateSchema({constructor:'spoof'},{type:'object',properties:{},additionalProperties:false}),/unexpected/);
  assert.throws(()=>validateSchema({},{$ref:'#/$defs/constructor',$defs:{}}),/unknown reference/);
  assert.throws(()=>validateSchema(Object.create({needed:true}),{required:['needed']}),/missing/);
});
test('room code normalization is bounded, explicit and never accepts a token/URL as invitation',()=>{
  assert.equal(normalizeRoomCode(' abcd-2345 '),'ABCD2345');
  for(const value of ['ABCD_2345','ABCO2345','ABCI2345','ABCD2341','https://example.test/ABCD2345','A'.repeat(100),null])assert.throws(()=>normalizeRoomCode(value));
});
test('names use grapheme limits; HTTP/WS payload budgets still apply to complex clusters',()=>{
  const m=sample('join');m.profile.name='👨‍👩‍👧‍👦'.repeat(24);assert.doesNotThrow(()=>validateRoomMessage(m));
  m.profile.name+='A';assert.throws(()=>validateRoomMessage(m),/INVALID_NAME/);
  for(const name of ['  Anna','Anna\n','\ud800','a'+'\u0301'.repeat(9000)]) {m.profile.name=name;assert.throws(()=>validateRoomMessage(m));}
  m.profile.name='Anna';m.profile.avatar.selections.url='https://evil.test/a.svg';assert.throws(()=>validateRoomMessage(m));
});
test('raw frame budget is checked before parsing, including whitespace and binary input',()=>{
  const raw=JSON.stringify(sample('ping'));assert.equal(parseRoomFrame(raw).type,'ping');
  assert.throws(()=>parseRoomFrame(' '.repeat(16384)+raw),/MESSAGE_TOO_LARGE/);
  assert.throws(()=>parseRoomFrame(Buffer.from(raw)),/UNSUPPORTED_FRAME/);
  assert.throws(()=>parseRoomFrame('{"resumeToken":"synthetic-secret"'),error=>error.message==='INVALID_JSON');
  assert.throws(()=>parseRoomFrame('null'),/INVALID_MESSAGE/);
});
test('handshake rejects incompatible content; credentials never enter ACK/error/action bodies',()=>{
  const m=sample('authenticate');const expected=structuredClone(m.handshake);assert.equal(expected.catalogHash,protocolCatalogHash());
  m.handshake.catalogHash='f'.repeat(64);assert.throws(()=>validateRoomMessage(m,{handshake:expected}),/CATALOG_MISMATCH/);
  for(const type of ['ack','error','startGame','submitOrder','snapshot'])assert.throws(()=>validateRoomMessage({...sample(type),resumeToken:'A'.repeat(43)}));
  m.resumeToken='A'.repeat(42)+'B';assert.throws(()=>validateRoomMessage(m),/NONCANONICAL_TOKEN/);
});
test('fixed verifier vectors bind the same synthetic credential to its own room',()=>{
  const vectors=JSON.parse(readFileSync(new URL('../../packages/protocol/fixtures/messages/resume-verifiers.json',import.meta.url),'utf8')).vectors;
  for(const vector of vectors)assert.equal(resumeVerifier(vector.roomId,vector.resumeToken),vector.expectedVerifier);
  assert.notEqual(vectors[0].expectedVerifier,vectors[1].expectedVerifier);
  assert.throws(()=>resumeVerifier('room_1','A'.repeat(42)+'B'),/NONCANONICAL/);
});
test('role and phase matrix does not make a host the judge or a judge the host',()=>{
  assert.throws(()=>validateRoomMessage(sample('submitOrder'),{roles:['host'],phase:'ordering'}),/UNAUTHORIZED/);
  assert.throws(()=>validateRoomMessage(sample('completeWithoutVerdict'),{roles:['judge'],phase:'ordering'}),/UNAUTHORIZED/);
  assert.throws(()=>validateRoomMessage(sample('startGame'),{roles:['host'],phase:'numbers'}),/INVALID_PHASE/);
  assert.doesNotThrow(()=>validateRoomMessage(sample('submitOrder'),{roles:['allJudgesParticipant'],phase:'ordering'}));
  assert.throws(()=>validateRoomMessage(sample('requestSnapshot'),{roles:['unauthenticated']}),/UNAUTHORIZED/);
  assert.throws(()=>validateRoomMessage(sample('credential'),{transport:'websocket'}),/TRANSPORT/);
  assert.throws(()=>validateRoomMessage(sample('ack'),{direction:'client'}),/DIRECTION/);
});
test('normal reveal exposes exactly its committed prefix and only the recipient receives own number',()=>{
  const m=sample('snapshot');m.public.phase='revealing';m.public.judgeOrder=['p2','p3'];m.public.revealCursor=1;m.public.revealed=[{playerId:'p2',number:2}];
  assert.doesNotThrow(()=>validateRoomMessage(m,{recipientId:'p2'}));
  assert.throws(()=>validateRoomMessage(m,{recipientId:'p1'}),/WRONG_RECIPIENT/);
  const early=structuredClone(m);early.public.phase='ordering';assert.throws(()=>validateRoomMessage(early),/EARLY_PUBLIC/);
  const future=structuredClone(m);future.public.revealed.push({playerId:'p3',number:3});assert.throws(()=>validateRoomMessage(future),/CURSOR/);
  const swapped=structuredClone(m);swapped.public.revealed[0].playerId='p3';assert.throws(()=>validateRoomMessage(swapped),/PREFIX/);
  const paused=structuredClone(m);Object.assign(paused.public,{phase:'paused',pausedFrom:'revealing',pauseReason:'host_unavailable'});assert.doesNotThrow(()=>validateRoomMessage(paused));
  delete paused.public.pausedFrom;assert.throws(()=>validateRoomMessage(paused),/PAUSE_CONTEXT/);
  m.you='p1';assert.throws(()=>validateRoomMessage(m),/FOREIGN_NUMBER/);
});
test('all-judge private orders/results cannot become host/public data in any phase',()=>{
  const base=sample('snapshot');base.public.config.allJudges=true;base.public.judgeId=null;base.public.readerId='p1';
  for(const phase of ['numbers','answers','ordering','revealing','judged','rule_event','paused','finished']) {
    const m=structuredClone(base);m.public.phase=phase;
    if(phase==='finished')m.public.completedCases=m.public.config.targetCases;
    if(phase==='rule_event'){Object.assign(m.public,{completedCases:1,activeRules:[{contentId:'swear_penalty',bindings:{}}],roundId:null,question:null,frozenRoster:[]});m.private={};}
    if(phase==='paused')Object.assign(m.public,{pausedFrom:'numbers',pauseReason:'host_unavailable'});
    if(['ordering','revealing','judged','finished'].includes(phase))m.private.ownOrder=['p1','p3','p2'];
    if(['judged','finished'].includes(phase)) {
      m.private.ownResult={errors:2,sips:2};m.public.revealCursor=3;
      m.public.revealed=['p1','p2','p3'].map((playerId,index)=>({playerId,number:index+1}));
    }
    assert.doesNotThrow(()=>validateRoomMessage(m),phase);
    for(const key of ['privateNumberAssignments','confirmedOrders','resumeToken','history']) {const bad=structuredClone(m);bad.public[key]={p1:2};assert.throws(()=>validateRoomMessage(bad),undefined,`${phase}/${key}`);}
    m.public.result={errors:0,penalties:[]};assert.throws(()=>validateRoomMessage(m),/PUBLIC_PRIVATE|BOUNDARY_HAS_CASE/);
  }
  const lobby=structuredClone(base);Object.assign(lobby.public,{phase:'lobby',gameId:null,roundId:null,question:null,frozenRoster:[],readerId:null});lobby.private={};assert.doesNotThrow(()=>validateRoomMessage(lobby));
  const pending=structuredClone(base);pending.public.phase='ordering';pending.public.players.push({...pending.public.players[0],playerId:'p4'});pending.you='p4';pending.private={ownOrder:['p1','p2','p3']};assert.throws(()=>validateRoomMessage(pending),/FOREIGN_ORDER/);
});
test('normal mode preserves only the same authorized fields throughout every wire phase',()=>{
  for(const phase of ['lobby','numbers','answers','ordering','revealing','judged','rule_event','paused','finished']) {
    const m=sample('snapshot');m.public.phase=phase;
    if(phase==='lobby'){Object.assign(m.public,{gameId:null,roundId:null,question:null,frozenRoster:[],judgeId:null});m.private={};}
    if(phase==='paused')Object.assign(m.public,{pausedFrom:'numbers',pauseReason:'host_unavailable'});
    if(phase==='rule_event'){Object.assign(m.public,{completedCases:1,activeRules:[{contentId:'swear_penalty',bindings:{}}],roundId:null,question:null,frozenRoster:[]});m.private={};}
    if(phase==='finished')m.public.completedCases=50;
    if(['revealing','judged'].includes(phase))m.public.judgeOrder=['p2','p3'];
    if(phase==='judged')Object.assign(m.public,{revealCursor:2,revealed:[{playerId:'p2',number:2},{playerId:'p3',number:3}],result:{errors:0,penalties:['p1','p2','p3'].map(playerId=>({playerId,sips:0}))}});
    assert.doesNotThrow(()=>validateRoomMessage(m),phase);
    const foreign=structuredClone(m);foreign.private.ownOrder=['p2','p3'];assert.throws(()=>validateRoomMessage(foreign),undefined,phase);
    m.public.resumeToken='A'.repeat(43);assert.throws(()=>validateRoomMessage(m),undefined,phase);
  }
});
test('boundary pauses do not invent a new case; verdicts require a complete reveal',()=>{
  const paused=sample('snapshot');Object.assign(paused.public,{phase:'paused',pausedFrom:'case_boundary',pauseReason:'insufficient_players',roundId:null,question:null,frozenRoster:[],judgeId:null,completedCases:1});paused.private={};
  assert.doesNotThrow(()=>validateRoomMessage(paused));
  paused.private.ownNumber=2;assert.throws(()=>validateRoomMessage(paused),/BOUNDARY_HAS_CASE/);
  const judged=sample('snapshot');Object.assign(judged.public,{phase:'judged',judgeOrder:['p2','p3'],result:{errors:0,penalties:['p1','p2','p3'].map(playerId=>({playerId,sips:0}))}});
  assert.throws(()=>validateRoomMessage(judged),/INCOMPLETE_VERDICT/);
  judged.public.revealed=[{playerId:'p2',number:2},{playerId:'p3',number:3}];judged.public.revealCursor=2;assert.doesNotThrow(()=>validateRoomMessage(judged));
});

test('rule and finished boundaries carry no previous or future case secrets in either mode',()=>{
  for(const allJudges of [false,true])for(const phase of ['rule_event','finished']){
    const m=sample('snapshot');Object.assign(m.public,{phase,config:{...m.public.config,allJudges},completedCases:phase==='finished'?50:1,roundId:null,question:null,frozenRoster:[],judgeId:allJudges?null:'p1',readerId:allJudges?'p1':null,activeRules:[{contentId:'swear_penalty',bindings:{}}]});m.private={};
    assert.doesNotThrow(()=>validateRoomMessage(m));
    for(const changes of [{question:sample('snapshot').public.question},{roundId:'future_round'},{frozenRoster:['p1','p2','p3']},{judgeOrder:[]},{result:{errors:0,penalties:[]}}]){
      const bad=structuredClone(m);Object.assign(bad.public,changes);assert.throws(()=>validateRoomMessage(bad));
    }
    const secret=structuredClone(m);secret.private.ownNumber=2;assert.throws(()=>validateRoomMessage(secret),/BOUNDARY_HAS_CASE/);
  }
});
test('history validates IDs, real UTC, strict six-hour boundary and idempotent page replay',()=>{
  const page=sample('historyImport');const offer={importId:page.importId,count:1,sha256:hash(canonicalJson(page.events))};
  assert.deepEqual(validateHistoryImport([page,page],offer),page.events);
  const status=sample('historyStatus');status.status='committed';assert.throws(()=>validateRoomMessage(status),/HISTORY_STATUS/);status.sha256=offer.sha256;assert.doesNotThrow(()=>validateRoomMessage(status));
  for(const timestampUtc of ['2026-10-27T06:00:00.001Z','2026-10-27T12:00:00.000Z']) {const edge=structuredClone(page);edge.events[0].timestampUtc=timestampUtc;assert.doesNotThrow(()=>validateRoomMessage(edge));}
  for(const [key,value] of [['contentId','999-z'],['timestampUtc','2026-02-30T11:00:00.000Z'],['timestampUtc','2026-10-27T06:00:00.000Z'],['timestampUtc','2026-10-27T12:00:00.001Z']]) {const bad=structuredClone(page);bad.events[0][key]=value;assert.throws(()=>validateHistoryImport([bad],offer));}
  const changed=structuredClone(page);changed.events[0].timestampUtc='2026-10-27T11:58:00.000Z';assert.throws(()=>validateHistoryImport([page,changed],offer),/PAGE_CONFLICT/);
  const missing=structuredClone(page);missing.page=1;assert.throws(()=>validateHistoryImport([missing],offer),/MISSING_HISTORY_PAGE/);
  const duplicates=structuredClone(page);duplicates.events.push({...page.events[0],timestampUtc:'2026-10-27T11:58:00.000Z'});assert.throws(()=>validateRoomMessage(duplicates),/DUPLICATE_EVENT/);
  page.events=Array.from({length:65},(_,i)=>({...page.events[0],eventId:'event_'+i}));assert.throws(()=>validateRoomMessage(page));
});
test('paged history fits frame budget and incomplete or oversized offers cannot commit',()=>{
  const p=sample('historyImport');p.events=Array.from({length:64},(_,i)=>({...p.events[0],eventId:'event_'+i}));
  const second=structuredClone(p);second.page=1;second.events=[{...p.events[0],eventId:'event_64'}];
  const events=[...p.events,...second.events],offer={importId:p.importId,count:65,sha256:hash(canonicalJson(events))};
  assert.equal(validateHistoryImport([second,p],offer).length,65);
  assert.throws(()=>validateHistoryImport([p],offer),/INCOMPLETE/);
  assert.throws(()=>validateHistoryImport([p],{...offer,count:4097}));
  assert.ok(Buffer.byteLength(JSON.stringify(p))<ROOM_LIMITS.frameBytes);
});
test('large projections reassemble atomically under frame limits and validate their private recipient',()=>{
  const snapshot=sample('snapshot');for(const player of snapshot.public.players)player.profile.name='A'+'\u0301'.repeat(4000);
  assert.throws(()=>validateRoomMessage(snapshot),/TOO_LARGE/);assert.doesNotThrow(()=>validateRoomMessage(snapshot,{logical:true}));
  const raw=Buffer.from(JSON.stringify(snapshot)),chunks=[];
  for(let offset=0;offset<raw.length;offset+=8192)chunks.push({...sample('projectionChunk'),index:chunks.length,data:raw.subarray(offset,offset+8192).toString('base64url')});
  const start={...sample('projectionStart'),bytes:raw.length,chunks:chunks.length,sha256:hash(raw)},end=sample('projectionEnd');
  assert.deepEqual(assembleProjection(start,chunks,end,{recipientId:'p2'}),snapshot);
  assert.throws(()=>assembleProjection(start,chunks,end,{recipientId:'p1'}),/RECIPIENT/);
  const bad=structuredClone(chunks);bad[0].data='e30';assert.throws(()=>assembleProjection(start,bad,end),/INTEGRITY/);
  assert.throws(()=>assembleProjection(start,chunks.slice(1),end),/INCOMPLETE/);
  assert.throws(()=>assembleProjection(start,chunks,{...end,transferId:'other'}),/MIXED/);
});
test('small deltas require the exact base and replace private values without retaining cleared secrets',()=>{
  const base=sample('snapshot'),delta=sample('delta');
  const next=applyDelta(base,delta,{recipientId:'p2'});assert.equal(next.public.phase,'answers');assert.equal(next.revision,2);assert.equal(next.public.question.contentId,base.public.question.contentId);
  const clear=structuredClone(delta);clear.private={};assert.deepEqual(applyDelta(base,clear).private,{});assert.equal(base.private.ownNumber,2);
  for(const changes of [{baseRevision:0},{you:'p1'},{roomId:'other_room'}])assert.throws(()=>applyDelta(base,{...delta,...changes}),/BASE_MISMATCH/);
  assert.throws(()=>applyDelta(base,{...delta,publicChanges:{revealed:[{playerId:'p3',number:1}]}}),/EARLY_PUBLIC/);
  assert.throws(()=>applyDelta(base,{...delta,publicChanges:{resumeToken:'A'.repeat(43)}}));
  assert.throws(()=>applyDelta(base,{...delta,private:{ownOrder:['p2','p3']}}),/FOREIGN_ORDER/);
});
