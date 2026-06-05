#!/usr/bin/env bash
set -euo pipefail

APP_NAME="InvoiceGen"
BUNDLE_ID="com.megabyte0x.InvoiceGen"
MIN_SYSTEM_VERSION="14.0"
BUILD_NUMBER="${INVOICEGEN_BUILD_NUMBER:-1}"
CODESIGN_IDENTITY="${CODESIGN_IDENTITY:--}"
NOTARY_PROFILE="${INVOICEGEN_NOTARY_PROFILE:-}"
NOTARY_TIMEOUT="${INVOICEGEN_NOTARY_TIMEOUT:-30m}"

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
NOTARY_SUBMISSION_JSON="$RELEASE_DIR/$APP_NAME-$VERSION-notary-submission.json"
NOTARY_RESULT_JSON="$RELEASE_DIR/$APP_NAME-$VERSION-notary-result.json"

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
}

swift build -c release --product "$APP_NAME"
BUILD_BINARY="$(swift build -c release --show-bin-path)/$APP_NAME"

rm -rf "$APP_BUNDLE"
rm -f "$DMG_PATH"
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
hdiutil create \
  -volname "$APP_NAME $VERSION" \
  -srcfolder "$APP_BUNDLE" \
  -ov \
  -format UDZO \
  "$DMG_PATH"
hdiutil verify "$DMG_PATH"

if [[ "$CODESIGN_IDENTITY" != "-" ]]; then
  codesign --force --sign "$CODESIGN_IDENTITY" --timestamp "$DMG_PATH"
  codesign --verify --verbose=2 "$DMG_PATH"
fi

if [[ -n "$NOTARY_PROFILE" ]]; then
  if [[ "$CODESIGN_IDENTITY" == "-" ]]; then
    echo "INVOICEGEN_NOTARY_PROFILE requires a Developer ID CODESIGN_IDENTITY." >&2
    exit 1
  fi

  echo "Submitting $DMG_PATH for notarization with keychain profile $NOTARY_PROFILE"
  xcrun notarytool submit "$DMG_PATH" \
    --keychain-profile "$NOTARY_PROFILE" \
    --no-s3-acceleration \
    --output-format json >"$NOTARY_SUBMISSION_JSON"

  SUBMISSION_ID="$(plutil -extract id raw -o - "$NOTARY_SUBMISSION_JSON")"
  echo "Notary submission ID: $SUBMISSION_ID"

  if ! xcrun notarytool wait "$SUBMISSION_ID" \
    --keychain-profile "$NOTARY_PROFILE" \
    --timeout "$NOTARY_TIMEOUT" \
    --output-format json >"$NOTARY_RESULT_JSON"; then
    echo "Notarization did not complete within $NOTARY_TIMEOUT." >&2
    echo "Poll status with:" >&2
    echo "xcrun notarytool info $SUBMISSION_ID --keychain-profile $NOTARY_PROFILE" >&2
    exit 1
  fi

  NOTARY_STATUS="$(plutil -extract status raw -o - "$NOTARY_RESULT_JSON")"
  if [[ "$NOTARY_STATUS" != "Accepted" ]]; then
    echo "Notarization finished with status: $NOTARY_STATUS" >&2
    echo "Fetch the log with:" >&2
    echo "xcrun notarytool log $SUBMISSION_ID --keychain-profile $NOTARY_PROFILE" >&2
    exit 1
  fi

  xcrun stapler staple "$DMG_PATH"
  xcrun stapler validate "$DMG_PATH"
fi

echo "Packaged $APP_BUNDLE"
echo "Created $DMG_PATH"
