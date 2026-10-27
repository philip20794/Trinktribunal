export function canonicalJson(value: unknown): string;
export function assertJsonDepth(raw: string, maxDepth: number): void;
export function validateSchema(
  value: unknown,
  schema: Readonly<Record<string, unknown>>,
  path?: string,
  root?: Readonly<Record<string, unknown>>,
): void;
