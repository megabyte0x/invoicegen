# @megabyte0x/invoicegen

Local-first invoice management CLI for InvoiceGen.

The package installs the `invoicegen` command and selects the matching native
binary package for your operating system and CPU. Invoice data stays on your
machine in the same local `store.json` format used by the InvoiceGen macOS app.

## Install

```sh
npm install -g @megabyte0x/invoicegen
```

## Usage

```sh
invoicegen --help
invoicegen invoice --help
invoicegen --store ./invoicegen-store.json seed-sample --force
invoicegen --store ./invoicegen-store.json invoice list --format json
invoicegen --store ./invoicegen-store.json invoice render INV-2026-0001
invoicegen --store ./invoicegen-store.json invoice render INV-2026-0001 --output ./exports
invoicegen --store ./invoicegen-store.json store export ./invoicegen-backup.json
invoicegen --store ./invoicegen-store.json store restore ./invoicegen-backup.json --force
```

When `--output` points to a directory, the CLI writes a PDF named from the
invoice number, such as `INV-2026-0001.pdf`.

If `--store` is not provided, the CLI uses the app store path. Set
`INVOICEGEN_APP_STORE` to point the CLI and macOS app at a custom store file.

```sh
INVOICEGEN_APP_STORE=~/invoices/store.json invoicegen invoice list
```

The CLI validates invoice data before replacing the local store and refuses
destructive restore operations unless `--force` is passed.

## Supported Platforms

- macOS arm64
- macOS x64
- Linux arm64
- Linux x64

Windows packages are not published yet. Unsupported platforms can build from
source with Cargo from the repository.

## Source

Repository: https://github.com/megabyte0x/invoicegen
