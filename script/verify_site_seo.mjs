import { existsSync, readdirSync, readFileSync, statSync } from "node:fs";
import { join, resolve } from "node:path";

const root = resolve(import.meta.dirname, "..");
const siteDir = resolve(root, "site");
const distDir = resolve(root, "dist/site");
const canonicalHost = "https://invoicegen.megabyte.sh";
const stalePatterns = [/Local Invoice/g, /useinvoicegen\.com/g];
const definitionStart = "InvoiceGen is a local-first invoicing workspace for macOS";
const expectedSeoPages = [
  { source: "cli.html", publicPath: "/cli", title: "InvoiceGen CLI - Rust invoice CLI for local-first invoice workflows" },
  { source: "privacy.html", publicPath: "/privacy", title: "Privacy-first invoice generation for macOS" },
  { source: "docs/local-first-invoicing.html", publicPath: "/docs/local-first-invoicing", title: "Local-first invoicing guide for freelancers using macOS" },
  { source: "docs/backup-restore.html", publicPath: "/docs/backup-restore", title: "Back up and restore invoice data on macOS with InvoiceGen" },
  { source: "changelog.html", publicPath: "/changelog", title: "InvoiceGen changelog and release notes" },
  { source: "open-source-invoice-generator.html", publicPath: "/open-source-invoice-generator", title: "Open-source invoice generator for macOS" },
  { source: "alternatives/manta.html", publicPath: "/alternatives/manta", title: "Manta alternative for local-first macOS invoicing" },
  { source: "alternatives/invoice-ninja.html", publicPath: "/alternatives/invoice-ninja", title: "Invoice Ninja alternative for local-first macOS invoicing" },
  { source: "offline-invoice-generator-mac.html", publicPath: "/offline-invoice-generator-mac", title: "Offline invoice generator for Mac" },
  { source: "launch-kit.html", publicPath: "/launch-kit", title: "InvoiceGen launch kit for product directories" },
];

const failures = [];

function fail(message) {
  failures.push(message);
}

function read(path) {
  return readFileSync(path, "utf8");
}

function assertIncludes(text, needle, label) {
  if (!text.includes(needle)) {
    fail(`${label} must include ${JSON.stringify(needle)}`);
  }
}

function assertNotMatches(text, pattern, label) {
  if (pattern.test(text)) {
    fail(`${label} must not match ${pattern}`);
  }
}

function stripHtml(html) {
  return html
    .replace(/<script[\s\S]*?<\/script>/gi, " ")
    .replace(/<style[\s\S]*?<\/style>/gi, " ")
    .replace(/<[^>]+>/g, " ")
    .replace(/\s+/g, " ")
    .trim();
}

function countMatches(text, pattern) {
  return [...text.matchAll(pattern)].length;
}

