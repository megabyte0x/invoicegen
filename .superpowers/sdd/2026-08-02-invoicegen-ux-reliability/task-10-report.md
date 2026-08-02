# Task 10 Report: Installed-App UX Acceptance

## Status

BLOCKED — frozen candidate `0.1.9 (2)` exposed a keyboard-navigation regression during Step 4. A source-only repair has been committed and requires a fresh build before the installed-app acceptance journey can resume.

## Confirmed Failure

In the frozen candidate, after creating a second line item, pressing Tab from its `Item Details` multiline editor selected `Delete Item`. This interrupted the required entry sequence:

`Title → Qty → Unit Price → Tax → Item Details → Notes → Terms`

The multiline editor correctly calls `selectNextKeyView(nil)`. The destructive `Delete Item` button immediately followed `LineItemEditor` in the native key-view chain, so it became the next selected control.

## Repair

- `Sources/InvoiceGenApp/Views/InvoiceEditorView.swift`
  - Added `.focusable(false)` to the `Delete Item` button only.
  - Preserved its visible destructive action, destructive role, label, styling, and pointer activation.
  - No fields were reordered and no other production behavior was changed.

This removes the destructive button from keyboard-focus traversal, allowing Tab from `Item Details` to continue to `Notes` and then `Terms`.

## Verification Performed

- Source-inspected `RuneyMultilineEditor`: Tab invokes `NSApp.keyWindow?.selectNextKeyView(nil)`.
- Source-inspected the invoice editor: the only changed control sits between `LineItemEditor` and the notes/terms card and is now marked non-focusable.
- Ran `git diff --check` after the edit; no whitespace errors.

## Not Run

Per the repair scope, no tests, builds, package scripts, app launch, or app interaction were run. The frozen candidate was not modified.

## Remaining Gate

Build a new candidate and restart Task 10 acceptance at Step 1. Specifically re-verify the complete Tab sequence, including multiline Tab exit and pointer activation of `Delete Item`, before marking Task 10 complete.
