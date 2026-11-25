# Silent Rescue: Cox's Bazar (নিঃশব্দ উদ্ধার: কক্সবাজার) — Game Design Document

> **Phase 5 — Cox's Bazar.** The game moved from Dhaka to the Cox's Bazar coast. Section 0 below is the
> current design and overrides the older sections wherever they differ (the Dhaka missions, the shop and
> the money, the gender lock, the voices and ambience). The older sections stay for the mechanics that
> are unchanged.

**Genre:** first-person tactical stealth and hostage-rescue shooter, in the style of I.G.I.
**Engine:** Godot 4.3 with the GL Compatibility renderer. It runs on Intel integrated graphics.
**Platform:** Windows 10/11, 64-bit, single `SilentRescueCoxsBazar.exe` (the internal project name stays "Silent Rescue: Dhaka" so earlier saves, photos and sound clips in `user://` are kept).
**Language:** Bengali for the UI and the dialogue boxes (text only, no voices). English appears only in names.

## 0. Cox's Bazar (Phase 5) — current design
### 0.1 Setting and story
- Eleven coastal missions (Laboni Point, Kolatoli, Sugandha, Himchari, Inani, the fishery ghat on the Bakkhali, Moheshkhali jetty, Sonadia, Patenga container yard, Sabrang, Saint Martin's). Each map (`scripts/world/CoastLayouts.gd`, a fixed seed per mission) has beach houses in two rows, walk-in shipping containers, a lane, Marine Drive, the beach with umbrellas, loungers, a lifeguard tower and fishing boats, the sea, and — depending on the mission — cliffs, coral rocks, a container yard, a jetty or an island. Beach houses and containers can be entered and have furnished interiors.
- The gang ("কালো ছায়া") holds people in the houses and containers; some are tourists ("visitors") taken off the beach. Parachute insertion, the exit vehicles, the companions, the VIP, the doctor, the intel beacon, residents' questions and the walkie-talkie work as before.
- Clothes: casual coastal wear for everyone — printed shirts and shorts, T-shirts and capri trousers, light sundresses, sandals; the team and the gang add plate carriers, caps and bandanas. No swimwear, no regional costume.
- No environmental sound (no ambience, rain, wind, thunder, traffic, horns, engines) and no voices: every line is a dialogue box.

### 0.2 Hostages (30+ per mission)
- Every hostage house and walk-in container holds 1–2 hostages (at least 24 in all) on a bed, sofa or chair, **untied and ungagged**; with the 9 captives of section 7 that is 33+ per mission. Every third site is guarded by two gunmen at the door.
- **Two-minute room timer:** once the Freelancer or an Alpha is in the room, the team has 2 minutes to tie and tape them. After that they start talking ("আপনারা কারা?", "এখানে কেন এসেছেন?" …) in dialogue boxes, and gunmen within their voice range hear it.
- **Unique people:** every hostage has a slot of her / his own (36 slots, customiser) and so a face of her / his own — built only from the face sliders, never from a photo, and fixed per slot (nothing random). Every hostage also has a **noise level** (0.55 quiet … 1.7 very loud, fixed per hostage) that scales how far the voice and the muffled sounds carry; the prompt names the lightest tape that keeps her / him quiet enough.
- **Yes / no questions (I):** a gagged hostage answers by nodding or shaking the head (the tape limits how far the head moves), each with your own sound clip; the questions: are you all right, are you hurt, are guards near, is anyone else held here, can you walk.
- Expressions (fear, anger, relief, struggle) on the face while being taped, carried and rescued.
- After taping, a hostage can be carried over the shoulder anywhere (section 5.4 and 6.12), ties and tape stay on.

### 0.3 Opposite-gender rule and the Alpha Team women's hand
| Who | Woman (hostage, visitor, senior guard, the downed Freelancer if female) | Man |
|---|---|---|
| The Freelancer (male) and Alpha men | tie / untie, tape / untape, carry | water only — **cannot** tie, tape or carry |
| Alpha women | water only — cannot tie, tape or carry | tie / untie, tape / untape, carry, **hand over the mouth** |
| Villains | a male villain takes women | a female villain takes men |

- The **hand over the mouth** is the Alpha Team women's own skill and works on men only: on a male hostage (order "মুখ চেপে ধরুন") he is silent at once and stays silent until the tape goes on — another Alpha woman, or the same one, then tapes him; and as a **silent takedown** — J while looking at an unaware male gunman sends the nearest free Alpha woman to sneak up behind him; her hand goes over his mouth and he is taped and tied (a captive for the police). A gunman wearing one of your photos is never taken down this way (people with photo faces are never tied or carried).
- The Alpha Team is mixed (slot genders from the customiser; the starting three always include a man and a woman). Alphas obey orders, hold the positions they are sent to, engage enemies who close in and stay within the ordered radius.
- **Hero at 0 health:** an Alpha of the opposite gender (an Alpha woman for the male Freelancer) runs over, lifts the Freelancer onto her shoulder, carries him to the nearest safe container or the extraction area, puts him down and gives medicine; the camera stays in third person on it the whole time and he gets up with 35 health. Only with no such Alpha left does the mission fail.

### 0.4 Tape (unlimited) and the tape types
No shop, no money, no stock: tape and rope are always there for the Freelancer and every Alpha. Taping is a quick functional action (the Phase 4 strip, rope and sounds; about a second for the tape, 1.6 s for the rope). **7** (or the pause menu) picks the type of the next strip; the HUD tape bar shows it.

| # | Type | Voice (tape off, the pad stays) | Breathing / struggling under the tape |
|---|---|---|---|
| — | the gang's tape | 10 m × noise level | 4 m × noise level |
| 1 | বেসিক টেপ — Basic | × 0.85 | × 0.75 |
| 2 | স্ট্যান্ডার্ড টেপ — Standard | × 0.7 | × 0.5 |
| 3 | অ্যাডভান্সড টেপ — Advanced | × 0.55 | × 0.3 |
| 4 | ট্যাকটিক্যাল টেপ — Tactical | × 0.4 | × 0.12 |

The recommended type keeps the muffled sounds within 2 m: quiet hostages need Basic, average ones Standard, loud ones Advanced and the loudest Tactical. A hostage's label warns "টেপ দুর্বল!" when the tape on her is lighter than that.

### 0.5 Senior guards and the tourist police
Every fourth ordinary gunman is a senior (older) guard. Hit hard — or worn out in a long firefight — he / she **faints instead of dying**. An Alpha of the opposite gender (or the Freelancer, for a woman) ties, tapes and carries him / her to the **tourist police post** (the last house of the south row): **250 points**. Gunmen taken down silently by an Alpha woman go the same way (80 points for the takedown). This is a score only — tape is never bought.

### 0.6 Score instead of money
Rescued hostage 100, visitor 120, police hand-over 250, takedown 80, the leader 500, the cache 300, the gang's stash 150, an arrest 150. The HUD shows the score; the debrief shows it with the police hand-overs, takedowns and how often an Alpha carried the Freelancer to safety; every mission keeps its best score (mission cards in the main menu). Medkits: 2 from HQ per mission, more from residents (every right answer: a medkit) and the doctor.

### 0.7 Faces — character slots, no lottery
Customiser pages: the Freelancer; Alpha Team (shared uniform + slots 1–6, each with its own gender); villains (slots 1–2); gunmen (shared + slots 1–8: gunman k uses slot (k mod 8) + 1); the boss; hostages (shared + slots 1–36). **Photos** (aligned with the 3-point tool, section 8.1, saved as `user://faces/slot_<role>_<n>.png`) go only on Alpha, villain, gunman and boss slots — people who are never tied, gagged or carried. The Freelancer, hostages, visitors, senior guards and captured Alphas always have slider faces. Older loose photos (`other_*`, `profile_*` …) fill empty slots in alphabetical order; nothing is chosen at random.

### 0.8 Sound slots (your clips)
Every tape-on, tape-off, lift onto the shoulder, put-down and gagged yes / no plays **your own clip** (customiser → শব্দ: one card per event with a slot for both genders and one each for women / men; Settings has a volume for them). These moments never use built-in recordings, and neither do the hostages' breathing, gasps or cries. Built-in gameplay sounds (guns, footsteps, doors, alarms, music) stay on unless Settings switches "গেমের নিজস্ব শব্দ" off. Bus layout (`default_bus_layout.tres`): Master ← Music, SFX, **Signals** (your clips), UI; Ambience and Voice are kept silent.

### 0.9 Interface
One theme for everything (`scripts/ui/UIStyle.gd`): deep-sea navy panels, lagoon-teal and sunset-coral accents, sand-coloured text, rounded cards with an accent strip, chips, key caps, drawn check boxes and slider grabbers. The HUD has the Alpha Team roster (gender, call sign, what each is doing, health), the tape bar with score / medkit / police / safe-hostage chips, stacked notices, dialogue cards with the speaker's name, the order menu with numbered key caps and the prompt on a pill. The main menu has a stacked title, mission cards (time of day, best score), a briefing with chips (hostages, houses, containers, exit), grouped options and a card with the rules.

### 0.10 Body, clothing and takedowns (phase 6 additions)
- **Full anatomical rig.** `CharacterModel.gd` builds every body from measured cross sections. A new `ANATOMY` table drives musculoskeletal relief independently of the silhouette: trapezius, deltoids, pectorals, six-pack abs with linea alba and V-cut obliques, gluteal lobes with a cleft, quadriceps, calves. The three stacked, z-fighting ab meshes were replaced by one build-scaled pass. Men's `muscular` build leads on abs and the V-line; the female `female_powerful` (Alpha) and `actress` builds carry more pronounced gluteal and pectoral definition than the male average, while all women keep breast relief.
- **New builds.** Men: `muscular`, `chubby`; women: `actress`, `chubby_f`. They are selectable in the customiser (gender-specific label lists) and have their own strength, mass and relief values.
- **Clothes on / off.** The old global `_swimwear()` override is gone. The default is the full coastal outfit from `_outfit_base` (as described in 0.1); the customiser offers **Outfit / Beachwear / Anatomy** (`Game.get_clothing_mode()`, persisted in `user://characters.cfg`). `CharacterModel.set_clothing_mode()`, `wear_clothes()` and `remove_clothes()` swap only the segment meshes on a live character, so ties, tape, the rifle and the carried pose survive. The anatomy mode shows the muscled body; beachwear keeps the existing briefs / bikini shells.
- **Alpha-woman takedowns.** J on an unaware enemy under the crosshair calls `Mission.request_takedown()`: a free Alpha woman sneaks up behind the target (`AllyAI._do_takedown`) and covers his mouth. `Game.TAKEDOWN_HOSTAGE_CHANCE = 0.5` decides the outcome: half the targets die (`EnemyAI.force_kill`), half become captives (`HostageOps.subdue_enemy`) - hand-gagged, taped and tied, then carried over the shoulder or to the tourist police post. `HostageOps.senior_fainted()` now spawns the surviving senior guard as a captive as well. Only Alpha women may hand-gag male captives (`Game.can_hand_gag`); photo-faced enemies, leaders and surrendering prisoners are never taken down this way.
- **Tests.** `tools/test/BodyClothingTest.tscn` and `tools/test/TakedownTest.tscn` run headlessly in CI before the export step.

### 0.11 Medical rescue (phase 7 additions)
- **Bombs on ~25% of the hostages.** A fixed quarter of the seated house / container captives (deterministic per mission seed) carry the gang's bomb strapped over their clothes: a dark chest block with wires, a blinking red LED and a timer panel (`MedicalProps.make_bomb_vest`). The label warns "বোম!", and **nobody can lift them while the device is armed**.
- **The consent form.** E on a bombed hostage (tape off, conscious) opens the full Bengali **চিকিৎসা সম্মতিপত্র** card: the procedure, the garment transfer, the 5-minute limit and the right to refuse. Key 1 signs, key 2 declines. Signing starts a **300 s bomb clock** (shown on the label and HUD) and calls the nurse by herself; if the clock runs out the bomb explodes and the mission fails. J on the hostage offers the same form through an Alpha.
- **The nurse and the removal procedure.** Every mission spawns a **medical nurse companion** (white uniform, U menu). On a signed form she walks over, kneels and removes the bomb-rigged garment (~4 s). The hostage goes to beachwear; **the rescuer who ordered the procedure puts on the hostage's bikini (woman) or shorts (man)** — the bomb was rigged into that layer — and the hostage receives the rescuer's own clothes (`CharacterModel.swap_clothes` / `wear_garment`, clothing keys only: face, build, hat, vest and rifle stay). The bomb device travels with the garment onto the rescuer; the nurse then **defuses it on them** (~3 s, +200 points). Signed forms queue while she works.
- **Changing the hostages' clothes.** Two new J orders on any hostage: **কাপড় বদলান** (swap clothes with the Alpha) and **নতুন কাপড় পরান** (fresh coastal outfit, e.g. after the removal procedure).
- **The Alpha chloroform power.** J order **ক্লোরোফর্ম দিন** on a conscious hostage: the Alpha presses a white cloth over the mouth and nose (~2.5 s) and the hostage goes **unconscious for 60 s** — silent (0 m voice and breathing), limp (head lolls, arms hang), no struggle while carried, no yes/no answers. They wake by themselves, by an Alpha / nurse order, or with the nurse's U menu.
- **The X-bed tie.** Every house now has its bed prop actually placed (two-storey houses get a ground-floor bed too; the story houses as well). J order **বিছানায় X-বেঁধে রাখুন** on an unconscious hostage: the Alpha lifts them, carries them to the nearest free bed (within 8 m) and straps them **spread-eagle on the mattress — both hands and both legs out to the four corner posts, the whole body an X** (`pose "bed_x"`, four corner straps). A bed-tied hostage must be untied (X hold, or the order) before carrying. Beds track their occupant.
- **The Matrix-style virus.** Another fixed ~25% of the captives carry a glowing green virus in the **head or the belly** (per-hostage marker + light). It drains 1 health every 6 s until extracted — left alone it downs and kills them. The extraction needs the hostage **unconscious and X-tied on a bed**: J order **ভাইরাস বের করুন** (or the nurse's U menu). After ~4 s the virus **comes out of the body** — a chrome-green spiked bug that hovers, wriggles and tries to slip away (15 s). Catch it: **E while looking at it**, or the extracting Alpha chases it down. Captured: +150 points, the hostage is cured (+25 health), and the virus goes into a **sealed containment jar** beside the bed. If it escapes, the hostage stays infected and the procedure can be repeated.
- **Nurse U menu:** বোম সরান (signed forms), ভাইরাস বের করুন, জাগান, চিকিৎসা (আহত / গুলিবিদ্ধ / the Freelancer +40), এখানে থাকুন / অনুসরণ.
- **HUD and debrief.** New chips: বোম left/total, ভাইরাস left/total, ভাইরাস ধরা, the nurse's current job. The debrief adds বোম নিষ্ক্রিয়, ভাইরাস ধরা, চিকিৎসা পদ্ধতি, ক্লোরোফর্ম and কাপড় বদল counts. Scores: defuse 200, virus capture 150.
- **Tests.** `tools/test/MedicalTest.tscn` runs headlessly in CI: the 25% rolls, beds in every house, the carrying block, consent → removal → garment transfer → defuse, chloroform silence, the X-bed straps, virus extraction + capture + jar, waking, untying and the clothes swap.

## 1. Premise
The "Kalo Chhaya" (কালো ছায়া, "Black Shadow") gang has kidnapped people across Dhaka (by default two women and two men per mission; the menu can make them all women or all men). Its people move arms through the river ghats, the diplomatic zone and the airport.

The player is **the Freelancer** (ফ্রিল্যান্সার). He is an unnamed rescue operative and is never called by a name. His face comes from the profile photo, `hero_1.jpg`.

HQ backs him with an **Alpha Team** of three, always including at least one **Alpha Team woman** (see 5.9, gender lock). Every mission ends the same way: every hostage must be loaded, tied and taped, onto that mission's exit vehicle.

## 2. Characters
| Role | Faces | Build | Notes |
|---|---|---|---|
| The Freelancer | `hero_*` (the profile photo) | average / athletic | olive tactical shirt, plate carrier, gloves, cargo trousers, boots |
| Alpha Team | `other_*` (AI faces of people who do not exist) or procedural | lean | navy uniform, black vest, cap |
| Gunmen | `profile_*` (AI faces) or procedural | heavy | T-shirts, jeans/cargo, bandanas/caps, AK-type rifles with wooden furniture |
| Villains | same as gunmen | heavy | black shirt and red bandana; they never shoot hostages (see 5.6) |
| Boss "Shokun" | `profile_*` | heavy | black, red beret |
| Alpha Team women | procedural (menu page "আলফা নারী দল") | tall (×1.08), athlete / wrestler build (`female_powerful`: broad deltoids and traps, big arms, heavy quads and calves) | short-sleeved shirt under the plate carrier; specially trained carriers — the only ones allowed to carry, tie and tape male hostages |
| Hostages | procedural, designed per hostage in the menu (জিম্মি ১–৪) | women: female; men: average | adults of different ages by default (slot ages ≈ 20s, 50s, 30s, 70s; grey hair for the oldest); women: salwar-kameez with dupatta, long hair / bun / plait; men: shirt-trousers, panjabi or vest-lungi; sandals |
| Residents | procedural | mixed, older | seated on plastic chairs by the stairs; neutral — nobody shoots them |
| Gang leaders | procedural | either gender (alternates per mission) | panjabi / dark kameez; surrender and get arrested (boss raid) |
| Civilians, VIP | procedural | mixed | panjabi + tupi, shirt + lungi, suit |

Builds: average, lean, heavy, **powerful** (men) and female, slim, strong, **powerful** (women); the height slider runs 0.90–1.12. Builds also set **strength** (how much a person can carry) and **mass** (how heavy a person is to carry). No real person's photo is used for anyone except the hero.

## 3. Controls
- **Movement and combat:**
  - WASD move · Shift sprint · Ctrl crouch · C/Q lean · Space jump
  - LMB fire · RMB aim · 1/2/3 weapons · R reload · V third-person camera
- **Interaction:** E interact. Held near a hostage, E removes or replaces her tape.
- **Hostage actions:**
  - F give water from your bottle
  - G pick up / put down a hostage. Up to two at once: one = pistol only, two = no weapon
  - X (hold) tie / untie
  - J call the nearest allowed Alpha member to the hostage and give her **orders** (menu, keys 1–6; see 6.1)
  - Y give a snack (from the vending machine) to a hostage whose tape is off, or eat it yourself; on an injured or wounded hostage, Y uses a first-aid kit
  - U the companion's menu (her / his skills; tape must be off) · O the gang's walkie-talkie (false order, needs the radio code) · Enter skip the briefing hostage
- **Phase 3 moves and gear:** Z prone (IGI-style crawl) · swimming (Space up, Ctrl dive, swim into a low bank to climb out) · 4 grenade · 5 Molotov · 6 time bomb (10 s) · Space opens the parachute on a jump
- **Recon:** B binoculars (12×, laser range and target type) · T thermal vision (white-hot) · N headphones (noise-cancelling: rain, street and ambience −6 dB, other effects −3 dB, voices clear)
- **Team and menus:** H Alpha Team follow / hold (releases carriers waiting for orders first) · K every carrier takes their hostage to the extraction vehicle · L call an Alpha woman by parachute (from the reserve) · Tab objectives · Esc pause
- **Phase 4:** I equipment shop (pauses; not under fire) · 7 which restraint kit the next strip of tape uses · M listen in on the gang's radio with your own walkie-talkie (patrol routes, the leader) · U also opens the doctor's menu

## 4. Core loop
1. **Infiltrate** (stealth: suspicion meter, noise, darkness, rain).
2. **Fill the water bottle** at a tube-well (টিউবওয়েল). The bottle starts empty and holds 3 drinks.
3. **Reach the hostages.** There are at least 4 per mission, kneeling, tied, with a small strip of tape over the lips.
4. **For each hostage:**
   - Peel the tape (E, hold) and give water (F).
   - She drinks, then tells **one clue**. A second drink gives her **second clue**, so 2 clues per hostage and 8 in total.
   - Tape her again (E) so her talking doesn't bring the gunmen.
5. **4 clues** unlock the objectives that depend on them; the HUD keeps a list.
6. Finish the mission's tasks (documents, tracker, explosives, boss...).
7. **Load every hostage**, tied and taped, onto the exit vehicle (boat, car, van, train, ambulance, plane, helicopter).

## 5. Hostage rules
### 5.1 States
`CAPTIVE` (at the spot where the gang left her) → `DRINKING` → `TALKING` → back to rest.

| State | Meaning |
|---|---|
| `WAITING` | Put down somewhere else |
| `RUNNING` | Untied: she bolts for cover |
| `CARRIED` | Over a shoulder |
| `BOARDED` | Safe on the exit vehicle |
| `DEAD` | **Mission failed** |

### 5.2 Noise
| Condition | Effect |
|---|---|
| Untaped | She talks every 5–10 s with her own Bengali voice: TTS pitch and speed per woman, plus different breath sounds. Gunmen within **10 m** hear her and come to look. Being overheard marks her as *exposed* for 15 s. |
| Taped | She only makes quiet breathing sounds, heard within 4 m. |

### 5.3 Safety
- Gunmen never shoot a hostage at her original spot.
- Once she has been **moved, untied or overheard**, any gunman who sees her opens fire.
- Hide hostages where enemies can't see them.
- Each hostage has 80 health.

### 5.4 Carrying (over-the-shoulder carry)
- **Position:** the hostage's hips sit on one of the carrier's shoulders, the torso hangs down the carrier's back, the legs hang down the front and the carrier's arm locks over the thighs just above the knees. Tied wrists stay behind the back; free arms hang loose; head, torso and arms swing slightly with every step.
- **Lifting:** the carrier squats with a straight back and the feet apart (one slightly ahead), takes the hips onto the shoulder, then stands by driving through the legs. The lift takes about 1–1.8 s depending on the load; the carrier cannot walk meanwhile.
- **Putting down:** the reverse — the carrier squats and the hostage slides off the shoulder onto the knees.
- **Load:** `load = hostage mass ÷ carrier capacity`. Capacity comes from the build, height and training (Freelancer and Alphas +15 %). Heavier loads mean shorter, flatter steps, a forward and sideways counter-lean and a slower walk (Freelancer 3.8 → 1.3 m/s). One person above 125 % or two above 170 % of capacity cannot be lifted.
- The Freelancer can carry **two** (one per shoulder): one = pistol only, two = no weapon. Each Alpha carries one.
- Nobody is carried through water; if a carrier dies, the hostage is put down where the carrier fell.

### 5.5 Untying
Untying a hostage makes her **run** 14–22 m for cover. She can get hurt, so clear the area of gunmen and villains first.

### 5.6 Villains
- Two red-bandana villains per mission. They never shoot hostages.
- They pick up any rescued hostage they see and carry her **back to her original spot**, where they tie and tape her again.
- If a villain sees the Freelancer or an Alpha, he drops her and fights.
- Only villains, the Freelancer, the Alphas and hostages enter houses. Gunmen stop at the door and shoot through windows; one villain watches the street from an upper window of each house.

### 5.7 Boarding
A hostage is accepted onto the exit vehicle only if she is **tied and taped**. Alphas do this themselves; the Freelancer must put her down (G), tie her (X), tape her (E) and pick her up again.

### 5.8 Reward
The first time a hostage's tape comes off, she or he gives **৳100** if never fired on. The total appears on the HUD and the mission summary. Snacks cost ৳20; a hungry hostage (tape off) eats one with Y and is healed and calmer.

### 5.9 Gender lock
> **Phase 5:** replaced by the opposite-gender rule (0.3). The table below is the Dhaka-era lock.
| Who | Woman hostage | Man hostage |
|---|---|---|
| The Freelancer (and any man or woman outside the Alpha women) | carry, tie / untie, tape / untape, water | water only (once the tape is off) — **cannot** carry, tie or tape |
| Alpha Team woman | everything, on the Freelancer's order | everything, on the Freelancer's order |
| Villains | drag her back to her spot | leave him alone |

So every mission needs at least one Alpha woman. One always starts in the team; L drops another by parachute from the reserve.

### 5.10 Sounds
All hostage sounds follow the hostage's gender (women: ~210 Hz voice, higher formants; men: ~115 Hz): breathing, nose breathing while taped, sighs, gasps (lifted, tape peeled), coughs, relief, drinking, and the text-to-speech pitch. Taped hostages make no voice sounds, only breathing through the nose and shifting against the ropes.

Tape removal uses six short recorded rips cut from one duct-tape recording (`assets/audio/sfx_tape_rip_1..6.wav`). The rip starts while the strip is coming off (from 12 % of the peel), never repeats the previous take, and is pitched ±6 % per hostage. The gasp and relief sounds follow once the tape is off. Source recording: `kai_audio-duct-tape-rip-471490` (supplied with this round); keep its licence terms with the project.

When a woman who is not taped is lifted onto the shoulder she gives a short startled cry (`assets/audio/sfx_lift_cry_f.wav`, a recorded clip supplied by the developer, pitched ±4 %). Taped women and all men keep the breath gasp.

#### Custom sounds (Sounds tab, `sounds` folder)
Every sound in the game can be replaced with your own file: put `<name>.mp3`, `.ogg` or 16-bit `.wav` in a `sounds` folder next to the exe, or use **চরিত্র সাজান → শব্দ**, which copies the chosen file into `user://sounds`. The tab has a ▶ button to listen and ✕ to go back to the built-in sound; ambience loops change on the next start.

Hostage moments have their own slots, one per gender. A file without `_f` / `_m` (e.g. `sfx_carry_down.mp3`) serves both. These play from the hostage's head and move with the body while carried. Empty slots keep the built-in sound.

| Slot | When it plays | Built-in when empty |
|---|---|---|
| `sfx_carry_start_f` / `_m` | the moment the lift onto the shoulder starts | startled cry (untaped woman) or breath |
| `sfx_carry_down_f` / `_m` | the moment the kneel-down from the shoulder starts | soft exhale |
| `sfx_gagging_f` / `_m` | while the strip of tape is being put on (gagging) | nothing (the tape sound stays) |
| `sfx_after_tape_on_f` / `_m` | 0.15 s after a strip of tape goes on (the tape sound stays) | nothing |
| `sfx_after_tape_off_f` / `_m` | as soon as the tape is off (the rip stays) | gasp, then a relief breath |
| `sfx_new_info_f` / `_m` | a carried hostage remembers something and taps the Alpha's back (6.10) | silent (only the tap) |
| `sfx_intel_signal` (`_f` / `_m`) | **Phase 4 intel beacon**: a hostage who remembered something signals every 9–14 s (6.12); gunmen within 12 m hear it | heel knocks on the floor (`assets/audio/sfx_intel_signal.wav`, made by `tools/generate_phase4_audio.py`) |

The game ships with these slots empty; the files are the player's own.

## 6. Alpha Team
- 3 Alphas at the start of every mission.
- **One reinforcement pool of 3**: each fallen Alpha is replaced after 12 s until the pool is empty.
- Alphas follow in formation or hold (H), give covering fire and drop ammo kits.
- Alpha women: tall, powerfully built, trained to lift and carry adults of either sex; the only team members allowed to handle male hostages (5.9).
- Tube-wells are a two-person job: when you hold E, the nearest free Alpha comes and works the handle (1.5 s); alone it takes 5 s.

### 6.1 Orders (the Freelancer commands, the Alpha asks and confirms)
The Alpha never acts on a hostage by herself. Every step is ordered:
1. **J** on a hostage → the nearest allowed Alpha says "আসছি, স্যার!", walks over, kneels and asks **"কী আদেশ, স্যার?"**. The order menu opens.
2. Orders (keys 1–6): **tape off / tape on**, **untie / tie**, **water and listen** (needs the tape off; uses her bottle), **lift onto the shoulder**, **dismiss**.
3. She confirms out loud ("জি স্যার, টেপ খুলছি।"), does it, and asks again ("আর কী আদেশ?").
4. After **lift** she stands and **waits** for orders with the hostage on her shoulder. J (near her) reopens her menu: **put down** (she kneels, puts the hostage down and asks again), **follow me**, **wait here**, **take to the extraction vehicle**. K sends every carrier to the vehicle; H makes waiting carriers follow.
5. At the vehicle she ties and tapes the hostage herself before loading — that is part of the extraction order.

## 6.2 Houses, residents and side missions (Phase 3)
- Houses follow the common Dhaka type: RCC frame with brick infill, often plastered and painted; painted M.S. steel grills and a concrete sunshade (chhajja) over every window; a stair hut (chilekotha) and a black water tank on the roof.
- A steel **collapsible gate** locks the stairs on the ground floor. A **resident** sits beside it on a plastic chair and asks a **BCS-style MCQ** (E, then keys 1–4). Right answer → the gate opens; wrong → the right answer is told and another question comes after 8 s. Grenades and time bombs can also blow the gate open (loudly). The question bank (`scripts/world/BCSQuestions.gd`) only uses settled facts.
- Stairs lead up to the roof.
- **Boss raid:** the gang leader (a man or a woman, alternating by mission) waits upstairs in the first house. Cover them with your aimed weapon from within 8 m (or wound them badly) and they surrender with hands up. Hold X to handcuff, then they walk behind you. A helicopter comes to the roof; take the prisoner up and they board for interrogation (৳500). Killing the leader fails this side mission.
- **Weapons cache** upstairs in the second house: destroy it with a grenade, a Molotov fire or a time bomb (৳300).
- **Snack machines** by the house doors (৳20).

## 6.3 Ammunition, surrender, prisoners
- Ordinary gunmen carry limited ammunition (rifles 2 magazines, pistols 3; each starts with a random amount). When a gun runs dry the gunman shouts, stops shooting and runs to the nearest **গুলির বাক্স** (gang ammo crate, up to 3 per mission) to restock for 3 s.
- Caught with an empty gun within 6 m of the Freelancer or an Alpha member, he surrenders with his hands up. Hold **X** to handcuff him; he then walks behind the Freelancer. Hand him over at the extraction vehicle for ৳150.
- Grenades, Molotovs and time bombs destroy ammo crates. Once the crates are gone, empty gunmen have nowhere to go.
- Snipers, the boss and gang leaders have unlimited ammunition (leaders surrender by their own rule, 6.2).
- **Surrender pose:** kneeling, fingers laced behind the head. Once cuffed, the hands are behind the back and the prisoner stands and walks.
- **Shouting:** a gunman who spots the team shouts ("ওই যে! ধর ওকে!"), and every gang member within 40 m comes. A cuffed prisoner left unwatched shouts for help every 7–14 s, sooner when gang members are near.
- **Keeping a prisoner quiet:**
  - Keep them covered (aimed weapon within 12 m, facing them), or stay right beside them.
  - Or press **J** on the prisoner: the nearest free Alpha takes them in a police escort grip (one hand on the cuffed wrists, one on the upper arm) and walks beside them.
  - Prisoners are never gagged or carried.
- **Interrogation (E on a cuffed gang member):** after some denial the prisoner gives up the gang leader's hiding place. The leader is marked on the minimap (purple) and above the head.

## 6.4 Micro-animations
- **Tape:** the strip peels progressively from one corner, curling back over itself while the rest stays stuck; putting it on is the reverse. Progress follows how long E is held, or the Alpha's order timer. The hostage pulls the head back. The lips and the skin around them stay faintly red for ~30 s after the tape comes off.
- **Rope:** loops loosen and slide down the wrists and ankles when untied, and pull tight when tied.
- **Hands:** an Alpha's hands go to the mouth (tape) or the wrists (rope) and work there; the Freelancer's body does the same in third person, and his weapon is lowered meanwhile.
- **Reload:** the gun tilts to the magazine well, the old magazine drops out, a fresh one goes in and is seated, then the charging handle or slide is racked. Each step has its own sound.
- **Carry:** the carried body rolls with each step and bounces harder when the carrier runs.
- **Hostages kept together:** they turn to look at each other, hold eye contact and nod, breathing through the nose. There are no voice sounds while taped.
- **Looking at the work:** whoever tapes or ties turns the head to the mouth / wrists; hands move out along an eased curve, stay while the job lasts and pull back. In first person the view drifts gently onto the spot while E / X is held.
- **First-person carry:** parts of the hostage closer than 0.8 m to the camera fade out with a stipple, so the load on your own shoulder never fills the screen from inside. Looking down you see the legs hanging. The slung rifle hangs muzzle-down on the back, away from the load.

## 6.5 Boarded hostages
Hostages already in the extraction vehicle who still have clues can be untaped (E, or an Alpha woman for men), given water (F) and heard.

## 6.6 Custom 3D models (.glb / .gltf / .fbx)
- Put a rigged human model in a `models` folder next to the exe (or `user://models`, or `assets/models` before building), named after the role: `hero`, `ally` (Alpha men), `villain`, `boss`, `civilian`, `vip`.
- The model needs Mixamo-style bone names (with or without the `mixamorig` prefix).
- It is scaled to the rig's hip height and turned to face the right way.
- Every frame the skeleton is posed from the invisible procedural rig:
  - limbs are aimed along the rig's limbs;
  - hips, spine, neck and head copy the rig's rotations;
  - the hips follow the rig's height.

  So every animation, from walking to aiming, kneeling, surrendering, reaching and carrying, drives the model.
- Hostages and Alpha women keep the built-in bodies.

## 6.7 Recorded Bengali voices
`tools/list_voice_lines.py` writes `tools/voice/voice_lines.csv` with every fixed line and its file key (`line_` + the first 10 hex digits of the MD5 of the text). Recordings named `<key>.ogg` (or `<key>_f` / `<key>_m`) in `voice_bn` next to the exe, or in `assets/audio/voice_bn`, replace text-to-speech. Lines built at run time stay on TTS.

## 6.8 Companions (Phase 3h)
Every mission opens with two hostages the Alpha Team freed on the way in, a woman and a man, whose husband or wife is still held. They will not leave without them, so they stay with the Freelancer and help. One is a **nurse** who also saw the gang leader; the other is a **school teacher** who knows the area and every house. Which of the two has which job changes from mission to mission.

They walk behind the Freelancer, crouch when he crouches, take cover while shooting is near and stay put on "wait". Gunmen do not single them out until they are overheard or a fight starts nearby. Moving with the team, they keep tape on their mouths (the stealth rule), so the Freelancer, or an Alpha woman for a man, takes it off before they can help. **U** opens their menu:

| Skill | Who | What happens |
|---|---|---|
| First aid | nurse | treats an injured or wounded hostage within 3.5 m |
| Patch the Freelancer | nurse | +40 health, once a minute |
| Point out the leader | nurse (witness) | within 35 m: the leader is marked on the map |
| Talk down Raju | teacher | a young gunman, the teacher's former student, puts his gun down (then cuff him, X) |
| Show the guards | teacher | every gunman within 55 m is marked on the map for 45 s |
| Mains off | teacher | at a house's meter box: 90 s of darkness inside; gunmen there see less than half as far |
| Phone the spouse | both | with the phone the briefing hostage gave: a whispered reply locates the spouse and marks the guards |
| The second BCS question | teacher | standing by a resident (tape off), the teacher knows the answer (option 5) |
| Tube-well | both | works the second handle |
| Stay here | both | sits on a friendly resident's bed or kneels in a safe container (safe) |
| Board | both | in the safe zone; a companion refuses to leave while the spouse is still held |

**Spouses.** The two spouses are held apart, upstairs in a guarded house, and stay off the map until a phone call or someone within 12 m finds them. When a companion reaches her or his spouse, they are reunited. The spouse tells what she or he overheard (the next piece of intel, 6.10), and from then on, once untied, follows quietly instead of running.

## 6.9 Shelters, residents and special hostages (Phase 3h)
- **Residents** ask two BCS questions. Two right answers open the gate, make them friendly, and earn a gift (a first-aid kit and two snacks). A friendly resident's **bed** is a shelter: an untied hostage put down by it sits on the bed and is given water, food and first aid, and counts as safe. Residents never take a tied person into their bed.
- **Safe container.** A walk-in shipping container with open doors stands part-way between the insertion point and the captives (a blue outline on the map). Hostages put down inside kneel out of sight and count as safe.
- **Heavy hostage.** A big, heavy-set woman (about 110 kg). The Freelancer cannot lift her. An Alpha calls a second one, and the two carry her on their joined hands (seat carry) with her arms over their shoulders, at 70 % speed. The heavy Alpha woman (6.11) can carry her over the shoulder alone.
- **Injured hostage.** Shot in the leg before the rescue: untied, he sits and cannot walk. Treat him with a first-aid kit (Y), the nurse or a resident's bed, or carry him.
- **Wounded hostages.** A hostage hit by gunfire falls and bleeds for 90 s (shown on the HUD; the map dot flashes). A free Alpha the gender lock allows runs over by herself, presses a bandage on the wound and carries the hostage to the nearest safe container or the vehicle. Y with a kit or the nurse also stop the bleeding. A hostage who bleeds out fails the mission, as any hostage death does.
- **Booby-trapped hostage.** A tripwire runs from her rope to a flash-bang. Take the tape off first and she warns you; then hold X to cut the wire (3 s) before untying. Untying first sets it off: a deafening bang every gunman around hears, and 18 damage up close.
- **The mole.** One "hostage" is a gang informer posing as a captive. Untape him before he is exposed and he shouts for the gang; untie him and he shouts and runs. Exposed by the intel, hold X to handcuff him (৳150). He never counts towards the rescue.
- **CNG driver.** Untied, she walks to her CNG auto-rickshaw, parked near the captives. Hostages put down beside it climb into the back (three seats). E on the CNG sends it off to the police cordon, where all of them are safe.

## 6.10 Briefing hostage, news and orders (Phase 3h)
- **Briefing.** At the start, an Alpha woman arrives with a man who escaped the gang overnight. He gives a fast briefing (where the captives are, the spouses, the heavy hostage, the captured Alphas, the mole) and hands over his phone. Enter skips the briefing; its key clue is still added. The Alpha then tapes him for the walk, carries him to the safe container and joins the team.
- **News on the shoulder.** One hostage, carried by an Alpha for a while, remembers something. She or he taps the Alpha's back with bound hands, and the custom `sfx_new_info` sound plays if set. The Alpha asks permission: **yes** = she puts the hostage down, takes the tape off, listens, tapes again and lifts again; **not now** = she keeps a safe distance behind the Freelancer and asks again 30 s later. The intel comes in this order: the cage **key** (marked on the map), the guards' **shift change** (a timer on the HUD: every 2½ minutes the guards leave their posts for 22 s), the gang's **radio code**, and who the **mole** is. Reunited spouses also share intel.
- **Radio code (O).** Once the code is known and you have a walkie-talkie (the first gunman to fall drops one), O sends a false order. For 40 s, every gunman within 75 m who is not fighting walks 55 m away. It works once.
- **New Alpha orders** (J): go to the spot the Freelancer is looking at and stay there; follow at a distance or close by; lift a heavy hostage with a second Alpha; bandage a wound; the yes / not-now news answers.

## 6.11 Captured Alpha members (Phase 3h)
The gang holds two Alpha members in a locked cage on a ground floor: a **heavy Alpha woman** and an Alpha man. The cage key lies in the gang leader's room; with it, E opens the cage silently. Without it, hold E for 6 s to cut the lock (loud). Untie them and they rejoin the team armed. The man is male, so an Alpha woman unties him. The heavy Alpha woman has 260 health (others 160), is bigger (scale 1.12) and can carry the heavy hostage alone.

## 6.12 Stealth economy, intel beacons, archetypes and the physical carry (Phase 4)
### Restraint kits (Acoustic Dampeners) and the shop
> **Phase 5:** no shop, no money, no stock — the four kits are now free, unlimited tape types (0.4) and rewards are points (0.6).
- Every **fresh strip of tape** the team puts on (the Freelancer's E, an Alpha's tape order, re-taping after news, taping at the vehicle) takes **one restraint kit** from the stock. With none left, the strip cannot go on (the prompt and the Alpha say so). The gang's own tape (villains) costs nothing. The rope never leaves the hostage, so tying again is free.
- A kit is a strip of acoustic tape plus a **damping pad that stays with the hostage** until another kit replaces it. It scales how far gunmen hear her: `TALK_NOISE` (voice, tape off, 10 m) and `MUFFLE_NOISE` (breathing, shifting and struggling, tape on, 4 m).

| Tier | Kit | Cost | Jam level | Voice heard within | Breathing / struggling heard within |
|---|---|---|---|---|---|
| — | the gang's tape | — | none | 10 m | 4 m |
| 1 | বেসিক রেস্ট্রেইন্ট — Basic Restraint | ৳50 | Low | 8.5 m | 3 m |
| 2 | স্ট্যান্ডার্ড রেস্ট্রেইন্ট — Standard Restraint | ৳100 | Medium | 7 m | 2 m |
| 3 | অ্যাডভান্সড রেস্ট্রেইন্ট — Advanced Restraint | ৳250 | High | 5.5 m | 1.2 m |
| 4 | ট্যাকটিক্যাল রেস্ট্রেইন্ট — Tactical Restraint | ৳500 | Maximum | 4 m | 0.5 m |

- **Shop** (I in a mission, or **সরঞ্জামের দোকান** in the main menu): the four kits and **medkits (৳75)**. In a mission the game pauses while it is open; it will not open under fire (hit in the last 4 s or a gunfight within 30 m). Keys 1–4 buy a kit, 5 a medkit; "ব্যবহার করুন" (or 7 in the field) picks the tier used next; when it runs out the nearest cheaper tier is used, then a dearer one.
- **Wallet:** money and kits are kept between missions (`user://economy.cfg`). A new save starts with ৳300 and three Basic kits. Rewards (৳100 per hostage, arrests ৳150, the leader ৳500, the cache ৳300, the gang's hidden cash ৳150) go straight into the wallet; the vending machine also takes from it. **What is earned or bought in a mission is kept only if the mission succeeds**; a restart, a failure or quitting to the menu rolls back to the last success. At the start of every mission HQ tops the stock up to at least 2 Basic kits and 1 medkit, and if the team has no kit and cannot afford a Basic one at the extraction vehicle, the vehicle's police crew lends a strip, so a mission can never get stuck.
- The HUD shows the kits, medkits and money above the status panel; hostage labels show the kit on them ("টেপ (কিট ২)"); the debrief shows purchases and kits used.

### Intel beacon
- A **rescued** captive (moved from the holding spot; not the companions, the briefing hostage, the mole, the news hostage or captured Alphas) remembers something now and then (first after about 1–2 minutes, then every 1½–2½ minutes), as long as there is something left to remember; at most two signal at a time.
- She cannot speak, so she **knocks her heel on the floor** every 9–14 s (custom slot `sfx_intel_signal`, per gender `_f` / `_m`), the sound moving with her body. **Gunmen within 12 m hear it and come to look** (also while she is carried). The HUD marks her: a ring with signal waves over her head, or an arrow at the screen edge with the distance; her minimap dot gets a pulsing ring.
- To hear it: take her to a **safe zone** (the extraction vehicle, a safe container, a resident's bed or the extraction area), peel the tape off and listen; anywhere else she whispers that she will only say it somewhere safe (and is overheard). Then put a new strip on (another kit) to hide her again.
- What they remember: first the gang's secrets (the cage key, the shift change, the radio code, the mole - the same list the news hostage and spouses draw from), then: the **patrol routes** (60 s on the minimap), the gang's **hidden cash** (৳150, a gold mark on the map), where the **snipers** are (90 s) and the **leader's** room.

### Wounded, heavy and the archetypes
- **Wounded:** a shot hostage bleeds out for 90 s. **A medkit stabilises** her / him (Y; an Alpha uses one of the team's medkits - without one she keeps pressure on the wound, which halves the bleeding, and asks for one; the nurse companion, the doctor or a resident's bed also work). **Before that nobody can lift her.** Once stabilised, the Freelancer or an Alpha carries her out, and she **boards without rope or tape**.
- **Heavy:** the heavy-set hostage weighs about 110 kg; one Alpha cannot carry her - two Alphas seat-carry her, or the captured elite Alpha woman carries her alone.
- **The VIP (a foreign diplomat):** held with the captives (dark suit or formal kameez, a purple ring on the minimap). The gang wants him / her alive and **never shoots** the VIP, but a gunman who **sees the VIP away from the holding spot** (carried or not) raises his radio: stop him within **2.2 s** (kill him or make him surrender) or a **reinforcement squad of three** comes for the VIP (at most three squads, 45 s apart). Keep the VIP out of sight: behind cover, inside containers, at night, past the gunmen's backs. Villains do not drag the VIP back.
- **The doctor (ডা.):** a captive. **Untied and untaped in a safe zone** (X may untie her even on the vehicle or in a container) she offers, with **U**: treatment for the Freelancer **(+50 health, once a minute)**, **medical supplies once (2 medkits)**, and first aid to a hurt hostage next to her.
- **The captured Alpha (elite):** unchanged from 6.11 - the heavy Alpha woman in the cage joins with 260 health and carries heavy hostages alone.

### Residents and the walkie-talkie
- Each resident asks **1, 2 or 3** BCS questions (rolled per resident) in their own words; the options are reshuffled every time, the questions come from the bag without repeats, and the wait after a wrong answer varies (6–12 s). **Every right answer earns a gift: a Standard (tier 2) restraint kit or a medkit**; after the last one the gate opens and the resident becomes friendly as before (bed, first-aid kit and snacks). The teacher companion helps with the last question.
- **M - the Freelancer's own walkie-talkie:** 3.5 s of listening in on the gang's channel; then every patrolling gunman's **route** is drawn on the minimap for 60 s and the **leader / boss** is marked (if alive). 50 s before the channel can be tried again. The false order (O) still needs a captured gang set and the radio code.

### The physical over-the-shoulder carry (CharacterModel `carry_*`)
- **Inertial weight:** the hanging body is a damped pendulum about the hip joint on the carrier's shoulder. It swings out from his back when he starts or speeds up, comes back against it (and bounces off - it never passes through him) when he stops, rolls to the outside of turns and with each step. Heavier people swing slower; running lowers the damping, so the bounce gets heavier and looser. A soft contact spring lets the hips lift off the shoulder at each running step and land again, jolting the torso and swinging the shins.
- **Head tracking:** a two-joint look-at (chest 25 %, neck and head 75 %, within joint limits) towards the nearest gunman, the camera or a scan of the surroundings, switching every 1–3.5 s; it lags his momentum, rises with each bounce, moves with the breath and pitches back (the face comes round towards the camera) the faster he runs. Blinking and breathing now go on while carried.
- **Hand grip:** each frame the carried body reports where the carrier's wrist goes so the palm rests on the **cloth over the front of the thighs just above the knees** (thigh radius from the build and the trousers' looseness + fabric + hand); the carrier's arm on the loaded shoulder reaches it with two-bone IK (left or right shoulder), so the hand rides the bounce and the kicks instead of floating or sinking in.
- **Struggle:** right after the lift (about 3 s, fading) and in short bursts whenever the player's camera is not on her, she kicks from the knees (both legs together while the ankles are tied), twists and shakes her head, pushing the pendulum; each burst makes muffled sounds and a little noise (her kit's `MUFFLE_NOISE` × 1.3). Calm companions, the wounded and captured Alphas do not struggle; carried off by a villain, she fights the whole way.
- Unchanged: every mesh (tape strip, ropes) and every sound file (tape rips, tape on, carry start and the other slots).

## 7. Missions
Phase 5: besides the house and container hostages of 0.2, each mission has 15 people from the earlier design: 9 captives (two spouses, a booby-trapped hostage, an injured one, a heavy one, one who remembers something, a CNG driver, the VIP diplomat and the doctor), 2 companions, the briefing hostage, the mole and the 2 captured Alphas. There are also 2 tube-wells, 2 villains, a safe container, a cage, guard posts with shift changes, a CNG and the young gunman Raju. Missions without houses (mall, ship) skip the residents, beds and meter boxes. The first clue is the mission's key clue; the rest come from the map: exit direction, enemy count, villains, snipers, water, rules.

| # | Title | Place | Time / weather | Map | Exit vehicle |
|---|---|---|---|---|---|
| 1 | লাবণী পয়েন্টের রাত — Laboni Point Night | Laboni Point | night, clear | beach strip | police speedboat |
| 2 | কলাতলীর সৈকত-বাড়ি — Kolatoli Beach Houses | Kolatoli | day, haze | beach strip | police van |
| 3 | সুগন্ধার সূর্যাস্ত — Sugandha Sunset | Sugandha Point | sunset → haze | beach strip | tourist police car |
| 4 | হিমছড়ির কুয়াশা — Himchari Fog | Marine Drive, Himchari | foggy morning | cliffs | police van |
| 5 | ইনানীর পাথুরে তীর — Inani Rocks | Inani beach | dawn, mist | coral rocks | police speedboat |
| 6 | বাঁকখালীর মাছঘাট — Fishery Ghat | Bakkhali fishery ghat | day, haze | harbour | police trawler |
| 7 | মহেশখালী জেটি — Moheshkhali Jetty | Moheshkhali | evening | long jetty | police speedboat |
| 8 | সোনাদিয়ার রাত — Sonadia Night | Sonadia island | night, light rain | island | police speedboat |
| 9 | পতেঙ্গার কন্টেইনার ইয়ার্ড — Patenga Container Yard | Patenga, Chattogram | dusk, haze | container port | police van |
| 10 | সাবরাংয়ের ঝড় — Sabrang Storm | Sabrang, Teknaf | stormy night | beach strip | police trawler |
| 11 | সেন্ট মার্টিনের শেষ লড়াই — Saint Martin's Final Stand | Saint Martin's island | dusk, light rain | island (boss) | rescue helicopter |

## 8. Character customisation (main menu → চরিত্র সাজান)
Four tabs, each with a turning 3D preview: the Freelancer, Alpha Team, enemies and villains, hostages.

| Option | Choices |
|---|---|
| Gender | male / female for the hero; male / female / mixed for Alpha Team and enemies. **Hostages are always women.** |
| Outfit | 3 per role (e.g. tactical / casual / panjabi; navy police / black commando / khaki; salwar-kameez / shirt and trousers / borka and hijab) |
| Skin tone, height | sliders (height 0.92–1.08) |
| Hair colour, hair style | black, dark brown, brown, grey, henna; short, medium, long open, bun (খোঁপা), plait (বেণী) |
| Build, beard | men only |
| Headwear | none, cap, bandana, beret, tupi, hijab, helmet |
| Colours | own shirt and trouser colours (toggle) |
| Face shape (every role) | face width, jaw, chin, cheekbones, eye size, eye spacing, eye tilt, brow arch, nose width, nose length, lip fullness, mouth width (sliders), age (young → old: wrinkles, deeper folds, grey brows), brow thickness, eye colour |
| Make-up and jewellery (every role) | lip colour (natural, pink, red, maroon, nude), kajal, blush, teep / bindi, nose pin (নাকফুল), earrings (studs / jhumka), beauty spot (তিল) |
| Face image | hero, Alpha Team and enemies only: "মুখের ছবি যোগ করুন…" copies the picture to the game's `faces` folder with the right prefix (`hero_`, `other_`, `profile_`) |

**Hostages:** the hostage tab has five pages — **সবাই** (shared by all hostages) and **জিম্মি ১–৪**. A mission's 1st–4th hostage uses look 1–4 (the 5th uses look 1 again); a value set on her own page wins over the shared page. Hostage faces are always built from these controls, never from photos. Untouched controls show the face that hostage already has, so every hostage looks different even before customising. "এলোমেলো মুখ" rolls a new random face for the current page; "মুখ কাছ থেকে দেখুন" zooms the preview onto the face (it also zooms automatically when a face control changes).

For the Alpha Team and gunmen the face controls set the team's typical face; each member still varies a little around it. Choices are saved in `user://characters.cfg` (sections `hero`, `ally`, `villain`, `hostage`, `hostage_1` … `hostage_4`). Without a face image, every character gets a procedural face.

### 8.1 Photo alignment (3 points)
Choosing a photo (hero, Alpha men, villains — the roles in `FACE_PREFIX`) opens the alignment window at once. Instructions at the top say which point is next:
1. Click the eye on the left of the picture (green ring).
2. Click the eye on the right of the picture (blue ring).
3. Click the centre of the mouth (orange ring).

Right click or **এক ধাপ পিছনে** removes the last point, **আবার শুরু (রিসেট)** clears all three, and a fourth click starts again. Clicks that cannot be a face (eyes too close, mouth far off to one side or level with the eyes) are rejected with a message.

The maths (`scripts/actors/FaceAlign.gd`, plain GDScript, no external tools):
- **Angle:** `atan2` of the vector from the left eye to the right eye; the photo is rotated by minus that angle, so the eye line becomes level.
- **Scale:** one uniform factor, 136 px divided by the distance from the eye midpoint to the mouth (measured square to the eye line). Width and height always use the same factor, so the face is never stretched.
- **Offset:** the eye midpoint is moved to (256, 246) of the output, the head's eye position.
- These three make one `Transform2D` (photo px → output px). `render_aligned()` crops the photo to the area it needs (`Image.get_region`), shrinks it first if it is much larger (Lanczos), then resamples it through the inverse transform (bilinear) into a straight **512 × 512** image.

A live preview shows the straightened result with guide lines (eye line, mouth mark, the head's face oval), plus the rotation and scale. **সংরক্ষণ** saves the 512 × 512 face as `user://faces/<prefix>_customN.png`, keeps the original in `user://faces/src/` and writes the three points and the `Transform2D` to `user://faces/align.cfg`. The face appears on the 3D head immediately. **আবার মেলান** reopens an aligned face on its original with the earlier clicks; **মুছুন** removes the face, its original and its alignment.

On the head, `face.gdshader` maps the photo with a strict planar front projection through one `face_xform` matrix (scale, rotation, offset — built from the same `Transform2D`), fades it softly into skin at the face oval and at the image borders (`edge_fade`), and never bends or stretches it. Photos added another way (copied into the faces folder, or prepared with the optional `tools/prepare_faces.py`) use their old `fit.cfg` points or a default placement through the same matrix, and can be aligned in the menu at any time.

Hostages and Alpha women always use generated faces. These are the roles that are bound, or that carry and handle bound people, and a real person's photo — famous or private — must not end up there without their consent. A celebrity detector would not cover private people and cannot ship inside the game, so photo import is simply not offered for these two roles.

## 9. Technical notes
- **Character rig:** a procedural anatomical rig (`CharacterModel.gd`):
  - Lofted super-ellipse segments from measured cross sections (front / back depth, centre offset, squareness per ring): trapezius slope, deltoid caps, pectorals, ribcage, waist, iliac crest, glutes, quadriceps with inner-thigh mass, kneecaps, calves, tibia, ankles.
  - Hands with palm, thenar pad, four jointed fingers and a thumb (curled round the rifle grip / bottle); bare feet with an arch and five toes, sandals with a toe post; mirrored left / right.
  - Clothing details: collars, plackets and buttons, pockets, cuffs, belt, plate carrier with straps and pouches, kameez with an embroidered neckline and hem border, dupatta (orna) draped across the chest, lungi knot.
  - Two-bone IK for both legs (planted feet, kneeling) and both arms (rifle grip, drinking, tied wrists).
  - One draw call per body segment. Beyond 14 m the head, hair and hands switch to light versions (visibility ranges). Meshes are cached; crowds share 10 face shapes per role. About 11 ms to build a character.
- **Head:** a high-resolution sculpted skull (warped grid, densest round the face): brow ridge, eye sockets and lids, nose bridge, tip and alae, cheeks, lips, mentolabial groove, chin, jaw angle, occiput — all driven by the face-shape controls. Separate ears (helix, lobe, tragus), a hair shell that follows a natural hairline (temples, sideburns, nape), long hair / bun / plait, jewellery. `face.gdshader`:
  - Projects the photo flat from the front through one scale/rotate/offset matrix (`face_xform`), with a soft fade at the face oval and image edges, an unsharp mask and rejection of background pixels.
  - Blends the photo into skin and hair colours sampled from it.
  - Without a photo it paints a matching face: iris, lids and lashes, kajal, brows, nostrils, lips with lipstick, blush, age lines, teep, beauty spot.
- **Body shader:** `character.gdshader`. Vertex-colour material IDs cover skin (translucent warm rim), hair (strand sheen), metal / gold, leather/tape and cloth: plain (weave + fold relief), check (lungi) and printed (kameez, dupatta).
- **Sound:** every sound is synthesised offline, so there are no recordings and no licences. `tools/generate_audio.py` and `tools/generate_hostage_sfx.py` made the original set. `tools/generate_phase3_audio.py` adds:
  - (Dhaka phases only — not used on the coast:) traffic with horns and rickshaw bells, crows, rain on tin roofs, thunder.
  - Explosives, gunshot echo tails (street slap-back or a short room), splashes and swim strokes, parachute and plane, helicopter, vending machine, MCQ chimes, handcuffs, door, chair, radio.
  - Gendered human non-speech sounds made from a glottal source through vowel formants.

  Any file can be replaced by a recording (`.ogg`, `.wav` or `.mp3`) with the same name in `assets/audio/`. Suitable CC0 libraries include freesound.org (filter: CC0), Sonniss GDC bundles and BBC Sound Effects (personal use only).
- **Face realism pass:**
  - Warm, slightly veined sclera instead of white.
  - Pink tear ducts, finer eyelashes.
  - Softly shadowed nostrils instead of black dots.
  - Skin pore bump up close, warmer translucency at the silhouette, less flat self-lighting.
  - The hair shell no longer shadows the face.
  - Grey cloth duct tape with a woven texture and a satin sheen.
- **Phase 3 audio buses:** headphone mode changes the bus volumes; a low-pass filter on Master applies while the head is under water.

## 10. Production phases
- **Phase 5 (this delivery) — Cox's Bazar:** section 0 — the coastal maps and missions, beach houses and walk-in containers with 30+ seated hostages, the two-minute room timer, noise levels, yes / no questions, visitors captured by villains, senior guards and the tourist police, the opposite-gender rule with the Alpha women's hand over the mouth and silent takedown, the downed Freelancer carried to safety, unlimited tape with four types, the score, character slots for faces, your own sound clips for tape / carry / yes-no, no ambience and no voices, and the new coastal UI.
- **Phase 1:** GDD; faces; character rig and shaders; hostage system; clues, water, villains and reinforcements; rename.
- **Phase 2 (this delivery):**
  - Character customisation menu (section 8).
  - B binoculars with rangefinder; T thermal vision; rotating minimap (buildings, team, hostages, spotted enemies, water, exit, objective).
  - Two enterable two-storey houses per outdoor mission: door, real window openings, stairs, hallway, lit rooms, roof parapet; gunmen kept outside; villain window posts.
  - Bengali posters, wall writing, cloth banners and overhead wire tangles on every street.
  - `SilentRescueCoxsBazar_HQ.bat`: Forward+ renderer with real SSAO, volumetric fog and glow.
- **Phase 2 (original plan, for reference):**
  - Combat and tools: ADS polish, binoculars (B) with range, thermal (T), detailed weapon models, minimap.
  - Interiors: multi-storey buildings you can enter (stairs, doors, windows); villains-only house access; AI cover and shooting from windows.
  - Dressing: Bengali posters, graffiti, banners and wires; volumetric fog and SSAO.
- **Phase 4 (this delivery):** the stealth economy - four tiers of restraint kits (Acoustic Dampeners) that scale `TALK_NOISE` / `MUFFLE_NOISE`, the shop (I and main menu), a persistent wallet and medkits; the intel beacon with the `sfx_intel_signal` sound slot, HUD and minimap markers, gunmen investigating it and listening in a safe zone; wounded hostages must be stabilised with a medkit before they are lifted and board without restraints; the VIP diplomat (reinforcements when seen) and the doctor (healing and supplies); residents ask 1–3 questions with a gift for every right answer; the walkie-talkie intercept (patrol routes, the leader); the physically simulated over-the-shoulder carry (6.12).
- **Phase 3h:** companions and their skills (6.8); spouses and reunions; shelters on residents' beds and in safe containers; heavy, injured and wounded hostages; the booby-trapped hostage, the mole, the CNG driver (6.9); the briefing hostage, news on the shoulder, radio code, shift changes, new Alpha orders (6.10); captured Alphas and the heavy Alpha woman (6.11); residents ask two questions; 114 BCS questions drawn without repeats, including 2025–2026 events; the Freelancer's health is 125 (+25 %); gagging and new-information sound slots.
- **Phase 3:**
  - **Sound:**
    - Dhaka soundscape (procedural, see section 9), gunshot echo tails, concrete footsteps, crawl and swim sounds.
    - Headphone mode (N).
    - Gendered hostage sounds.
  - **Moves and gear:**
    - Prone (Z); swimming in lakes, rivers and canals, with breath and climbing out.
    - Grenade, Molotov and time bomb.
    - Parachute jump opening Mission 1, with the team parachuting alongside.
  - **Hostages and team:**
    - Male and female hostages; the gender lock (5.9); Alpha Team women; the order system (6.1); L parachute reinforcement; K extraction order.
    - Strength- and mass-based over-the-shoulder carry: squat-lift, kneel-down, loaded gait, secondary motion.
  - **Faces:** blinking, eye saccades and gaze, breathing (chest and nostrils) on every procedural face.
  - **Houses and side missions:**
    - Houses with grills, sunshades, roof access, stair hut and water tank; brick and plaster shaders with recessed joints, efflorescence, fungus and floor bands.
    - Collapsible gates with MCQ residents, plastic chairs and snack machines.
    - Boss raid with surrender, handcuffs and helicopter pickup from the roof; weapons cache.
  - **Build:** GitHub Actions build of `SilentRescueDhaka.exe` and the 5-step README.
