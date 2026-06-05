# InvoiceGen SERP Baseline

Date: 2026-06-05
Target: https://invoicegen.megabyte.sh/
Goal: verify whether InvoiceGen has reached first-page visibility for invoice-generation related searches.

## Result

First-page ranking is **not yet proven**. Current search snapshots did not surface InvoiceGen for the priority long-tail searches checked below. This means the backlink/ranking goal must remain active.

## Queries checked

| Query | InvoiceGen visible in returned results? | Notable visible competitors/comparables |
| --- | --- | --- |
| `local-first invoice generator macOS` | No | InvoiceOffline, Billly, native Swift invoice app Reddit threads |
| `Rust invoice CLI` | No | Invoice-X, Klirr/Rust invoicing discussions, unrelated Rust CLI tools |
| `open source invoice generator macOS` | No | Tilly Billy, Invoice-X, EasyInvoicePDF, Invoice Builder/self-hosted threads |
| `privacy-first invoice app freelancers` | No | InvoicesCraft, Dime, Recevo, Native Invoice privacy policy |
| `site:invoicegen.megabyte.sh invoicegen cli privacy local-first invoicing` | Weak/unclear | Search tooling returned unrelated mirror content, so live sitemap verification is stronger for page-discovery evidence right now |

## Live deployment evidence

Latest production deployment: `dpl_7kZLiL3k4tDtRW118bdGugiz5mzu`

Previous offline/launch-kit deployment: `dpl_2RYiuQZ1xcz53sc2wnRxEDd1XMco`

Previous open-source/Manta deployment: `dpl_A6Kb8Gkb8X6Qz2BVGjUM659v6CC5`

Verified live URLs:

| URL | H1 count | Raw text chars | Canonical |
| --- | ---: | ---: | --- |
| `https://invoicegen.megabyte.sh/` | 1 | 2,889 | `https://invoicegen.megabyte.sh/` |
| `https://invoicegen.megabyte.sh/cli` | 1 | 3,159 | `https://invoicegen.megabyte.sh/cli` |
| `https://invoicegen.megabyte.sh/privacy` | 1 | 3,164 | `https://invoicegen.megabyte.sh/privacy` |
| `https://invoicegen.megabyte.sh/docs/local-first-invoicing` | 1 | 2,910 | `https://invoicegen.megabyte.sh/docs/local-first-invoicing` |
| `https://invoicegen.megabyte.sh/docs/backup-restore` | 1 | 2,643 | `https://invoicegen.megabyte.sh/docs/backup-restore` |
| `https://invoicegen.megabyte.sh/changelog` | 1 | 2,198 | `https://invoicegen.megabyte.sh/changelog` |
| `https://invoicegen.megabyte.sh/open-source-invoice-generator` | 1 | 3,406 | `https://invoicegen.megabyte.sh/open-source-invoice-generator` |
| `https://invoicegen.megabyte.sh/alternatives/manta` | 1 | 3,787 | `https://invoicegen.megabyte.sh/alternatives/manta` |
| `https://invoicegen.megabyte.sh/alternatives/invoice-ninja` | 1 | 5,035 | `https://invoicegen.megabyte.sh/alternatives/invoice-ninja` |
| `https://invoicegen.megabyte.sh/offline-invoice-generator-mac` | 1 | 3,640 | `https://invoicegen.megabyte.sh/offline-invoice-generator-mac` |
| `https://invoicegen.megabyte.sh/launch-kit` | 1 | 3,568 | `https://invoicegen.megabyte.sh/launch-kit` |

Live `sitemap.xml` and `llms.txt` both include:

- `https://invoicegen.megabyte.sh/cli`
- `https://invoicegen.megabyte.sh/privacy`
- `https://invoicegen.megabyte.sh/docs/local-first-invoicing`
- `https://invoicegen.megabyte.sh/docs/backup-restore`
- `https://invoicegen.megabyte.sh/changelog`
- `https://invoicegen.megabyte.sh/open-source-invoice-generator`
- `https://invoicegen.megabyte.sh/alternatives/manta`
- `https://invoicegen.megabyte.sh/alternatives/invoice-ninja`
- `https://invoicegen.megabyte.sh/offline-invoice-generator-mac`
- `https://invoicegen.megabyte.sh/launch-kit`

## Interpretation

InvoiceGen now has the crawlable pages needed for backlinks to point at specific intents. The next bottleneck is off-site authority: accepted directory listings, launch pages, community mentions, and editorial links. The next outreach wave should prioritize Product Hunt, AlternativeTo, FOSSHUNTER, Repoz, WarmIndex, FossFinder, OSSAlternatives, r/macapps, r/SideProject, r/opensource, and a Rust/CLI-focused Show HN or r/rust post after demo assets are ready.

