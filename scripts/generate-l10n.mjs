import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
const root = fileURLToPath(new URL('../apps/client/lib/l10n/', import.meta.url));
const de = JSON.parse(fs.readFileSync(path.join(root, 'app_de.arb'),'utf8'));
const en = JSON.parse(fs.readFileSync(path.join(root, 'app_en.arb'),'utf8'));
const keys = obj => Object.keys(obj).filter(k=>!k.startsWith('@')).sort();
if (JSON.stringify(keys(de)) !== JSON.stringify(keys(en))) throw new Error('ARB key parity failed');
if (de['@@locale'] !== 'de' || en['@@locale'] !== 'en') throw new Error('Wrong ARB locales');
const placeholders = text => [...text.matchAll(/\{([A-Za-z][A-Za-z0-9]*)\}/g)].map(x=>x[1]).sort().join(',');
for (const k of keys(de)) {
  if (typeof de[k]!=='string' || typeof en[k]!=='string' ||
      placeholders(de[k])!==placeholders(en[k])) throw new Error('ARB mismatch: '+k);
}
const quote = value => JSON.stringify(value).replaceAll('$','\\$');
const output = '// Generated from app_de.arb and app_en.arb; do not edit manually.\n// dart format off\n' +
  'const localizedUiStrings = <String, Map<String, String>>{\n' +
  ['de','en'].map(lang => '  '+quote(lang)+': {\n' +
    keys(de).map(k=>'    '+quote(k)+': '+quote((lang==='de'?de:en)[k])+',').join('\n')+'\n  },').join('\n')+'\n};\n' +
  'const localizedFeedbackKeys = <String, String>{\n' + keys(de).filter(k=>de['@'+k]?.source).map(k=>'  '+quote(de['@'+k].source)+': '+quote(k)+',').join('\n')+'\n};\n';
const target=path.join(root,'app_strings_data.dart');
if (process.argv.includes('--check')) {
  if(fs.readFileSync(target,'utf8').replaceAll('\r\n','\n')!==output) throw new Error('Generated l10n out of date');
} else fs.writeFileSync(target,output);
console.log(keys(de).length+' localized UI strings OK');
