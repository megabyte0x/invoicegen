# InvoiceGen SEO Analysis

Date: 2026-06-04  
Target: https://invoicegen.megabyte.sh/  
Business type: local-first macOS invoicing software and Rust CLI  
Current SEO Health Score: 71/100  
Current GEO Readiness Score: 58/100

## Current State

InvoiceGen has a good foundation for a small software site: HTTPS works, production canonical metadata points to `https://invoicegen.megabyte.sh/`, Open Graph and Twitter metadata are present, JSON-LD is present in the initial HTML, `robots.txt` references the sitemap, `llms.txt` exists, and `/SKILL.md` is public.

The primary blocker across both SEO and GEO is raw-page extractability. The live homepage is a client-rendered React app. The raw HTML exposes the title, metadata, schema, JS, CSS, and `<div id="root"></div>`, but it does not expose the visible H1, body copy, feature sections, FAQ content, internal anchors, or image markup before JavaScript runs.

The primary deployment risk is local-source drift. The live site is `InvoiceGen` on `invoicegen.megabyte.sh`, while the current dirty worktree includes SEO-critical local edits around alternate brand/domain copy. Treat the live target as authoritative unless the product is intentionally being migrated.

## Artifact Map

| Artifact | Purpose |
| --- | --- |
| `FULL-AUDIT-REPORT.md` | Full weighted SEO audit with technical, content, schema, performance, image, sitemap, and AI-readiness findings. |
| `ACTION-PLAN.md` | Prioritized implementation plan from Critical through Low. |
| `GEO-ANALYSIS.md` | AI search, `llms.txt`, crawler, citability, brand signal, and entity-disambiguation analysis. |
| `screenshots/desktop.png` | Desktop visual evidence for above-fold layout. |
| `screenshots/mobile.png` | Mobile visual evidence for above-fold layout. |

## Verified Production Evidence

Collected on 2026-06-04 at approximately 16:20 UTC:

| Check | Current result |
| --- | --- |
| Homepage | `200`, `text/html`, `content-length: 4194` |
| Homepage title | `InvoiceGen - Local-first macOS invoicing` |
| Meta description length | 128 characters |
| Raw body text after stripping scripts/styles/tags | 40 characters, effectively just the title text |
| Raw H1 count | 0 |
| JSON-LD types | `WebSite`, `SoftwareApplication` |
| `robots.txt` | `200`, allows GPTBot, OAI-SearchBot, ChatGPT-User, ClaudeBot, PerplexityBot |
| `sitemap.xml` | `200`, contains `/` and `/SKILL.md`, lastmod `2026-06-02` |
| `llms.txt` | `200`, 1,646 bytes |
| `/SKILL.md` | `200`, 7,845 bytes |
| GitHub repo metadata | Homepage set; Apache-2.0; `description: null`, `topics: []`, `stargazers_count: 0`, `forks_count: 0` |

## Sub-Skill Coverage Matrix

| SEO area | Coverage status | Main artifact |
| --- | --- | --- |
| Business detection | Complete | `FULL-AUDIT-REPORT.md` |
| Technical SEO | Complete, with current live evidence | `FULL-AUDIT-REPORT.md` |
| On-page SEO | Complete | `FULL-AUDIT-REPORT.md` |
| Content quality / E-E-A-T | Complete at audit level; implementation remains open | `FULL-AUDIT-REPORT.md` |
| Schema | Complete at audit level; enhancement recommendations remain open | `FULL-AUDIT-REPORT.md`, `GEO-ANALYSIS.md` |
| Sitemap | Complete | `FULL-AUDIT-REPORT.md`, `ACTION-PLAN.md` |
| Images | Complete at audit level | `FULL-AUDIT-REPORT.md` |
| Performance / CWV | Partial | Asset/header-based review done; Lighthouse/CrUX field data was not available in this environment. |
| Visual/mobile | Complete for screenshot evidence | `screenshots/desktop.png`, `screenshots/mobile.png` |
| GEO / AI search | Complete | `GEO-ANALYSIS.md` |
| Strategic plan | Complete at tactical level | `ACTION-PLAN.md` |

