// Declarative source for schemas/room-message.schema.json. No server implementation.
const ref=name=>({$ref:'#/$defs/'+name});
const object=(properties,optional=[])=>({type:'object',additionalProperties:false,required:Object.keys(properties).filter(k=>!optional.includes(k)),properties});
const array=(items,maxItems,minItems=0)=>({type:'array',items,minItems,maxItems,uniqueItems:true});
const integer=(minimum,maximum=Number.MAX_SAFE_INTEGER)=>({type:'integer',minimum,maximum});
const text=(pattern,maxLength=64)=>({type:'string',pattern,maxLength});
const nullable=schema=>({oneOf:[schema,{const:null}]});
export const ROOM_LIMITS=Object.freeze({frameBytes:16384,jsonDepth:32,projectionBytes:524288,projectionChunkBytes:8192,projectionChunks:64,historyPageEntries:64,historyEvents:4096,historyStagingBytes:1048576,historyTimeoutMs:60000,historyWindowMs:21600000,authTimeoutMs:5000,projectionTimeoutMs:15000,actionsPerSecond:10,actionBurst:20,actionJournalEntries:16384,createAttempts:8,hostGraceMs:90000,roomIdleMs:86400000,roomHardMs:172800000});
const defs={
  id:text('^[A-Za-z0-9_-]{1,64}$'),
  hash:text('^[a-f0-9]{64}$',64),
  token:text('^[A-Za-z0-9_-]{43}$',43),
  roomCode:text('^[ABCDEFGHJKLMNPQRSTUVWXYZ23456789]{8}$',8),
  utc:text('^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}\\.[0-9]{3}Z$',24),
  revision:integer(0),
  config:object({targetCases:integer(1,491),requestedRuleEvents:integer(0,25),factorTenths:integer(10,30),allJudges:{type:'boolean'},contentLanguage:{enum:['de','en']}}),
  handshake:object({protocolVersion:{const:1},catalogHash:ref('hash'),avatarVersion:{const:1}}),
  avatar:object({version:{const:1},selections:object({
    face:{enum:['round','square','long']},skin:{enum:['light','medium','brown','dark']},eyes:{enum:['open','sleepy']},brows:{enum:['calm','raised']},nose:{enum:['round','long']},mouth:{enum:['smile','neutral','surprised']},hair:{enum:['short','curly','long','bald']},hairColor:{enum:['brown','black','gold','gray']},beard:{enum:['none','stubble','full']},top:{enum:['shirt','jacket']},topColor:{enum:['blue','red','green','brown']},glasses:{enum:['none','round']},hat:{enum:['none','cap']},extra:{enum:['none','bowtie']},
  })}),
  profile:object({name:{type:'string',minLength:1},avatar:ref('avatar')}),
  historyEvent:object({eventId:ref('id'),kind:{enum:['question','rule']},contentId:text('^[A-Za-z0-9_-]{1,64}$'),timestampUtc:ref('utc')}),
  historyOffer:object({importId:ref('id'),count:integer(0,ROOM_LIMITS.historyEvents),sha256:ref('hash')}),
  revealed:object({playerId:ref('id'),number:integer(1,60)}),
  binding:{type:'object',propertyNames:text('^player[1-9][0-9]*$',16),maxProperties:20,additionalProperties:ref('id')},
  assignment:object({contentId:text('^[A-Za-z0-9_-]{1,64}$'),bindings:ref('binding')}),
  participant:object({playerId:ref('id'),profile:ref('profile'),connected:{type:'boolean'},ready:{type:'boolean'},orderSubmitted:{type:'boolean'},active:{type:'boolean'}},['active']),
  penalty:object({playerId:ref('id'),sips:integer(0,20)}),
  publicResult:object({errors:integer(0,20),penalties:array(ref('penalty'),20)}),
  ownResult:object({errors:integer(0,20),sips:integer(0,20)}),
  privateView:object({ownNumber:integer(1,60),ownOrder:array(ref('id'),20,2),ownResult:ref('ownResult')},['ownNumber','ownOrder','ownResult']),
  publicView:object({
    phase:{enum:['lobby','numbers','answers','ordering','revealing','judged','rule_event','paused','finished']},
    hostId:ref('id'),hostRevision:ref('revision'),config:ref('config'),players:array(ref('participant'),20,1),
    frozenRoster:array(ref('id'),20),pendingRoster:array(ref('id'),20),
    gameId:nullable(ref('id')),roundId:nullable(ref('id')),judgeId:nullable(ref('id')),readerId:nullable(ref('id')),
    question:nullable(ref('assignment')),activeRules:array(ref('assignment'),25),completedCases:integer(0,491),
    revealCursor:integer(0,20),revealed:array(ref('revealed'),20),judgeOrder:array(ref('id'),20,2),result:ref('publicResult'),
    pauseReason:{enum:['insufficient_players','content_exhausted','host_unavailable']},expiresAtUtc:ref('utc'),
    pausedFrom:{enum:['lobby','case_boundary','numbers','answers','ordering','revealing','judged','rule_event','finished']},
  },['judgeOrder','result','pauseReason','pausedFrom']),
};
defs.publicChanges=object(defs.publicView.properties,Object.keys(defs.publicView.properties));

