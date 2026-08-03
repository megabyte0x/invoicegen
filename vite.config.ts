import react from '@vitejs/plugin-react';
import { existsSync, readFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { defineConfig, type Plugin } from 'vite';

const root = dirname(fileURLToPath(import.meta.url));
const version = readReleaseVersion();
const dateModified = new Date().toISOString().slice(0, 10);

const cleanResourceRoutes = {
  '/alternatives/invoice-ninja': '/alternatives/invoice-ninja.html',
  '/alternatives/manta': '/alternatives/manta.html',
  '/changelog': '/changelog.html',
  '/cli': '/cli.html',
  '/docs/backup-restore': '/docs/backup-restore.html',
  '/docs/local-first-invoicing': '/docs/local-first-invoicing.html',
  '/launch-kit': '/launch-kit.html',
  '/offline-invoice-generator-mac': '/offline-invoice-generator-mac.html',
  '/open-source-invoice-generator': '/open-source-invoice-generator.html',
  '/privacy': '/privacy.html',
} as const;

export default defineConfig({
  root: 'site',
  publicDir: 'public',
  plugins: [cleanResourceRoutePlugin(), react(), invoicegenHtmlPlaceholders()],
  define: {
    __INVOICEGEN_VERSION__: JSON.stringify(version),
    __INVOICEGEN_DATE_MODIFIED__: JSON.stringify(dateModified),
  },
  build: {
    outDir: '../dist/site',
    emptyOutDir: true,
  },
  server: {
    host: '127.0.0.1',
    port: 5173,
  },
  preview: {
    host: '127.0.0.1',
    port: 4173,
  },
});

function cleanResourceRoutePlugin(): Plugin {
  const rewrite = (requestUrl: string | undefined): string | undefined => {
    if (!requestUrl) return requestUrl;
    const queryIndex = requestUrl.indexOf('?');
    const path = queryIndex === -1 ? requestUrl : requestUrl.slice(0, queryIndex);
    const query = queryIndex === -1 ? '' : requestUrl.slice(queryIndex);
    if (!Object.prototype.hasOwnProperty.call(cleanResourceRoutes, path)) return requestUrl;
    const route = cleanResourceRoutes[path as keyof typeof cleanResourceRoutes];
    return `${route}${query}`;
  };

  return {
    name: 'invoicegen-clean-resource-routes',
    configureServer(server) {
      server.middlewares.use((request, _response, next) => {
        request.url = rewrite(request.url);
        next();
      });
    },
    configurePreviewServer(server) {
      server.middlewares.use((request, _response, next) => {
        request.url = rewrite(request.url);
        next();
      });
    },
  };
}

function invoicegenHtmlPlaceholders(): Plugin {
  return {
    name: 'invoicegen-html-placeholders',
    transformIndexHtml(html) {
      return html
        .replaceAll('__INVOICEGEN_VERSION__', version)
        .replaceAll('__INVOICEGEN_DATE_MODIFIED__', dateModified);
    },
  };
}

function readReleaseVersion(): string {
  const cargoTomlPath = resolve(root, 'Cargo.toml');
  if (existsSync(cargoTomlPath)) {
    return readCargoVersion(cargoTomlPath);
  }

  const packageJson = JSON.parse(readFileSync(resolve(root, 'package.json'), 'utf8')) as { version?: string };
  if (typeof packageJson.version === 'string' && packageJson.version.length > 0) {
    return packageJson.version;
  }

  throw new Error('Neither Cargo.toml nor package.json contains a release version');
}

function readCargoVersion(cargoTomlPath: string): string {
  const cargoToml = readFileSync(cargoTomlPath, 'utf8');
  const versionMatch = cargoToml.match(/^version = "([^"]+)"/m);
  if (!versionMatch) {
    throw new Error('Cargo.toml does not contain a package version');
  }

  return versionMatch[1];
}
