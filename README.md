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
`dist/release/InvoiceGen-0.1.0.zip`.

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
git tag v0.1.0
git push origin v0.1.0
```

The release workflow runs `script/package_release.sh` on macOS and uploads
`dist/release/InvoiceGen-<version>.zip` to the matching GitHub Release.
