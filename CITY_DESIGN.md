# Sontek Kajla — dense colony / shop / economy design (implementation target)

## Colonies
The playable area is split into three named colonies plus the connecting arterial:
- **Sontek Main Road** (arterial, shops, traffic, two-lane)
- **Sontek North** (dense residential, narrow lanes)
- **Sontek South** (dense residential + market)
- **Kajla Park / Highway / Rooftops** remain tactical sectors for missions.

Each colony is separated by a wider road. Inside a colony, narrow lanes split the
house blocks; some lanes are so tight that two vehicles cannot pass side by side.

## Buildings
- Ground floors are shops, pharmacies or other public rooms.
- Houses are 5-, 10- or 15-storey. Every floor and the roof is reachable by
  interior stairs. Doorways and window openings are cut into the walls.
- Roofs are open, with stair huts and water tanks, and are navmesh-reachable.

## Shops and pharmacy
- **Pharmacy**: sells medicine (instant heal), bandages (slow heal) and a
  health-upgrade item (increases maximum health for the rest of the campaign).
- **Shop**: sells guns and ammunition; buys back ammunition and guns that the
  hero picked up from fallen enemies. Shop owners and shops cannot be attacked
  by either the hero or the enemies.
- Every mission has a BCS-question gate; answering correctly can unlock a
  discount at the colony shop.

## Economy and drops
- The hero carries a wallet (৳). Money is saved between missions.
- A killed enemy drops money plus some ammunition and sometimes a gun.
- The hero collects the money immediately; weapons/ammo are carried and can be
  sold to the shop owner.

## People
- Normal civilians walk the lanes. They can be hurt or killed by both the hero
  and the enemies. Killing a civilian costs score / can fail stealth missions.

## Status — implemented (dense revision)
All of the above is implemented in `PROJECT\`:
- All 1,500 OSM footprints are walk-in towers of 2-20 storeys: street door,
  floors, visible stairs, lift shaft, windows and roof (33,450 window openings;
  60 directly vaultable). Geometry is one MultiMesh; a single smart door proxy
  handles every building, so load takes ~26 s.
- 6 detailed feature towers (5/6/8/10/12/15 floors) with physical stairs,
  lifts (56 stops), roof-hut doors and roof-to-roof plank bridges.
- Markets with stalls in every colony.
- 30 safe shops of 8 types (10 pharmacies/clinics) with a Bengali trade panel;
  wallet, loot and +25 HP upgrades persist between missions.
- Neutral forces: 40 military (10 squads of 4, retaliate as a group), 40
  police, 40 air force (death calls 2 bombs from a plane on the attacker;
  shelter under a roof avoids them), 40 naval commandos (4 teams of 10),
  4 bomber commandos, and 1 white-clad protector who only fights when a
  civilian is attacked. All passive until attacked by hero or villain.
- 6 kishor knife gangs (3 each) attack anyone for no reason, civilians included.
- Every mission begins with a plane and HALO parachute insertion.
- Hero-only scope (key 8 / right mouse); enemies have no scope.
- Enemy death drops money, ammo, guns and occasional medkits.
- 24 damageable civilians; civilian deaths cost score or raise the alarm.

Verified with `tools/test/CityTest.tscn` and `tools/test/IgiTest.tscn` (headless).
