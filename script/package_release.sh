#!/usr/bin/env bash
set -euo pipefail

APP_NAME="InvoiceGen"
BUNDLE_ID="com.megabyte0x.InvoiceGen"
MIN_SYSTEM_VERSION="14.0"
BUILD_NUMBER="${INVOICEGEN_BUILD_NUMBER:-1}"
CODESIGN_IDENTITY="${CODESIGN_IDENTITY:--}"
NOTARY_PROFILE="${INVOICEGEN_NOTARY_PROFILE:-}"
NOTARY_KEYCHAIN="${INVOICEGEN_NOTARY_KEYCHAIN:-}"
NOTARY_TIMEOUT="${INVOICEGEN_NOTARY_TIMEOUT:-30m}"
DMG_WINDOW_WIDTH=760
DMG_WINDOW_HEIGHT=440

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION="${INVOICEGEN_VERSION:-$(sed -n 's/^version = "\(.*\)"/\1/p' "$ROOT_DIR/Cargo.toml" | head -n 1)}"
RELEASE_DIR="$ROOT_DIR/dist/release"
APP_BUNDLE="$RELEASE_DIR/$APP_NAME.app"
APP_CONTENTS="$APP_BUNDLE/Contents"
APP_MACOS="$APP_CONTENTS/MacOS"
APP_RESOURCES="$APP_CONTENTS/Resources"
APP_BINARY="$APP_MACOS/$APP_NAME"
INFO_PLIST="$APP_CONTENTS/Info.plist"
APP_ICON_NAME="InvoiceGenAppIcon"
APP_ICON_SOURCE="$ROOT_DIR/Sources/InvoiceGenApp/Resources/invoicegen-logo.png"
DMG_PATH="$RELEASE_DIR/$APP_NAME-$VERSION.dmg"
DMG_VOLUME_NAME="$APP_NAME"
DMG_RW_PATH="$RELEASE_DIR/$APP_NAME-$VERSION-rw.dmg"
DMG_MOUNT_DIR="$RELEASE_DIR/$APP_NAME-$VERSION-mount"
DMG_STAGING_DIR="$RELEASE_DIR/$APP_NAME-$VERSION-dmg-root"
DMG_BACKGROUND_DIR="$DMG_STAGING_DIR/.background"
DMG_BACKGROUND_NAME="background.png"
DMG_BACKGROUND_PATH="$DMG_BACKGROUND_DIR/$DMG_BACKGROUND_NAME"
DMG_BACKGROUND_SWIFT="$RELEASE_DIR/render-dmg-background.swift"
NOTARY_SUBMISSION_JSON="$RELEASE_DIR/$APP_NAME-$VERSION-notary-submission.json"
NOTARY_RESULT_JSON="$RELEASE_DIR/$APP_NAME-$VERSION-notary-result.json"

cleanup() {
  hdiutil detach "$DMG_MOUNT_DIR" -force >/dev/null 2>&1 || true
  rm -rf "$DMG_STAGING_DIR" "$DMG_MOUNT_DIR"
  rm -f "$DMG_RW_PATH" "$DMG_BACKGROUND_SWIFT"
}

trap cleanup EXIT

