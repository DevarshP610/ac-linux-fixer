#!/usr/bin/env bash
set -Eeuo pipefail

readonly SCRIPT_NAME="$(basename "$0")"
readonly AC_APPID=244210
readonly PROTONTRICKS_APP=com.github.Matoking.protontricks
readonly GE_PROTON_VERSION=GE-Proton9-27
readonly GE_PROTON_URL="https://github.com/GloriousEggroll/proton-ge-custom/releases/download/GE-Proton9-27/GE-Proton9-27.tar.gz"
readonly LAUNCH_OPTIONS='WINEDLLOVERRIDES="dwrite=n,b" LC_ALL=C %command%'

log() { printf '[%s] %s\n' "$SCRIPT_NAME" "$*"; }
warn() { printf '[%s] WARNING: %s\n' "$SCRIPT_NAME" "$*" >&2; }
die() { printf '[%s] ERROR: %s\n' "$SCRIPT_NAME" "$*" >&2; exit 1; }
trap 'die "failed at line $LINENO: $BASH_COMMAND"' ERR

require_command() {
    command -v "$1" >/dev/null 2>&1 || die "Required command not found: $1"
}

detect_steam_dir() {
    local candidate
    for candidate in \
        "${STEAM_DIR:-}" \
        "$HOME/.steam/debian-installation" \
        "$HOME/.local/share/Steam" \
        "$HOME/.steam/steam"; do
        if [[ -n "$candidate" && -d "$candidate" ]]; then
            printf '%s\n' "$candidate"
            return 0
        fi
    done
    return 1
}

detect_ac_dir() {
    local steam_dir="$1" library ac_dir
    while IFS= read -r library; do
        ac_dir="$library/steamapps/common/assettocorsa"
        if [[ -d "$ac_dir" ]]; then
            printf '%s\n' "$ac_dir"
            return 0
        fi
    done < <(detect_library_roots "$steam_dir")
    return 1
}

detect_library_roots() {
    local steam_dir="$1" library_file
    printf '%s\n' "$steam_dir"
    [[ -d "$HOME/.local/share/Steam" ]] && printf '%s\n' "$HOME/.local/share/Steam"
    [[ -d "$HOME/.steam/debian-installation" ]] && printf '%s\n' "$HOME/.steam/debian-installation"
    [[ -d "$HOME/.steam/steam" ]] && printf '%s\n' "$HOME/.steam/steam"
    while IFS= read -r library_file; do
        awk -F'"' '/^[[:space:]]*"path"/ { print $4 }' "$library_file"
    done < <(find /mnt -maxdepth 4 -type f -path '*/steamapps/libraryfolders.vdf' 2>/dev/null)
    while IFS= read -r library; do
        [[ -d "$library" ]] && printf '%s\n' "$library"
    done < <(find /mnt -maxdepth 4 -type d -name steamapps -printf '%h\n' 2>/dev/null)
}

configure_flatpak_access() {
    local steam_dir="$1" path
    require_command flatpak
    while IFS= read -r path; do
        [[ -d "$path" ]] || continue
        flatpak override --user --filesystem="$path" "$PROTONTRICKS_APP"
        log "Granted Protontricks access to $path"
    done < <(detect_library_roots "$steam_dir" | sort -u)
}

install_protontricks() {
    require_command flatpak
    if command -v apt >/dev/null 2>&1 && dpkg-query -W -f='${Status}' protontricks 2>/dev/null | grep -q 'install ok installed'; then
        log "Removing repository Protontricks (known appinfo.vdf parser bug)"
        sudo apt remove -y protontricks
    fi
    flatpak install -y flathub "$PROTONTRICKS_APP"
}

install_ge_proton() {
    local steam_dir="$1" target temp
    target="$steam_dir/compatibilitytools.d/$GE_PROTON_VERSION"
    [[ -x "$target/proton" ]] && { log "$GE_PROTON_VERSION is already installed"; return; }
    require_command curl
    require_command tar
    temp="$(mktemp -d)"
    mkdir -p "$steam_dir/compatibilitytools.d"
    log "Downloading $GE_PROTON_VERSION"
    curl --fail --location --retry 3 --output "$temp/ge-proton.tar.gz" "$GE_PROTON_URL"
    tar -xzf "$temp/ge-proton.tar.gz" -C "$steam_dir/compatibilitytools.d"
    rm -rf "$temp"
    [[ -x "$target/proton" ]] || die "GE-Proton extraction did not create $target/proton"
}

