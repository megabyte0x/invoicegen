# Full SEO Audit Report: invoicegen.megabyte.sh

Audit date: 2026-06-04  
Audited target: https://invoicegen.megabyte.sh/  
Business type detected: local-first macOS invoicing software and CLI  
Overall SEO Health Score: 71/100

## Executive Summary

InvoiceGen has a solid SEO foundation for a small software landing page: HTTPS is enforced, the canonical URL is correct on production, title and meta tags are clean, Open Graph and Twitter cards are present, JSON-LD is included in the initial HTML, and both `robots.txt` and `llms.txt` exist.

The main limitation is that the production HTML body contains no meaningful crawlable content before JavaScript runs. The raw HTML has the SEO head, JSON-LD, one script, one stylesheet, and an empty React root. Google can usually render this, but many non-JS crawlers, link extractors, and AI citation systems will miss the visible product copy, H1, FAQ, and internal anchors.

The other major finding is deployment risk in the local worktree. Production currently uses `InvoiceGen` and `invoicegen.megabyte.sh`, but the local dirty files include SEO-critical brand changes. If deployed without review, that could regress canonicals, sitemap URLs, `llms.txt`, Open Graph URLs, and brand consistency.

## Evidence Collected

Sources checked:

- Live homepage: https://invoicegen.megabyte.sh/
- Live robots: https://invoicegen.megabyte.sh/robots.txt
- Live sitemap: https://invoicegen.megabyte.sh/sitemap.xml
- Live llms: https://invoicegen.megabyte.sh/llms.txt
- Live repository skill: https://invoicegen.megabyte.sh/SKILL.md
- Desktop screenshot: `screenshots/desktop.png`
- Mobile screenshot: `screenshots/mobile.png`

Live response highlights:

| Check | Result |
| --- | --- |
| Homepage status | 200 |
| HTTP to HTTPS | 308 to HTTPS |
| Canonical | `https://invoicegen.megabyte.sh/` |
| Title | `InvoiceGen - Local-first macOS invoicing` |
| Title length | 40 characters |
| Meta description length | 128 characters |
| Raw HTML body text | 0 characters |
| Raw HTML H1 count | 0 |
| JSON-LD types | `WebSite`, `SoftwareApplication` |
| Sitemap URLs | 2 |
| JS bundle | 208,075 bytes |
| CSS bundle | 14,391 bytes |
| Preview image | 1,033,123 bytes PNG |
| Logo image | 197,681 bytes PNG |

## Score Breakdown

| Category | Weight | Score | Notes |
| --- | ---: | ---: | --- |
| Technical SEO | 25% | 72 | Good HTTPS, canonical, robots, sitemap; weak raw HTML and missing security headers. |
| Content Quality | 25% | 68 | Rendered product copy is clear, but indexable raw content is absent and E-E-A-T signals are thin. |
| On-Page SEO | 20% | 70 | Title/meta/OG are good; raw H1 and body content are missing due CSR. |
| Schema / Structured Data | 10% | 80 | Valid useful JSON-LD exists; can be enriched with entity links and WebPage context. |
| Performance | 10% | 72 | Static Vercel hosting and cached assets are good; 1 MB preview PNG and third-party font request add weight. |
| Images | 5% | 62 | Descriptive alt and dimensions are present in rendered React, but PNG assets are oversized. |
| AI Search Readiness | 5% | 70 | `llms.txt` and AI crawler rules are good; raw HTML extraction and selective AI blocks limit coverage. |

## Top Issues

### Critical: Local source can regress production SEO on next deploy

Production currently serves correct `InvoiceGen` metadata and `invoicegen.megabyte.sh` URLs. The dirty local worktree currently contains SEO-critical brand replacements in:

- `site/index.html`
- `site/public/robots.txt`
- `site/public/sitemap.xml`
- `site/public/llms.txt`
- `site/src/data/siteContent.ts`
- related React components

This is not a current live-site defect, but it is the highest-risk operational issue because the next deploy from this worktree could publish the wrong canonical, sitemap, Open Graph URL, and AI citation source.

### High: Critical page content is absent from raw HTML

The live HTML body contains only:

```html
<div id="root"></div>
```

The rendered page has a good H1, product explanation, FAQ, feature sections, and internal anchors, but none of that appears in the initial HTML. This weakens:

