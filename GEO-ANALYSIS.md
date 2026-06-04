# InvoiceGen GEO Analysis

Date: 2026-06-04  
Target: https://invoicegen.megabyte.sh/  
Business type: local-first macOS invoicing software and Rust CLI  
GEO Readiness Score: 58/100

## Executive Summary

InvoiceGen has the right starting pieces for AI search visibility: a public domain, HTTPS, correct canonical metadata on production, `SoftwareApplication` JSON-LD in the initial HTML, an accessible `/llms.txt`, a public `/SKILL.md`, and explicit access for OpenAI, ClaudeBot, and Perplexity crawlers.

The limiting factor is extractability. The live homepage body is an empty React root until JavaScript executes. That is a serious GEO weakness because AI crawlers and citation systems often do not execute JavaScript. The best machine-readable content today is in `/llms.txt` and `/SKILL.md`, not the homepage itself.

The other major GEO gap is entity authority. The GitHub repository is public and has a release, but it currently has no description, topics, stars, forks, discussions, or visible third-party mentions. Broader search results also show that the `InvoiceGen` brand name is crowded by unrelated invoice tools and apps.

## Score Breakdown

| GEO Factor | Weight | Score | Notes |
| --- | ---: | ---: | --- |
| Citability | 25% | 15/25 | `/llms.txt` and `/SKILL.md` are clear, but the suggested citation is only 30 words and the homepage body has no raw crawlable passage. |
| Structural readability | 20% | 13/20 | `llms.txt` and `/SKILL.md` are structured; the raw homepage lacks H1/H2/body content for non-JS crawlers. |
| Multi-modal content | 15% | 8/15 | Product image exists, but there is no video, no transcript, no infographic, and image markup is client-rendered. |
| Authority and brand signals | 20% | 7/20 | Public GitHub and release exist; no repo description/topics/stars and weak third-party mentions. |
| Technical accessibility | 20% | 15/20 | AI crawler access, schema, and `llms.txt` are strong; client-only homepage rendering is the major deduction. |

## Platform Breakdown

| Platform | Score | Rationale |
| --- | ---: | --- |
| Google AI Overviews | 52/100 | Metadata/schema are good, but Google AI citations still depend heavily on indexed, rankable, extractable passages. Raw homepage content is missing. |
| ChatGPT Search | 64/100 | OpenAI crawlers are allowed and `/llms.txt` plus `/SKILL.md` are strong machine-readable assets. Entity authority is still thin. |
| Perplexity | 56/100 | PerplexityBot is allowed and the site has concise facts, but there are no community mentions or durable citations from third-party sources. |
| Bing Copilot | 50/100 | Public pages are crawlable, but no IndexNow, no content cluster, and weak external authority limit visibility. |

## AI Crawler Access Status

Production `robots.txt` at https://invoicegen.megabyte.sh/robots.txt:

| Crawler | Status | GEO interpretation |
| --- | --- | --- |
| GPTBot | Allowed | Good for OpenAI discovery and training access if desired. |
| OAI-SearchBot | Allowed | Good for OpenAI search features. |
| ChatGPT-User | Allowed | Good for user-triggered ChatGPT browsing. |
| ClaudeBot | Allowed | Good for Claude search and citation discovery. |
| PerplexityBot | Allowed | Good for Perplexity discovery. |
| CCBot | Blocked | Reasonable if blocking broad training datasets is intentional. |
| anthropic-ai | Blocked | Training crawler blocked; ClaudeBot remains allowed. |
| Bytespider | Blocked | Fine unless ByteDance AI visibility matters. |
| cohere-ai | Blocked | Fine unless Cohere visibility matters. |
| `*` | Allowed | Standard crawlers can access the site. |

Recommendation: keep the current allowlist if the strategy is "allow AI search crawlers, block some broad training crawlers." If the strategy is maximum AI visibility, revisit `CCBot`, `anthropic-ai`, `Bytespider`, and `cohere-ai`.

## llms.txt Status

