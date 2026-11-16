# Assetto Corsa Linux No Hesi Fixer

[![Platform](https://img.shields.io/badge/platform-Ubuntu%20%2F%20Debian%20%2F%20Zorin%20OS-E95420?logo=linux&logoColor=white)](https://www.debian.org/)
[![Proton](https://img.shields.io/badge/Proton-GE--Proton9--27-557C94)](https://github.com/GloriousEggroll/proton-ge-custom)
[![CSP](https://img.shields.io/badge/CSP-v0.2.11%20Ready-2ea44f)](https://acstuff.club/patch/)
[![No Hesi](https://img.shields.io/badge/No%20Hesi-Supported-00a98f)](https://nohesi.gg/)

Production-oriented repair scripts for Assetto Corsa, Content Manager, Custom Shaders Patch (CSP 0.2.11+), and No Hesi on Ubuntu, Debian, and Zorin OS using Steam Proton and Flatpak Protontricks.

> **Scope:** run these scripts on a dedicated gaming installation, review commands before granting filesystem access, and keep backups of custom mods. The scripts do not download No Hesi content or bypass licenses.

## What this fixes

- Replaces the obsolete `apt` Protontricks 1.10.5 parser with Flatpak Protontricks.
- Grants Protontricks access to Steam libraries on the primary disk and `/mnt/*` secondary disks.
- Installs GE-Proton9-27, which avoids the Proton 11 `dbghelp.dll` symbol parsing issue.
- Removes GE-Proton wine-mono/.NET stubs before installing .NET 4.8 and verifies `ngen.exe`.
- Removes CSP's `[NAMES_WINE]` mapping and stale `acs.pdb.acd` cache.
- Creates the visible `~/Games/assettocorsa` path for Content Manager's hidden-folder browser.
- Safely swaps the game executable for Content Manager without overwriting an existing backup.
- Registers `acmanager://` links used by No Hesi server join buttons.

## Quick Start (One-Line Install)

From a terminal in the directory containing the scripts:

```bash
curl -fsSL https://raw.githubusercontent.com/DevarshP610/ac-linux-nohesi-fixer/main/ac-linux-fixer.sh -o ac-linux-fixer.sh && chmod +x ac-linux-fixer.sh && ./ac-linux-fixer.sh
```

The script asks for `sudo` only when removing the obsolete apt package. Steam and Assetto Corsa must have been started once so the prefix exists.

For a local checkout:

```bash
git clone https://github.com/DevarshP610/ac-linux-nohesi-fixer.git
cd ac-linux-nohesi-fixer
chmod +x ac-linux-fixer.sh fix-csp-patch.sh
./ac-linux-fixer.sh
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

## CSP update repair

CSP updates can restore `extension/config/data_alt_mapping.ini` and regenerate the bad memory-layout cache. Run this whenever Content Manager updates CSP:

```bash
./fix-csp-patch.sh "$HOME/Games/assettocorsa"
```

The script removes `[NAMES_WINE]` to end-of-file, deletes `acs.pdb.acd`, and disables `CACHE_CSP_CONFIGS` when that setting is present. Restart Content Manager before trying **Patch Assetto Corsa** again.

## No Hesi `acmanager://` links

Install the handler once:

```bash
mkdir -p "$HOME/.local/share/applications"
install -m 0644 acmanager.desktop "$HOME/.local/share/applications/acmanager.desktop"
update-desktop-database "$HOME/.local/share/applications" 2>/dev/null || true
xdg-mime default acmanager.desktop x-scheme-handler/acmanager
```

Then click a No Hesi server join link in the browser and allow it to open Assetto Corsa Content Manager. The handler prefers the executable installed at `~/Games/assettocorsa/AssettoCorsa.exe` and otherwise searches the normal Steam locations for `Content Manager.exe`.

## Troubleshooting Reference

| Exact error/message | Root cause | Command fix |
|---|---|---|
| `SyntaxError: Invalid file magic number` | Ubuntu/Zorin apt Protontricks 1.10.5 cannot parse Steam's newer binary `appinfo.vdf`. | `sudo apt remove -y protontricks && flatpak install -y flathub com.github.Matoking.protontricks` then rerun `./ac-linux-fixer.sh`. |
| `It appears that .NET 4.5.2 is not installed` | Changing from Proton 11 to GE-Proton9 left an invalid prefix registry. | `./ac-linux-fixer.sh` (it deletes both NDP registry trees and reinstalls dotnet48). |
| `warning: dotnet40 install completed, but installed file .../ngen.exe not found` | GE-Proton9 wine-mono registry/file stubs made the installer skip extraction. | `./ac-linux-fixer.sh` (it removes `Microsoft.NET`, both `mscoree.dll` files, and verifies `Framework64/v4.0.30319/ngen.exe`). |
| `Failed to patch Assetto Corsa: Can't find "CarLabel::render"` | CSP `[NAMES_WINE]` mappings and cached `acs.pdb.acd` break modern Proton symbol resolution. | `./fix-csp-patch.sh "$HOME/Games/assettocorsa"` |
| `.steam` missing in Browse For Folder | Wine hides dot-directories in Content Manager's folder dialog. | Select `~/Games/assettocorsa`, created by `./ac-linux-fixer.sh`. |

### Other useful checks

```bash
flatpak run com.github.Matoking.protontricks --version
ls "$HOME/.steam/debian-installation/compatibilitytools.d/GE-Proton9-27/proton"
ls "$HOME/.steam/debian-installation/steamapps/compatdata/244210/pfx/drive_c/windows/Microsoft.NET/Framework64/v4.0.30319/ngen.exe"
```

If Steam is installed in a different location, export it before running:

```bash
STEAM_DIR="/path/to/Steam" ./ac-linux-fixer.sh
```

## Safety and support notes

- The scripts are idempotent for installed Protontricks, GE-Proton9-27, CSP repairs, and the Content Manager backup.
- `mv -n` ensures an existing `AssettoCorsa_original.exe` is never overwritten.
- The scripts intentionally use the Assetto Corsa Steam AppID `244210`.
- Inspect downloaded software and keep your distribution, Steam, Proton, CSP, and Content Manager installations current.

## License

MIT. See [LICENSE](LICENSE).