install_app_icon() {
  if [[ ! -f "$APP_ICON_SOURCE" ]]; then
    echo "missing app icon source: $APP_ICON_SOURCE" >&2
    exit 1
  fi

  local iconset_dir="$APP_RESOURCES/$APP_ICON_NAME.iconset"
  rm -rf "$iconset_dir"
  mkdir -p "$iconset_dir"

  sips -z 16 16 "$APP_ICON_SOURCE" --out "$iconset_dir/icon_16x16.png" >/dev/null
  sips -z 32 32 "$APP_ICON_SOURCE" --out "$iconset_dir/icon_16x16@2x.png" >/dev/null
  sips -z 32 32 "$APP_ICON_SOURCE" --out "$iconset_dir/icon_32x32.png" >/dev/null
  sips -z 64 64 "$APP_ICON_SOURCE" --out "$iconset_dir/icon_32x32@2x.png" >/dev/null
  sips -z 128 128 "$APP_ICON_SOURCE" --out "$iconset_dir/icon_128x128.png" >/dev/null
  sips -z 256 256 "$APP_ICON_SOURCE" --out "$iconset_dir/icon_128x128@2x.png" >/dev/null
  sips -z 256 256 "$APP_ICON_SOURCE" --out "$iconset_dir/icon_256x256.png" >/dev/null
  sips -z 512 512 "$APP_ICON_SOURCE" --out "$iconset_dir/icon_256x256@2x.png" >/dev/null
  sips -z 512 512 "$APP_ICON_SOURCE" --out "$iconset_dir/icon_512x512.png" >/dev/null
  sips -z 1024 1024 "$APP_ICON_SOURCE" --out "$iconset_dir/icon_512x512@2x.png" >/dev/null

  iconutil -c icns "$iconset_dir" -o "$APP_RESOURCES/$APP_ICON_NAME.icns"
  rm -rf "$iconset_dir"
  cp "$APP_ICON_SOURCE" "$APP_RESOURCES/invoicegen-logo.png"
}

create_dmg_background() {
  mkdir -p "$DMG_BACKGROUND_DIR"
  cat >"$DMG_BACKGROUND_SWIFT" <<'SWIFT'
import AppKit

let outputPath = CommandLine.arguments[1]
let appName = CommandLine.arguments[2]
let width = Double(CommandLine.arguments[3]) ?? 760
let height = Double(CommandLine.arguments[4]) ?? 440
let size = NSSize(width: width, height: height)
let image = NSImage(size: size)

func drawCentered(_ text: String, y: CGFloat, font: NSFont, color: NSColor) {
    let attributes: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: color
    ]
    let attributed = NSAttributedString(string: text, attributes: attributes)
    let textSize = attributed.size()
    let rect = NSRect(
        x: (size.width - textSize.width) / 2,
        y: y,
        width: textSize.width,
        height: textSize.height
    )
    attributed.draw(in: rect)
}

func roundedRect(_ rect: NSRect, radius: CGFloat, fill: NSColor, stroke: NSColor) {
    let path = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
    fill.setFill()
    path.fill()
    stroke.setStroke()
    path.lineWidth = 1
    path.stroke()
}

image.lockFocus()
NSColor(calibratedWhite: 0.985, alpha: 1).setFill()
NSBezierPath(rect: NSRect(origin: .zero, size: size)).fill()

NSColor(calibratedWhite: 0.90, alpha: 0.7).setFill()
for x in stride(from: 10.0, through: width - 10.0, by: 16.0) {
    for y in stride(from: 10.0, through: height - 10.0, by: 16.0) {
        NSBezierPath(ovalIn: NSRect(x: x, y: y, width: 1.2, height: 1.2)).fill()
    }
}

drawCentered(
    "Drag and drop \(appName) into Applications",
    y: size.height - 78,
    font: NSFont.systemFont(ofSize: 18, weight: .semibold),
    color: NSColor(calibratedWhite: 0.38, alpha: 1)
)
drawCentered(
    "Then open it from Applications.",
    y: size.height - 103,
    font: NSFont.systemFont(ofSize: 12.5, weight: .regular),
    color: NSColor(calibratedWhite: 0.62, alpha: 1)
)

roundedRect(
    NSRect(x: 438, y: 78, width: 250, height: 166),
    radius: 10,
    fill: NSColor(calibratedWhite: 0.92, alpha: 0.84),
    stroke: NSColor(calibratedWhite: 0.82, alpha: 1)
)

let arrow = NSBezierPath()
arrow.move(to: NSPoint(x: 330, y: 205))
arrow.line(to: NSPoint(x: 410, y: 205))
NSColor.white.withAlphaComponent(0.88).setStroke()
arrow.lineWidth = 17
arrow.lineCapStyle = .round
arrow.stroke()

