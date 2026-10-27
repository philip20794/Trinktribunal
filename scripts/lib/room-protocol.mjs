import {createHash} from 'node:crypto';
import {readFileSync} from 'node:fs';
import {canonicalJson,validateSchema} from './catalogs.mjs';
import {roomMessageSchema,messagePolicies,ROOM_LIMITS} from '../../packages/protocol/room-contract.mjs';
import {assertJsonDepth} from '../../packages/protocol/schema-validation.mjs';

const catalog=kind=>JSON.parse(readFileSync(new URL(kind==='question'?'../../data/questions/top-ten/de.json':'../../data/rules/de.json',import.meta.url),'utf8'))[kind==='question'?'questions':'rules'];
const ids={question:new Set(catalog('question').map(e=>e.id)),rule:new Set(catalog('rule').map(e=>e.id))};
const sha=value=>createHash('sha256').update(value).digest('hex');
const fail=message=>{throw new Error(message);};
export const protocolCatalogHash=()=>sha(canonicalJson(JSON.parse(readFileSync(new URL('../../apps/client/assets/catalogs/manifest.json',import.meta.url),'utf8'))));
export function normalizeRoomCode(value) {
  if(typeof value!=='string'||value.length>64)fail('INVALID_ROOM_CODE');
  const code=value.trim().toUpperCase().replace(/[ -]/g,'');
  validateSchema(code,roomMessageSchema.$defs.roomCode);return code;
}
export function resumeVerifier(roomId,token) {
  validateSchema(roomId,roomMessageSchema.$defs.id);
  validateSchema(token,roomMessageSchema.$defs.token);
  const bytes=Buffer.from(token,'base64url');
  if(bytes.length!==32||bytes.toString('base64url')!==token)fail('NONCANONICAL_TOKEN');
  return sha(Buffer.concat([Buffer.from('trinktribunal-resume-v1\0'),Buffer.from(roomId),Buffer.from([0]),bytes]));
}
function utc(value) {const time=Date.parse(value);if(!Number.isFinite(time)||new Date(time).toISOString()!==value)fail('INVALID_UTC');return time;}
function historyEvents(events,nowUtc) {
  const seen=new Set();const now=utc(nowUtc);
  for(const event of events) {
    if(seen.has(event.eventId))fail('DUPLICATE_EVENT');seen.add(event.eventId);
    if(!ids[event.kind].has(event.contentId))fail('UNKNOWN_CONTENT');
    const time=utc(event.timestampUtc);if(time<=now-ROOM_LIMITS.historyWindowMs||time>now)fail('HISTORY_WINDOW');
  }
}
function checkName(profile) {
  if(!profile.name.isWellFormed()||profile.name!==profile.name.trim()||/[\u0000-\u001f\u007f]/u.test(profile.name))fail('INVALID_NAME');
  const length=[...new Intl.Segmenter(undefined,{granularity:'grapheme'}).segment(profile.name)].length;
  if(length<1||length>24)fail('INVALID_NAME');
}
function permutation(order,expected) {
  if(order.length!==expected.length||new Set(order).size!==order.length||order.some(id=>!expected.includes(id)))fail('INVALID_PERMUTATION');
}
function projection(message,recipientId) {
  const pub=message.public,own=message.private,all=pub.config.allJudges;
  if(pub.phase==='paused'&&(!pub.pausedFrom||!pub.pauseReason))fail('MISSING_PAUSE_CONTEXT');
  if(pub.phase!=='paused'&&(pub.pausedFrom!==undefined||pub.pauseReason!==undefined))fail('UNEXPECTED_PAUSE_CONTEXT');
  const phase=pub.phase==='paused'?pub.pausedFrom:pub.phase;
  const roster=pub.frozenRoster,players=pub.players.map(p=>p.playerId);
  if(new Set(players).size!==players.length||!players.includes(pub.hostId)||[...roster,...pub.pendingRoster].some(id=>!players.includes(id)))fail('INVALID_ROSTER');
  if(recipientId!==undefined&&message.you!==recipientId)fail('WRONG_RECIPIENT');
  if(!players.includes(message.you))fail('WRONG_RECIPIENT');
  for(const player of pub.players)checkName(player.profile);
  if(pub.completedCases>pub.config.targetCases)fail('INVALID_CASE_COUNT');
  if((phase==='finished')!==(pub.completedCases===pub.config.targetCases))fail('INVALID_CASE_COUNT');
  if(phase==='rule_event'&&(pub.completedCases===0||pub.activeRules.length===0))fail('INVALID_RULE_EVENT');
  if(phase==='lobby'&&(pub.gameId!==null||pub.roundId!==null||pub.question!==null||roster.length||pub.completedCases!==0||pub.activeRules.length||Object.keys(own).length))fail('LOBBY_HAS_GAME_DATA');
  const boundary=['case_boundary','rule_event'].includes(phase)||(phase==='finished'&&pub.roundId===null);
  if(boundary&&(pub.gameId===null||pub.roundId!==null||pub.question!==null||roster.length||Object.keys(own).length||pub.revealCursor||pub.revealed.length||pub.judgeOrder!==undefined||pub.result!==undefined))fail('BOUNDARY_HAS_CASE_DATA');
  if(phase!=='lobby'&&!boundary&&(roster.length<3||pub.gameId===null||pub.roundId===null||pub.question===null))fail('MISSING_ACTIVE_GAME');
  if(pub.question&&!ids.question.has(pub.question.contentId))fail('UNKNOWN_CONTENT');
  for(const rule of pub.activeRules)if(!ids.rule.has(rule.contentId))fail('UNKNOWN_CONTENT');
  const revealing=['revealing','judged','finished'].includes(phase);
  if(!revealing&&(pub.revealCursor!==0||pub.revealed.length))fail('EARLY_PUBLIC_NUMBER');
  if(pub.revealCursor!==pub.revealed.length)fail('INVALID_REVEAL_CURSOR');
  if(all&&(pub.judgeId!==null||pub.judgeOrder!==undefined||pub.result!==undefined))fail('PUBLIC_PRIVATE_DATA');
  if(all&&!['lobby','case_boundary'].includes(phase)&&!(boundary?players:roster).includes(pub.readerId))fail('INVALID_READER');
  if(!all&&pub.readerId!==null)fail('INVALID_READER');
  if(!all&&['rule_event','finished'].includes(phase)&&boundary&&!players.includes(pub.judgeId))fail('INVALID_JUDGE');
  if(!all&&!['lobby','case_boundary'].includes(phase)&&roster.length&&!roster.includes(pub.judgeId))fail('INVALID_JUDGE');
  if(pub.judgeOrder!==undefined) {
    if(!revealing)fail('EARLY_JUDGE_ORDER');
    permutation(pub.judgeOrder,roster.filter(id=>id!==pub.judgeId));
  }
  if(pub.revealed.length) {
    const sequence=all?roster:pub.judgeOrder;
    if(!sequence)fail('MISSING_REVEAL_ORDER');
    if(new Set(pub.revealed.map(p=>p.number)).size!==pub.revealed.length)fail('DUPLICATE_NUMBER');
    pub.revealed.forEach((p,i)=>{if(p.playerId!==sequence[i])fail('INVALID_REVEAL_PREFIX');});
  }
  if(pub.result!==undefined&&!['judged','finished'].includes(phase))fail('EARLY_RESULT');
  const expectedRecipients=all?roster:roster.filter(id=>id!==pub.judgeId);
  if((phase==='judged'||pub.result!==undefined||own.ownResult!==undefined)&&pub.revealCursor!==expectedRecipients.length)fail('INCOMPLETE_VERDICT_REVEAL');
  if(phase==='judged'&&!all&&pub.result===undefined)fail('MISSING_VERDICT');
  if(phase==='judged'&&all&&roster.includes(message.you)&&own.ownResult===undefined)fail('MISSING_VERDICT');
  if(pub.result!==undefined) {
    const result=pub.result;
    if(result.errors===1||result.errors>roster.length-1)fail('INVALID_RESULT');
    permutation(result.penalties.map(p=>p.playerId),roster);
    if(result.penalties.find(p=>p.playerId===pub.judgeId)?.sips!==result.errors)fail('INVALID_RESULT');
    if(result.penalties.some(p=>p.sips!==0&&p.sips!==result.errors))fail('INVALID_RESULT');
    if(result.errors>0&&result.penalties.filter(p=>p.playerId!==pub.judgeId&&p.sips===result.errors).length!==result.errors)fail('INVALID_RESULT');
  }
  if(own.ownNumber!==undefined&&(!roster.includes(message.you)||(!all&&message.you===pub.judgeId)))fail('FOREIGN_NUMBER');
  if(own.ownOrder!==undefined) {
    if(!roster.includes(message.you)||(!all&&message.you!==pub.judgeId))fail('FOREIGN_ORDER');
    if(!['ordering','revealing','judged','finished'].includes(phase))fail('EARLY_OWN_ORDER');
    permutation(own.ownOrder,all?roster:roster.filter(id=>id!==pub.judgeId));
  }
  if(own.ownResult!==undefined&&(!all||!roster.includes(message.you)||!['judged','finished'].includes(phase)||own.ownResult.sips!==own.ownResult.errors||own.ownResult.errors===1||own.ownResult.errors>roster.length))fail('FOREIGN_OR_EARLY_RESULT');
  const max=Math.ceil(roster.length*pub.config.factorTenths/10);
  if((own.ownNumber??0)>max||pub.revealed.some(p=>p.number>max))fail('NUMBER_OUT_OF_RANGE');
  utc(pub.expiresAtUtc);
}

