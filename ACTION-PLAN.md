# SEO Action Plan: invoicegen.megabyte.sh

## Critical

### 1. Stop the local worktree from deploying stale domain and brand metadata

Impact: prevents canonical, sitemap, Open Graph, and AI citation regression.

Files currently showing risky local changes:

- `site/index.html`
- `site/public/robots.txt`
- `site/public/sitemap.xml`
- `site/public/llms.txt`
- `site/src/data/siteContent.ts`
- related React components

Expected fix:

- Keep production-facing metadata on `InvoiceGen` and `https://invoicegen.megabyte.sh/`, unless the product is intentionally moving to another canonical domain.
- Add a build or test check that fails if generated site files contain the wrong canonical host.

Verification:

- `rg "useinvoicegen|Local Invoice" site SKILL.md`
- `pnpm build:site`
- Fetch production after deploy and confirm canonical, robots sitemap URL, Open Graph URLs, sitemap locs, and `llms.txt` all use `invoicegen.megabyte.sh`.

## High

### 2. Prerender the homepage or move critical copy into static HTML

Impact: improves crawlability, snippet extraction, AI citation readiness, and resilience.

Expected fix:

- Generate static HTML for the homepage during the Vite build, or switch the site to a static/SSR framework.
- Ensure the initial HTML contains:
  - one H1
  - the hero summary
  - primary CTA links
  - main feature headings
  - FAQ questions and answers
  - product image markup with alt text

Verification:

- `curl -sL https://invoicegen.megabyte.sh/` should show meaningful body text.
- Raw HTML should include exactly one H1.
- Raw HTML body text should be at least several hundred words for the homepage.

### 3. Optimize product images

Impact: improves LCP risk, page weight, social preview handling, and mobile experience.

Expected fix:

- Convert `invoicegen-preview.png` to AVIF and WebP.
- Create responsive widths, for example 640, 960, 1280, and 1536.
- Convert or resize the 512 x 512 logo for repeated UI icon use.
- Use `<picture>` plus `srcset` and `sizes`.
- Keep explicit width and height.

Verification:

- Main preview target: ideally under 300 KB for the largest rendered variant.
- Mobile variant: ideally under 150 KB.
- No layout shift in screenshots.

### 4. Add a small static content architecture

Impact: expands indexable keyword coverage without creating thin programmatic pages.

Recommended pages:

- `/download`
- `/cli`
- `/privacy`
- `/docs/backup-restore`
- `/docs/local-first-invoicing`
- `/changelog`

Quality bar:

- Each page should answer a distinct search intent.
- Avoid duplicate homepage copy.
- Add each page to the sitemap only after it has useful, unique content.

## Medium

### 5. Fix sitemap freshness and simplify sitemap fields

Impact: improves crawl freshness signals and reduces misleading metadata.

Expected fix:

- Update `lastmod` from the release/build date.
- Remove `priority` and `changefreq`; Google ignores them.
- Keep only canonical 200 URLs.

Verification:

- `curl -sL https://invoicegen.megabyte.sh/sitemap.xml`
- Confirm `lastmod` matches the current deployed content date.

### 6. Add baseline security headers

Impact: improves technical quality and trust posture.

Recommended headers:

- `Content-Security-Policy`
- `X-Content-Type-Options: nosniff`
- `Referrer-Policy: strict-origin-when-cross-origin`
- `Permissions-Policy`
- `X-Frame-Options: DENY` or CSP `frame-ancestors 'none'`

Verification:

- `curl -sI https://invoicegen.megabyte.sh/`
- Confirm headers are present without breaking Fontshare or GitHub API calls.

### 7. Decide and configure the `www` host

Impact: prevents failed visits from links that include `www`.

Expected fix:

- If `www.invoicegen.megabyte.sh` should work, add it to Vercel with a valid cert and redirect to non-www.
- If it should not exist, remove its DNS records.

Verification:

- `curl -sIL https://www.invoicegen.megabyte.sh/`
- It should validate TLS and end at `https://invoicegen.megabyte.sh/`.

### 8. Enrich structured data

Impact: improves entity clarity for search engines and AI systems.

Expected fix:

- Add `WebPage` linked to `WebSite`.
- Add truthful `sameAs` URLs for the project/creator.
- Connect the page `mainEntity` to the `SoftwareApplication`.
- Keep JSON-LD in initial HTML.

Verification:

- Parse JSON-LD from raw HTML.
- Confirm all URLs are absolute and use `invoicegen.megabyte.sh`.

### 9. Document AI crawler policy

Impact: aligns robots rules with the desired AI visibility strategy.

Expected fix:

- If the goal is maximum AI visibility, consider allowing more AI crawlers.
- If the goal is selective access, add a short repo note explaining why `CCBot`, `anthropic-ai`, `Bytespider`, and `cohere-ai` are blocked.
- Keep `llms.txt` updated with every product positioning change.

Verification:

- `curl -sL https://invoicegen.megabyte.sh/robots.txt`
- `curl -sL https://invoicegen.megabyte.sh/llms.txt`

## Low

### 10. Improve above-fold product visibility

Impact: improves conversion and visual context more than pure SEO.

Expected fix:

- Bring part of the product preview higher in the desktop first viewport.
- Recheck mobile subtitle wrapping at 390 px width.

Verification:

- Capture desktop and mobile screenshots after the change.
- Confirm CTAs and text do not clip or overlap.

### 11. Add trust pages and clearer ownership context

Impact: improves E-E-A-T and user confidence.

Recommended additions:

- privacy page
- changelog or release notes page
- creator/project profile details
- license page or clearer license section
- GitHub/release badges if they do not add visual clutter

Verification:

- Pages are linked from the homepage/footer.
- Pages are included in the sitemap.
- Content is specific to InvoiceGen, not generic boilerplate.