export const messagePolicies={};
function message(type,fields,{direction='client',roles=['authenticated'],phases=['any'],optional=[],action=false}={}) {
  const metadata=action?{actionId:ref('id'),expectedRevision:ref('revision')}:{requestId:ref('id')};
  defs[type]=object({type:{const:type},protocolVersion:{const:1},...metadata,...fields},optional);
  const transports=['create','join','credential','leaveHttp'].includes(type)?['http']:['ack','error'].includes(type)?['http','websocket']:['websocket'];
  messagePolicies[type]={direction,transports,roles,phases,maxBytes:['snapshot','delta'].includes(type)?ROOM_LIMITS.projectionBytes:ROOM_LIMITS.frameBytes,action};
}
const any={phases:['any']},lobby={phases:['lobby']},host={roles:['host']},server={direction:'server',roles:['recipient'],phases:['any']};
message('create',{profile:ref('profile'),handshake:ref('handshake'),historyOffer:ref('historyOffer')},{roles:['anonymous'],phases:['none'],optional:['historyOffer']});
message('join',{profile:ref('profile'),handshake:ref('handshake')},{roles:['anonymous'],phases:['any']});
message('credential',{roomCode:ref('roomCode'),roomId:ref('id'),playerId:ref('id'),resumeToken:ref('token'),expiresAtUtc:ref('utc')},server);
message('authenticate',{resumeToken:ref('token'),handshake:ref('handshake')},{roles:['unauthenticated'],phases:['any']});
message('leaveHttp',{resumeToken:ref('token'),actionId:ref('id'),confirmed:{const:true}},{roles:['credentialOwner'],phases:['any']});
message('authenticated',{roomId:ref('id'),playerId:ref('id'),generation:integer(1),expiresAtUtc:ref('utc'),handshake:ref('handshake')},server);
message('requestSnapshot',{},any);
message('setConfig',{config:ref('config')},{...host,...lobby,action:true});
message('startGame',{},{...host,...lobby,action:true});
message('restartGame',{gameId:ref('id'),config:ref('config'),confirmed:{const:true}},{...host,...any,action:true});
message('editOwnProfile',{profile:ref('profile')},{...any,action:true});
message('reorderRoster',{playerIds:array(ref('id'),20,1)},{...host,...any,action:true});
message('kick',{targetPlayerId:ref('id'),confirmed:{const:true}},{...host,...any,action:true});
message('leave',{confirmed:{const:true}},{...any,action:true});
message('closeRoom',{confirmed:{const:true}},{...host,...any,action:true});
const round={gameId:ref('id'),roundId:ref('id')};
message('acknowledgeNumber',round,{roles:['numberRecipient'],phases:['numbers'],action:true});
message('readyForOrdering',round,{roles:['roundParticipant'],phases:['answers'],action:true});
message('beginOrdering',round,{...host,phases:['answers'],action:true});
message('submitOrder',{...round,order:array(ref('id'),20,2),confirmed:{const:true}},{roles:['judge','allJudgesParticipant'],phases:['ordering'],action:true});
message('revealNext',{...round,expectedCursor:integer(0,19)},{...host,phases:['revealing'],action:true});
message('completeCase',round,{...host,phases:['judged'],action:true});
message('completeWithoutVerdict',{...round,confirmed:{const:true}},{...host,phases:['numbers','answers','ordering','revealing','judged','paused'],action:true});
message('continueRule',{gameId:ref('id'),afterCase:integer(1,490)},{...host,phases:['rule_event'],action:true});
message('resumePaused',{gameId:ref('id')},{...host,phases:['paused'],action:true});
message('historyImport',{importId:ref('id'),page:integer(0,ROOM_LIMITS.historyEvents/ROOM_LIMITS.historyPageEntries-1),events:array(ref('historyEvent'),ROOM_LIMITS.historyPageEntries,1)},{...host,...lobby});
message('historyBegin',{offer:ref('historyOffer')},{...host,...lobby});
message('historyStatus',{importId:ref('id'),status:{enum:['receiving','committed','cancelled']},receivedPages:array(integer(0,ROOM_LIMITS.historyEvents/ROOM_LIMITS.historyPageEntries-1),ROOM_LIMITS.historyEvents/ROOM_LIMITS.historyPageEntries),receivedEvents:integer(0,ROOM_LIMITS.historyEvents),sha256:ref('hash')},{...server,roles:['historyOwner'],phases:['lobby'],optional:['sha256']});
message('cancelHistoryImport',{importId:ref('id')},{...host,...lobby});
message('historyPull',{cursor:nullable(ref('id'))},{roles:['historyOwner'],phases:['any']});
message('historyEvents',{cursor:ref('id'),hasMore:{type:'boolean'},events:array(ref('historyEvent'),ROOM_LIMITS.historyPageEntries)},{...server,roles:['historyOwner']});
message('historyReceipt',{cursor:ref('id')},{roles:['historyOwner'],phases:['any']});
message('ack',{actionId:ref('id'),revision:ref('revision'),outcome:{enum:['committed','duplicate','left','closed']}},server);
export const ERROR_CODES=['INVALID_MESSAGE','MESSAGE_TOO_LARGE','PROTOCOL_MISMATCH','CATALOG_MISMATCH','AVATAR_MISMATCH','CREDENTIAL_INVALID','ROOM_UNAVAILABLE','ROOM_FULL','RATE_LIMITED','UNAUTHORIZED_ACTION','INVALID_CONFIG','INVALID_NAME','INVALID_PHASE','STALE_ROUND','STALE_REVISION','ACTION_ID_CONFLICT','INVALID_PERMUTATION','CONTENT_EXHAUSTED','INSUFFICIENT_PLAYERS','HISTORY_INVALID','HISTORY_INCOMPLETE','SESSION_REPLACED'];
message('error',{code:{enum:ERROR_CODES}},{...server,roles:['requester']});
message('sessionReplaced',{},server);
message('roomClosed',{},server);
message('ping',{},any);message('pong',{},server);
const projection={roomId:ref('id'),you:ref('id'),revision:ref('revision'),public:ref('publicView'),private:ref('privateView')};
message('snapshot',projection,server);
message('delta',{roomId:ref('id'),you:ref('id'),revision:ref('revision'),baseRevision:ref('revision'),publicChanges:ref('publicChanges'),private:ref('privateView')},server);
message('projectionStart',{transferId:ref('id'),revision:ref('revision'),chunks:integer(1,ROOM_LIMITS.projectionChunks),bytes:integer(1,ROOM_LIMITS.projectionBytes),sha256:ref('hash')},server);
message('projectionChunk',{transferId:ref('id'),index:integer(0,ROOM_LIMITS.projectionChunks-1),data:text('^[A-Za-z0-9_-]+$',Math.ceil(ROOM_LIMITS.projectionChunkBytes*4/3))},server);
message('projectionEnd',{transferId:ref('id')},server);

export const roomMessageSchema={$schema:'https://json-schema.org/draft/2020-12/schema',title:'Trinktribunal room messages v1',oneOf:Object.keys(messagePolicies).map(ref),$defs:defs};
