# InvoiceGen SEO Backlink Roadmap

Date: 2026-06-05
Target page: https://invoicegen.megabyte.sh/
Primary goal: earn enough relevant, durable authority for first-page Google visibility on invoice-generation searches, starting with long-tail searches where InvoiceGen has a real differentiator.

## Current evidence

- Live homepage is indexable and raw-crawlable: `curl -sL https://invoicegen.megabyte.sh/` returns one raw `<h1>` and about 2.3k body-text characters.
- GitHub repo metadata is already strong for first-party entity authority: public repo, homepage set, Apache-2.0, description set, and topics include `invoice`, `invoicing`, `macos`, `rust-cli`, `local-first`, `pdf-export`, and `freelancers`.
- Exact web searches for `invoicegen.megabyte.sh`, `"megabyte0x" "InvoiceGen"`, and `github.com/megabyte0x/invoicegen` did not show meaningful third-party mentions. Backlinks are the main missing authority layer.
- Benchmark searches on 2026-06-05 for long-tail terms like `local-first invoice generator macOS InvoiceGen`, `open source invoice generator macOS InvoiceGen`, and `Rust invoice CLI InvoiceGen` did not surface InvoiceGen on the first visible results page. Nearby competitors and comparables included InvoiceOffline, Billly, Tilly Billy, Invoice-X, ILoveInvoice, EasyInvoicePDF, and other open-source/no-signup invoice tools.
- Production deployment `dpl_6pSaaBoAsse6nc4FS6fVsUSG3Zos` published five linkable backlink targets on 2026-06-05: `/cli`, `/privacy`, `/docs/local-first-invoicing`, `/docs/backup-restore`, and `/changelog`. Live verification found each page returns one raw H1, canonical metadata, and 2.1k-3.2k raw text characters.
- Production deployment `dpl_A6Kb8Gkb8X6Qz2BVGjUM659v6CC5` published two more backlink landing pages on 2026-06-05: `/open-source-invoice-generator` for open-source directory submissions and `/alternatives/manta` for AlternativeTo/Manta-alternative submissions. Live verification found one raw H1, canonical metadata, no placeholders, and 3.4k-3.8k raw text characters on those pages.
- Production deployment `dpl_2RYiuQZ1xcz53sc2wnRxEDd1XMco` published two more backlink assets on 2026-06-05: `/offline-invoice-generator-mac` for offline/no-cloud Mac invoice searches and `/launch-kit` for Product Hunt, Peerlist, Uneed, TinyLaunch, SaaSHub, and directory editor submissions. Live verification found one raw H1, canonical metadata, no placeholders, and 3.5k-3.6k raw text characters on those pages.
- Production deployment `dpl_7kZLiL3k4tDtRW118bdGugiz5mzu` published `/alternatives/invoice-ninja` on 2026-06-05 for Invoice Ninja alternative submissions. Live verification found one raw H1, canonical metadata, no placeholders, sitemap/llms inclusion, and 5,035 raw text characters.
- `SEO-BACKLINK-TRACKER.csv` now tracks 50 unique prospects. New evidence-backed surfaces include live npm/GitHub release pages plus SourceForge, MacUpdate, Open Hub, Just OpenSource, OpenAlternative, OSSAlt, OpenCLI Hub, ToolShelf, ToolHunter, CLIs Finder, Softpedia Mac, and a new first-party Invoice Ninja alternative page.
- The broad head term `invoice generator` is extremely competitive and crowded with browser invoice generators, app-store apps, and large accounting brands. The best path is to rank first for long-tail intent first, then expand.

## Ranking targets

### Tier A: fastest realistic first-page targets

Use these for anchor text, directory descriptions, and community posts.

- `local-first invoice generator macOS`
- `open source invoice generator macOS`
- `native macOS invoice app`
- `Rust invoice CLI`
- `offline invoice generator for Mac`
- `privacy-first invoice app for freelancers`
- `scriptable invoice generator`

### Tier B: mid-competition targets

- `mac invoice generator`
- `invoice app for freelancers mac`
- `open source invoice generator`
- `invoice generator CLI`
- `free invoice generator mac`

### Tier C: long-term head terms

- `invoice generator`
- `invoice generation`
- `free invoice generator`
- `invoice maker`