Production `/llms.txt` is present at https://invoicegen.megabyte.sh/llms.txt.

Strengths:

- Uses the expected title, summary, section, link, key-facts, citation, and ownership structure.
- Links to homepage, `/SKILL.md`, GitHub repository, and latest release.
- States the key local-first, no-account, shared-store, CLI, license, and macOS-support facts.
- Gives AI systems a clean suggested citation.

Gaps:

- The suggested citation is 30 words, below the skill's 134-167 word target for highly citable answer blocks.
- It does not include a `What is InvoiceGen?` question heading.
- It does not include release/version facts beyond links.
- It does not include a machine-readable licensing or reuse policy beyond Apache 2.0 in plain text.

Recommended addition:

```markdown
## What is InvoiceGen?

InvoiceGen is a local-first invoicing workspace for macOS that combines a native Swift app with a Rust command-line interface. It is designed for freelancers, consultants, and small teams who want to manage clients, projects, invoice line items, due dates, payment details, taxes, notes, backups, and PDF-ready invoice exports without creating a cloud account or storing billing data on a hosted service. The macOS app and CLI use the same local store format, so users and AI agents can inspect, create, list, render, export, and restore invoice data through scripts while preserving compatibility with the desktop app. InvoiceGen is open source under the Apache 2.0 license, targets macOS 14 Sonoma or newer, and publishes its source, releases, and agent workflow at github.com/megabyte0x/invoicegen and invoicegen.megabyte.sh/SKILL.md. This combination differentiates it from browser-only invoice generators and cloud accounting tools by emphasizing privacy, local ownership, and scriptable workflows.
```

Word count: 143 words.

## Brand Mention Analysis

Current first-party signals:

- Public GitHub repository: https://github.com/megabyte0x/invoicegen
- Repository homepage: `https://invoicegen.megabyte.sh`
- Latest release: https://github.com/megabyte0x/invoicegen/releases/tag/v0.1.6
- Release asset exists for `InvoiceGen-0.1.6.dmg`.
- GitHub API reported `stargazers_count: 0`, `forks_count: 0`, `topics: []`, and `description: null` at audit time.

Search visibility observations:

- Exact searches for `invoicegen.megabyte.sh`, `"InvoiceGen" "megabyte0x"`, and related owner/domain combinations did not surface strong third-party mentions in the search tool.
- Broader `InvoiceGen` searches surfaced unrelated or competing entities, including `invoicegenerator.best`, `invoicegen.co.za`, unrelated GitHub projects, and an App Store app using the same name.
- Reddit search results show demand for offline-first invoicing, native macOS invoicing, and Rust/CLI tooling, but no visible third-party mentions for this specific InvoiceGen project.

Implication: the project needs entity disambiguation. AI systems may confuse `InvoiceGen` with browser invoice generators, mobile invoice apps, or unrelated open-source repositories unless first-party and third-party references consistently pair the brand with phrases like `megabyte0x InvoiceGen`, `local-first macOS invoicing`, `native macOS invoice app`, and `Rust invoice CLI`.

## Passage-Level Citability

Current strongest machine-readable passages:

| Source | Strength | Weakness |
| --- | --- | --- |
| `/llms.txt` summary | Clear and direct. | Too short for an optimal answer block. |
| `/llms.txt` key facts | Good fact bullets. | Not structured as question-answer passages. |
| `/SKILL.md` intro | Strong agent workflow context. | Written for agents, not general search users. |
| Homepage rendered hero | Clear product positioning. | Not present in raw HTML. |
| Homepage rendered overview | Good product explanation. | Not present in raw HTML. |

Highest-impact citability fix:

- Add one 134-167 word `What is InvoiceGen?` block to raw homepage HTML and `/llms.txt`.
- Follow it with short Q&A sections:
  - `Is InvoiceGen cloud-based?`
  - `Does InvoiceGen require an account?`
  - `What does the InvoiceGen CLI do?`
  - `What macOS version does InvoiceGen support?`
  - `Where is InvoiceGen's source code?`

## Server-Side Rendering Check

