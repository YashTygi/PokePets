#!/bin/sh
# PokéPets installer:
#   curl -fsSL https://raw.githubusercontent.com/YashTygi/PokePets/main/docs/install.sh | sh
#
# Downloads PokePets.dmg, checks its SHA-256 against the published PokePets.dmg.sha256, copies
# PokePets.app into /Applications and opens it. Nothing else is changed: no sudo, no PATH edits,
# no login items. PokéPets' own welcome guide asks for each permission, so you see and approve each one.
#
# About the macOS warning: PokéPets is free, so it isn't notarized by Apple (that costs $99 a year).
# A DMG downloaded in a browser carries a "downloaded from the internet" mark (com.apple.quarantine)
# and macOS stops it once. A file fetched with curl never gets that mark, and this script clears it
# from the installed copy too, so there is nothing to click through. The checksum is what vouches for
# the download instead. The script is short on purpose: read it before you run it.
#
# Testing: POKEPETS_BASE=<url or file://dir> overrides the download location; POKEPETS_DEST=<path>
# installs somewhere other than /Applications and skips quitting and opening the app.

set -eu

main() {
  base="${POKEPETS_BASE:-https://raw.githubusercontent.com/YashTygi/PokePets/main/docs/downloads}"
  dest="${POKEPETS_DEST:-/Applications/PokePets.app}"

  say() { printf '\033[1m==>\033[0m %s\n' "$1"; }
  die() { printf '\033[31mError:\033[0m %s\n' "$1" >&2; reported=1; exit 1; }

  [ "$(uname -s)" = "Darwin" ] || die "PokéPets runs on macOS only."
  major="$(sw_vers -productVersion | cut -d. -f1)"
  [ "${major}" -ge 14 ] || die "PokéPets needs macOS 14 or later (you have $(sw_vers -productVersion))."

  tmp="$(mktemp -d -t pokepets)"
  mnt="${tmp}/mnt"
  reported=""; finished=""
  cleanup() {
    hdiutil detach "${mnt}" -quiet 2>/dev/null || true
    rm -rf "${tmp}"
    if [ -z "${finished}" ] && [ -z "${reported}" ]; then
      printf '\n\033[31mInstall failed.\033[0m PokéPets was not installed. Try again, or download the DMG from https://github.com/YashTygi/PokePets\n' >&2
      exit 1
    fi
  }
  trap cleanup EXIT
  trap 'exit 130' INT TERM

  say "Downloading PokéPets..."
  curl -fL --progress-bar -o "${tmp}/PokePets.dmg" "${base}/PokePets.dmg" || die "Download failed. Check your connection and try again."
  curl -fsSL -o "${tmp}/PokePets.dmg.sha256" "${base}/PokePets.dmg.sha256" || die "Couldn't download the checksum, so the install was stopped."

  say "Checking the download..."
  want="$(awk '{print $1; exit}' "${tmp}/PokePets.dmg.sha256")"
  got="$(shasum -a 256 "${tmp}/PokePets.dmg" | awk '{print $1}')"
  [ -n "${want}" ] && [ "${want}" = "${got}" ] || die "Checksum mismatch. The download may be damaged or tampered with; nothing was installed."

  mkdir -p "${mnt}"
  hdiutil attach -nobrowse -readonly -noautoopen -mountpoint "${mnt}" "${tmp}/PokePets.dmg" -quiet || die "Couldn't open the disk image."
  [ -d "${mnt}/PokePets.app" ] || die "PokePets.app wasn't found in the disk image."

  if [ -z "${POKEPETS_DEST:-}" ]; then
    if pgrep -xq PokePets; then
      say "Quitting the running PokéPets..."
      osascript -e 'tell application id "com.yash.PokePets" to quit' >/dev/null 2>&1 || true
      sleep 2
      pkill -x PokePets 2>/dev/null || true
    fi
    if [ ! -w "$(dirname "${dest}")" ]; then      # a managed Mac may not let you write to /Applications
      dest="${HOME}/Applications/PokePets.app"
      mkdir -p "${HOME}/Applications"
      say "/Applications isn't writable here, so installing to ~/Applications instead."
    fi
  fi

  say "Installing to ${dest}..."
  rm -rf "${dest}"
  ditto "${mnt}/PokePets.app" "${dest}" || die "Copying PokePets.app failed."
  xattr -dr com.apple.quarantine "${dest}" 2>/dev/null || true
  codesign --verify --deep --strict "${dest}" 2>/dev/null || die "The installed app failed its signature check; it was left in ${dest} but not opened."

  finished=1
  [ -z "${POKEPETS_DEST:-}" ] || { say "Installed (test mode, not opened)."; return; }
  say "Opening PokéPets. Follow the welcome guide to finish."
  open "${dest}"
  printf '\n\033[32mInstalled.\033[0m Click the Poké Ball in your menu bar, then click the Egg.\n'
  printf 'To remove it later: curl -fsSL https://raw.githubusercontent.com/YashTygi/PokePets/main/docs/uninstall.sh | sh\n'
}

main "$@"