Do not over-optimize every backlink with the exact phrase `invoice generator`. Rotate anchors:

- `InvoiceGen`
- `InvoiceGen for macOS`
- `local-first macOS invoicing`
- `open-source invoice generator for macOS`
- `Rust invoice CLI`
- `privacy-first invoice app`
- `scriptable invoice workflows`

## Best backlink opportunities

### Priority 1: high-signal launch and product discovery

| Prospect | Why it matters | Target URL | Pitch angle | Status |
| --- | --- | --- | --- | --- |
| Product Hunt | Proven fit for Mac invoice tools; a comparable Invoice Builder App listing had a Product Hunt launch page, Mac/iOS tags, followers, comments, and a daily rank. Product Hunt says makers can submit products and get distribution to early adopters. | Homepage + `/launch-kit` asset hub | `Open-source, local-first macOS invoicing app with a Rust CLI` | Prepare assets, then launch |
| Hacker News Show HN | Strong technical/referral signal for open-source and CLI projects; best for the Rust CLI + local-first angle, not generic invoicing. | GitHub repo or homepage | `Show HN: InvoiceGen, a local-first macOS invoicing app with a Rust CLI` | Needs demo GIF and concise post |
| Reddit r/macapps | Recent search results show recurring demand for native Swift/macOS invoice apps and user feedback threads. | Homepage or `/offline-invoice-generator-mac` | `Native, local-first invoice app for Mac; looking for feedback` | Draft feedback post |
| Reddit r/SideProject | Current invoice-generator posts show users are still sharing and discussing no-signup/offline invoice tools. | Homepage or `/launch-kit` | `I built a free local-first invoice app for Mac` | Draft feedback post |
| Reddit r/opensource | Fits Apache-2.0 and open-source angle; avoid sales language. | GitHub repo | `Open-source macOS invoice app + Rust CLI` | Draft project post |
| Reddit r/rust | Only if the CLI is the center; highlight data model, rendering, packaging, and validation. | GitHub repo | `Rust CLI for local invoice workflows` | Draft technical post |

### Priority 2: software directories and open-source catalogs

| Prospect | Evidence/fit | Best category/action | Target URL | Status |
| --- | --- | --- | --- | --- |
| GitHub Topics | `invoice-generator` topic has hundreds of public repos and active discovery. | Keep repo topics complete: `invoice-generator`, `invoice-pdf`, `invoice-cli`, `macos`, `swiftui`, `rust-cli`, `local-first`. | GitHub repo | Done 2026-06-05 |
| AlternativeTo | Existing Manta and invoice-maker pages list many invoicing alternatives across Mac/Web/iOS. | Add InvoiceGen as an alternative to Manta, Invoice Ninja, Quick Invoice Maker, and desktop invoice tools. | `/alternatives/manta` | Submit manually |
| FOSSHUNTER | Open-source tools directory with an Accounting category and a visible Submit route. | Submit as Accounting + Developer Tools. | GitHub repo + homepage | Submit manually |
| Repoz | Open-source discovery site with `Submit a Project`. | Submit as CLI, macOS, productivity/accounting. | GitHub repo | Submit manually |
| WarmIndex | Directory for active side projects/open-source with `Submit your project`; says it lists 850+ apps. | Submit if accepted as side-project/open-source app. | Homepage | Submit manually |
| FossFinder | Open-source tools directory; submit favorite open-source tools. | Submit as open-source alternative/invoicing. | GitHub repo | Submit manually |
| OSSAlternatives | Submission page asks for open-source alternatives to proprietary software. | Position as an open-source alternative to cloud/browser invoice generators. | `/open-source-invoice-generator` | Submit manually |
| BetaList | Requires a working website on your own domain; curatorial and not guaranteed. | Submit if we want startup-directory exposure. | Homepage | Optional |
| Apple App Store | App Store pages are strong discovery/brand assets. Apple submission guidance emphasizes product-page name, icon, description, screenshots, previews, keywords, and privacy details. | Submit only when app-store-ready. | App Store product page | Future |

### Priority 2.5: newly verified backlink targets for the next submission wave

These were added to `SEO-BACKLINK-TRACKER.csv` and expanded into a field-ready submission pack in `SEO-SUBMISSION-PACK.md`.