Update 2026-06-05: the next outreach wave is now more concrete. `SEO-SUBMISSION-PACK.md` contains field-ready copy, submit URLs, anchor choices, and account-gated blockers. `SEO-BACKLINK-TRACKER.csv` has 36 rows and includes additional verified prospects: RepoRanker, SaaSHub, Peerlist Launchpad, Uneed, OpenAltFinder, OSSSoftware, TinyLaunch, CLI Directory, inrust, RustUtils, PickYourTech, and offline Mac software roundups. Two additional first-party backlink targets are now live: `https://invoicegen.megabyte.sh/open-source-invoice-generator` for open-source directory submissions and `https://invoicegen.megabyte.sh/alternatives/manta` for AlternativeTo/Manta-alternative submissions.

Update 2026-06-05 after deployment `dpl_2RYiuQZ1xcz53sc2wnRxEDd1XMco`: two more first-party backlink targets are live. Use `https://invoicegen.megabyte.sh/offline-invoice-generator-mac` for offline/no-cloud Mac invoice searches and Mac productivity outreach, and use `https://invoicegen.megabyte.sh/launch-kit` as the copy/image/source-of-truth page for Product Hunt, Peerlist, Uneed, TinyLaunch, SaaSHub, and software-directory editors. Live `sitemap.xml` and `llms.txt` include both pages and contain no build placeholders.

Update 2026-06-05 directory wave: `SEO-BACKLINK-TRACKER.csv` now has 50 unique prospects. The added wave includes live npm/GitHub release surfaces plus SourceForge, MacUpdate, Open Hub, Just OpenSource, OpenAlternative, OSSAlt, OpenCLI Hub, ToolShelf, ToolHunter, CLIs Finder, Softpedia Mac, and a first-party Invoice Ninja alternative page. Local package metadata now points npm/Homebrew/Cargo homepage fields toward the canonical `/cli` page for future package-registry backlinks, but the already-published npm package still needs the next publish before npmjs.com links the `/cli` homepage.

Update 2026-06-05 fresh search snapshot: searches for `invoicegen.megabyte.sh invoice generator InvoiceGen`, `local-first invoice generator macOS InvoiceGen`, `open source invoice generator macOS InvoiceGen`, and `Rust invoice CLI InvoiceGen` still returned competitors and discussion pages rather than `invoicegen.megabyte.sh` in the returned first-page set. Visible competitors/comparables included Tilly Billy, InvoiceOffline, Invoice-X, ILoveInvoice, EasyInvoicePDF, invoicegenerator.best, Billly, Aryan Shinde's InvoiceGen, and multiple Reddit invoice-generator threads. This reinforces that the next bottleneck is accepted third-party backlinks and indexed mentions, not another homepage rewrite.

Update 2026-06-05 comparison-intent expansion: search results and directory research show repeated Invoice Ninja alternative intent across AlternativeTo, PickYourTech, and Reddit/self-hosted discussions. Production deployment `dpl_7kZLiL3k4tDtRW118bdGugiz5mzu` published `https://invoicegen.megabyte.sh/alternatives/invoice-ninja` as a live target for AlternativeTo, OpenAlternative, OSSAlt, PickYourTech, and editorial comparison backlinks. Live verification found one raw H1, 5,035 raw text characters, canonical metadata, no placeholders, and sitemap/llms inclusion.

## Sources to monitor

- Product Hunt launch: https://www.producthunt.com/launch
- GitHub invoice-generator topic: https://github.com/topics/invoice-generator
- AlternativeTo Manta alternatives: https://alternativeto.net/software/manta/
- FOSSHUNTER: https://fosshunter.com/
- Repoz: https://www.repoz.io/
- WarmIndex: https://warmindex.com/
- FossFinder: https://fossfinder.com/
- OSSAlternatives submit: https://ossalternatives.to/submit
- RepoRanker: https://reporanker.com/
- SaaSHub submit: https://www.saashub.com/submit
- Peerlist Launchpad: https://help.peerlist.io/individual/launchpad/introduction
- Uneed submit-product help: https://help.uneed.best/getting-started
- OpenAltFinder submit: https://openaltfinder.com/submit
- CLI Directory: https://www.cli.directory/
- SourceForge: https://sourceforge.net/directory/
- MacUpdate: https://www.macupdate.com/help
- Open Hub: https://openhub.net/
- Just OpenSource: https://justopensource.xyz/
- OpenAlternative submit: https://openalternative.co/submit
- OSSAlt: https://ossalt.com/
- OpenCLI Hub: https://www.openclihub.com/
- ToolShelf submit: https://toolshelf.dev/submit
- ToolHunter submit: https://www.toolhunter.cc/submit
- CLIs Finder: https://clisfinder.com/
- Softpedia Mac: https://mac.softpedia.com/