function getDefinitionBlock(text) {
  const start = text.indexOf(definitionStart);
  if (start === -1) return "";

  const rest = text.slice(start);
  const markdownEnd = rest.search(/\n#{1,3} |\n- \[|\n## /);
  const htmlEnd = rest.search(/<\/p>|<\/section>/i);
  const endCandidates = [markdownEnd, htmlEnd].filter((index) => index > 0);
  const end = endCandidates.length > 0 ? Math.min(...endCandidates) : rest.length;
  return rest.slice(0, end).replace(/<[^>]+>/g, " ").replace(/\s+/g, " ").trim();
}

function assertDefinitionLength(text, label) {
  const block = getDefinitionBlock(text);
  if (!block) {
    fail(`${label} must include the InvoiceGen definition block`);
    return;
  }

  const words = block.split(/\s+/).filter(Boolean).length;
  if (words < 134 || words > 167) {
    fail(`${label} definition block must be 134-167 words, got ${words}`);
  }
}

function listFiles(dir) {
  const result = [];
  for (const entry of readdirSync(dir)) {
    const path = join(dir, entry);
    const stat = statSync(path);
    if (stat.isDirectory()) {
      result.push(...listFiles(path));
    } else if (/\.(html|txt|xml|tsx?|json|mjs)$/.test(entry)) {
      result.push(path);
    }
  }
  return result;
}

function verifyNoStaleSeoText() {
  for (const file of listFiles(siteDir)) {
    const text = read(file);
    for (const pattern of stalePatterns) {
      assertNotMatches(text, pattern, file.replace(`${root}/`, ""));
    }
  }
}

function verifyIndexHtml(path, label) {
  const html = read(path);
  assertIncludes(html, "<title>InvoiceGen - Local-first macOS invoicing</title>", label);
  assertIncludes(html, `rel="canonical" href="${canonicalHost}/"`, label);
  assertIncludes(html, 'property="og:site_name" content="InvoiceGen"', label);
  assertIncludes(html, '"@type": "WebPage"', label);
  assertIncludes(html, '"mainEntity"', label);
  assertIncludes(html, '<h1 id="hero-title">Local-first invoices, built for your Mac.</h1>', label);
  assertIncludes(html, '<h2 id="what-is-invoicegen">What is InvoiceGen?</h2>', label);
  assertIncludes(html, '<h2 id="resources-title">Indexable guides for local-first invoice generation.</h2>', label);
  assertIncludes(html, '<a href="/cli">Rust invoice CLI workflows</a>', label);
  assertIncludes(html, '<a href="/privacy">Privacy-first invoice generation</a>', label);
  assertIncludes(html, '<a href="/docs/local-first-invoicing">Local-first invoicing guide</a>', label);
  assertIncludes(html, '<a href="/docs/backup-restore">Backup and restore invoices</a>', label);
  assertIncludes(html, '<a href="/open-source-invoice-generator">Open-source invoice generator</a>', label);
  assertIncludes(html, '<a href="/alternatives/manta">Manta alternative for Mac invoicing</a>', label);
  assertIncludes(html, '<a href="/alternatives/invoice-ninja">Invoice Ninja alternative for Mac freelancers</a>', label);
  assertIncludes(html, '<a href="/offline-invoice-generator-mac">Offline invoice generator for Mac</a>', label);
  assertIncludes(html, '<a href="/launch-kit">InvoiceGen launch and directory assets</a>', label);
  assertIncludes(html, '<a class="button primary"', label);
  assertIncludes(html, '<picture class="hero-window-picture">', label);
  assertIncludes(html, '/assets/invoicegen-preview-640.webp 640w', label);
  assertIncludes(html, '/assets/invoicegen-preview-960.webp 960w', label);
  assertIncludes(html, '/assets/invoicegen-preview-1280.webp 1280w', label);
  assertIncludes(html, '/assets/invoicegen-preview-640.png 640w', label);
  assertIncludes(html, 'sizes="(max-width: 720px) calc(100vw - 36px), 1180px"', label);
  assertIncludes(html, 'alt="InvoiceGen macOS app window showing invoice lists, client revenue charts, and native sidebar tabs"', label);
  assertDefinitionLength(html, label);

  const h1Count = countMatches(html, /<h1\b/gi);
  if (h1Count !== 1) {
    fail(`${label} must contain exactly one raw h1, got ${h1Count}`);
  }

  const rawTextLength = stripHtml(html).length;
  if (rawTextLength < 900) {
    fail(`${label} raw text must be at least 900 characters, got ${rawTextLength}`);
  }
}

function verifyPublicFiles(baseDir, label, { expectSourcePlaceholders = true } = {}) {
  const robots = read(resolve(baseDir, "robots.txt"));
  const sitemap = read(resolve(baseDir, "sitemap.xml"));
  const llms = read(resolve(baseDir, "llms.txt"));

  assertIncludes(robots, `Sitemap: ${canonicalHost}/sitemap.xml`, `${label}/robots.txt`);
  assertIncludes(sitemap, `<loc>${canonicalHost}/</loc>`, `${label}/sitemap.xml`);
  assertIncludes(sitemap, `<loc>${canonicalHost}/SKILL.md</loc>`, `${label}/sitemap.xml`);
  for (const page of expectedSeoPages) {
    assertIncludes(sitemap, `<loc>${canonicalHost}${page.publicPath}</loc>`, `${label}/sitemap.xml`);
  }
  if (expectSourcePlaceholders) {
    assertIncludes(sitemap, "__INVOICEGEN_DATE_MODIFIED__", `${label}/sitemap.xml source placeholder`);
  } else if (sitemap.includes("__INVOICEGEN_DATE_MODIFIED__")) {
    fail(`${label}/sitemap.xml must have date placeholders replaced`);
  }
  assertIncludes(llms, "# InvoiceGen", `${label}/llms.txt`);
  assertIncludes(llms, `${canonicalHost}/SKILL.md`, `${label}/llms.txt`);
  for (const page of expectedSeoPages) {
    assertIncludes(llms, `${canonicalHost}${page.publicPath}`, `${label}/llms.txt`);
  }
  assertDefinitionLength(llms, `${label}/llms.txt`);

  for (const pattern of stalePatterns) {
    assertNotMatches(robots, pattern, `${label}/robots.txt`);
    assertNotMatches(sitemap, pattern, `${label}/sitemap.xml`);
    assertNotMatches(llms, pattern, `${label}/llms.txt`);
  }
}

function verifyDistPublicFiles() {
  if (!existsSync(distDir)) return;

  for (const file of listFiles(distDir)) {
    const text = read(file);
    if (text.includes("__INVOICEGEN_DATE_MODIFIED__") || text.includes("__INVOICEGEN_VERSION__")) {
      fail(`${file.replace(`${root}/`, "")} must have build placeholders replaced`);
    }
  }
}

function verifyStaticSeoPage(baseDir, page, label) {
  const pagePath = resolve(baseDir, page.source);
  if (!existsSync(pagePath)) {
    fail(`${label}/${page.source} must exist`);
    return;
  }

  const html = read(pagePath);
  assertIncludes(html, `<title>${page.title}</title>`, `${label}/${page.source}`);
  assertIncludes(html, `rel="canonical" href="${canonicalHost}${page.publicPath}"`, `${label}/${page.source}`);
  assertIncludes(html, 'property="og:site_name" content="InvoiceGen"', `${label}/${page.source}`);
  assertIncludes(html, '"@type": "WebPage"', `${label}/${page.source}`);
  assertIncludes(html, '<a class="brand" href="/" aria-label="InvoiceGen home">', `${label}/${page.source}`);
  assertIncludes(html, 'https://github.com/megabyte0x/invoicegen', `${label}/${page.source}`);
  assertIncludes(html, 'href="/open-source-invoice-generator"', `${label}/${page.source}`);
  assertIncludes(html, 'href="/alternatives/manta"', `${label}/${page.source}`);
  assertIncludes(html, 'href="/alternatives/invoice-ninja"', `${label}/${page.source}`);
  assertIncludes(html, 'href="/offline-invoice-generator-mac"', `${label}/${page.source}`);
  assertIncludes(html, 'href="/launch-kit"', `${label}/${page.source}`);

  const h1Count = countMatches(html, /<h1\b/gi);
  if (h1Count !== 1) {
    fail(`${label}/${page.source} must contain exactly one h1, got ${h1Count}`);
  }

  const rawTextLength = stripHtml(html).length;
  if (rawTextLength < 900) {
    fail(`${label}/${page.source} raw text must be at least 900 characters, got ${rawTextLength}`);
  }

  for (const pattern of stalePatterns) {
    assertNotMatches(html, pattern, `${label}/${page.source}`);
  }
}

function verifyVercelHeaders() {
  const vercel = JSON.parse(read(resolve(root, "vercel.json")));
  const wwwRedirect = vercel.redirects?.find(
    (entry) =>
      entry.source === "/:path*" &&
      entry.destination === `${canonicalHost}/:path*` &&
      entry.permanent === true &&
      entry.has?.some((condition) => condition.type === "host" && condition.value === "www.invoicegen.megabyte.sh"),
  );

  if (!wwwRedirect) {
    fail("vercel.json must permanently redirect www.invoicegen.megabyte.sh to the canonical apex host");
  }

  const globalHeaders = vercel.headers?.find((entry) => entry.source === "/(.*)")?.headers ?? [];
  const headerNames = new Set(globalHeaders.map((header) => header.key.toLowerCase()));
  for (const required of ["content-security-policy", "x-content-type-options", "referrer-policy", "permissions-policy"]) {
    if (!headerNames.has(required)) {
      fail(`vercel.json must define ${required}`);
    }
  }
}

function verifyImageVariants() {
  const assetsDir = resolve(siteDir, "public/assets");
  const expected = [
    "invoicegen-preview-640.png",
    "invoicegen-preview-960.png",
    "invoicegen-preview-1280.png",
    "invoicegen-preview-640.webp",
    "invoicegen-preview-960.webp",
    "invoicegen-preview-1280.webp",
    "invoicegen-preview.webp",
    "invoicegen-logo-128.png",
    "invoicegen-logo-128.webp",
  ];

  for (const file of expected) {
    const path = resolve(assetsDir, file);
    if (!existsSync(path)) {
      fail(`site/public/assets/${file} must exist`);
    }
  }

  const previewWebp = resolve(assetsDir, "invoicegen-preview-1280.webp");
  if (existsSync(previewWebp)) {
    const bytes = statSync(previewWebp).size;
    if (bytes > 300_000) {
      fail(`invoicegen-preview-1280.webp must stay below 300KB, got ${bytes} bytes`);
    }
  }
}

verifyNoStaleSeoText();
verifyIndexHtml(resolve(siteDir, "index.html"), "site/index.html");
verifyPublicFiles(resolve(siteDir, "public"), "site/public");
for (const page of expectedSeoPages) {
  verifyStaticSeoPage(resolve(siteDir, "public"), page, "site/public");
}
verifyVercelHeaders();
verifyImageVariants();

if (existsSync(resolve(distDir, "index.html"))) {
  verifyIndexHtml(resolve(distDir, "index.html"), "dist/site/index.html");
  verifyPublicFiles(distDir, "dist/site", { expectSourcePlaceholders: false });
  for (const page of expectedSeoPages) {
    verifyStaticSeoPage(distDir, page, "dist/site");
  }
  verifyDistPublicFiles();
}

if (failures.length > 0) {
  console.error("Site SEO verification failed:");
  for (const failure of failures) {
    console.error(`- ${failure}`);
  }
  process.exit(1);
}

console.log("Site SEO verification passed.");