Live homepage:

- Status: `200`
- Raw HTML size: 4,194 bytes
- Raw HTML body text sample: effectively empty after removing scripts and tags.
- Raw HTML H1 count: 0
- Root markup: `<div id="root"></div>`
- Critical visible content is delivered by `/assets/index-CC6g0LgV.js`.

GEO interpretation:

This is the single biggest technical blocker. AI crawlers can read the title, meta description, canonical, Open Graph tags, Twitter card tags, and JSON-LD, but they cannot reliably read the visible homepage copy unless they execute JavaScript. For GEO, the homepage should be statically rendered or prerendered at build time.

## Schema Recommendations

Current production schema:

- `WebSite`
- `SoftwareApplication`

Recommended schema additions:

- Add a `WebPage` node for the homepage.
- Link `WebPage.mainEntity` to `SoftwareApplication`.
- Add `sameAs` links where truthful, including GitHub repository, GitHub owner, npm package if public, Homebrew tap if public, and any launch posts once published.
- Add a richer `creator` or `author` `Person` node for `megabyte0x`.
- Keep JSON-LD in the initial HTML, not only in JavaScript.

Avoid:

- FAQ schema for this commercial software page, because FAQ rich results are restricted and not a reliable fit.
- Review or aggregate rating schema until there is verified review data.

## RSL 1.0 and Licensing

No RSL 1.0 licensing file or policy was detected during this audit. The site and `/llms.txt` do state Apache 2.0 licensing for the project, and schema links the Apache license.

Recommendation:

- Keep Apache 2.0 as the human-readable source license.
- If AI reuse licensing becomes a product requirement, add an explicit machine-readable policy and link it from `/llms.txt`.

## Top 5 Highest-Impact Changes

1. Prerender the homepage so the H1, answer block, feature facts, FAQ, CTAs, and image markup exist in raw HTML.
2. Add the 143-word `What is InvoiceGen?` answer block to both the homepage and `/llms.txt`.
3. Update GitHub repository metadata: description, topics, social preview, and README intro using the same entity phrase.
4. Publish 3-5 high-signal supporting URLs: `/cli`, `/privacy`, `/docs/local-first-invoicing`, `/docs/backup-restore`, and `/changelog`.
5. Build third-party entity signals with a launch post, a short demo video, and targeted community posts in macOS, freelancer, open-source, and Rust/CLI communities.

## Content Reformatting Suggestions

Homepage:

- Add an immediately crawlable H1: `Local-first invoices, built for your Mac.`
- Add a crawlable H2: `What is InvoiceGen?`
- Add the 143-word answer block above.
- Add short Q&A blocks with direct answers in the first sentence.
- Add a comparison table: `InvoiceGen vs browser-only invoice generators vs cloud accounting tools`.
- Add a `Last updated: 2026-06-04` line near the content or in schema.

`/llms.txt`:

- Add the `What is InvoiceGen?` section.
- Add a `Best citation passages` section with one long answer block and 3-5 short facts.
- Add a `Disambiguation` line: `This InvoiceGen is the open-source macOS app and Rust CLI by megabyte0x at invoicegen.megabyte.sh.`

GitHub:

- Add repository description: `Local-first macOS invoicing app and Rust CLI for private, scriptable invoice workflows.`
- Add topics: `invoice`, `invoicing`, `macos`, `swiftui`, `rust-cli`, `local-first`, `pdf-export`, `freelancers`.
- Add release notes that repeat the same entity phrase.
- Pin or link the production site from README and release notes.

## Source Links

- Homepage: https://invoicegen.megabyte.sh/
- robots.txt: https://invoicegen.megabyte.sh/robots.txt
- llms.txt: https://invoicegen.megabyte.sh/llms.txt
- Repository skill: https://invoicegen.megabyte.sh/SKILL.md
- GitHub repository: https://github.com/megabyte0x/invoicegen
- Latest release: https://github.com/megabyte0x/invoicegen/releases/tag/v0.1.6
- Name-collision example: https://invoicegenerator.best/