- non-JavaScript crawler discovery
- AI extraction and citation
- fast snippet generation
- accessibility tools that inspect source instead of rendered DOM
- resilience if JavaScript fails

Recommended fix: prerender the homepage at build time or move critical landing copy, headings, primary links, and image markup into static HTML.

### High: Preview image is oversized

The main product preview is a 1536 x 1024 PNG and is 1,033,123 bytes. It is used as the social preview image and the product preview image in the page. This is above the normal target for a hero or preview asset.

Recommended fix: generate AVIF and WebP variants, keep PNG only as fallback if needed, and serve responsive image sizes.

### High: Site architecture is very shallow

The sitemap lists only:

- `/`
- `/SKILL.md`

That is fine for a tiny product, but it gives search engines little surface area for specific intents such as local-first invoicing, macOS invoice app, invoice CLI, privacy, backup and restore, and open-source invoicing.

Recommended fix: add a small set of static, high-quality pages rather than many thin pages:

- `/download`
- `/cli`
- `/privacy`
- `/docs/backup-restore`
- `/docs/local-first-invoicing`
- `/changelog`

### Medium: Sitemap metadata is stale and includes ignored fields

Production sitemap `lastmod` values are `2026-06-02`, while the live homepage JSON-LD reports `dateModified` as `2026-06-04` and response headers show a June 4 deployment. `priority` and `changefreq` are present but ignored by Google.

Recommended fix: update `lastmod` from the release/build date and simplify the sitemap to canonical URLs plus accurate `lastmod`.

### Medium: Missing security headers

The live responses include HSTS, but do not include common hardening headers:

- `Content-Security-Policy`
- `X-Content-Type-Options`
- `Referrer-Policy`
- `Permissions-Policy`
- `X-Frame-Options` or CSP `frame-ancestors`

This is not a direct ranking boost, but security and trustworthiness are part of technical quality and user trust.

### Medium: `www` host is not cleanly configured

`https://www.invoicegen.megabyte.sh/` failed normal TLS verification in `curl`. With certificate verification bypassed, Vercel redirects it to the canonical non-www URL. If users or crawlers hit the `www` host with strict TLS validation, they may fail before seeing the redirect.

Recommended fix: either configure the `www` alias with a valid certificate and redirect, or remove its DNS records if it is not intended to be used.

### Medium: AI crawler strategy is selective

Production allows `GPTBot`, `OAI-SearchBot`, `ChatGPT-User`, `ClaudeBot`, and `PerplexityBot`, while blocking `CCBot`, `anthropic-ai`, `Bytespider`, and `cohere-ai`.

This may be intentional. If the goal is maximum AI citation and model visibility, consider allowing more AI crawlers. If the goal is selective control, document that strategy and keep `llms.txt` maintained.

### Low: Above-fold product image visibility is limited

The desktop screenshot shows clear messaging and CTAs, but the product preview is mostly below the first viewport. The mobile screenshot shows the primary CTA fitting well, but the subtitle is tight at the right edge in the captured viewport.

Recommended fix: reduce hero vertical spacing or bring a small product preview signal higher in the first viewport, and run a mobile visual regression after changes.

## Technical SEO

Strengths:

- Homepage returns `200`.
- HTTP redirects to HTTPS.
- HSTS is enabled.
- Canonical tag is self-referencing and correct on production.
- `robots.txt` exists and points to the sitemap.
- `sitemap.xml` is valid XML and contains canonical HTTPS URLs.
- Unknown path returns `404`.
- Static hashed assets have long immutable cache headers.

Issues:

- Raw HTML body has no indexable page text.
- Raw HTML has no H1, H2, product body copy, internal anchors, or image markup.
- `www` host has TLS validation problems.
- Security headers are incomplete.
- Sitemap `lastmod` is stale.

Technical score: 72/100

## Content Quality

Rendered content strengths:

- The value proposition is clear: local-first invoices for macOS.
- The page explains privacy, exports, clients, projects, CLI automation, backup, and pricing.
- FAQ answers are practical and concise.
- The `llms.txt` file has a strong summary and suggested citation.

Content gaps:

- No crawlable raw body text.
- Limited proof and trust signals: no screenshots above the fold, no changelog, no release history page, no privacy page, no testimonials, and no deeper docs.
- Creator identity exists, but author/entity context is minimal outside GitHub links.

