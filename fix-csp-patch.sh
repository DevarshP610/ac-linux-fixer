#!/usr/bin/env bash
set -Eeuo pipefail

readonly SCRIPT_NAME="$(basename "$0")"
log() { printf '[%s] %s\n' "$SCRIPT_NAME" "$*"; }
die() { printf '[%s] ERROR: %s\n' "$SCRIPT_NAME" "$*" >&2; exit 1; }

ac_dir="${1:-}"
if [[ -z "$ac_dir" ]]; then
    for ac_dir in \
        "$HOME/.steam/debian-installation/steamapps/common/assettocorsa" \
        "$HOME/.local/share/Steam/steamapps/common/assettocorsa" \
        "$HOME/.steam/steam/steamapps/common/assettocorsa"; do
        [[ -d "$ac_dir" ]] && break
    done
fi
[[ -d "$ac_dir" ]] || die "Usage: $SCRIPT_NAME /path/to/assettocorsa"

mapping="$ac_dir/extension/config/data_alt_mapping.ini"
if [[ -f "$mapping" ]] && grep -q '^\[NAMES_WINE\]' "$mapping"; then
    sed -i '/^\[NAMES_WINE\]/,$d' "$mapping"
    log "Removed [NAMES_WINE] and trailing entries"
else
    log "No [NAMES_WINE] section found"
fi
rm -f "$ac_dir/acs.pdb.acd"
if [[ -f "$ac_dir/extension/config/general.ini" ]]; then
    sed -i -E 's/^([[:space:]]*CACHE_CSP_CONFIGS[[:space:]]*=[[:space:]]*)1/\10/I' \
        "$ac_dir/extension/config/general.ini" || true
fi
log "CSP symbol cache repaired. Restart Content Manager before patching again."
