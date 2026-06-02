# InvoiceGen GEO Analysis

Date: 2026-06-02
Target: https://invoicegen.megabyte.sh/

## GEO Readiness Score: 78/100

This score reflects the post-change production deployment. Before these changes, the live deployment returned 404 for `/SKILL.md`, `/robots.txt`, `/sitemap.xml`, and `/llms.txt`; those files now return 200 on `https://invoicegen.megabyte.sh/`.

## Platform Breakdown

| Platform | Score | Notes |
| --- | ---: | --- |
| Google AI Overviews | 79/100 | Static HTML, clear metadata, SoftwareApplication schema, and a question-based answer block improve extractability. Ranking authority is still the limiting factor. |
| ChatGPT Search | 80/100 | `/llms.txt`, `/SKILL.md`, open-source repository links, and AI crawler access improve machine readability. Brand entity presence remains thin. |
| Perplexity | 74/100 | Technical access is strong, but third-party mentions and community validation are currently weak. |

## AI Crawler Access Status

`site/robots.txt` now allows the main search and AI-answer crawlers:

| Crawler | Status |
| --- | --- |
| GPTBot | Allowed |
| OAI-SearchBot | Allowed |
| ChatGPT-User | Allowed |
| ClaudeBot | Allowed |
| PerplexityBot | Allowed |
| CCBot | Blocked |
| anthropic-ai | Blocked |
| Bytespider | Blocked |
| cohere-ai | Blocked |

## llms.txt Status

`site/llms.txt` is now present with:

- Homepage and repository skill links
- GitHub source and latest release links
- Key local-first, no-account, shared-store, CLI, license, and macOS support facts
- A suggested citation sentence for AI answer engines

## Brand Mention Analysis

Current web search showed weak exact-brand visibility for this specific InvoiceGen app. Results for `InvoiceGen` are dominated by unrelated invoice-generator brands and projects, including:

- https://www.invoicegen.co/
- https://invoicegenerator.best/
- https://github.com/aditi755/InvoiceGen
- https://github.com/Invoice-Generator/invoice-generator-api

Reddit results show demand and discussion around offline or macOS invoice apps, but not strong mentions for this specific project yet:

- https://www.reddit.com/r/selfhosted/comments/1qvgr4z/invoice_builder_a_fully_offlinefirst_invoicing/
- https://www.reddit.com/r/u_ACInvoicePro/comments/1t41u53/i_built_a_499_onetime_invoice_app_for_mac_because/
- https://www.reddit.com/r/macapps/comments/1q7uzz8/native_swift_invoice_app/

Recommendation: publish and link the project consistently as "InvoiceGen local-first macOS invoicing" or "InvoiceGen by megabyte0x" to avoid confusion with existing generic InvoiceGen brands.

## Passage-Level Citability

The homepage now includes a question-based H2, "What is InvoiceGen?", followed by a 141-word self-contained answer block. It directly states:

- What InvoiceGen is
- Who it is for
- What it manages
- How the Rust CLI relates to the macOS app
- License, platform, and local-first positioning
- Where agents can find the repository skill

This is the strongest current citation passage on the page.

## Server-Side Rendering Check

The homepage is static HTML copied into `dist/site`, so primary content is accessible without JavaScript. JavaScript is only used for theme toggling, FAQ expansion, copy behavior, and best-effort latest release link updates.

## Top 5 Highest-Impact Changes

1. Build and deploy the new `/SKILL.md`, `/robots.txt`, `/sitemap.xml`, and `/llms.txt` files.
2. Keep the "What is InvoiceGen?" answer block stable and update it when product positioning changes.
3. Add release notes, GitHub README links, and third-party posts that use the same entity phrase: "InvoiceGen local-first macOS invoicing".
4. Create a short demo video or README GIF and link it from the homepage, GitHub README, and release page.
5. Seed credible discussion in relevant communities with the local-first macOS angle, not generic invoice-generator wording.

## Schema Recommendations

Implemented:

- `WebSite`
- `SoftwareApplication`
- Creator, code repository, MIT license, price, operating system, version, download URL, and canonical product image

Avoided:

- FAQ schema, because this is not a government or healthcare site.
- Review/rating schema, because no verified review data is present.

## Content Reformatting Suggestions

Completed:

- Added a question-based "What is InvoiceGen?" section.
- Added a fact list for platform, storage, automation, and license.
- Fixed the agent prompt to use the full HTTPS `/SKILL.md` URL.

Future:

- Add a comparison section for "local-first macOS invoicing vs cloud invoicing tools" once there is enough original detail to avoid thin content.
- Add a CLI examples section if the homepage should rank for agentic or scriptable invoicing queries.
- Add screenshots or video clips showing invoice creation and CLI rendering to strengthen multi-modal selection.
