# How to build IGI 3 — Sontek Kajla

Two ways: let GitHub build it (no installation) or build locally with Godot 4.3.

## A. GitHub build (no installation)

1. Push a change to `main`, or open **Actions → Build IGI 3 - Sontek Kajla (Windows) → Run workflow**.
2. GitHub downloads Godot 4.3 + Windows export templates, imports the project,
   then runs five headless checks: menu smoke test, city test, mission M01,
   mission M15, neutral-forces test and save-system test.
3. Open the finished run and download the **IGI3-SontekKajla-Windows** artifact.
   It contains `IGI3_SontekKajla.exe`, the README, design notes and visuals.
4. Pushing a `v*` tag (for example `v3.0.0`) also uploads the `.exe` to that
   tag's GitHub Release.

If a step turns red, open it and read the log: the headless tests print the
failing `[CITY]` / `[IGI]` / `[NEUTRAL]` / `[SAVE]` line and a `PASS` or `FAIL`.

## B. Local build

Requirements: **Godot 4.3 stable** (standard edition) and its export templates.
Android additionally needs JDK 17 and Android SDK 34 in Editor Settings.

```powershell
cd path\to\igi3-sontek-kajla

# one-off asset import
godot --headless --path . --import

# headless checks (each should print PASS and exit 0)
godot --headless --path . res://tools/test/CityTest.tscn
$env:MISSION = '1';  godot --headless --path . res://tools/test/IgiTest.tscn
$env:MISSION = '15'; godot --headless --path . res://tools/test/IgiTest.tscn
Remove-Item Env:MISSION
godot --headless --path . res://tools/test/NeutralTest.tscn
godot --headless --path . res://tools/test/SaveTest.tscn

# exports (output paths are relative, defined in export_presets.cfg)
godot --headless --path . --export-release "Windows Desktop"
godot --headless --path . --export-release "Android"
```

You can also open `project.godot` in the Godot editor and use
**Project → Export → Windows Desktop → Export Project**.

The Windows build is a single self-contained `.exe` with the PCK embedded.
`build/` is intentionally git-ignored: binaries are published as Actions
artifacts and GitHub Releases instead of being committed to Git (GitHub limits
regular files to 100 MB).

## Regenerating the README visuals

```powershell
python tools/make_readme_visuals.py   # needs Pillow
```

This reads the project's OSM raster and fonts and writes `docs/images/*.png`.

## Notes

- The editor-only `addons/asset_placer/` addon is not part of this repository: it
  requires Godot 4.4+ typed dictionaries and the game never uses it.
- The navigation map cell size/cell height in `project.godot` deliberately match
  the generated navigation mesh in `scripts/world/IGIMission.gd` (0.5 / 0.4 m).
  Changing either one without the other makes Godot reject the navigation region.
