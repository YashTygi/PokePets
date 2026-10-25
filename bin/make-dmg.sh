#!/bin/sh
# Builds the Release app and packs it into docs/downloads/PokePets.dmg, with its SHA-256 next to it.
#
#   bin/make-dmg.sh                          ad-hoc signed: runs on any Mac, but macOS asks once (see README)
#   SIGN="Apple Development: Your Name (TEAMID)" bin/make-dmg.sh      sign with your own identity instead
#   ARCHS=arm64 bin/make-dmg.sh              Apple silicon only (the default is both, so Intel Macs work too)
#
# The build goes to a temporary folder, so it never touches ~/Applications (your own running PokePets).
# docs/install.sh downloads exactly these two files, so commit both together.

set -eu

root="$(cd "$(dirname "$0")/.." && pwd)"
out="${root}/docs/downloads"
tmp="$(mktemp -d -t pokepets-dmg)"
trap 'rm -rf "${tmp}"' EXIT

echo "==> Building PokePets (Release)..."
xcodebuild -project "${root}/PokePets.xcodeproj" -scheme PokePets -configuration Release \
  -destination 'generic/platform=macOS' ARCHS="${ARCHS:-arm64 x86_64}" ONLY_ACTIVE_ARCH=NO \
  CONFIGURATION_BUILD_DIR="${tmp}/build" CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY="${SIGN:--}" DEVELOPMENT_TEAM= \
  -quiet build

app="${tmp}/build/PokePets.app"
codesign --verify --deep --strict "${app}"

echo "==> Packing the disk image..."
mkdir -p "${tmp}/dmg" "${out}"
ditto "${app}" "${tmp}/dmg/PokePets.app"
ln -s /Applications "${tmp}/dmg/Applications"
rm -f "${out}/PokePets.dmg"
hdiutil create -volname PokePets -srcfolder "${tmp}/dmg" -fs HFS+ -format UDZO -ov "${out}/PokePets.dmg" >/dev/null
(cd "${out}" && shasum -a 256 PokePets.dmg > PokePets.dmg.sha256)

version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "${app}/Contents/Info.plist")"
echo "==> PokePets ${version}: $(du -h "${out}/PokePets.dmg" | cut -f1) ($(lipo -archs "${app}/Contents/MacOS/PokePets"))"
cat "${out}/PokePets.dmg.sha256"
