#!/usr/bin/env bash
set -euo pipefail

APP_NAME="GlobeSwitch"
ARCHITECTURE="arm64"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RELEASE_DIR="$ROOT_DIR/release"
APP_BUNDLE="$RELEASE_DIR/$APP_NAME.app"
APP_CONTENTS="$APP_BUNDLE/Contents"
APP_MACOS="$APP_CONTENTS/MacOS"
APP_RESOURCES="$APP_CONTENTS/Resources"
APP_BINARY="$APP_MACOS/$APP_NAME"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$ROOT_DIR/Resources/Info.plist")"
DMG_NAME="$APP_NAME-$VERSION-$ARCHITECTURE.dmg"
DMG_PATH="$RELEASE_DIR/$DMG_NAME"
CHECKSUM_PATH="$RELEASE_DIR/SHA256SUMS.txt"
TEMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/GlobeSwitchRelease.XXXXXX")"
DMG_SOURCE="$TEMP_ROOT/dmg"

cleanup() {
  rm -rf "$TEMP_ROOT"
}
trap cleanup EXIT

if [[ "$RELEASE_DIR" != "$ROOT_DIR/release" ]]; then
  echo "Unexpected release directory: $RELEASE_DIR" >&2
  exit 1
fi

cd "$ROOT_DIR"
swift build -c release --arch "$ARCHITECTURE"
BUILD_BINARY="$(swift build -c release --arch "$ARCHITECTURE" --show-bin-path)/$APP_NAME"

rm -rf "$APP_BUNDLE"
rm -f "$DMG_PATH" "$CHECKSUM_PATH"
mkdir -p "$APP_MACOS" "$APP_RESOURCES" "$DMG_SOURCE"

cp "$BUILD_BINARY" "$APP_BINARY"
cp "$ROOT_DIR/Resources/Info.plist" "$APP_CONTENTS/Info.plist"
cp "$ROOT_DIR/Resources/AppIcon.icns" "$APP_RESOURCES/AppIcon.icns"
chmod +x "$APP_BINARY"
xattr -cr "$APP_BUNDLE"

codesign \
  --force \
  --deep \
  --sign - \
  --options runtime \
  --timestamp=none \
  "$APP_BUNDLE"

plutil -lint "$APP_CONTENTS/Info.plist"
codesign --verify --deep --strict --verbose=2 "$APP_BUNDLE"
file "$APP_BINARY" | grep -q "arm64"

BUNDLE_IDENTIFIER="$(codesign -d --verbose=4 "$APP_BUNDLE" 2>&1 | sed -n 's/^Identifier=//p')"
if [[ "$BUNDLE_IDENTIFIER" != "com.alexd.sound.GlobeSwitch" ]]; then
  echo "Unexpected bundle identifier: $BUNDLE_IDENTIFIER" >&2
  exit 1
fi

ENTITLEMENTS_OUTPUT="$(codesign -d --entitlements - "$APP_BUNDLE" 2>&1 || true)"
if grep -q "com.apple.security.get-task-allow" <<<"$ENTITLEMENTS_OUTPUT"; then
  echo "Release build unexpectedly contains get-task-allow." >&2
  exit 1
fi

cp -R "$APP_BUNDLE" "$DMG_SOURCE/$APP_NAME.app"
ln -s /Applications "$DMG_SOURCE/Applications"
cp "$ROOT_DIR/Resources/INSTALL_UK.txt" "$DMG_SOURCE/INSTALL_UK.txt"

hdiutil create \
  -volname "$APP_NAME $VERSION" \
  -srcfolder "$DMG_SOURCE" \
  -format UDZO \
  -ov \
  "$DMG_PATH"

hdiutil verify "$DMG_PATH"

(
  cd "$RELEASE_DIR"
  shasum -a 256 "$DMG_NAME" "$APP_NAME.app/Contents/MacOS/$APP_NAME" > "$CHECKSUM_PATH"
)

echo "Release ready:"
echo "  $APP_BUNDLE"
echo "  $DMG_PATH"
echo "  $CHECKSUM_PATH"
