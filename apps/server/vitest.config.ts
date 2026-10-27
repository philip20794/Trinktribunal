import { cloudflareTest } from '@cloudflare/vitest-plugin';
import { defineConfig } from 'vitest/config';
import { readFileSync } from 'node:fs';

export default defineConfig({
  define: {
    __TT_PARITY_FIXTURE__: JSON.stringify(
      readFileSync(
        process.env.TT_PARITY_FIXTURE ?? '../../packages/protocol/fixtures/rules/parity/v1.json',
        'utf8',
      ),
    ),
  },
  plugins: [cloudflareTest({ wrangler: { configPath: './wrangler.jsonc' } })],
  test: { include: ['test/**/*.test.ts'] },
});
