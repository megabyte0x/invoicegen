---
name: invoicegen
description: Use when working in the InvoiceGen repository on the Rust CLI, the shared InvoiceGen store.json format, invoice/client/project/payment-detail workflows, or when an agent needs to inspect, test, document, or operate the invoicegen-rs command-line tool that mirrors the macOS app.
---

# InvoiceGen CLI

Use this skill in the repo root at `/Users/megabyte0x/Developer/invoicegen`.

## Core Rule

Treat the Swift app and Rust CLI as two clients for the same local-first invoice store. Preserve compatibility with the Swift `InvoiceCore` models and the versioned JSON document at `store.json`.

## Files To Inspect

- Rust CLI entrypoint: `src/main.rs`
- Rust command handling: `src/cli.rs`
- Rust domain and rendering logic: `src/domain.rs`
- Rust store persistence: `src/store.rs`
- Rust JSON parser/serializer: `src/json.rs`
- Rust contract tests: `RustTests/rust_cli_contract.rs`
- npm package metadata and wrapper: `npm/`
- CLI release scripts: `script/build_cli_release.mjs`, `script/stage_npm_packages.mjs`, `script/render_homebrew_formula.mjs`, `script/verify_cli_packaging.mjs`
- Homebrew formula template: `Formula/invoicegen.rb`
- CLI release workflow: `.github/workflows/release-cli.yml`
- Swift source of truth: `Sources/InvoiceCore/`

## How To Use The CLI

If the CLI has already been published, install and use it through a package manager:

```sh
npm install -g @megabyte0x/invoicegen
invoicegen --help
```

Or with Homebrew:

```sh
brew tap megabyte0x/tap
brew install invoicegen
invoicegen --help
```

Prefer the installed `invoicegen` command when verifying the published user experience. Use `cargo run` for repo-local development, debugging, or unpublished changes.

Run from the repo root:

```sh
cargo run -- --help
```

Use `--store PATH` for experiments so agent work does not mutate the user's real app data:

```sh
cargo run -- --store /tmp/invoicegen-store.json seed-sample --force
cargo run -- --store /tmp/invoicegen-store.json summary
cargo run -- --store /tmp/invoicegen-store.json invoice list
cargo run -- --store /tmp/invoicegen-store.json invoice render INV-2026-0001
```

When `--store` is omitted, the CLI honors `INVOICEGEN_APP_STORE`. If that environment variable is also unset, it uses the same default app store convention as the macOS app.

## Common Workflows

Create and inspect sample data:

```sh
cargo run -- --store /tmp/invoicegen-store.json seed-sample --force
cargo run -- --store /tmp/invoicegen-store.json client list
cargo run -- --store /tmp/invoicegen-store.json project list
cargo run -- --store /tmp/invoicegen-store.json payment-detail list
cargo run -- --store /tmp/invoicegen-store.json invoice list
```

Create an invoice flow:

```sh
cargo run -- --store /tmp/invoicegen-store.json client add --name "Ada Lovelace" --email ada@example.com
cargo run -- --store /tmp/invoicegen-store.json project add --name "Launch" --client <client-id> --rate 125.00
cargo run -- --store /tmp/invoicegen-store.json payment-detail add --kind bank-details --label "Primary bank" --detail "Account: 123456789"
cargo run -- --store /tmp/invoicegen-store.json invoice add --number INV-2026-0001 --client <client-id> --project <project-id> --issue-date 2026-01-01 --due-date 2026-01-15 --currency USD --terms "Net 14."
cargo run -- --store /tmp/invoicegen-store.json invoice add-item INV-2026-0001 --title "Design implementation" --quantity 2 --unit-price 100.00 --tax-rate 10
cargo run -- --store /tmp/invoicegen-store.json invoice accept-payment INV-2026-0001 <payment-detail-id>
cargo run -- --store /tmp/invoicegen-store.json invoice render INV-2026-0001
```

Payment and status commands:

```sh
cargo run -- --store /tmp/invoicegen-store.json invoice mark-sent INV-2026-0001
cargo run -- --store /tmp/invoicegen-store.json invoice mark-paid INV-2026-0001
cargo run -- --store /tmp/invoicegen-store.json invoice mark-unpaid INV-2026-0001
cargo run -- --store /tmp/invoicegen-store.json invoice set-status INV-2026-0001 void
```

Invoice commands accept either the invoice UUID or invoice number. Client, project, payment-detail, and line-item commands require UUIDs.

## Store Safety

- Prefer `/tmp/...` stores while testing.
- Do not run `seed-sample --force` against the user's real app store unless explicitly asked.
- Keep backup behavior intact: saving over an existing store creates `store.json.bak`.
- Preserve legacy decoding behavior for stores missing v2 fields such as `paymentAcceptanceDetails` and `acceptedPaymentDetailIDs`.

## Compatibility Notes

- Money parsing and formatting must match `Sources/InvoiceCore/Money.swift`.
- Text invoice rendering must match `Sources/InvoiceCore/InvoiceTextRenderer.swift` closely enough for copied raw invoice text to remain compatible.
- Status refresh behavior must match Swift: paid invoices become `paid`; sent, paid, or overdue invoices can refresh to `sent` or `overdue`; void invoices stay void.
- The Rust crate intentionally has no third-party dependencies. Do not add dependencies unless the user explicitly accepts that tradeoff.

## Verification

Run Rust verification after CLI changes:

```sh
cargo fmt
cargo test
```

Run Swift verification when changes might affect shared behavior or compatibility:

```sh
swift test
```

If `swift test` fails because SwiftPM cannot write cache files outside the workspace sandbox, rerun it with the appropriate sandbox approval instead of treating that as a code failure.

## Publishing

Keep the root `package.json` private for the static website. The publishable npm CLI package lives at `npm/invoicegen` as `@megabyte0x/invoicegen` and exposes the `invoicegen` command. Platform-specific native packages live under `npm/invoicegen-*`.

Run packaging checks after changing npm/Homebrew/release files:

```sh
npm run test:cli-packaging
npm run build:cli-release
ALLOW_MISSING_CLI_BINARIES=1 npm run stage:npm-cli
```

Use strict `npm run stage:npm-cli` only when all platform binaries exist in `dist/cli/<rust-target>/bin/`; it should fail if a publishable native package would be missing its binary.

The release workflow expects these secrets when publishing is desired:

- `NPM_TOKEN` for npm package publishing
- `HOMEBREW_TAP_TOKEN` for pushing `Formula/invoicegen.rb` to `megabyte0x/homebrew-tap`