let arrowHead = NSBezierPath()
arrowHead.move(to: NSPoint(x: 405, y: 238))
arrowHead.line(to: NSPoint(x: 454, y: 205))
arrowHead.line(to: NSPoint(x: 405, y: 172))
arrowHead.close()
NSColor.white.withAlphaComponent(0.88).setFill()
arrowHead.fill()

image.unlockFocus()

guard
    let tiffData = image.tiffRepresentation,
    let bitmap = NSBitmapImageRep(data: tiffData),
    let pngData = bitmap.representation(using: .png, properties: [:])
else {
    fatalError("Could not render DMG background")
}

try pngData.write(to: URL(fileURLWithPath: outputPath))
SWIFT

  swift "$DMG_BACKGROUND_SWIFT" "$DMG_BACKGROUND_PATH" "$APP_NAME" "$DMG_WINDOW_WIDTH" "$DMG_WINDOW_HEIGHT"
}

configure_dmg_finder_layout() {
  osascript <<APPLESCRIPT
tell application "Finder"
  set dmgFolder to POSIX file "$DMG_MOUNT_DIR" as alias
  open dmgFolder
  set dmgWindow to container window of dmgFolder
  set current view of dmgWindow to icon view
  set toolbar visible of dmgWindow to false
  set statusbar visible of dmgWindow to false
  set bounds of dmgWindow to {100, 100, $((100 + DMG_WINDOW_WIDTH)), $((100 + DMG_WINDOW_HEIGHT))}
  set viewOptions to icon view options of dmgWindow
  set arrangement of viewOptions to not arranged
  set icon size of viewOptions to 96
  set background picture of viewOptions to file "$DMG_BACKGROUND_NAME" of folder ".background" of dmgFolder
  set position of item "$APP_NAME.app" of dmgFolder to {190, 250}
  set position of item "Applications" of dmgFolder to {565, 250}
  update dmgFolder without registering applications
  delay 1
  close dmgWindow
end tell
APPLESCRIPT
}

create_dmg() {
  create_dmg_background
  hdiutil create \
    -volname "$DMG_VOLUME_NAME" \
    -srcfolder "$DMG_STAGING_DIR" \
    -ov \
    -format UDRW \
    "$DMG_RW_PATH"

  mkdir -p "$DMG_MOUNT_DIR"
  hdiutil attach "$DMG_RW_PATH" \
    -readwrite \
    -noverify \
    -nobrowse \
    -mountpoint "$DMG_MOUNT_DIR"
  configure_dmg_finder_layout
  sync
  rm -rf "$DMG_MOUNT_DIR/.fseventsd"
  sync
  hdiutil detach "$DMG_MOUNT_DIR"
  hdiutil convert "$DMG_RW_PATH" \
    -format UDZO \
    -imagekey zlib-level=9 \
    -o "$DMG_PATH"
  hdiutil verify "$DMG_PATH"
}

swift build -c release --product "$APP_NAME"
BUILD_PRODUCTS_DIR="$(swift build -c release --show-bin-path)"
BUILD_BINARY="$BUILD_PRODUCTS_DIR/$APP_NAME"

rm -rf "$APP_BUNDLE"
rm -rf "$DMG_STAGING_DIR"
rm -rf "$DMG_MOUNT_DIR"
rm -f "$DMG_PATH" "$DMG_RW_PATH"
mkdir -p "$APP_MACOS" "$APP_RESOURCES"
cp "$BUILD_BINARY" "$APP_BINARY"
chmod +x "$APP_BINARY"

cat >"$INFO_PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>$APP_NAME</string>
  <key>CFBundleIdentifier</key>
  <string>$BUNDLE_ID</string>
  <key>CFBundleName</key>
  <string>$APP_NAME</string>
  <key>CFBundleDisplayName</key>
  <string>$APP_NAME</string>
  <key>CFBundleIconFile</key>
  <string>$APP_ICON_NAME</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>$VERSION</string>
  <key>CFBundleVersion</key>
  <string>$BUILD_NUMBER</string>
  <key>LSApplicationCategoryType</key>
  <string>public.app-category.business</string>
  <key>LSMinimumSystemVersion</key>
  <string>$MIN_SYSTEM_VERSION</string>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
  <key>NSAppleEventsUsageDescription</key>
  <string>InvoiceGen needs permission to open a Mail draft with your invoice PDF attached.</string>