// Reference contract checks for fixtures. Network authentication/authority is TT-036+.
export function validateRoomMessage(message,{nowUtc=new Date().toISOString(),handshake,recipientId,roles,phase,direction,transport,logical=false}={}) {
  const policy=messagePolicies[message?.type];
  if(!policy)fail('INVALID_MESSAGE');
  const bytes=Buffer.byteLength(JSON.stringify(message));
  if(bytes>(logical?policy.maxBytes:ROOM_LIMITS.frameBytes))fail('MESSAGE_TOO_LARGE');
  validateSchema(message,roomMessageSchema);
  if(direction&&policy.direction!==direction)fail('INVALID_DIRECTION');
  if(transport&&!policy.transports.includes(transport))fail('INVALID_TRANSPORT');
  if(roles&&!policy.roles.some(role=>roles.includes(role)))fail('UNAUTHORIZED_ACTION');
  if(phase&&!policy.phases.includes('any')&&!policy.phases.includes(phase))fail('INVALID_PHASE');
  if(message.profile)checkName(message.profile);
  if(message.handshake&&handshake) {
    if(message.handshake.protocolVersion!==handshake.protocolVersion)fail('PROTOCOL_MISMATCH');
    if(message.handshake.catalogHash!==handshake.catalogHash)fail('CATALOG_MISMATCH');
    if(message.handshake.avatarVersion!==handshake.avatarVersion)fail('AVATAR_MISMATCH');
  }
  if(message.resumeToken&&Buffer.from(message.resumeToken,'base64url').toString('base64url')!==message.resumeToken)fail('NONCANONICAL_TOKEN');
  if(message.expiresAtUtc)utc(message.expiresAtUtc);
  if(message.type==='delta'&&message.baseRevision>=message.revision)fail('INVALID_DELTA_REVISION');
  if(message.you!==undefined&&recipientId!==undefined&&message.you!==recipientId)fail('WRONG_RECIPIENT');
  if(message.events)historyEvents(message.events,nowUtc);
  if(message.type==='historyStatus'&&((message.status==='committed')!==(message.sha256!==undefined)))fail('INVALID_HISTORY_STATUS');
  if(message.public)projection(message,recipientId);
  if(message.type==='projectionChunk') {
    const buffer=Buffer.from(message.data,'base64url');
    if(buffer.byteLength>ROOM_LIMITS.projectionChunkBytes||buffer.toString('base64url')!==message.data)fail('INVALID_CHUNK');
  }
  return message;
}

