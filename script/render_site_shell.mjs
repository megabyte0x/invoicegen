import react from '@vitejs/plugin-react';
import { mkdir, writeFile } from 'node:fs/promises';
import { resolve } from 'node:path';
import { createServer } from 'vite';

const repository = resolve(import.meta.dirname, '..');
const outputDirectory = resolve(repository, '.site-shell');
const server = await createServer({
  root: resolve(repository, 'site'),
  configFile: false,
  appType: 'custom',
  plugins: [react()],
  define: {
    __INVOICEGEN_VERSION__: JSON.stringify('__INVOICEGEN_VERSION__'),
  },
  server: { middlewareMode: true },
});

try {
  const entry = await server.ssrLoadModule('/src/entry-server.tsx');
  await mkdir(outputDirectory, { recursive: true });
  await writeFile(resolve(outputDirectory, 'homepage.html'), entry.renderHomepage(), 'utf8');
} finally {
  await server.close();
}