</dict>
</plist>
PLIST

install_app_icon
if [[ "$CODESIGN_IDENTITY" == "-" ]]; then
  codesign --force --deep --sign "$CODESIGN_IDENTITY" "$APP_BUNDLE"
else
  codesign --force --deep --options runtime --timestamp --sign "$CODESIGN_IDENTITY" "$APP_BUNDLE"
fi

codesign --verify --deep --strict --verbose=2 "$APP_BUNDLE"
mkdir -p "$DMG_STAGING_DIR"
ditto "$APP_BUNDLE" "$DMG_STAGING_DIR/$APP_NAME.app"
ln -s /Applications "$DMG_STAGING_DIR/Applications"
create_dmg

if [[ "$CODESIGN_IDENTITY" != "-" ]]; then
  codesign --force --sign "$CODESIGN_IDENTITY" --timestamp "$DMG_PATH"
  codesign --verify --verbose=2 "$DMG_PATH"
fi

if [[ -n "$NOTARY_PROFILE" ]]; then
  if [[ "$CODESIGN_IDENTITY" == "-" ]]; then
    echo "INVOICEGEN_NOTARY_PROFILE requires a Developer ID CODESIGN_IDENTITY." >&2
    exit 1
  fi

  NOTARY_AUTH_ARGS=(--keychain-profile "$NOTARY_PROFILE")
  if [[ -n "$NOTARY_KEYCHAIN" ]]; then
    NOTARY_AUTH_ARGS+=(--keychain "$NOTARY_KEYCHAIN")
  fi

  echo "Submitting $DMG_PATH for notarization with keychain profile $NOTARY_PROFILE"
  xcrun notarytool submit "$DMG_PATH" \
    "${NOTARY_AUTH_ARGS[@]}" \
    --no-s3-acceleration \
    --output-format json >"$NOTARY_SUBMISSION_JSON"

  SUBMISSION_ID="$(plutil -extract id raw -o - "$NOTARY_SUBMISSION_JSON")"
  echo "Notary submission ID: $SUBMISSION_ID"

  if ! xcrun notarytool wait "$SUBMISSION_ID" \
    "${NOTARY_AUTH_ARGS[@]}" \
    --timeout "$NOTARY_TIMEOUT" \
    --output-format json >"$NOTARY_RESULT_JSON"; then
    echo "Notarization did not complete within $NOTARY_TIMEOUT." >&2
    echo "Poll status with:" >&2
    if [[ -n "$NOTARY_KEYCHAIN" ]]; then
      echo "xcrun notarytool info $SUBMISSION_ID --keychain-profile $NOTARY_PROFILE --keychain $NOTARY_KEYCHAIN" >&2
    else
      echo "xcrun notarytool info $SUBMISSION_ID --keychain-profile $NOTARY_PROFILE" >&2
    fi
    exit 1
  fi

  NOTARY_STATUS="$(plutil -extract status raw -o - "$NOTARY_RESULT_JSON")"
  if [[ "$NOTARY_STATUS" != "Accepted" ]]; then
    echo "Notarization finished with status: $NOTARY_STATUS" >&2
    echo "Fetch the log with:" >&2
    if [[ -n "$NOTARY_KEYCHAIN" ]]; then
      echo "xcrun notarytool log $SUBMISSION_ID --keychain-profile $NOTARY_PROFILE --keychain $NOTARY_KEYCHAIN" >&2
    else
      echo "xcrun notarytool log $SUBMISSION_ID --keychain-profile $NOTARY_PROFILE" >&2
    fi
    exit 1
  fi

  xcrun stapler staple "$DMG_PATH"
  xcrun stapler validate "$DMG_PATH"
fi

echo "Packaged $APP_BUNDLE"
echo "Created $DMG_PATH with a drag-to-Applications Finder layout"
