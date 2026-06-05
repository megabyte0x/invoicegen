# InvoiceGen

InvoiceGen is a local-first invoice generation app for freelancers and small
teams. It ships as a native macOS SwiftUI app and a Rust CLI that can inspect,
create, render, export, and restore invoice data from the same local store.

All data is stored locally. There is no server, sync service, telemetry service, or
remote database.

## Website Resources

- Product page: <https://invoicegen.megabyte.sh/>
- Rust invoice CLI guide: <https://invoicegen.megabyte.sh/cli>
- Privacy-first invoice generation: <https://invoicegen.megabyte.sh/privacy>
- Local-first invoicing guide: <https://invoicegen.megabyte.sh/docs/local-first-invoicing>
- Backup and restore guide: <https://invoicegen.megabyte.sh/docs/backup-restore>
- Open-source invoice generator for macOS: <https://invoicegen.megabyte.sh/open-source-invoice-generator>
- Manta alternative for local-first macOS invoicing: <https://invoicegen.megabyte.sh/alternatives/manta>
- Invoice Ninja alternative for local-first macOS invoicing: <https://invoicegen.megabyte.sh/alternatives/invoice-ninja>
- Offline invoice generator for Mac: <https://invoicegen.megabyte.sh/offline-invoice-generator-mac>
- Launch kit for product directories: <https://invoicegen.megabyte.sh/launch-kit>
- Changelog: <https://invoicegen.megabyte.sh/changelog>

## Data Location

The macOS app uses:
- `~/Library/Application Support/InvoiceGen/store.json`
- set `INVOICEGEN_APP_STORE` only if you want to force a specific app store file

The store is a versioned JSON document written atomically by `InvoiceCore`.

## Build

```sh
swift build
```

## Rust CLI

This repo also includes a Rust CLI that ships as a single native binary and
reads and writes the same local `store.json` format as the macOS app.

```sh
cargo run -- --help
cargo run -- invoice --help
cargo run -- --store /tmp/invoicegen-store.json seed-sample --force
cargo run -- --store /tmp/invoicegen-store.json invoice list --status overdue --format json
cargo run -- --store /tmp/invoicegen-store.json invoice render INV-2026-0001
cargo run -- --store /tmp/invoicegen-store.json invoice render INV-2026-0001 --output ./exports
cargo run -- --store /tmp/invoicegen-store.json store export /tmp/invoicegen-backup.json
cargo run -- --store /tmp/invoicegen-store.json store restore /tmp/invoicegen-backup.json --force
cargo run -- completion zsh
```

When `--output` points to a directory, the CLI writes a PDF named from the
invoice number, such as `INV-2026-0001.pdf`.

Common workflows are available as subcommands for `profile`, `client`,
`project`, `payment-detail`, and `invoice`. The CLI honors the same
`INVOICEGEN_APP_STORE` override as the app when `--store` is not provided.

List, show, summary, and config commands support `--format text|tsv|csv|json`.
List commands also support common filters such as `--query`, `--status`,
`--client`, `--sort`, and `--reverse` where they apply. Destructive delete
commands and store restores require `--force`.

The app and CLI validate invoice data before replacing the local store. Invalid
invoice numbers, duplicate invoice numbers, due dates before issue dates,
invalid currency codes, non-positive quantities, negative prices, invalid tax
rates, and overpayments are rejected before disk writes.

CLI defaults can be stored separately from invoice data:

```sh
invoicegen-rs --config ~/.config/invoicegen/config.json config set --store ~/invoices/store.json --default-output json
invoicegen-rs --config ~/.config/invoicegen/config.json client list
invoicegen-rs config show --format json
```

### Install the CLI

From source:

```sh
cargo install --path .
invoicegen-rs --help
```

Users can install the npm wrapper package. The npm package exposes the shorter
`invoicegen` command and downloads the matching native binary package for the
user's OS and CPU:

```sh
npm install -g @megabyte0x/invoicegen
invoicegen --help
```