| Prospect | Evidence/fit | Best category/action | Target URL | Status |
| --- | --- | --- | --- | --- |
| RepoRanker | GitHub-verified repo-review directory; says repo submission is free and live quickly, with permanent 800+ character reviews. | Submit repo, then invite real developer reviews. | GitHub repo | Draft ready |
| SaaSHub | Product submit/verify flow plus directory/community distribution from the product management page. | Submit and verify InvoiceGen, then use SaaSHub Submit for relevant directories. | Homepage | Draft ready |
| Peerlist Launchpad | Launchpad for projects/products; requires verified individual profile and a 100% complete project before launching. | Prepare screenshots/demo, then launch on a Monday. | `/launch-kit` | Assets needed |
| Uneed | Product Hunt alternative for indie hackers with submit-product help and backlink/auto-submit resources. | Prepare launch listing and product assets. | `/launch-kit` | Assets needed |
| OpenAltFinder | Direct submit form for open-source alternatives; asks for project URL, repository URL, and alternative-to field. | Submit as an open-source alternative to hosted/cloud invoice generators. | `/open-source-invoice-generator` + GitHub repo | Draft ready |
| OSSSoftware | Open-source alternatives directory; says projects can be submitted for review or contributed to the database. | Submit/contribute entry for InvoiceGen. | `/open-source-invoice-generator` | Research/contact |
| TinyLaunch | Product launch platform; free launches can earn top-3 backlink, premium has guaranteed backlink. | Launch only after screenshots/demo are ready. | `/launch-kit` | Assets needed |
| CLI Directory | CLI catalog with a submit-tool surface; relevant to `Rust invoice CLI` long-tail intent. | Submit or pitch the `/cli` page. | `/cli` | Draft ready |
| inrust | Rust CLI catalog for Rust-built tools; high topical fit for the CLI page. | Find maintainer/contact or contribution route. | `/cli` | Outreach draft |
| RustUtils | Rust CLI listing format links repo/package details; topical fit for the CLI page. | Pitch once package metadata is stable. | `/cli` | Outreach draft |
| PickYourTech | Curated open-source/commercial tooling directory across many categories. | Secondary contact/research prospect. | `/open-source-invoice-generator` | Research/contact |

Update after page expansion: use `https://invoicegen.megabyte.sh/open-source-invoice-generator` for OpenAltFinder, OSSAlternatives, OSSSoftware, and PickYourTech-style open-source directory submissions. Use `https://invoicegen.megabyte.sh/alternatives/manta` for AlternativeTo and any review page that asks for a specific Manta alternative URL.

Update after deployment `dpl_2RYiuQZ1xcz53sc2wnRxEDd1XMco`: use `https://invoicegen.megabyte.sh/offline-invoice-generator-mac` for offline Mac productivity/no-cloud/freelancer tool roundups, and use `https://invoicegen.megabyte.sh/launch-kit` as the asset hub for Product Hunt, Peerlist, Uneed, TinyLaunch, SaaSHub, and directory editors that want screenshots, logo, and copy in one place.

### Priority 2.6: registry, download, and developer-tool directories

This wave expands beyond generic launch directories into places that can create durable package, download, and developer-tool authority.

