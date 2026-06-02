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