After the Homebrew tap is published:

```sh
brew tap megabyte0x/tap
brew install invoicegen
invoicegen --help
```

### Publish the CLI

The npm package metadata lives in `npm/`. The root package remains private
because it is used for the static site. The publishable CLI package is
`@megabyte0x/invoicegen`, with platform packages such as
`@megabyte0x/invoicegen-darwin-arm64` and
`@megabyte0x/invoicegen-linux-x64`. Windows publishing is intentionally paused
for now. The public npm package README lives in `npm/invoicegen/README.md` and
is included in the package tarball.

Publishing prerequisites:

- create or confirm access to the npm scope `@megabyte0x`
- configure npm trusted publishers for the npm packages with workflow filename
  `publish.yml` (filename only, not `.github/workflows/publish.yml`)
- create the Homebrew tap repository, expected by default at
  `megabyte0x/homebrew-tap`
- create `HOMEBREW_TAP_TOKEN` as a GitHub Actions secret with push access to
  that tap

Local packaging checks:

```sh
npm run test:cli-packaging
npm run build:cli-release
ALLOW_MISSING_CLI_BINARIES=1 npm run stage:npm-cli
```

Tagged releases run `.github/workflows/publish.yml`, which builds native CLI
archives, uploads GitHub Release assets, stages npm packages, publishes npm
packages through npm trusted publishing with provenance, and optionally updates
the Homebrew tap when `HOMEBREW_TAP_TOKEN` exists.

## Run the macOS App

```sh
./script/build_and_run.sh
```

The Codex app Run action is wired to the same script.

## Package a Release Build

```sh
./script/package_release.sh
```

The package script builds the native macOS app in release mode, stages
`dist/release/InvoiceGen.app`, signs it, verifies the app bundle, and creates
`dist/release/InvoiceGen-<version>.dmg`.

By default the script uses ad-hoc signing for local validation. For a
distributable build, provide a Developer ID identity:

```sh
CODESIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" ./script/package_release.sh
```

With a Developer ID identity, the script also signs and verifies the generated
DMG. To notarize and staple the DMG, first store Apple notarization credentials
in your Keychain:

```sh
xcrun notarytool store-credentials invoicegen-notary --apple-id "you@example.com" --team-id "TEAMID"
```

Then pass the stored profile name:

```sh
CODESIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" \
INVOICEGEN_NOTARY_PROFILE="invoicegen-notary" \
./script/package_release.sh
```

If Apple keeps a submission in `In Progress`, the script exits after the
bounded notarization wait and prints the submission ID. Poll that ID instead of
re-uploading the same artifact repeatedly:

```sh
xcrun notarytool info <submission-id> --keychain-profile invoicegen-notary
```

## Website

The static website lives in `site/` and is built without dependencies:

```sh
npm run build:site
```

The build output is written to `dist/site`. Vercel is configured to run that
command and deploy only the generated static site output.

## GitHub Releases

Version tags publish a GitHub Release automatically:

```sh
git tag v<version>
git push origin v<version>
```

The release workflow runs `script/package_release.sh` on macOS and uploads
`dist/release/InvoiceGen-<version>.dmg` to the matching GitHub Release. It
requires these GitHub Actions secrets so the uploaded DMG passes Gatekeeper:

- `MACOS_CERTIFICATE_P12`: base64-encoded Developer ID Application `.p12`
  certificate
- `MACOS_CERTIFICATE_PASSWORD`: password for that `.p12`
- `APP_STORE_CONNECT_API_ISSUER_ID`: issuer ID for a Team API key
- `APP_STORE_CONNECT_API_KEY_ID`: key ID for that API key
- `APP_STORE_CONNECT_API_PRIVATE_KEY`: private `.p8` key for that API key

After those secrets are present, either push a new `v<version>` tag or run the
GitHub Release workflow manually with a version like `0.1.7` to replace that
release's DMG.