Content quality score: 68/100

## On-Page SEO

Strengths:

- Title is concise and brand-specific.
- Meta description is readable and relevant.
- Canonical, OG, and Twitter metadata are present.
- Production social image URL is absolute.
- Rendered page appears to have a single clear H1 and logical section headings.

Issues:

- Raw HTML has no H1.
- Raw HTML has no crawlable internal links except asset references.
- The single-page anchor structure is not represented in the sitemap.

On-page score: 70/100

## Schema & Structured Data

Current implementation:

- `WebSite`
- `SoftwareApplication`

Strengths:

- JSON-LD is in the initial HTML, not injected later by JavaScript.
- Software name, category, operating system, version, download URL, repository, license, image, creator, offer, and date modified are present.

Recommended enhancements:

- Add `WebPage` connected to the `WebSite`.
- Add `sameAs` links for the creator or project where truthful.
- Add `publisher` or clearer `creator` entity details.
- Add `mainEntity` linking the page to the `SoftwareApplication`.
- Keep FAQ content in rendered/static HTML; do not rely on FAQ rich-result eligibility.

Schema score: 80/100

## Performance

Observed asset sizes:

- HTML: 4,194 bytes
- JS: 208,075 bytes
- CSS: 14,391 bytes
- Preview PNG: 1,033,123 bytes
- Logo PNG: 197,681 bytes
- `llms.txt`: 1,646 bytes

Strengths:

- Vercel cache is serving the main static files.
- Hashed assets use immutable caching.
- CSS and JS sizes are reasonable for a small React app.
- Image width and height are set in rendered React markup, reducing CLS risk.

Issues:

- Preview image is large and PNG-only.
- Logo image is large for repeated icon use.
- External Fontshare CSS adds another third-party request.
- No Lighthouse or CrUX field data was available in this local environment, so Core Web Vitals were not measured.

Performance score: 72/100

## Images

Strengths:

- Product preview alt text is descriptive.
- Decorative logo images use empty alt text where appropriate.
- Rendered image dimensions are present.

Issues:

- Preview PNG is above the recommended target for hero/product preview images.
- No AVIF/WebP variants.
- No responsive `srcset`/`sizes` for the product preview.
- Below-fold images and heavy visual panels are all client-rendered.

Image score: 62/100

## AI Search Readiness

Strengths:

- `llms.txt` exists and is well structured.
- Suggested citation is clear and concise.
- OpenAI, ClaudeBot, and Perplexity crawler access is explicitly allowed.
- `/SKILL.md` is public and included in the sitemap.

Issues:

- Raw HTML body has no quotable content.
- Some AI crawler tokens are blocked.
- The sitemap only exposes two URLs.
- No static docs pages exist for specific answer intents.

AI readiness score: 70/100

## Crawl Summary

Crawled URLs from sitemap:

| URL | Status | Notes |
| --- | --- | --- |
| `https://invoicegen.megabyte.sh/` | 200 | Canonical homepage; React-rendered body. |
| `https://invoicegen.megabyte.sh/SKILL.md` | 200 | Public agent-facing Markdown skill. |

Additional checks:

| URL | Status | Notes |
| --- | --- | --- |
| `http://invoicegen.megabyte.sh/` | 308 then 200 | Redirects to HTTPS. |
| `https://invoicegen.megabyte.sh/robots.txt` | 200 | Allows standard crawlers and selected AI crawlers. |
| `https://invoicegen.megabyte.sh/sitemap.xml` | 200 | Valid but shallow and stale `lastmod`. |
| `https://invoicegen.megabyte.sh/llms.txt` | 200 | Good AI-readable summary. |
| `https://invoicegen.megabyte.sh/__missing_seo_probe_404` | 404 | Correct missing-page status. |
| `https://www.invoicegen.megabyte.sh/` | TLS issue | Redirect exists only after bypassing certificate verification. |

## Quick Wins

1. Fix the dirty local SEO source drift before the next deploy.
2. Add static/prerendered homepage body content.
3. Convert the preview and logo assets to AVIF/WebP and responsive sizes.
4. Update sitemap `lastmod` and remove ignored `priority`/`changefreq`.
5. Add baseline security headers through Vercel config.