## Highest-Impact Priorities

### 1. Prerender or statically render the homepage

This is the most important shared fix for SEO and GEO. The initial HTML should contain:

- one H1
- a `What is InvoiceGen?` answer block
- core feature copy
- FAQ content
- primary links and CTAs
- product image markup with alt text
- static internal links to future support pages

Expected impact: better non-JS crawlability, better AI extractability, stronger snippets, more reliable accessibility tooling, and less dependence on client rendering.

### 2. Resolve local source drift before the next deploy

Do not deploy the current dirty worktree until the intended brand/domain state is explicit.

If the canonical target remains `invoicegen.megabyte.sh`, source files should not publish alternate canonical URLs, sitemap URLs, Open Graph URLs, or `llms.txt` links. If the product is intentionally moving to another domain, redo the live audit against that target before shipping.

### 3. Add a small indexable content architecture

Recommended first pages:

- `/cli`
- `/privacy`
- `/download`
- `/docs/local-first-invoicing`
- `/docs/backup-restore`
- `/changelog`

Keep these as specific, first-party pages. Avoid thin programmatic pages.

### 4. Optimize product imagery

The main preview PNG is about 1.03 MB and the logo PNG is about 198 KB. Add AVIF/WebP variants, responsive sizes, and a smaller repeated-logo asset.

### 5. Improve entity authority

Update GitHub metadata and seed consistent third-party references:

- repository description
- repository topics
- README intro aligned with the homepage
- release notes with the same entity phrase
- launch/demo post
- short video or GIF
- community posts in relevant macOS, freelancer, Rust, and open-source channels

## Recommended Definition Block

Use this in raw homepage HTML and `/llms.txt`:

```markdown
## What is InvoiceGen?

InvoiceGen is a local-first invoicing workspace for macOS that combines a native Swift app with a Rust command-line interface. It is designed for freelancers, consultants, and small teams who want to manage clients, projects, invoice line items, due dates, payment details, taxes, notes, backups, and PDF-ready invoice exports without creating a cloud account or storing billing data on a hosted service. The macOS app and CLI use the same local store format, so users and AI agents can inspect, create, list, render, export, and restore invoice data through scripts while preserving compatibility with the desktop app. InvoiceGen is open source under the Apache 2.0 license, targets macOS 14 Sonoma or newer, and publishes its source, releases, and agent workflow at github.com/megabyte0x/invoicegen and invoicegen.megabyte.sh/SKILL.md. This combination differentiates it from browser-only invoice generators and cloud accounting tools by emphasizing privacy, local ownership, and scriptable workflows.
```

Word count: 143 words.

## Completion Criteria For Implementation

The analysis points to implementation work, but the implementation itself is not complete until these checks pass:

- `curl -sL https://invoicegen.megabyte.sh/` shows meaningful body copy, including one H1.
- Raw homepage HTML includes the `What is InvoiceGen?` block.
- `curl -sL https://invoicegen.megabyte.sh/llms.txt` includes the same definition block or a close derivative.
- `curl -sL https://invoicegen.megabyte.sh/sitemap.xml` lists all new canonical pages with current `lastmod` values.
- GitHub repo metadata includes a description and topics.
- Screenshot verification shows no mobile text clipping or above-fold regression.

## Source Links

- Homepage: https://invoicegen.megabyte.sh/
- robots.txt: https://invoicegen.megabyte.sh/robots.txt
- sitemap.xml: https://invoicegen.megabyte.sh/sitemap.xml
- llms.txt: https://invoicegen.megabyte.sh/llms.txt
- Repository skill: https://invoicegen.megabyte.sh/SKILL.md
- GitHub repository: https://github.com/megabyte0x/invoicegen

