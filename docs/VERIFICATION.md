# Verification report — 2026-11-25

Environment: Godot **4.3 stable** (`Godot_v4.3-stable_win64_console.exe`),
Windows, headless mode. Every command exited with code **0**.

## Campaign: all 15 missions

Run with `powershell tools/test/run_all_missions.ps1 -Godot "<path to Godot console exe>"`.
Each run loads the real mission scene, builds the 1,500-building city, spawns
enemies and neutrals, checks navmesh reachability of feature-house interiors,
upper floors and roofs, then drives every objective through the real objective
hook to the final extraction.

| Mission | Result | Objectives | Buildings |
|---:|---|---:|---:|
| M01 Kajla Recon | PASS | 10 | 1,500 |
| M02 Document Run | PASS | 9 | 1,500 |
| M03 Park Stakeout | PASS | 10 | 1,500 |
| M04 R110 Sabotage | PASS | 9 | 1,500 |
| M05 Final Sweep | PASS | 10 | 1,500 |
| M06 Rooftop War (HALO) | PASS | 10 | 1,500 |
| M07 Diplomatic Compound | PASS | 7 | 1,500 |
| M08 Motijheel Nightfall | PASS | 7 | 1,500 |
| M09 Hatirjheel Bridge | PASS | 7 | 1,500 |
| M10 Lalbagh Fort | PASS | 7 | 1,500 |
| M11 Karwan Bazar | PASS | 7 | 1,500 |
| M12 Airport Dawn | PASS | 7 | 1,500 |
| M13 Buriganga Night | PASS | 7 | 1,500 |
| M14 Parliament Zone | PASS | 7 | 1,500 |
| M15 Final Operation | PASS | 10 | 1,500 |

## Other headless suites

| Suite | Result | Notes |
|---|---|---|
| `CityTest.tscn` | PASS | 1,500 buildings; 6 feature towers, max 15 floors; 14,380 window openings; 30 shops (10 pharmacies); 200 civilians; 56 lift stops |
| `NeutralTest.tscn` | PASS | 165 neutral actors; 10 military squads; passive until attacked; squad retaliation; enemy retaliation; airstrike call |
| `SaveTest.tscn` | PASS | Checkpoint save/reload, medals, unlocks, ranks |
| Menu smoke test | PASS | `SontekMenu.tscn` boots with no script/parse errors |

## Build and launch

- `godot --headless --path . --export-release "Windows Desktop"` → success
  (embedded-PCK `.exe`, 118 MB).
- The exported executable was launched on Windows and stayed running for 12 s
  before being stopped deliberately — no startup crash.
- GitHub Actions run
  [45640226663](https://github.com/Sakibpedia/igi3-sontek-kajla/actions/runs/45640226663)
  completed successfully in 2 m 2 s: import, menu smoke, all headless suites,
  Windows export, packaging and artifact upload all passed.

## Engine messages

The navigation map cell size/height in `project.godot` now match the navmesh in
`IGIMission.gd` (0.5 / 0.4 m), so Godot no longer rejects the navigation region.
The remaining `Parameter "m" is null` lines in headless logs come from Godot's
dummy renderer while generating thousands of meshes; they do not occur in the
GL Compatibility renderer used by the game and did not affect any test.
