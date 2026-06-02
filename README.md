# InvoiceGen

InvoiceGen is a local-first invoice management app for freelancers and small teams.
It ships as a native macOS SwiftUI app.

All data is stored locally. There is no server, sync service, telemetry service, or
remote database.

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

This repo also includes a dependency-free Rust CLI that reads and writes the
same local `store.json` format as the macOS app.

```sh
cargo run -- --help
cargo run -- --store /tmp/invoicegen-store.json seed-sample --force
cargo run -- --store /tmp/invoicegen-store.json invoice list
cargo run -- --store /tmp/invoicegen-store.json invoice render INV-2026-0001
```

Common workflows are available as subcommands for `profile`, `client`,
`project`, `payment-detail`, and `invoice`. The CLI honors the same
`INVOICEGEN_APP_STORE` override as the app when `--store` is not provided.

### Install the CLI

From source:

```sh
cargo install --path .
invoicegen-rs --help
```

After npm publishing, users can install the wrapper package. The npm package
exposes the shorter `invoicegen` command and downloads the matching native
binary package for the user's OS and CPU:

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
`@megabyte0x/invoicegen-win32-x64`.

Publishing prerequisites:

- create or confirm access to the npm scope `@megabyte0x`
- create `NPM_TOKEN` as a GitHub Actions secret with publish access
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

Tagged releases run `.github/workflows/release-cli.yml`, which builds native
CLI archives, uploads GitHub Release assets, stages npm packages, optionally
publishes npm packages when `NPM_TOKEN` exists, and optionally updates the
Homebrew tap when `HOMEBREW_TAP_TOKEN` exists.

## Run the macOS App

```sh
./script/build_and_run.sh
```

The Codex app Run action is wired to the same script.

## Package a Release Build

```sh
./script/package_release.sh
```

The package script builds `InvoiceGen` in release mode, stages
`dist/release/InvoiceGen.app`, signs it, verifies the app bundle, and creates
`dist/release/InvoiceGen-0.1.1.dmg`.

By default the script uses ad-hoc signing for local validation. For a
distributable build, provide a Developer ID identity:

```sh
CODESIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" ./script/package_release.sh
```

Notarization still requires Apple credentials and a Developer ID signature.

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
git tag v0.1.1
git push origin v0.1.1
```

The release workflow runs `script/package_release.sh` on macOS and uploads
`dist/release/InvoiceGen-<version>.dmg` to the matching GitHub Release.