| Prospect | Evidence/fit | Best category/action | Target URL | Status |
| --- | --- | --- | --- | --- |
| npm package page | `npm view @megabyte0x/invoicegen` confirms v0.1.6 is live with package/repository metadata. | Keep package metadata accurate; next publish should point homepage to `/cli`. | GitHub README today; `/cli` after next publish | Live |
| GitHub release v0.1.6 | Stable downloadable app page for app/download-directory submissions. | Use when a form asks for direct download/release URL. | GitHub release page | Live |
| SourceForge | High-authority software/download and open-source directory. | Create project/listing with homepage, GitHub repo, and v0.1.6 release/download. | `/open-source-invoice-generator` | Draft ready |
| MacUpdate | Mac app directory with submission/help surface. | Submit native macOS app using offline Mac page and release DMG. | `/offline-invoice-generator-mac` | Draft ready |
| Open Hub | Open-source project analytics/directory surface. | Add project with GitHub SCM URL and project metadata. | GitHub repo | Draft ready |
| Just OpenSource | Open-source directory with Finance & Business / Productivity fit. | Submit as open-source local-first invoicing tool. | `/open-source-invoice-generator` | Draft ready |
| OpenAlternative | Open-source alternatives submit route. | Submit as alternative to hosted/cloud invoice tools. | `/open-source-invoice-generator` | Draft ready |
| OSSAlt | Open-source alternatives directory. | Submit as FOSS alternative to FreshBooks/QuickBooks invoicing/browser invoice makers. | `/open-source-invoice-generator` | Draft ready |
| OpenCLI Hub | CLI directory with AI-agent tooling angle. | Submit InvoiceGen CLI as agent-friendly invoice workflow CLI. | `/cli` | Draft ready |
| ToolShelf | Developer tools directory with submit route and CLI/Productivity categories. | Submit `/cli` and GitHub repo. | `/cli` | Draft ready |
| ToolHunter | Developer tool submission/review directory. | Pitch CLI and local invoice automation. | `/cli` | Draft ready |
| CLIs Finder | CLI directory with no submit route found yet. | Research maintainer/contact path. | `/cli` | Research/contact |
| Softpedia Mac | Large Mac software/download directory. | Research editor/contact or PAD/submission path. | `/offline-invoice-generator-mac` | Research/contact |

### Priority 3: linkable content and editorial outreach

These are slower but strongest for long-term rankings because they can earn contextual editorial links.

| Asset to publish | Backlink target | Outreach targets | Anchor angle |
| --- | --- | --- | --- |
| `/cli` page | `https://invoicegen.megabyte.sh/cli` | Rust newsletters, CLI/tooling roundups, GitHub topic curators | `Rust invoice CLI` |
| `/docs/local-first-invoicing` | Docs page | privacy/local-first blogs, indie maker newsletters | `local-first invoicing` |
| `/docs/backup-restore` | Docs page | Mac productivity blogs, freelancers/accounting guides | `back up invoice data on Mac` |
| `/privacy` | Privacy page | privacy-first software lists | `privacy-first invoice app` |
| `/changelog` | Changelog page | software directories, reviewers, launch writeups | `InvoiceGen release notes` |
| `/open-source-invoice-generator` | Open-source page | OpenAltFinder, OSSAlternatives, OSSSoftware, PickYourTech | `open-source invoice generator for macOS` |
| `/alternatives/manta` | Comparison page | AlternativeTo, Manta alternative submissions, software reviewers | `Manta alternative for local-first macOS invoicing` |
| `/alternatives/invoice-ninja` | Comparison page | AlternativeTo, OpenAlternative, OSSAlt, PickYourTech, Invoice Ninja alternative lists | `Invoice Ninja alternative for Mac` |
| `/offline-invoice-generator-mac` | Offline Mac page | Mac productivity blogs, no-cloud software lists, freelancer tool roundups | `offline invoice generator for Mac` |
| `/launch-kit` | Launch asset page | Product Hunt, Peerlist, Uneed, TinyLaunch, SaaSHub, directory editors | `InvoiceGen launch kit` |
| short demo video/GIF | Product Hunt, Reddit, directories | Product pages and launch posts | `native macOS invoice app` |
| comparison table | Homepage or `/compare` | AlternativeTo, software reviewers | `open-source alternative to cloud invoice generators` |

## Submission copy

### 1-line tagline

InvoiceGen is a free, open-source, local-first macOS invoicing app with a Rust CLI for private, scriptable invoice workflows.

### 60-word directory description

InvoiceGen is a local-first invoice generator for macOS. Freelancers and small teams can manage clients, projects, payment details, invoice line items, taxes, notes, backups, and PDF-ready exports without creating a cloud account. The native Swift app and Rust CLI share the same local store, making invoice workflows private, scriptable, and open source under Apache-2.0.

### 120-word launch description

InvoiceGen is a native macOS invoicing workspace for freelancers and small teams who want invoice data to stay on their Mac. It supports clients, projects, payment details, line items, due dates, taxes, notes, backups, and PDF-ready invoice exports. Unlike browser-only invoice generators or hosted accounting tools, InvoiceGen does not require a signup, subscription, cloud backend, or telemetry service. The app ships with a Rust CLI that reads the same local store, so users and AI agents can inspect, create, list, render, export, and restore invoices through scripts. InvoiceGen is free, open source, Apache-2.0 licensed, and currently targets macOS 14 Sonoma or newer.

