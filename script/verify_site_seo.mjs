import { existsSync, readdirSync, readFileSync, statSync } from "node:fs";
import { join, resolve } from "node:path";

const root = resolve(import.meta.dirname, "..");
const siteDir = resolve(root, "site");
const distDir = resolve(root, "dist/site");
const canonicalHost = "https://invoicegen.megabyte.sh";
const stalePatterns = [/Local Invoice/g, /useinvoicegen\.com/g];
const definitionStart = "InvoiceGen is a local-first invoicing workspace for macOS";

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

function verifyPublicFiles(baseDir, label) {
  const robots = read(resolve(baseDir, "robots.txt"));
  const sitemap = read(resolve(baseDir, "sitemap.xml"));
  const llms = read(resolve(baseDir, "llms.txt"));

  assertIncludes(robots, `Sitemap: ${canonicalHost}/sitemap.xml`, `${label}/robots.txt`);
  assertIncludes(sitemap, `<loc>${canonicalHost}/</loc>`, `${label}/sitemap.xml`);
  assertIncludes(sitemap, `<loc>${canonicalHost}/SKILL.md</loc>`, `${label}/sitemap.xml`);
  assertIncludes(sitemap, "__INVOICEGEN_DATE_MODIFIED__", `${label}/sitemap.xml source placeholder`);
  assertIncludes(llms, "# InvoiceGen", `${label}/llms.txt`);
  assertIncludes(llms, `${canonicalHost}/SKILL.md`, `${label}/llms.txt`);
  assertDefinitionLength(llms, `${label}/llms.txt`);

  for (const pattern of stalePatterns) {
    assertNotMatches(robots, pattern, `${label}/robots.txt`);
    assertNotMatches(sitemap, pattern, `${label}/sitemap.xml`);
    assertNotMatches(llms, pattern, `${label}/llms.txt`);
  }
}

function verifyDistPublicFiles() {
  const sitemapPath = resolve(distDir, "sitemap.xml");
  if (!existsSync(sitemapPath)) return;

  const sitemap = read(sitemapPath);
  if (sitemap.includes("__INVOICEGEN_DATE_MODIFIED__")) {
    fail("dist/site/sitemap.xml must have date placeholders replaced");
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
verifyVercelHeaders();
verifyImageVariants();

if (existsSync(resolve(distDir, "index.html"))) {
  verifyIndexHtml(resolve(distDir, "index.html"), "dist/site/index.html");
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
