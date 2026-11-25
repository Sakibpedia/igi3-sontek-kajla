# IGI mode — implementation notes

This file records how the IGI-style campaign is implemented. For player-facing
information see [README.md](README.md).

## Map and city generation

- `assets/maps/kajla_osm.png` is a stitched OpenStreetMap raster (zoom 18,
  4×4 tiles) of Kajla, Dhaka: R110, Kajla Bus Stop, Mosque Road, Kajla Park,
  Chan Mia Park and surrounding lanes. It is drawn under the rotating minimap.
- `assets/maps/kajla.json` holds 1,500 real OSM building footprints with heights.
  `tools/fetch_map_tiles.py` and `tools/build_kajla_map.py` regenerate the data.
  Map data © OpenStreetMap contributors (ODbL 1.0).
- `scripts/world/KajlaMap.gd` lays out three colonies (Sontek North, South and
  Main Road), roads, markets, shops, civilians and mission zones.
- `scripts/world/LevelBuilder.gd` turns each footprint into a walk-in building:
  street door, 2–20 floors, slabs, stairs, lift shaft, window openings and roof.
  All wall/slab/roof boxes are emitted into one batched `MultiMesh` via
  `scripts/world/CityMesh.gd`, so 30,000 boxes cost one draw call.
- `scripts/world/DoorProxy.gd` finds the nearest street door and animates the
  climb through every floor to the roof, avoiding 1,500 separate door nodes.

## Campaign

- `scripts/autoload/Game.gd` defines 15 missions (`MISSION_COUNT`), Bengali
  briefing/objective text, medals, ranks, unlocks and the wallet/loot economy
  saved under `user://`.
- `scripts/world/IGIMission.gd` builds the world, bakes the navigation mesh,
  spawns enemies/neutrals/civilians, runs the chained objectives and handles
  enemy drops and extraction. Each mission has 7–10 objectives:
  `reach`, `photo`, `collect`, `infiltrate`, `survive`, `sabotage`, `wiretap`,
  `eliminate`, `disable_alarm`, `bcs_gate`, `extract`.
- `scripts/world/BCSGate.gd` + `BCSQuestions.gd` implement the MCQ gate
  (keys 1–4). `scripts/world/ShopProp.gd` implements the safe Bengali trade
  panel; shops and shopkeepers have no damage method and are outside the
  `actors` group, so neither side can attack them.
- `scripts/actors/` holds the lightweight animated human model, player controller
  and enemy AI. Neutral forces never fire first; they retaliate as squads.
  Killing an air force member calls an aircraft that drops two bombs on the
  attacker. The white-punjabi protector only fights when a civilian is hurt.
- `scripts/weapons/` holds ballistics, weapon definitions and throwables.
  Only the hero has a scope (key 8 / RMB).

## Navigation

`IGIMission.gd` creates a `NavigationMesh` with `cell_size = 0.5` and
`cell_height = 0.4` for fast baking. The default 3D navigation map must use the
same values; they are set in `project.godot` under `[navigation]`. Agent height
(2.0 m) and max climb (0.4 m) are multiples of the cell height, so Godot does
not have to round them and print precision warnings.

## Tests

Headless scenes in `tools/test/`:

| Scene | What it checks |
|---|---|
| `CityTest.tscn` | 1,500 buildings, 6 feature towers, 14,380 windows, 30 shops, 200 civilians, 56 lift stops |
| `IgiTest.tscn` (`MISSION=1..15`) | Map load, enemies, objectives, navmesh reachability, full objective chain |
| `NeutralTest.tscn` | 165 neutral actors, squads, passive-until-attacked, retaliation, airstrike call |
| `SaveTest.tscn` | Checkpoint save/reload, medals, unlocks, ranks |

Run them with `godot --headless --path . res://tools/test/<Scene>.tscn`. The
GitHub workflow runs them on every push before exporting the `.exe`.
