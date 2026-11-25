# Build lineage: the `IGI_SontekKajla*.exe` series

All binaries in `G:\GTA\Code\` were inspected by reading their embedded Godot
PCK resource index (mission scene paths and script paths). They are **the same
game series**, not separate games: `IGI Sontek Kajla` by S M Nazmuz Sakib.

| Build | File size | Missions | Notable scripts in the pack |
|---|---:|---:|---|
| `IGI_SontekKajla.exe` (first) | 109.1 MB | 5 | original Sontek Kajla build |
| `v2`, `v3` | 109–112 MB | 5 | same campaign, incremental fixes |
| `v4` – `v7` | 118.1–118.1 MB | 6 | sixth mission added |
| `v8` | 118.1 MB | 6 | `Vault.gd` (window vaulting) |
| `v9` | 118.2 MB | 6 | + `NeutralAI.gd` (neutral forces) |
| `v10` | 118.2 MB | 6 | + `AirstrikeSource.gd`, `Lift.gd` |
| **`v11`** | **118.2 MB** | **6** | + `Vault.gd`, `Lift.gd` — refined 6-mission build |
| `v12`, `v13`, `v14` | 118.2 MB | 6 | final builds of the 6-mission line |
| `IGI 3 - S M Nazmuz Sakib.exe` | 118.2 MB | **15** | `CityMesh`, `DoorProxy`, `WindowProp`, `ShopProp` — dense-city rebuild |
| Fresh export of this repository | 118.2 MB | **15** | same 15 missions + fixed navigation cells |

## Verdict on `G:\GTA\Code\IGI_SontekKajla_v11.exe`

It is **an earlier build of the same game**, not a different game:

- same menu (`SontekMenu.tscn`), same world scripts (`KajlaMap.gd`,
  `LevelBuilder.gd`, `IGIMission.gd`), same OSM map and poster assets;
- it contains only **M01–M06**, so it predates the 15-mission IGI 3 campaign;
- it still uses the older `NeutralAI.gd`, `AirstrikeSource.gd`, `Vault.gd`,
  `Lift.gd` and `Shop.gd` scripts, while the 15-mission rebuild uses the
  batched `CityMesh`, single `DoorProxy`, `WindowProp`, `LiftProp` and
  `ShopProp` system;
- SHA-256: `3726DC614D19EE78B7E935F22A834FE761BF10D164F70B54F593F4BC028303B4`.

There is **no separate source tree** for v11 under `G:\GTA\Code` (only the
executables, helper scripts and zipped TauntONomics backups). The playable
binary is preserved as a legacy GitHub Release asset.

## Note on screenshots in `G:\GTA\Code`

The `shot_*.png` files in that folder show the separate **TauntONomics Dhaka**
project (missions like "চায়ের দোকানের খবর", health/energy/stamina HUD). They
are not IGI screenshots, so they are not used as IGI visuals here.
