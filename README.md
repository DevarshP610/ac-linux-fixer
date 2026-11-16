# Assetto Corsa Linux Fixer and Setup

[![Platform](https://img.shields.io/badge/platform-Ubuntu%20%2F%20Debian%20%2F%20Zorin%20OS-E95420?logo=linux&logoColor=white)](https://www.debian.org/)
[![Proton](https://img.shields.io/badge/Proton-GE--Proton9--27-557C94)](https://github.com/GloriousEggroll/proton-ge-custom)
[![CSP](https://img.shields.io/badge/CSP-v0.2.11%20Ready-2ea44f)](https://acstuff.club/patch/)

Production-oriented setup and repair scripts for Assetto Corsa, Content Manager, and Custom Shaders Patch (CSP 0.2.11+) on Ubuntu, Debian, Zorin OS, Arch, Fedora, and openSUSE using Steam Proton and Flatpak Protontricks.

> **Scope:** run these scripts on a dedicated gaming installation, review commands before granting filesystem access, and keep backups of custom mods. The scripts do not download game content or bypass licenses.

## What this fixes

- Replaces the obsolete `apt` Protontricks 1.10.5 parser with Flatpak Protontricks.
- Grants Protontricks access to Steam libraries on the primary disk and `/mnt/*` secondary disks.
- Installs GE-Proton9-27, which avoids the Proton 11 `dbghelp.dll` symbol parsing issue.
- Removes GE-Proton wine-mono/.NET stubs before installing .NET 4.8 and verifies `ngen.exe`.
- Removes CSP's `[NAMES_WINE]` mapping and stale `acs.pdb.acd` cache.
- Creates the visible `~/Games/assettocorsa` path for Content Manager's hidden-folder browser.
- Safely swaps the game executable for Content Manager without overwriting an existing backup.
- Detects apt, pacman, dnf, and zypper and installs missing host tools automatically.

## Quick Start (One-Line Install)

From a terminal in the directory containing the scripts:

```bash
curl -fsSL https://raw.githubusercontent.com/DevarshP610/ac-linux-fixer/main/ac-linux-setup.sh -o ac-linux-setup.sh && chmod +x ac-linux-setup.sh && ./ac-linux-setup.sh
```

The script asks for `sudo` to install missing host tools and remove a conflicting distro Protontricks package. Steam and Assetto Corsa must have been started once so the prefix exists. Flatpak must be available from your distribution repositories; the script adds the Flathub remote if needed.

For a local checkout:

```bash
git clone https://github.com/DevarshP610/ac-linux-fixer.git
cd ac-linux-fixer
chmod +x ac-linux-setup.sh fix-csp-patch.sh
./ac-linux-setup.sh
```

## After setup

1. In Steam, select **Assetto Corsa → Properties → Compatibility** and choose `GE-Proton9-27`.
2. Paste this exact launch option into **General → Launch Options**:

   ```text
   WINEDLLOVERRIDES="dwrite=n,b" LC_ALL=C %command%
   ```

3. Start Content Manager from `~/Games/assettocorsa/AssettoCorsa.exe` or Steam.
4. In Content Manager's first-run folder picker, select the visible `Games/assettocorsa` path instead of navigating into the hidden `.steam` directory.
5. Install/enable CSP 0.2.11 or newer, then apply the CSP repair if patching fails.

## Distribution support

The main script supports common Steam layouts on:

- **Ubuntu, Debian, Zorin OS, and derivatives:** `apt-get`
- **Arch Linux and derivatives (including EndeavourOS and Manjaro):** `pacman`
- **Fedora and derivatives:** `dnf`
- **openSUSE Tumbleweed/Leap:** `zypper`

It checks for and installs `curl`, `find`, `flatpak`, `pkill`, `tar`, and `unzip`, then uses the Flatpak Protontricks build on every distribution. Steam libraries are searched under the standard per-user locations plus `/mnt`, `/media`, and `/run/media/$USER` mounted drives. If your Steam library is elsewhere, use `STEAM_DIR="/path/to/Steam" ./ac-linux-setup.sh`.

## CSP update repair

CSP updates can restore `extension/config/data_alt_mapping.ini` and regenerate the bad memory-layout cache. Run this whenever Content Manager updates CSP:

```bash
./fix-csp-patch.sh "$HOME/Games/assettocorsa"
```

The script removes `[NAMES_WINE]` to end-of-file, deletes `acs.pdb.acd`, and disables `CACHE_CSP_CONFIGS` when that setting is present. Restart Content Manager before trying **Patch Assetto Corsa** again.

## Troubleshooting Reference

| Exact error/message | Root cause | Command fix |
|---|---|---|
| `SyntaxError: Invalid file magic number` | A distro Protontricks package cannot parse Steam's newer binary `appinfo.vdf`. | `flatpak install -y flathub com.github.Matoking.protontricks` then rerun `./ac-linux-setup.sh`; the script removes conflicting apt/pacman/rpm packages. |
| `It appears that .NET 4.5.2 is not installed` | Changing from Proton 11 to GE-Proton9 left an invalid prefix registry. | `./ac-linux-setup.sh` (it deletes both NDP registry trees and reinstalls dotnet48). |
| `warning: dotnet40 install completed, but installed file .../ngen.exe not found` | GE-Proton9 wine-mono registry/file stubs made the installer skip extraction. | `./ac-linux-setup.sh` (it removes `Microsoft.NET`, both `mscoree.dll` files, and verifies `Framework64/v4.0.30319/ngen.exe`). |
| `Failed to patch Assetto Corsa: Can't find "CarLabel::render"` | CSP `[NAMES_WINE]` mappings and cached `acs.pdb.acd` break modern Proton symbol resolution. | `./fix-csp-patch.sh "$HOME/Games/assettocorsa"` |
| `.steam` missing in Browse For Folder | Wine hides dot-directories in Content Manager's folder dialog. | Select `~/Games/assettocorsa`, created by `./ac-linux-setup.sh`. |

### Other useful checks

```bash
flatpak run com.github.Matoking.protontricks --version
ls "$HOME/.steam/debian-installation/compatibilitytools.d/GE-Proton9-27/proton"
ls "$HOME/.steam/debian-installation/steamapps/compatdata/244210/pfx/drive_c/windows/Microsoft.NET/Framework64/v4.0.30319/ngen.exe"
```

If Steam is installed in a different location, export it before running:

```bash
STEAM_DIR="/path/to/Steam" ./ac-linux-setup.sh
```

## Safety and support notes

- The setup script is idempotent for installed Protontricks, GE-Proton9-27, CSP repairs, and the Content Manager backup.
- `mv -n` ensures an existing `AssettoCorsa_original.exe` is never overwritten.
- The scripts intentionally use the Assetto Corsa Steam AppID `244210`.
- Inspect downloaded software and keep your distribution, Steam, Proton, CSP, and Content Manager installations current.

## License

MIT. See [LICENSE](LICENSE).
