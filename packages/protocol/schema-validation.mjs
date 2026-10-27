export function assertJsonDepth(raw,maxDepth) {
  let depth=0,quoted=false,escaped=false;
  for(const character of raw) {
    if(quoted) {
      if(escaped) escaped=false;
      else if(character==='\\') escaped=true;
      else if(character==='"') quoted=false;
    } else if(character==='"') quoted=true;
    else if(character==='{'||character==='[') {if(++depth>maxDepth)throw new Error('JSON_DEPTH');}
    else if(character==='}'||character===']') depth--;
  }
}
export const canonicalJson = value => {
  if (Array.isArray(value)) return `[${value.map(canonicalJson).join(',')}]`;
  if (value !== null && typeof value === 'object') {
    return `{${Object.keys(value).sort().map(key => `${JSON.stringify(key)}:${canonicalJson(value[key])}`).join(',')}}`;
  }
  return JSON.stringify(value);
};
const fail = (path, message) => { throw new Error(`${path}: ${message}`); };

// Small interpreter for precisely the assertion keywords used by our schemas.
// No external package or network resolution; unknown keywords fail closed.
export function validateSchema(value, schema, path = '$', root = schema) {
  const supported = new Set(['$schema', '$id', '$defs', '$ref', 'title', 'description', 'type', 'const', 'enum', 'required', 'properties', 'additionalProperties', 'propertyNames', 'items', 'minItems', 'maxItems', 'uniqueItems', 'minLength', 'maxLength', 'pattern', 'minimum', 'maximum', 'maxProperties', 'oneOf']);
  for (const key of Object.keys(schema)) if (!supported.has(key)) fail(path, `unsupported schema keyword ${key}`);
  if(schema.oneOf) {
    let matches=0;
    for(const branch of schema.oneOf) {
      try {validateSchema(value,branch,path,root);matches++;}
      catch(error) {if(/unsupported schema|unknown reference|only local/.test(error.message)) throw error;}
    }
    if(matches!==1) fail(path,'expected exactly one schema alternative');
  }
  if (schema.$ref) {
    if (!schema.$ref.startsWith('#/$defs/')) fail(path, 'only local $defs references supported');
    const refName = schema.$ref.slice(8);
    const target = root.$defs && Object.hasOwn(root.$defs,refName) ? root.$defs[refName] : undefined;
    if (!target) fail(path, `unknown reference ${schema.$ref}`);
    validateSchema(value, target, path, root);
  }
  if (schema.type) {
    const valid = schema.type === 'object' ? value !== null && typeof value === 'object' && !Array.isArray(value)
      : schema.type === 'array' ? Array.isArray(value)
        : schema.type === 'integer' ? Number.isSafeInteger(value) : typeof value === schema.type;
    if (!valid) fail(path, `expected ${schema.type}`);
  }
  if ('const' in schema && value !== schema.const) fail(path, `expected ${schema.const}`);
  if (schema.enum && !schema.enum.includes(value)) fail(path, 'value outside enum');
  if (typeof value === 'string') {
    if (schema.minLength !== undefined && [...value].length < schema.minLength) fail(path, 'text too short');
    if (schema.maxLength !== undefined && [...value].length > schema.maxLength) fail(path, 'text too long');
    if (schema.pattern && !new RegExp(schema.pattern, 'u').test(value)) fail(path, 'pattern mismatch');
  }
  if (typeof value === 'number' && schema.minimum !== undefined && value < schema.minimum) fail(path, 'below minimum');
  if (typeof value === 'number' && schema.maximum !== undefined && value > schema.maximum) fail(path, 'above maximum');
  if (Array.isArray(value)) {
    if (schema.minItems && value.length < schema.minItems) fail(path, 'too few items');
    if (schema.maxItems !== undefined && value.length > schema.maxItems) fail(path, 'too many items');
    if (schema.uniqueItems && new Set(value.map(canonicalJson)).size !== value.length) fail(path, 'duplicate items');
    if (schema.items) value.forEach((item, index) => validateSchema(item, schema.items, `${path}[${index}]`, root));
  } else if (value !== null && typeof value === 'object') {
    if (schema.maxProperties !== undefined && Object.keys(value).length > schema.maxProperties) fail(path,'too many properties');
    for (const key of schema.required ?? []) if (!Object.hasOwn(value,key)) fail(path, `missing ${key}`);
    for (const [key, item] of Object.entries(value)) {
      if (schema.propertyNames) validateSchema(key, schema.propertyNames, `${path}.${key}`, root);
      const child = schema.properties && Object.hasOwn(schema.properties,key) ? schema.properties[key] : undefined;
      if (child) validateSchema(item, child, `${path}.${key}`, root);
      else if (schema.additionalProperties === false) fail(path, `unexpected ${key}`);
      else if (typeof schema.additionalProperties === 'object') validateSchema(item, schema.additionalProperties, `${path}.${key}`, root);
    }
  }
}