### Product Hunt draft

**Name:** InvoiceGen
**Tagline:** Local-first macOS invoicing with a Rust CLI
**Description:** Create and manage invoices locally on your Mac, export PDF-ready invoices, back up your data, and automate workflows through a Rust CLI that shares the same store as the native Swift app. Free and open source.

### Show HN draft

Title: `Show HN: InvoiceGen – local-first macOS invoicing with a Rust CLI`

Body:

> I built InvoiceGen for freelancers and small teams who want invoices to stay local instead of living in a hosted accounting app. It is a native macOS app plus a Rust CLI that shares the same local store, so invoices can be created, listed, rendered, exported, and restored from scripts.
>
> The app is free and Apache-2.0. I am looking for feedback on the local data model, CLI ergonomics, and what invoice workflows should be added next.

## 30-day execution plan

### Week 1: fix entity consistency and make submissions possible

- Keep public copy consistent on `InvoiceGen`, `invoicegen.megabyte.sh`, and `github.com/megabyte0x/invoicegen`.
- Add missing GitHub topics: `invoice-generator`, `invoice-pdf`, `invoice-cli`, `invoice-app`, `invoicing-software`. ✅ Done 2026-06-05.
- Create a 30-60 second demo GIF/video and 3 screenshots for Product Hunt, directories, and Reddit.
- Add or publish a `/cli` page so CLI-focused backlinks do not all point at the homepage. ✅ Live 2026-06-05.
- Add `/privacy`, `/docs/local-first-invoicing`, `/docs/backup-restore`, and `/changelog` as additional first-party link targets for directory and editorial outreach. ✅ Live 2026-06-05.
- Add `/open-source-invoice-generator` and `/alternatives/manta` as focused first-party link targets for open-source directories and AlternativeTo/Manta-alternative submissions. ✅ Live 2026-06-05.
- Add `/offline-invoice-generator-mac` and `/launch-kit` as focused first-party link targets for offline Mac roundups and launch-directory submissions. ✅ Live 2026-06-05.
- Add `/alternatives/invoice-ninja` as a focused first-party link target for Invoice Ninja alternative submissions. ✅ Live 2026-06-05.

### Week 2: submit high-signal directories

- Submit to Product Hunt.
- Add InvoiceGen to AlternativeTo alternatives for Manta, Invoice Ninja, Quick Invoice Maker, and similar invoice tools.
- Submit to RepoRanker, FOSSHUNTER, Repoz, OpenAltFinder, OSSAlternatives, SaaSHub, WarmIndex, FossFinder, and OSSSoftware.
- Submit/download-directory wave: SourceForge, MacUpdate, Open Hub, Just OpenSource, OpenAlternative, OSSAlt, OpenCLI Hub, ToolShelf, and ToolHunter.
- Research contact paths for CLIs Finder and Softpedia Mac.
- Prepare screenshots/demo assets before launching on Product Hunt, Peerlist Launchpad, Uneed, or TinyLaunch.
- Use `/launch-kit` as the source-of-truth URL for directory editors that ask for screenshots, logo assets, and launch copy.
- Build a contact list for offline Mac software roundups and pitch `/offline-invoice-generator-mac`.
- Use `/alternatives/invoice-ninja` for Invoice Ninja-specific AlternativeTo, OpenAlternative, OSSAlt, PickYourTech, and editorial comparison submissions after deployment.
- Pitch `/cli` to CLI Directory, inrust, and RustUtils for `Rust invoice CLI` topical backlinks.
- Track each submission URL, login, date submitted, acceptance status, link target, and anchor text.

### Week 3: community backlinks and feedback

- Post in r/macapps and r/SideProject with screenshots and a feedback request.
- Post in r/opensource with the GitHub repo and a contributor-oriented angle.
- Post in r/rust only if the post is CLI/implementation focused.
- Reply to every comment and update the product page if feedback reveals missing user intent.

### Week 4: editorial outreach

