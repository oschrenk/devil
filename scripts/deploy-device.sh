#!/usr/bin/env bash
# scripts/deploy-device.sh - build Devil for a connected iPhone and install it.
#
# iOS has no notarization step; that is a Mac distribution concept. A device
# build needs an Apple Development identity and a provisioning profile, and
# -allowProvisioningUpdates fetches the profile from Apple as part of the build.
#
# One-time setup, the only part that needs the Xcode window:
#   1. Open Xcode, Settings > Accounts, add your Apple ID.
#   2. Manage Certificates, +, Apple Development. This puts the certificate and
#      its private key in your login keychain. The private key cannot be
#      re-downloaded, so back the keychain up.
#   3. Set DEVELOPMENT_TEAM in Local.xcconfig to your Team ID.
#   4. Plug the iPhone in and trust this computer on the phone.
# After that this script needs no window again.
#
# Usage: ./scripts/deploy-device.sh [device-udid]
#
# With no argument it uses the only connected device, and refuses to guess when
# there is more than one.

set -euo pipefail

cd "$(dirname "$0")/.."

SCHEME="Devil"
PROJECT="Devil.xcodeproj"
APP_NAME="Devil"
BUILD_DIR="build/device"
ARCHIVE_PATH="$BUILD_DIR/$APP_NAME.xcarchive"
APP_PATH="$ARCHIVE_PATH/Products/Applications/$APP_NAME.app"

step() { printf "\n\033[1;36m> %s\033[0m\n" "$*"; }
fail() { printf "\n\033[1;31mx %s\033[0m\n" "$*" >&2; exit 1; }

# Everything below is checked before the archive rather than after it. An
# archive takes minutes, and every one of these failures is knowable up front.
step "Pre-flight"

command -v xcodegen >/dev/null || fail "xcodegen is not on PATH. Run this inside 'nix develop'."

[ -f Local.xcconfig ] || fail "Local.xcconfig is missing. Copy it from Local.xcconfig.example."

TEAM_ID="$(sed -n 's/^[[:space:]]*DEVELOPMENT_TEAM[[:space:]]*=[[:space:]]*//p' Local.xcconfig | tr -d '[:space:]')"
[ -n "$TEAM_ID" ] || fail "DEVELOPMENT_TEAM is empty in Local.xcconfig. Set it to your Apple Team ID."

if ! security find-identity -v -p codesigning | grep -q "Apple Development"; then
  # A certificate with no valid chain reports zero identities while looking
  # present in Keychain Access, so say which of the two is missing.
  if security find-identity -p codesigning | grep -q "Apple Development"; then
    fail "The Apple Development certificate has no valid chain. The WWDR G3 intermediate is probably missing: fetch https://www.apple.com/certificateauthority/AppleWWDRCAG3.cer and add it to the login keychain."
  fi
  fail "No Apple Development identity in the keychain. Do the one-time Xcode setup at the top of this script."
fi

DEVICE_UDID="${1:-}"
if [ -z "$DEVICE_UDID" ]; then
  command -v jq >/dev/null || fail "jq is not on PATH. Run this inside 'nix develop'."

  # Filter on reality == physical. `devicectl list devices` lists every booted
  # simulator alongside real hardware, and a simulator UDID looks exactly like a
  # device UDID, so an unfiltered list installs to the wrong place or reports a
  # phone that is not plugged in.
  #
  # Not mapfile: macOS ships bash 3.2, where it does not exist, and this script
  # has to run outside the nix shell as well as inside it.
  UDIDS=()
  while IFS= read -r line; do
    [ -n "$line" ] && UDIDS+=("$line")
  done < <(xcrun devicectl list devices --json-output - 2>/dev/null \
    | jq -r '.result.devices[]
             | select(.hardwareProperties.reality == "physical")
             | select(.connectionProperties.tunnelState == "connected")
             | .hardwareProperties.udid' || true)
  case "${#UDIDS[@]}" in
    0) fail "No connected iPhone found. Plug it in, unlock it, and trust this computer." ;;
    1) DEVICE_UDID="${UDIDS[0]}" ;;
    *) fail "More than one iPhone connected. Pass a UDID: $(printf '%s ' "${UDIDS[@]}")" ;;
  esac
fi

step "Regenerating project"
xcodegen generate

# An Xcode can list an iOS SDK and still be unable to build for a device,
# because the platform itself was never downloaded. `-showsdks` and
# `-showdestinations` report the same for both, so probe the real thing: this
# resolves a device destination and exits 64 when the platform is missing.
# Without it the failure arrives minutes into the archive as
# "iOS <version> is not installed", which does not name the cause.
step "Checking the toolchain can build for a device"
xcodebuild -project "$PROJECT" -scheme "$SCHEME" \
  -destination 'generic/platform=iOS' -showBuildSettings >/dev/null 2>&1 \
  || fail "The selected Xcode cannot build for iOS. 'xcode-select -p' says $(xcode-select -p). Install the iOS platform in that Xcode, or select one that has it."

rm -rf "$BUILD_DIR"

step "Archiving for the device (Release, signed)"
xcodebuild \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath "$ARCHIVE_PATH" \
  -allowProvisioningUpdates \
  archive

[ -d "$APP_PATH" ] || fail "No app in the archive at $APP_PATH."

step "Installing on $DEVICE_UDID"
xcrun devicectl device install app --device "$DEVICE_UDID" "$APP_PATH"

printf "\n\033[1;32mv %s installed.\033[0m\n" "$APP_NAME"