repair_csp() {
    local ac_dir="$1" mapping="$ac_dir/extension/config/data_alt_mapping.ini"
    if [[ -f "$mapping" ]] && grep -q '^\[NAMES_WINE\]' "$mapping"; then
        sed -i '/^\[NAMES_WINE\]/,$d' "$mapping"
        log "Removed CSP [NAMES_WINE] symbol mappings"
    fi
    rm -f "$ac_dir/acs.pdb.acd"
    if [[ -f "$ac_dir/extension/config/general.ini" ]]; then
        sed -i -E 's/^([[:space:]]*CACHE_CSP_CONFIGS[[:space:]]*=[[:space:]]*)1/\10/I' \
            "$ac_dir/extension/config/general.ini" || true
    fi
}

repair_dotnet_prefix() {
    local steam_dir="$1" prefix="$steam_dir/steamapps/compatdata/$AC_APPID/pfx"
    [[ -d "$prefix" ]] || die "Assetto Corsa prefix not found: $prefix (run the game once first)"
    rm -rf "$prefix/dosdevices/c:/windows/Microsoft.NET"
    rm -f "$prefix/dosdevices/c:/windows/system32/mscoree.dll" \
        "$prefix/dosdevices/c:/windows/syswow64/mscoree.dll"
    log "Removed GE-Proton wine-mono .NET stubs"
    STEAM_DIR="$steam_dir" WINEDLLOVERRIDES="mscoree=d" flatpak run "$PROTONTRICKS_APP" \
        -c 'wine64 reg delete "HKLM\Software\Microsoft\NET Framework Setup\NDP" /f' "$AC_APPID" || true
    STEAM_DIR="$steam_dir" WINEDLLOVERRIDES="mscoree=d" flatpak run "$PROTONTRICKS_APP" \
        -c 'wine reg delete "HKLM\Software\Microsoft\NET Framework Setup\NDP" /f' "$AC_APPID" || true
    flatpak run "$PROTONTRICKS_APP" "$AC_APPID" dotnet48 vcrun2019 d3dcompiler_47 d3dx11_43 corefonts win10
    pkill -9 -f 'mscorsvw|tabtip' 2>/dev/null || true
    local ngen
    ngen="$prefix/drive_c/windows/Microsoft.NET/Framework64/v4.0.30319/ngen.exe"
    [[ -f "$ngen" ]] || die "dotnet48 completed but ngen.exe is missing: $ngen"
    log ".NET 4.8 verification passed"
}

install_content_manager_swap() {
    local ac_dir="$1" cm_zip temp cm_exe
    mkdir -p "$HOME/Games"
    ln -sfn "$ac_dir" "$HOME/Games/assettocorsa"
    if [[ -f "$ac_dir/AssettoCorsa.exe" && ! -f "$ac_dir/AssettoCorsa_original.exe" ]]; then
        mv -n "$ac_dir/AssettoCorsa.exe" "$ac_dir/AssettoCorsa_original.exe"
    fi
    if [[ -f "$ac_dir/AssettoCorsa.exe" ]]; then
        log "Content Manager swap already exists"
        return
    fi
    require_command curl
    require_command unzip
    temp="$(mktemp -d)"
    cm_zip="$temp/content-manager.zip"
    curl --fail --location --retry 3 --output "$cm_zip" "https://acstuff.club/app/latest.zip"
    unzip -q "$cm_zip" -d "$temp/cm"
    cm_exe="$(find "$temp/cm" -type f -iname 'Content Manager.exe' -print -quit)"
    [[ -n "$cm_exe" ]] || die "Content Manager.exe was not found in the downloaded archive"
    install -m 0644 "$cm_exe" "$ac_dir/AssettoCorsa.exe"
    rm -rf "$temp"
    log "Installed Content Manager as AssettoCorsa.exe"
}

main() {
    require_command sudo
    require_command find
    local steam_dir ac_dir
    steam_dir="$(detect_steam_dir)" || die "Steam installation not found"
    ac_dir="$(detect_ac_dir "$steam_dir")" || die "Assetto Corsa installation not found"
    log "Steam: $steam_dir"
    log "Assetto Corsa: $ac_dir"
    install_protontricks
    configure_flatpak_access "$steam_dir"
    install_ge_proton "$steam_dir"
    repair_dotnet_prefix "$steam_dir"
    repair_csp "$ac_dir"
    install_content_manager_swap "$ac_dir"
    cat <<EOF

Setup complete.
Steam Launch Options:
$LAUNCH_OPTIONS

Visible Content Manager path:
$HOME/Games/assettocorsa

If CSP updates later, run:
$(dirname "$0")/fix-csp-patch.sh "$ac_dir"
EOF
}

main "$@"