- Pitch 10 Mac productivity/software blogs with the native-local-first angle.
- Pitch 10 freelancer/accounting blogs with the free/offline invoice workflow angle.
- Pitch 5 Rust/CLI newsletters with the CLI angle.
- Offer a concise guest post: `How to keep freelancer invoice data local on macOS`.

## Tracking sheet fields

Use this schema for each backlink attempt:

| Field | Example |
| --- | --- |
| Prospect | Product Hunt |
| Prospect URL | `https://www.producthunt.com/launch` |
| Category | launch directory |
| Target page | homepage |
| Anchor text | `local-first macOS invoicing` |
| Submission date | `2026-06-05` |
| Status | drafted / submitted / accepted / rejected / live |
| Live backlink URL | TBD |
| Follow-up date | TBD |
| Notes | Needs video before launch |

## First-page verification loop

Do not mark the SEO goal complete until first-page evidence exists.

Weekly checks:

1. Google Search Console: impressions, clicks, indexed pages, and queries for the target page.
2. Manual incognito checks from the target country for Tier A and Tier B keywords.
3. Search `invoicegen.megabyte.sh`, `"InvoiceGen" "megabyte0x"`, and `github.com/megabyte0x/invoicegen` for new third-party mentions.
4. Record backlink URLs and whether Google has indexed them.
5. If Tier A keywords are not moving after 4 weeks, prioritize more contextual editorial links and publish the `/cli`, `/privacy`, and `/docs/local-first-invoicing` pages.

## Source notes

- Product Hunt launch guidance: https://www.producthunt.com/launch
- Product Hunt comparable invoice Mac app: https://www.producthunt.com/products/invoice-builder-app?launch=invoice-builder-app
- GitHub invoice-generator topic: https://github.com/topics/invoice-generator
- InvoiceOffline comparable local Mac app: https://www.invoiceoffline.com/
- Billly comparable local Mac app: https://www.getbillly.app/
- Tilly Billy open-source invoice generator: https://tillybilly.co/
- AlternativeTo Manta alternatives: https://alternativeto.net/software/manta/
- FOSSHUNTER open-source tools directory: https://fosshunter.com/
- Repoz open-source project discovery: https://www.repoz.io/
- WarmIndex side-project/open-source directory: https://warmindex.com/
- FossFinder open-source tools directory: https://fossfinder.com/
- OSSAlternatives submit page: https://ossalternatives.to/submit
- RepoRanker open-source repo reviews: https://reporanker.com/
- SaaSHub submit flow: https://www.saashub.com/submit
- Peerlist Launchpad intro/process: https://help.peerlist.io/individual/launchpad/introduction and https://help.peerlist.io/individual/launchpad/how-to-launch-a-project-on-peerlist-launchpad
- Uneed getting started: https://help.uneed.best/getting-started
- OpenAltFinder submit page: https://openaltfinder.com/submit
- OSSSoftware open-source alternatives directory: https://osssoftware.org/
- TinyLaunch launch/backlink terms: https://www.tinylaunch.com/
- CLI Directory submit-tool surface: https://www.cli.directory/
- inrust Rust CLI catalog: https://inrust.dev/
- RustUtils Rust CLI listing format: https://rustutils.com/tools/miniserve/
- npm package metadata verification: `npm view @megabyte0x/invoicegen`
- GitHub release/download page: https://github.com/megabyte0x/invoicegen/releases/tag/v0.1.6
- SourceForge software directory: https://sourceforge.net/directory/
- MacUpdate help/submission surface: https://www.macupdate.com/help
- Open Hub open-source project directory: https://openhub.net/
- Just OpenSource directory: https://justopensource.xyz/
- OpenAlternative submit route: https://openalternative.co/submit
- OSSAlt open-source alternatives directory: https://ossalt.com/
- OpenCLI Hub CLI directory: https://www.openclihub.com/
- ToolShelf submit page: https://toolshelf.dev/submit
- ToolHunter submit page: https://www.toolhunter.cc/submit
- CLIs Finder directory: https://clisfinder.com/
- Softpedia Mac directory: https://mac.softpedia.com/
- BetaList submission terms: https://betalist.com/terms/submissions
- Apple App Store submission guidance: https://developer.apple.com/app-store/submitting/
