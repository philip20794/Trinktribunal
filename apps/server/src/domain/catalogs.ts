import { createHash } from 'node:crypto';
import deQuestions from '../../../../data/questions/top-ten/de.json';
import enQuestions from '../../../../data/questions/top-ten/en.json';
import deRules from '../../../../data/rules/de.json';
import enRules from '../../../../data/rules/en.json';
import manifest from '../../../../data/manifest.json';
import questionSchema from '../../../../packages/protocol/schemas/questions.schema.json';
import ruleSchema from '../../../../packages/protocol/schemas/rules.schema.json';
import manifestSchema from '../../../../packages/protocol/schemas/catalog-manifest.schema.json';
import { canonicalJson, validateSchema } from '../../../../packages/protocol/schema-validation.mjs';
import { currentProtocolCatalogHash } from '../protocol/room_message';
import { immutable } from './game_state';
import type { Roles } from './selection/person_assignment';

export interface ContentEntry {
  readonly id: string;
  readonly text: string;
  readonly players?: Roles;
  readonly excludes?: readonly string[];
  readonly scale?: { readonly green: string; readonly connector: string; readonly red: string };
}
export interface Catalogs {
  readonly questions: readonly ContentEntry[];
  readonly rules: readonly ContentEntry[];
}
const hash = (value: string) => createHash('sha256').update(value, 'utf8').digest('hex');

/** Executed once per isolate, never while selecting or broadcasting an action. */
function loadCatalogs(): Readonly<Record<'de' | 'en', Catalogs>> {
  validateSchema(manifest, manifestSchema);
  if (hash(canonicalJson(manifest)) !== currentProtocolCatalogHash)
    throw new Error('CATALOG_MANIFEST_MISMATCH');
  const sources = [deQuestions, enQuestions, deRules, enRules];
  for (let index = 0; index < sources.length; index++) {
    const source = sources[index]!,
      entry = manifest.catalogs[index]!;
    validateSchema(source, entry.kind === 'questions' ? questionSchema : ruleSchema);
    if (hash(canonicalJson(source) + '\n') !== entry.sha256)
      throw new Error('CATALOG_CONTENT_MISMATCH');
  }
  return immutable({
    de: { questions: deQuestions.questions, rules: deRules.rules },
    en: { questions: enQuestions.questions, rules: enRules.rules },
  }) as unknown as Readonly<Record<'de' | 'en', Catalogs>>;
}
export const catalogs = loadCatalogs();
export const catalogHash = currentProtocolCatalogHash;
