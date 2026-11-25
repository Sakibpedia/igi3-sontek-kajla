===============================================================================
  IGI 3 - S M NAZMUS SAKIB
  15 Bengali IGI-style missions in a dense, shop-filled Sontek Kajla
===============================================================================

PLAY
-------------------------------------------------------------------------------
Double-click:  "IGI 3 - S M Nazmuz Sakib.exe"
(118 MB, Godot 4.3, embedded data - no install needed.)

WHAT'S IN THE CITY (NEW)
-------------------------------------------------------------------------------
* DENSE COLONIES: 1,494 real OSM building footprints are now walk-in structures,
  not solid boxes. Every building has a street door, interior floors with a
  stair, windows on every floor and a reachable roof. Packed solid except for
  the roads, the Sontek pond and the playing field. Three colonies:
    - সনটেক উত্তর / Sontek North
    - সনটেক দক্ষিণ / Sontek South
    - সনটেক মূল সড়ক / Sontek Main Road
  Main road is 9 m (4-5 cars), colony dividers 3.6 m (2 cars), internal lanes
  1.6 m (a single car only). Markets with stalls fill every colony. Open
  ground: সনটেক পুকুর / Sontek Pond and সনটেক মাঠ / Sontek Field.
* WALK-IN BUILDINGS: all 1,500 colony buildings are 2 to 20 storeys, each with
  visible windows, staircases, a lift shaft, a street door and a roof. A single
  smart E door proxy finds the nearest building door and steps through every
  floor to the roof and back to the street with a smooth ~1 s STAIR CLIMB
  animation (visible stair treads on every floor); no 1,500 door nodes. 33,450
  window openings; 60 are directly vaultable. All geometry is ONE batched
  MultiMesh, so a mission loads in ~24 s instead of ~5 minutes. Geometry was
  reduced (~14,380 window openings) and distant actors now sleep so the game
  stays responsive on weak laptops.
  6 detailed feature towers (5 / 6 / 8 / 10 / 12 / 15 storeys) still have
  physical doors, stairs, lifts (56 floor stops), roof huts and roof-to-roof
  plank bridges; navmesh validation passes on all their floors and roofs.
  A Bengali loading card is shown while the mission is generated.
* HERO-ONLY SCOPE: key 8 toggles the gun scope; right mouse also aims. No
  enemy uses a scope.
* NEUTRAL FORCES (new): at least 40 of each kind — 40 military (10 squads of
  4), 40 police, 40 air force, 40 naval commandos (4 teams of 10), plus 4 army
  bomber commandos and 1 white-punjabi civilian protector. They never attack
  first; they return fire on whoever attacks them — hero or villain. Squads
  retaliate together. Distinct uniforms and Bengali "নিরপেক্ষ" labels.
  * Killing an AIR FORCE member calls an aircraft that drops 2 bombs on the
    attacker. Stand under a roof (a building/stairs/road shelter) to avoid them.
  * The WHITE PROTECTOR only attacks whoever hurts a civilian.
  * KISHOR GANGS: 6 groups of 3 knife-wielding youths attack everyone for no
    reason, including civilians.
  * Every mission now opens with a plane fly-over and a HALO parachute jump.
* 30 SHOPS with 8 business types: pharmacies, clinics, arms dealers, grocery,
  general stores, mobile shops, tea stalls and hardware stores (10 pharmacies/
  clinics). Arms dealers sell AWP and MP5; grocery/tea/hardware sell snacks
  that heal; mobile shops sell radio codes. All sell ammo/medkits and BUY BACK
  enemy loot. Pharmacies/clinics sell medicine, bandages and a permanent
  +25 HP health upgrade (up to +75).
* SAFE SHOPS: shops and shopkeepers have no damage method and are not in the
  "actors" group - neither the hero nor the enemies can attack them.
* ENEMY DROPS: every killed enemy leaves money for the hero plus ammunition and
  often a gun to collect and sell; commanders drop more. Some drop medkits.
  Money, loot and health upgrades persist between missions (user://economy.cfg).
* CIVILIANS: 200 ordinary residents walk the colony lanes with animated
  limbs/head, varied clothing, eyes and 3D bodies; the neutral forces use the
  same lightweight animated human model rather than static capsules. They can be wounded
  or killed by the hero's bullets/grenades and by enemy fire. Killing one
  costs 200 points; an enemy killing one raises the alarm.
* Every mission still has its BCS-question gate (keys 1-4), IGI-style wanted
  posters and Bengali PA voice/subtitles.

MISSION CAMPAIGN
-------------------------------------------------------------------------------
15 missions (Kajla Recon ... Final Operation), each with 7-10 chained
objectives: reach, photo, collect, infiltrate, survive, sabotage, wiretap,
eliminate commander, disable alarm, bcs_gate and extract.

CONTROLS
-------------------------------------------------------------------------------
WASD move | Shift sprint | Ctrl crouch/prone | C/Q lean | LMB fire | RMB aim
E interact / shop / pharmacy / lift / vault window / photo / collect / drive | 1-3 weapons | 8 scope |
4 grenade | 5 molotov | 6 time bomb | R reload | T thermal | N headphones |
B binoculars | Tab objectives | M map | Esc pause

FOLDERS
-------------------------------------------------------------------------------
IGI 3 - S M Nazmuz Sakib.exe   Playable Windows game (rebuilt with the city)
PROJECT\                       Full Godot 4.3 source, including:
  scripts\world\KajlaMap.gd      colony layout, dense footprints, shops, civilians
  scripts\world\LevelBuilder.gd  walk-in houses, stairs, doors, windows, roofs
  scripts\world\ShopProp.gd      shop / pharmacy interactable and trade panel
  scripts\world\Civilian.gd      damageable residents
  scripts\world\IGIMission.gd    drops, spawns, mission objectives
  scripts\autoload\Game.gd       15 missions, Bengali text, wallet and loot
  scripts\ui\SontekMenu.gd       Bengali mission-select UI
POSTERS\                       6 poster SVGs (2 Bengali)
EXTRAS_BCS_TauntONomics\       BCS-themed TauntONomics builds
CITY_DESIGN.md                 Design notes
README.txt                     This file

VERIFICATION
-------------------------------------------------------------------------------
* City test (headless): buildings=1500, mass_walkins=1500, all_windows=14380,
  feature houses=6, max_floors=15, shops=30, pharmacies=10, civilians=200,
  lifts=6 - PASS.
* Mission test M01: 1500 buildings (2-20 floors), 10 objectives, navmesh
  reachable on every feature-tower floor and roof; load time ~24 s - PASS.
* Neutral test: 165 neutral actors (40 military in 10 squads of 4, 40 police,
  40 air force, 40 naval in teams of 10, 4 bomber commandos, 1 protector),
  18 kishor gang members, all neutral passive until attacked, retaliation and
  airstrike-on-airman-death verified - PASS.
* No GDScript parse errors; EXE built and launched successfully on Windows
  (~56% of one CPU core while playing, 230 MB RAM on the test machine).
* PERFORMANCE: off-screen NPCs sleep, civilians update at half rate, AI thinks
  every 0.35 s, the door scan runs 5x/second, and city geometry is one draw
  call. These changes specifically target the mid-play freeze.
* Bengali text fix: restored the clean Bengali HUD strings (the old copy had
  literal "????" strings) and assigned NotoSansBengali to every 3D Label3D,
  so shop signs, lift/window prompts, street signs and the HUD all render
  Bengali correctly instead of question marks.
