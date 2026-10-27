import {readFileSync,writeFileSync} from 'node:fs';
import {roomMessageSchema,messagePolicies,ROOM_LIMITS} from '../packages/protocol/room-contract.mjs';
const files=new Map([
  [new URL('../packages/protocol/schemas/room-message.schema.json',import.meta.url),roomMessageSchema],
  [new URL('../packages/protocol/message-policies.json',import.meta.url),{protocolVersion:1,limits:ROOM_LIMITS,messages:messagePolicies}],
]);
for(const [url,value] of files) {
  const expected=JSON.stringify(value,null,2)+'\n';
  if(process.argv.includes('--check')) {if(readFileSync(url,'utf8').replaceAll('\r\n','\n')!==expected)throw new Error('Stale protocol artifact: '+url.pathname);}
  else writeFileSync(url,expected);
}
process.stdout.write(`Room protocol: ${Object.keys(messagePolicies).length} message schemas/policies OK\n`);
