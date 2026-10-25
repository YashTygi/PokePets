#!/bin/sh
# PokéPets uninstaller:
#   curl -fsSL https://raw.githubusercontent.com/YashTygi/PokePets/main/docs/uninstall.sh | sh
#   curl -fsSL https://raw.githubusercontent.com/YashTygi/PokePets/main/docs/uninstall.sh | sh -s -- --purge
#
# Quits PokéPets and moves the app to the Trash (in one "PokePets uninstall" folder), not deleted.
# Your Pokémon are kept, so installing again brings them back. Add --purge to also remove their
# save and settings and reset the macOS permissions PokéPets was given; the settings are backed up
# into the same Trash folder first.
#
# Testing: POKEPETS_HOME=<dir> runs against a fake home folder and skips quitting the app,
# /Applications and the permission reset.

set -eu

main() {
  home="${POKEPETS_HOME:-$HOME}"
  test_mode="${POKEPETS_HOME:+1}"
  id="com.yash.PokePets"
  trash="${home}/.Trash/PokePets uninstall $(date +%Y-%m-%d_%H%M%S)"
  purge=""; [ "${1:-}" = "--purge" ] && purge=1
  removed=0

  say() { printf '\033[1m==>\033[0m %s\n' "$1"; }
  [ "$(uname -s)" = "Darwin" ] || { echo "PokéPets is a macOS app; nothing to do here."; exit 0; }
  mkdir -p "${trash}"

  # Move one path into the Trash folder, keeping a readable name.
  bin() {
    [ -e "$1" ] || return 0
    mv "$1" "${trash}/$(printf '%s' "$1" | sed "s#^${home}#~#; s#/#_#g; s#^_##")" && say "Moved to Trash: $1" && removed=$((removed + 1))
  }

  if [ -z "${test_mode}" ] && pgrep -xq PokePets; then
    say "Quitting PokéPets..."
    osascript -e "tell application id \"${id}\" to quit" >/dev/null 2>&1 || true
    sleep 2
    pkill -x PokePets 2>/dev/null || true
  fi

  bin "${home}/Applications/PokePets.app"
  [ -n "${test_mode}" ] || bin "/Applications/PokePets.app"

  if [ -n "${purge}" ]; then
    plist="${home}/Library/Preferences/${id}.plist"
    [ -n "${test_mode}" ] || defaults delete "${id}" >/dev/null 2>&1 || true
    bin "${plist}"
    bin "${home}/Library/Caches/${id}"
    bin "${home}/Library/HTTPStorages/${id}"
    bin "${home}/Library/Saved Application State/${id}.savedState"
    [ -n "${test_mode}" ] || { tccutil reset All "${id}" >/dev/null 2>&1 && say "Reset PokéPets' privacy permissions (Accessibility, Automation, Notifications)."; }
  fi

  if [ "${removed}" -eq 0 ]; then
    rmdir "${trash}" 2>/dev/null || true
    echo "PokéPets wasn't found on this Mac. Nothing to remove."
  else
    printf '\nPokéPets is uninstalled. Everything removed is in the Trash, in "%s".\n' "$(basename "${trash}")"
    [ -n "${purge}" ] || echo "Your Pokémon were kept. Run again with --purge to remove them too."
  fi
}

main "$@"