export function parseRoomFrame(raw,context={}) {
  if(typeof raw!=='string')fail('UNSUPPORTED_FRAME');
  if(Buffer.byteLength(raw)>ROOM_LIMITS.frameBytes)fail('MESSAGE_TOO_LARGE');
  try {assertJsonDepth(raw,ROOM_LIMITS.jsonDepth);} catch {fail('INVALID_MESSAGE');}
  let message;
  try {message=JSON.parse(raw);} catch {fail('INVALID_JSON');}
  return validateRoomMessage(message,context);
}

export function applyDelta(base,delta,context={}) {
  validateRoomMessage(base,{...context,logical:true});
  validateRoomMessage(delta,{...context,logical:true});
  if(base.type!=='snapshot'||delta.type!=='delta'||base.revision!==delta.baseRevision||base.you!==delta.you||base.roomId!==delta.roomId)fail('DELTA_BASE_MISMATCH');
  const next={type:'snapshot',protocolVersion:1,requestId:delta.requestId,roomId:delta.roomId,you:delta.you,revision:delta.revision,public:{...base.public,...delta.publicChanges},private:delta.private};
  return validateRoomMessage(next,{...context,logical:true});
}

export function validateHistoryImport(pages,offer,{nowUtc=new Date().toISOString()}={}) {
  validateSchema(offer,roomMessageSchema.$defs.historyOffer,'offer',roomMessageSchema);
  const received=new Map();
  for(const page of pages) {
    validateRoomMessage(page,{nowUtc});
    if(page.type!=='historyImport'||page.importId!==offer.importId)fail('WRONG_IMPORT');
    const old=received.get(page.page);
    if(old&&canonicalJson(old.events)!==canonicalJson(page.events))fail('PAGE_CONFLICT');
    received.set(page.page,page);
  }
  const ordered=[...received.values()].sort((a,b)=>a.page-b.page);
  if(ordered.some((p,i)=>p.page!==i))fail('MISSING_HISTORY_PAGE');
  const events=ordered.flatMap(page=>page.events);
  historyEvents(events,nowUtc);
  if(events.length!==offer.count||sha(canonicalJson(events))!==offer.sha256)fail('HISTORY_INCOMPLETE');
  return events;
}

export function assembleProjection(start,chunks,end,context={}) {
  for(const message of [start,...chunks,end])validateRoomMessage(message,context);
  if(start.type!=='projectionStart'||end.type!=='projectionEnd'||chunks.length!==start.chunks)fail('INCOMPLETE_PROJECTION');
  const ordered=[...chunks].sort((a,b)=>a.index-b.index);
  for(const [i,chunk] of ordered.entries())if(chunk.type!=='projectionChunk'||chunk.index!==i||chunk.transferId!==start.transferId||chunk.requestId!==start.requestId)fail('MIXED_PROJECTION');
  if(end.transferId!==start.transferId||end.requestId!==start.requestId)fail('MIXED_PROJECTION');
  const bytes=Buffer.concat(ordered.map(chunk=>Buffer.from(chunk.data,'base64url')));
  if(bytes.length!==start.bytes||sha(bytes)!==start.sha256)fail('PROJECTION_INTEGRITY');
  const message=JSON.parse(new TextDecoder('utf-8',{fatal:true}).decode(bytes));
  if(!['snapshot','delta'].includes(message.type)||message.revision!==start.revision||message.requestId!==start.requestId)fail('MIXED_PROJECTION');
  return validateRoomMessage(message,{...context,logical:true});
}
