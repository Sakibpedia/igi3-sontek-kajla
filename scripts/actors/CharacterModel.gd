extends Node3D
## Procedural anatomical humanoid used by every character in "Silent Rescue: Dhaka".
## - Full rig of pivots: hips > thighs > shins (feet), hips > torso > chest > neck/head, chest > upper
##   arms > forearms (hands). Two-bone IK for arms and legs, so feet stay planted, kneeling folds the
##   legs correctly and both hands grip the rifle.
## - Anatomy: every segment is a lofted surface built from measured cross sections (front / back depth,
##   centre offset, squareness): trapezius slope, deltoid caps, pectorals, ribcage, waist, iliac crest,
##   glutes, quadriceps, kneecaps, calves, tibia, ankles. Hands have a palm, thenar pad, four jointed
##   fingers and a thumb; bare feet have an arch and five toes. Thighs, hands and feet are mirrored
##   per side. One draw call per body segment (vertex-colour alpha picks skin / hair / metal / cloth).
## - Builds: "average", "lean" (Alpha Team), "heavy" (villains), "female" (hostages). Every build has
##   the SAME standing height (crown at about 1.73 m) - only widths change.
## - The head is a high-resolution sculpted skull (brow ridge, eye sockets and lids, nose bridge, tip and
##   alae, cheekbones, lips, chin, jaw angle, occiput) driven by face-shape controls (see FACE_SLIDERS),
##   with a real hair shell, ears, braid / bun / long hair and jewellery. A photo, when there is one, is
##   wrapped onto it by shaders/face.gdshader; without one the shader paints a matching face.
## Front of the model is -Z.

const WORLD_SHADER := preload("res://shaders/world.gdshader")
const BODY_SHADER := preload("res://shaders/character.gdshader")
const HEAD_SHADER := preload("res://shaders/face.gdshader")
const SkinnedModel := preload("res://scripts/actors/SkinnedModel.gd")
const RENDER_LAYER := 2
## Beyond this distance (m) a character switches to a lighter head, hair and hands (no fingers).
const LOD_DIST := 14.0

# ---- standard skeleton (metres) - identical for every build so all characters share one height
const HIP_Y := 0.94
const HIP_X := 0.092
const HIP_DROP := 0.03
const THIGH := 0.42
const SHIN := 0.42
const ANKLE_Y := 0.07
const TORSO_UP := 0.07
const CHEST_UP := 0.165
const NECK_UP := 0.25
const SHOULDER_Y := 0.25
const SHOULDER_X := 0.176
const UPPER_ARM := 0.29
const FOREARM := 0.26
const HEAD_C := Vector3(0.0, 0.19, 0.004)
const HEAD_R := Vector3(0.081, 0.118, 0.1)
const EYE_Y := 0.192

const BUILDS := {
	"average": {"sh": 1.0, "ch": 1.0, "bel": 0.0, "hip": 1.0, "arm": 1.0, "leg": 1.0, "neck": 1.0},
	"lean": {"sh": 1.03, "ch": 0.95, "bel": -0.006, "hip": 0.94, "arm": 0.93, "leg": 0.93, "neck": 0.96},
	"heavy": {"sh": 1.1, "ch": 1.2, "bel": 0.045, "hip": 1.14, "arm": 1.22, "leg": 1.16, "neck": 1.22},
	"female": {"sh": 0.87, "ch": 0.95, "bel": 0.0, "hip": 1.25, "arm": 0.82, "leg": 1.05, "neck": 0.9},
	"powerful": {"sh": 1.17, "ch": 1.18, "bel": -0.004, "hip": 1.06, "arm": 1.34, "leg": 1.24, "neck": 1.3},
	"female_slim": {"sh": 0.85, "ch": 0.9, "bel": -0.004, "hip": 1.18, "arm": 0.78, "leg": 0.98, "neck": 0.88},
	"female_strong": {"sh": 0.95, "ch": 1.0, "bel": 0.0, "hip": 1.28, "arm": 0.98, "leg": 1.15, "neck": 0.97},
	"female_powerful": {"sh": 1.2, "ch": 1.15, "bel": 0.004, "hip": 1.35, "arm": 1.42, "leg": 1.4, "neck": 1.22},
	"female_heavy": {"sh": 0.98, "ch": 1.18, "bel": 0.042, "hip": 1.4, "arm": 1.08, "leg": 1.25, "neck": 1.06},
	# Extra silhouettes (phase 6): a defined muscular man, a soft/heavier body, and a toned actress build.
	"muscular": {"sh": 1.22, "ch": 1.16, "bel": -0.006, "hip": 1.02, "arm": 1.4, "leg": 1.22, "neck": 1.28},
	"chubby": {"sh": 1.08, "ch": 1.24, "bel": 0.058, "hip": 1.22, "arm": 1.16, "leg": 1.1, "neck": 1.16},
	"actress": {"sh": 0.88, "ch": 0.96, "bel": -0.005, "hip": 1.22, "arm": 0.86, "leg": 1.08, "neck": 0.92},
	"chubby_f": {"sh": 0.96, "ch": 1.2, "bel": 0.052, "hip": 1.38, "arm": 1.04, "leg": 1.16, "neck": 1.04},
}
## Build dropdown (customiser) -> build name, for men and for women.
## Both arrays stay the same length: the customiser shows one label per index for either gender.
const BUILD_MALE := ["average", "lean", "heavy", "powerful", "muscular", "chubby"]
const BUILD_FEMALE := ["female", "female_slim", "female_strong", "female_powerful", "actress", "chubby_f"]
## Relative lifting strength and body mass of each build (mass_of / strength_of below).
const BUILD_STRENGTH := {"average": 1.0, "lean": 0.92, "heavy": 1.12, "powerful": 1.5, "female": 0.82, "female_slim": 0.74, "female_strong": 1.1, "female_powerful": 1.6, "female_heavy": 0.9, "muscular": 1.45, "chubby": 1.05, "actress": 0.86, "chubby_f": 0.95}
const BUILD_MASS := {"average": 1.0, "lean": 0.9, "heavy": 1.25, "powerful": 1.3, "female": 1.0, "female_slim": 0.9, "female_strong": 1.12, "female_powerful": 1.45, "female_heavy": 1.78, "muscular": 1.26, "chubby": 1.45, "actress": 0.96, "chubby_f": 1.55}

## Detailed musculoskeletal relief (metres) per build. Kept separate from the silhouette
## multipliers above so muscle definition can be tuned without changing a character's size.
## glute/pec are the two muscle groups the Alpha women are trained on: the female Powerful
## and Actress profiles deliberately carry more gluteal and pectoral definition than the
## equivalent male profiles, while the male Muscular profile leads on abs and the V-line.
const ANATOMY := {
	"average":       {"muscle": 1.0,  "glute": 0.012, "glute_w": 1.0,  "cleft": 1.0,  "abs": 1.0,  "vline": 1.0,  "pec": 1.0},
	"lean":          {"muscle": 0.95, "glute": 0.011, "glute_w": 0.96, "cleft": 1.0,  "abs": 1.2,  "vline": 1.25, "pec": 0.95},
	"heavy":         {"muscle": 1.1,  "glute": 0.014, "glute_w": 1.1,  "cleft": 0.8,  "abs": 0.35, "vline": 0.3,  "pec": 1.05},
	"powerful":      {"muscle": 1.35, "glute": 0.015, "glute_w": 1.08, "cleft": 1.0,  "abs": 1.45, "vline": 1.4,  "pec": 1.3},
	"muscular":      {"muscle": 1.6,  "glute": 0.016, "glute_w": 1.05, "cleft": 1.1,  "abs": 1.9,  "vline": 1.7,  "pec": 1.55},
	"chubby":        {"muscle": 0.8,  "glute": 0.015, "glute_w": 1.25, "cleft": 0.5,  "abs": 0.2,  "vline": 0.15, "pec": 0.7},
	"female":        {"muscle": 0.85, "glute": 0.021, "glute_w": 1.1,  "cleft": 1.0,  "abs": 0.6,  "vline": 0.5,  "pec": 0.3},
	"female_slim":   {"muscle": 0.8,  "glute": 0.019, "glute_w": 1.05, "cleft": 1.0,  "abs": 0.7,  "vline": 0.6,  "pec": 0.35},
	"female_strong": {"muscle": 1.15, "glute": 0.025, "glute_w": 1.15, "cleft": 1.0,  "abs": 0.9,  "vline": 0.8,  "pec": 0.6},
	"female_powerful":{"muscle": 1.5, "glute": 0.031, "glute_w": 1.2,  "cleft": 1.05, "abs": 1.15, "vline": 1.05, "pec": 1.2},
	"actress":       {"muscle": 1.0,  "glute": 0.023, "glute_w": 1.12, "cleft": 1.0,  "abs": 1.0,  "vline": 0.9,  "pec": 0.55},
	"chubby_f":      {"muscle": 0.85, "glute": 0.026, "glute_w": 1.3,  "cleft": 0.6,  "abs": 0.25, "vline": 0.2,  "pec": 0.3},
	"female_heavy":  {"muscle": 0.9,  "glute": 0.027, "glute_w": 1.3,  "cleft": 0.7,  "abs": 0.3,  "vline": 0.2,  "pec": 0.35},
}


## Body mass in kg of a character with this outfit (build, sex, height scale).
static func mass_of(o: Dictionary) -> float:
	var base := 57.0 if bool(o.get("female", false)) else 68.0
	var sc := float(o.get("scale", 1.0))
	return base * float(BUILD_MASS.get(str(o.get("build", "average")), 1.0)) * pow(sc, 2.6)


## How much a person can carry on one shoulder, in kg, comfortably (load 1.0). Trained people
## (the Freelancer, Alpha Team) lift with proper technique and carry about 15 % more.
static func carry_capacity(o: Dictionary, trained: bool) -> float:
	var st := float(BUILD_STRENGTH.get(str(o.get("build", "average")), 1.0)) * float(o.get("scale", 1.0))
	return 82.0 * st * (1.15 if trained else 1.0)

# vertex-colour alpha = material id (see shaders/character.gdshader)
const SKIN := 0.0
const HAIR := 0.25
const METAL := 0.5
const LEATHER := 0.75
const CHECK := 0.9
const PRINT := 0.95
const CLOTH := 1.0
const GOLD := Color(0.86, 0.64, 0.26, METAL)

# ---- face controls (main menu > চরিত্র সাজান). Sliders run -1..1, 0 = average.
const FACE_SLIDERS := ["fw", "jaw", "chin", "cheek", "eye_size", "eye_sp", "eye_tilt", "brow_arch", "nose_w", "nose_l", "lip_full", "lip_w"]
## keys that change the skull mesh (the rest only drive the face shader)
const FACE_GEO := ["fw", "jaw", "chin", "cheek", "nose_w", "nose_l", "lip_full", "lip_w", "eye_size", "eye_sp", "age"]
const EYE_COLORS := [Color(0.11, 0.065, 0.035), Color(0.2, 0.11, 0.05), Color(0.32, 0.19, 0.08), Color(0.38, 0.3, 0.12), Color(0.3, 0.34, 0.27)]
## rgb = lipstick colour, a = how much of it (0 = natural lips)
const LIP_COLORS := [Color(0.6, 0.3, 0.3, 0.0), Color(0.78, 0.33, 0.42, 0.5), Color(0.66, 0.05, 0.1, 0.85), Color(0.36, 0.05, 0.09, 0.8), Color(0.55, 0.32, 0.26, 0.55)]
const BINDI_COLORS := [Color(0, 0, 0, 0), Color(0.78, 0.04, 0.06, 1), Color(0.42, 0.03, 0.08, 1), Color(0.03, 0.03, 0.03, 1)]
const EARRINGS := ["none", "stud", "jhumka"]
## distinct face shapes per crowd role (gunmen, civilians, Alpha Team)
const CROWD_FACES := 10

static var _mats := {}
static var _mesh_cache := {}
static var _skull_cache := {}
static var _hair_cache := {}

var role := "villain"
var build := "average"
var outfit := {}
var clothing_mode := "outfit"
var hips: Node3D
var skirt: Node3D
var foot_l: Node3D
var foot_r: Node3D
var torso: Node3D
var chest: Node3D
var head: Node3D
var leg_l: Node3D
var leg_r: Node3D
var knee_l: Node3D
var knee_r: Node3D
var arm_l: Node3D
var arm_r: Node3D
var fore_l: Node3D
var fore_r: Node3D
var gun: Node3D
var muzzle: Node3D
var face: MeshInstance3D
var face_lo: MeshInstance3D
var features: Node3D
var gag: MeshInstance3D
var bottle: MeshInstance3D
var ropes: Array = []
## Phase 7: corner straps of the X-bed tie (wrists and ankles out to the bed posts)
var bed_straps: Array = []
## Phase 7: chloroformed / fainted - the head lolls and the arms hang limp
var unconscious := false
var body_mat: ShaderMaterial
var head_mat: ShaderMaterial
var _face_mat: ShaderMaterial

var _phase := 0.0
var _t := 0.0
var _groin_pulse_timer := 0.0
var _groin_pulse_active := false
var _dead := false
var crouch_amount := 0.0
var aim_amount := 0.0
var kneel := false
var hands_up := false
var tied := false
var carried := false
var is_carried := false
var carrier_node: Node3D = null
## 0 standing .. 1 deep squat (lifting someone onto the shoulder or putting them down)
var _squat := 0.0
const SQUAT_HIP := 0.5
## Living face: blinking, small eye movements (saccades), breathing (chest, nostrils).
## breath_rate in rad/s of the breathing cycle (~0.25 Hz calm; faster when scared or working hard).
var breath_rate := 1.6
var nostril_flare: float = 0.0
var is_in_pain: bool = false
var look_at_target: Node3D = null
var _blink_t := 2.0
var _blink := 0.0
var _gaze := Vector2.ZERO
var _gaze_goal := Vector2.ZERO
var _saccade_t := 1.0
var _breath_ph := 0.0
## Interaction micro-animations:
##   reach_target (global): both hands go there and work (taping, tying) - Vector3.INF = off
##   gag_anim 0..1: tape strip peeled away from one corner (0 = pressed on the lips)
##   rope_anim 0..1: ropes loosened and sliding off (0 = tight)
var reach_target := Vector3.INF
## one-armed reach (two-person seat carry): -1 left / +1 right arm goes to reach_target, the other
## arm to reach_target2 (a hand on the carried person's back); 0 = both hands to reach_target
var reach_side := 0.0
var reach_target2 := Vector3.INF
## pose "seat_carried": where the two hands go (over the two carriers' shoulders), global
var hand_targets: Array = []
## head look-at (global point); while reaching, the head follows the hands' target by itself
var head_target := Vector3.INF
var _reach_k := 0.0
var _reach_last := Vector3.INF
## tape strip grid (for the peel animation) and the faint red mark left on the lips (fades)
var _tape_v := PackedVector3Array()
var _tape_n := PackedVector3Array()
var _tape_cols := 0
var _tape_rows := 0
var _tape_mesh0: Mesh = null
var _tape_mesh_cache: Dictionary = {}
var tape_mark := 0.0
var _gag_pivot := Vector3.ZERO
var _rope_rest: Array = []
## "" (default), "drink" or "talk" - used by hostages
var pose := ""
## Facial expressions (face.gdshader "expr"): fear, anger, relief, struggle 0..1, eased towards the
## goal set_expression() gives. They move the brows, cheeks, mouth corners and chin of the head mesh
## (photo or painted face alike) and narrow the eyes when struggling or angry.
var _expr := Vector4.ZERO
var _expr_goal := Vector4.ZERO
var _expr_sent := Vector4(-1, -1, -1, -1)
## How far the head may turn (1 free; ~0.55 gagged: the tape holds the jaw and pulls on the cheeks)
var head_limit := 1.0
## yes / no head signal of a gagged hostage: a nod (pitch) or a shake (yaw), ~1.3 s
var _sig_t := 0.0
var _sig_yes := true
var _sig_off := Vector2.ZERO
var _lod_skip := 0
var _lod_acc := 0.0
var _female := false
## face controls of this character (see FACE_SLIDERS) and the packed skull parameters
var _fp := {}
var _g := PackedFloat32Array()


# ============================================================================ static helpers
static func mat(color: Color, rough: float = 0.85) -> ShaderMaterial:
	var key := color.to_html() + str(rough)
	if _mats.has(key):
		return _mats[key]
	var m := ShaderMaterial.new()
	m.shader = WORLD_SHADER
	m.set_shader_parameter("albedo", color)
	m.set_shader_parameter("use_baked", false)
	m.set_shader_parameter("roughness", rough)
	m.set_shader_parameter("receives_wet", false)
	_mats[key] = m
	return m


static func _pick(arr: Array, rng: RandomNumberGenerator):
	return arr[rng.randi_range(0, arr.size() - 1)]


const HAIR_COLORS := [Color(0.035, 0.03, 0.028), Color(0.08, 0.055, 0.04), Color(0.16, 0.1, 0.06), Color(0.55, 0.53, 0.5), Color(0.35, 0.12, 0.06)]
## coastal headwear (customiser index): no hats tied to one place or faith
const HEADWEAR := ["none", "cap", "bandana", "beret", "sunhat", "helmet"]
## beachwear colours: printed shirts and dresses, shorts
const BEACH_PRINTS := [Color(0.95, 0.55, 0.25), Color(0.2, 0.62, 0.78), Color(0.95, 0.82, 0.3), Color(0.85, 0.3, 0.42), Color(0.3, 0.7, 0.5),
	Color(0.95, 0.93, 0.88), Color(0.52, 0.38, 0.72), Color(0.25, 0.42, 0.75)]
const SHORTS_COLS := [Color(0.62, 0.56, 0.42), Color(0.18, 0.24, 0.4), Color(0.85, 0.82, 0.74), Color(0.3, 0.42, 0.3), Color(0.12, 0.12, 0.14)]
## Swimwear colours (_swim_colour): most people in black, then white, then grey, the rest in SWIM_OTHER.
const SWIM_BLACK := Color(0.055, 0.055, 0.06)
const SWIM_WHITE := Color(0.93, 0.93, 0.91)
const SWIM_GREY := Color(0.48, 0.48, 0.5)
const SWIM_OTHER := [Color(0.72, 0.1, 0.12), Color(0.1, 0.16, 0.42), Color(0.12, 0.42, 0.75), Color(0.08, 0.5, 0.52),
	Color(0.45, 0.08, 0.14), Color(0.9, 0.62, 0.12), Color(0.85, 0.35, 0.55)]
## chance of black, white and grey; whatever is left goes to SWIM_OTHER (here 0.2)
const SWIM_ODDS := [0.4, 0.25, 0.15]


static func skin_from(v: float) -> Color:
	return Color(0.8, 0.62, 0.5).lerp(Color(0.34, 0.23, 0.16), clampf(v, 0.0, 1.0))


## slot: the character slot (Game.custom "<role>_<slot>"): 1..36 for hostages, 1..6 Alpha Team,
## 1..2 villains, 1..8 gunmen ("enemy"); 0 = no slot (crowds). The face comes from a fixed seed per
## slot, so the same slot always gives the same person - nothing is drawn at random.
## variant: a second person on the same slot (hostage 37+, gunman 9+) gets a face of her / his own
## near the slot's face.
static func outfit_for(p_role: String, rng: RandomNumberGenerator, slot: int = 0, variant: int = 0) -> Dictionary:
	if p_role == "ally_f" and slot <= 0:
		return _alpha_woman(rng)
	var base_role := "ally" if p_role == "ally_f" else ("villain" if p_role == "enemy" else p_role)
	var key := "villain" if p_role == "boss" and slot <= 0 else ("ally" if p_role == "ally_f" else p_role)
	var o := _outfit_traits(base_role, rng)
	var fr := RandomNumberGenerator.new()
	if p_role == "hero":
		fr.seed = 4242
	elif slot > 0:
		fr.seed = 9100 + (hash(key) % 997) * 11 + slot * 37 + variant * 1013
	else:
		# crowds draw from CROWD_FACES face shapes per role, so their heads come from the mesh cache
		fr.seed = hash(p_role) + rng.randi_range(0, CROWD_FACES - 1) * 7919
	var female := bool(o.get("female", false))
	if p_role == "hero":
		female = Game.hero_female()
	elif p_role == "ally_f":
		female = true
	elif slot > 0:
		female = Game.slot_gender(key, slot) == "female"
	elif p_role == "civilian":
		female = rng.randf() < 0.5
	o["face"] = _random_face(base_role, fr, female)
	_apply_custom(o, key, rng, slot, fr, female, variant)
	return o


## Alpha Team woman: specially trained operator, tall and powerfully built (customiser page "ally_f").
## The only team members allowed to carry, tie and tape male hostages (Game.can_handle).
static func _alpha_woman(rng: RandomNumberGenerator) -> Dictionary:
	var o := _outfit_traits("ally", rng)
	var fr := RandomNumberGenerator.new()
	fr.seed = hash("ally_f") + rng.randi_range(0, CROWD_FACES - 1) * 7919
	o["face"] = _random_face("ally", fr, true)
	_apply_custom(o, "ally", rng, 0, fr, true)
	return o


## Turns any outfit into a woman's (residents, women gang leaders, visitors): build, hair, no beard,
## own face, and the bikini (same colour as before when the outfit was already swimwear).
static func feminize(o: Dictionary, rng: RandomNumberGenerator) -> void:
	o["female"] = true
	o["build"] = "female"
	o["beard"] = 0.0
	o["hair_len"] = _pick([2, 3, 4], rng)
	o["brow"] = rng.randf_range(0.7, 0.9)
	var fr := RandomNumberGenerator.new()
	fr.seed = rng.randi()
	o["face"] = _random_face("civilian_f", fr, true)
	_swimwear(o, rng)


## Natural variation for a face that nobody customised. Crowds snap to coarse steps so lookalikes share
## one cached skull mesh.
static func _random_face(p_role: String, fr: RandomNumberGenerator, female: bool) -> Dictionary:
	var f := {}
	var step := 0.25 if p_role == "civilian" else 0.05
	for k in FACE_SLIDERS:
		f[k] = snappedf(fr.randf_range(-0.55, 0.55), step)
	match p_role:
		"civilian":
			f["age"] = snappedf(fr.randf_range(0.0, 1.0) if fr.randf() < 0.35 else fr.randf_range(0.0, 0.4), 0.25)
		"villain", "boss":
			f["age"] = fr.randf_range(0.1, 0.55)
		"hostage":
			f["age"] = fr.randf_range(0.0, 0.3)
		_:
			f["age"] = fr.randf_range(0.1, 0.4)
	f["kajal"] = 0.0
	f["blush"] = 0.0
	f["lip_color"] = 0
	f["bindi"] = 0
	f["nose_pin"] = false
	f["earrings"] = 0
	f["mole"] = fr.randf() < 0.18
	if female:
		_female_extras(f, fr)
	return f


static func _female_extras(f: Dictionary, fr: RandomNumberGenerator) -> void:
	f["kajal"] = snappedf(fr.randf_range(0.15, 0.7), 0.05)
	f["blush"] = snappedf(fr.randf_range(0.0, 0.3), 0.05)
	f["lip_color"] = _pick([0, 0, 1, 4], fr)
	f["nose_pin"] = fr.randf() < 0.5
	f["earrings"] = _pick([0, 1, 1, 2], fr)
	f["bindi"] = 1 if fr.randf() < 0.12 else 0


## A woman's coastal clothes: 0 light sundress, 1 T-shirt + capri trousers, 2 printed shirt + shorts.
static func _coastal_woman(o: Dictionary, rng: RandomNumberGenerator, style: int) -> void:
	o.erase("dupatta")
	o.erase("tie")
	match style:
		0:
			o.merge({"top": "dress", "sleeve": "short", "pants_style": "bare", "shoes": "sandals", "shirt": _pick(BEACH_PRINTS, rng)}, true)
		1:
			o.merge({"top": "tshirt", "sleeve": "short", "pants_style": "capri", "shoes": "sandals", "shirt": _pick(BEACH_PRINTS, rng),
				"pants": _pick(SHORTS_COLS, rng)}, true)
		_:
			o.merge({"top": "beachshirt", "sleeve": "short", "pants_style": "shorts", "shoes": "sandals", "shirt": _pick(BEACH_PRINTS, rng),
				"pants": _pick(SHORTS_COLS, rng)}, true)


## A man's coastal clothes: 0 printed beach shirt + shorts, 1 T-shirt + shorts, 2 linen shirt + capri.
static func _coastal_man(o: Dictionary, rng: RandomNumberGenerator, style: int) -> void:
	o.erase("dupatta")
	o.erase("tie")
	match style:
		0:
			o.merge({"top": "beachshirt", "sleeve": "short", "pants_style": "shorts", "shoes": "sandals", "shirt": _pick(BEACH_PRINTS, rng),
				"pants": _pick(SHORTS_COLS, rng)}, true)
		1:
			o.merge({"top": "tshirt", "sleeve": "short", "pants_style": "shorts", "shoes": "sandals", "shirt": _pick(BEACH_PRINTS, rng),
				"pants": _pick(SHORTS_COLS, rng)}, true)
		_:
			o.merge({"top": "shirt", "sleeve": "short", "pants_style": "capri", "shoes": "shoes", "shirt": Color(0.92, 0.9, 0.84),
				"pants": _pick(SHORTS_COLS, rng)}, true)


## Everyone's clothes, every role, minimal cover: men in brief swim briefs with a narrow cheeky back and
## narrow side bands; women in a padded halter bikini (rounded cups with frills, bows at the nape and the
## back) with a Brazilian-cut bottom tied to metal rings at the hips. Sandals; the whole outfit in one
## colour (_swim_colour). Plate carriers, hats, rifles and the rest of the outfit are kept. The bare body
## gets its muscles and forms from _relief (glutes, abs, pecs, breasts).
## Built by _build_meshes: top "bikini" / "none", pants_style "bikini" / "briefs", sleeve "none".
## An outfit that is already swimwear keeps its colours (e.g. briefs turned into a bikini by feminize()).
static func _swimwear(o: Dictionary, rng: RandomNumberGenerator) -> void:
	var pst := str(o.get("pants_style", ""))
	var was_swim := pst == "briefs" or pst == "bikini"
	var female := bool(o.get("female", false))
	o.erase("dupatta")
	o.erase("tie")
	o.erase("check")
	o.merge({"top": "bikini" if female else "none", "sleeve": "none", "pants_style": "bikini" if female else "briefs",
		"shoes": "sandals"}, true)
	if not was_swim:
		var c := _swim_colour(rng)
		o["shirt"] = c
		o["pants"] = c


static func _swim_colour(rng: RandomNumberGenerator) -> Color:
	var r := rng.randf()
	if r < float(SWIM_ODDS[0]):
		return SWIM_BLACK
	if r < float(SWIM_ODDS[0]) + float(SWIM_ODDS[1]):
		return SWIM_WHITE
	if r < float(SWIM_ODDS[0]) + float(SWIM_ODDS[1]) + float(SWIM_ODDS[2]):
		return SWIM_GREY
	return _pick(SWIM_OTHER, rng)


## Clothing modes. "outfit" keeps the full coastal clothes chosen in _outfit_base (the GDD look),
## "swim" is the beachwear variant, "bare" shows the anatomical body. The mode is part of the
## outfit so the mesh cache key changes with it and a rebuild always gets its own meshes.
const CLOTHING_MODES := ["outfit", "swim", "bare"]


## Apply a clothing mode to an outfit dictionary in place. This is the single entry point used
## both when a character is created and when a player changes clothes at runtime.
static func apply_clothing(o: Dictionary, rng: RandomNumberGenerator, mode: String) -> void:
	match mode:
		"swim":
			_swimwear(o, rng)
		"bare":
			o.erase("dupatta")
			o.erase("tie")
			o.erase("check")
			o.merge({"top": "none", "sleeve": "none", "pants_style": "bare", "shoes": "sandals"}, true)
		_:
			# "outfit": keep the coastal clothes already in the dictionary.
			pass
	o["clothing_mode"] = mode


## Overrides from the main-menu customiser (Game.custom: "<key>" shared + "<key>_<slot>" own) and the
## person's gender. key: hero, ally, villain, enemy, boss, hostage.
static func _apply_custom(o: Dictionary, key: String, rng: RandomNumberGenerator, slot: int = 0, fr: RandomNumberGenerator = null, female: bool = false, variant: int = 0) -> void:
	var c: Dictionary = Game.custom_for(key, slot) if ["hero", "ally", "villain", "enemy", "boss", "hostage"].has(key) else {}
	if key == "hostage":
		female = Game.slot_gender("hostage", slot) == "female" if slot > 0 else female
	o["female"] = female
	if female:
		o["build"] = "female_strong" if key == "ally" else "female"
		o["beard"] = 0.0
		o["hair_len"] = _pick([2, 3, 4, 4], rng) if key != "ally" else _pick([3, 4, 4], rng)
		o["brow"] = rng.randf_range(0.7, 0.9)
		if fr != null and o.get("face") is Dictionary:
			_female_extras(o["face"], fr)
	else:
		if str(o.get("build", "")).begins_with("female"):
			o["build"] = "average"
		o["hair_len"] = _pick([0, 0, 1], rng) if key != "hostage" else _pick([0, 1], rng)
	# Clothing mode: full coastal outfit (default, as in the GDD), beachwear or the anatomical body.
	# The customiser's colours still feed whichever garments the selected mode uses.
	apply_clothing(o, rng, Game.get_clothing_mode())
	if not female and key == "hostage":
		o["beard"] = rng.randf_range(0.0, 0.7)
		o["brow"] = rng.randf_range(0.85, 1.2)
	if key == "hostage" and o.get("face") is Dictionary and not c.has("age"):
		# hostages of different adult ages (20s .. 70s) per slot, grey hair for the oldest
		var ages := [0.15, 0.6, 0.32, 0.85, 0.45, 0.25, 0.38, 0.52, 0.2, 0.7, 0.28, 0.48]
		var ag: float = ages[(slot - 1 + variant * 5) % ages.size()] if slot > 0 else rng.randf_range(0.0, 0.9)
		(o["face"] as Dictionary)["age"] = ag
		if ag > 0.7 and not c.has("hair_color"):
			o["hair"] = HAIR_COLORS[3]
	if c.is_empty():
		return
	if c.has("skin"):
		o["skin"] = skin_from(float(c["skin"]))
	if c.has("hair_color"):
		o["hair"] = HAIR_COLORS[clampi(int(c["hair_color"]), 0, HAIR_COLORS.size() - 1)]
	if c.has("hair_len"):
		o["hair_len"] = int(c["hair_len"])
	if c.has("height"):
		o["scale"] = clampf(float(c["height"]), 0.9, 1.12)
	if c.has("build"):
		var bl: Array = BUILD_FEMALE if female else BUILD_MALE
		o["build"] = bl[clampi(int(c["build"]), 0, bl.size() - 1)]
	if bool(c.get("use_colors", false)):
		if c.get("top_color") is Color:
			o["shirt"] = c["top_color"]
		if c.get("pants_color") is Color:
			o["pants"] = c["pants_color"]
	if c.has("headwear") and int(c["headwear"]) > 0:
		o["hat"] = HEADWEAR[clampi(int(c["headwear"]), 0, HEADWEAR.size() - 1)]
		if not o.has("hat_color"):
			o["hat_color"] = c.get("top_color", Color(0.3, 0.32, 0.4)) if bool(c.get("use_colors", false)) else Color(0.32, 0.3, 0.42)
	elif c.has("headwear"):
		o["hat"] = "none"
	if c.has("beard") and not female:
		o["beard"] = clampf(float(c["beard"]), 0.0, 1.0)
	if c.has("brow"):
		o["brow"] = clampf(float(c["brow"]), 0.4, 1.5)
	if c.has("eye_color"):
		o["eye"] = EYE_COLORS[clampi(int(c["eye_color"]), 0, EYE_COLORS.size() - 1)]
	# face shape: a slotted person takes the values exactly (the hero, every hostage, every Alpha,
	# villain and gunman slot); a second person on the same slot keeps some of her / his own face
	var f: Dictionary = o.get("face", {})
	var exact := (key == "hero" or slot > 0) and variant == 0
	for k in FACE_SLIDERS:
		if c.has(k):
			var v := clampf(float(c[k]), -1.0, 1.0)
			f[k] = v if exact else clampf(v * 0.6 + float(f.get(k, 0.0)) * 0.6, -1.0, 1.0)
	for k in ["age", "kajal", "blush"]:
		if c.has(k):
			f[k] = clampf(float(c[k]), 0.0, 1.0)
	for k in ["lip_color", "bindi", "earrings"]:
		if c.has(k):
			f[k] = int(c[k])
	for k in ["nose_pin", "mole"]:
		if c.has(k):
			f[k] = bool(c[k])
	o["face"] = f


static func _outfit_traits(p_role: String, rng: RandomNumberGenerator) -> Dictionary:
	var o := _outfit_base(p_role, rng)
	var hairs := [Color(0.04, 0.035, 0.03), Color(0.06, 0.045, 0.035), Color(0.09, 0.06, 0.04), Color(0.03, 0.03, 0.03)]
	o["hair"] = _pick(hairs, rng)
	if p_role == "civilian" and rng.randf() < 0.18:
		o["hair"] = Color(0.55, 0.53, 0.5)
	o["seed"] = rng.randf() * 100.0
	o["eye"] = _pick([Color(0.18, 0.1, 0.05), Color(0.12, 0.07, 0.04), Color(0.26, 0.16, 0.08)], rng)
	o["brow"] = rng.randf_range(0.8, 1.25)
	match p_role:
		"villain", "boss":
			o["beard"] = rng.randf_range(0.45, 1.0)
		"ally", "hero":
			o["beard"] = rng.randf_range(0.0, 0.6)
		"hostage":
			o["beard"] = 0.0
			o["brow"] = rng.randf_range(0.7, 0.9)
			o["hair_len"] = _pick([2, 2, 4, 4, 3], rng)
		_:
			o["beard"] = rng.randf_range(0.0, 1.0) if rng.randf() < 0.6 else 0.0
			o["hair_len"] = _pick([0, 0, 0, 1], rng)
	return o


## Beachwear for everyone (Cox's Bazar): shorts, T-shirts, printed beach shirts, light dresses; the
## team and the gang add plate carriers / caps / bandanas. No regional costume.
## NOTE: the clothes picked here are replaced by swimwear in _apply_custom (_swimwear); only the build,
## skin, hat, plate carrier and rifle carry through. Remove that _swimwear() call to bring them back.
static func _outfit_base(p_role: String, rng: RandomNumberGenerator) -> Dictionary:
	var skins := [Color(0.56, 0.39, 0.29), Color(0.48, 0.33, 0.24), Color(0.62, 0.45, 0.34), Color(0.44, 0.3, 0.22)]
	var skin: Color = _pick(skins, rng)
	match p_role:
		"hero":
			return {"build": "average", "top": "beachshirt", "sleeve": "short", "shirt": Color(0.34, 0.4, 0.3), "pants": Color(0.42, 0.38, 0.28),
				"pants_style": "shorts", "shoes": "shoes", "gloves": false, "skin": skin, "hat": "none",
				"vest": Color(0.24, 0.26, 0.19), "armed": true}
		"ally":
			return {"build": "lean", "top": "tshirt", "sleeve": "short", "shirt": Color(0.12, 0.2, 0.34), "pants": Color(0.6, 0.55, 0.42),
				"pants_style": "shorts", "shoes": "shoes", "gloves": false, "skin": skin, "hat": "cap", "hat_color": Color(0.07, 0.11, 0.2),
				"vest": Color(0.05, 0.05, 0.06), "armed": true}
		"villain":
			var o := {"build": "heavy", "top": _pick(["tshirt", "beachshirt", "tshirt"], rng), "sleeve": "short", "shirt": _pick(BEACH_PRINTS + [Color(0.1, 0.1, 0.1), Color(0.24, 0.12, 0.1)], rng),
				"pants": _pick(SHORTS_COLS, rng), "pants_style": _pick(["shorts", "shorts", "capri"], rng), "shoes": _pick(["shoes", "sandals"], rng), "skin": skin,
				"hat": "none", "hat_color": Color(0.5, 0.08, 0.06), "armed": true}
			if rng.randf() < 0.45:
				o["hat"] = _pick(["bandana", "cap", "sunhat"], rng)
				o["hat_color"] = _pick([Color(0.5, 0.08, 0.06), Color(0.1, 0.1, 0.1), Color(0.82, 0.76, 0.6)], rng)
			if rng.randf() < 0.5:
				o["vest"] = _pick([Color(0.22, 0.22, 0.15), Color(0.12, 0.12, 0.1)], rng)
			return o
		"boss":
			return {"build": "heavy", "top": "beachshirt", "sleeve": "short", "shirt": Color(0.08, 0.08, 0.08), "pants": Color(0.86, 0.82, 0.72),
				"pants_style": "shorts", "shoes": "shoes", "gloves": false, "skin": skin, "hat": "beret", "hat_color": Color(0.35, 0.05, 0.05),
				"vest": Color(0.12, 0.12, 0.1), "armed": true}
		"hostage":
			return {"build": "female", "top": "dress", "sleeve": "short", "shirt": _pick(BEACH_PRINTS, rng), "pants": Color(0.9, 0.86, 0.8),
				"pants_style": "bare", "shoes": "sandals", "skin": Color(0.64, 0.47, 0.36), "hat": "none", "armed": false,
				"female": true}
		"vip":
			return {"build": "average", "top": "shirt", "sleeve": "long", "shirt": Color(0.95, 0.94, 0.9), "pants": Color(0.78, 0.72, 0.6),
				"pants_style": "trousers", "shoes": "shoes", "skin": Color(0.78, 0.64, 0.53), "hat": "none", "armed": false}
		_:
			var o := {"build": _pick(["average", "lean", "heavy", "average"], rng), "top": "tshirt", "sleeve": "short",
				"shirt": _pick(BEACH_PRINTS, rng), "pants": _pick(SHORTS_COLS, rng), "pants_style": "shorts",
				"shoes": "sandals", "skin": skin, "hat": "none", "armed": false}
			_coastal_man(o, rng, rng.randi_range(0, 2))
			if rng.randf() < 0.3:
				o["hat"] = _pick(["cap", "sunhat"], rng)
				o["hat_color"] = _pick([Color(0.85, 0.8, 0.66), Color(0.2, 0.3, 0.55), Color(0.9, 0.9, 0.88)], rng)
			return o


# ============================================================================ mesh building
class Mesher:
	var v := PackedVector3Array()
	var nr := PackedVector3Array()
	var col := PackedColorArray()
	var idx := PackedInt32Array()

	func vert(p: Vector3, n: Vector3, c: Color) -> int:
		v.append(p)
		nr.append(n.normalized())
		col.append(c)
		return v.size() - 1

	## Adds a triangle facing along the averaged vertex normals (Godot: clockwise = front face).
	func tri(a: int, b: int, c: int) -> void:
		var fn := (v[b] - v[a]).cross(v[c] - v[a])
		if fn.dot(nr[a] + nr[b] + nr[c]) > 0.0:
			idx.append(a)
			idx.append(c)
			idx.append(b)
		else:
			idx.append(a)
			idx.append(b)
			idx.append(c)

	func is_empty() -> bool:
		return v.is_empty()

	## Triangulates a (rows+1) x (seg+1) vertex grid with ONE winding for every quad, chosen so the
	## surface faces away from `inside`. Used for the skull and hair shell, whose steep features (nose
	## wings, hairline) can fool the per-triangle normal test in tri().
	func grid(base: int, rows: int, seg: int, inside: Vector3) -> void:
		var j0 := rows / 2
		var k0 := seg / 2
		var a0 := base + j0 * (seg + 1) + k0
		var fn := (v[a0 + 1] - v[a0]).cross(v[a0 + seg + 2] - v[a0])
		var flip := fn.dot(v[a0] - inside) > 0.0
		for j in rows:
			for k in seg:
				var a := base + j * (seg + 1) + k
				var b := a + 1
				var d := a + seg + 1
				var e := d + 1
				if flip:
					idx.append_array(PackedInt32Array([a, e, b, a, d, e]))
				else:
					idx.append_array(PackedInt32Array([a, b, e, a, e, d]))

	func arrays() -> Array:
		var arr := []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = v
		arr[Mesh.ARRAY_NORMAL] = nr
		arr[Mesh.ARRAY_COLOR] = col
		arr[Mesh.ARRAY_INDEX] = idx
		return arr

	## Inner surface for open garments (skirts, scarves) so they are not see-through from inside.
	func _double(base: int, ibase: int) -> void:
		var vend := v.size()
		var iend := idx.size()
		var off2 := vend - base
		for i in range(base, vend):
			v.append(v[i] - nr[i] * 0.0015)
			nr.append(-nr[i])
			col.append(col[i])
		for i in range(ibase, iend, 3):
			idx.append(idx[i] + off2)
			idx.append(idx[i + 2] + off2)
			idx.append(idx[i + 1] + off2)

	## Loft through cross sections. ring = [centre: Vector3, rx, rz_front, colour, rz_back, squareness].
	## Sections lie in the local XZ plane at centre.y and are transformed by xf. rz_back (optional) is the
	## depth behind the centre (glutes, calves, shoulder blades); squareness < 1 makes the section boxier.
	func loft(rings: Array, seg: int, xf: Transform3D, cap_a: bool, cap_b: bool, sq: float = 1.0, double: bool = false) -> void:
		var nring := rings.size()
		var base := v.size()
		var ibase := idx.size()
		var pts := []
		for i in nring:
			var r: Array = rings[i]
			var c: Vector3 = r[0]
			var row := []
			var rzb: float = float(r[4]) if r.size() > 4 else float(r[2])
			var sqr: float = float(r[5]) if r.size() > 5 else sq
			for k in seg:
				var th := TAU * float(k) / float(seg)
				var cs := cos(th)
				var sn := sin(th)
				var ex := signf(cs) * pow(absf(cs), sqr)
				var ez := signf(sn) * pow(absf(sn), sqr)
				row.append(c + Vector3(float(r[1]) * ex, 0.0, (rzb if sn > 0.0 else float(r[2])) * ez))
			pts.append(row)
		for i in nring:
			var r: Array = rings[i]
			var ia := maxi(i - 1, 0)
			var ib := mini(i + 1, nring - 1)
			while ia > 0 and ((rings[ia] as Array)[0] as Vector3).distance_to((rings[i] as Array)[0]) < 0.004:
				ia -= 1
			while ib < nring - 1 and ((rings[ib] as Array)[0] as Vector3).distance_to((rings[i] as Array)[0]) < 0.004:
				ib += 1
			for k in seg:
				var k1 := (k + 1) % seg
				var k0 := (k + seg - 1) % seg
				var p: Vector3 = pts[i][k]
				var along: Vector3 = (pts[ib][k] as Vector3) - (pts[ia][k] as Vector3)
				if along.length_squared() < 1e-8:
					along = Vector3.UP
				var around: Vector3 = (pts[i][k1] as Vector3) - (pts[i][k0] as Vector3)
				var n := around.cross(along)
				var radial := p - (r[0] as Vector3)
				radial.y = 0.0
				if n.dot(radial) < 0.0:
					n = -n
				if n.length_squared() < 1e-12:
					n = radial if radial.length_squared() > 1e-10 else Vector3.UP
				vert(xf * p, xf.basis * n, r[3])
		for i in nring - 1:
			for k in seg:
				var k2 := (k + 1) % seg
				var a := base + i * seg + k
				var b := base + i * seg + k2
				var c := base + (i + 1) * seg + k2
				var d := base + (i + 1) * seg + k
				tri(a, b, c)
				tri(a, c, d)
		var axis := xf.basis * Vector3.UP
		if cap_a:
			var r0: Array = rings[0]
			var ci := vert(xf * (r0[0] as Vector3), -axis, r0[3])
			for k in seg:
				var a2 := base + k
				var b2 := base + (k + 1) % seg
				nr[a2] = (nr[a2] - axis * 0.6).normalized()
				tri(ci, b2, a2)
		if cap_b:
			var r1: Array = rings[nring - 1]
			var cj := vert(xf * (r1[0] as Vector3), axis, r1[3])
			var off := base + (nring - 1) * seg
			for k in seg:
				var a3 := off + k
				var b3 := off + (k + 1) % seg
				nr[a3] = (nr[a3] + axis * 0.6).normalized()
				tri(cj, a3, b3)
		if double:
			_double(base, ibase)

	## Tube along a path (fingers, toes, braids, straps, scarves). rad: float or Vector2(side, normal)
	## per point. ups (optional): the direction the "normal" radius should face at each point, so flat
	## ribbons lie on the body. colors: one Color or one per point.
	func sweep(pts: Array, rad: Array, colors, seg: int, cap_a: bool, cap_b: bool, ups: Array = [], double: bool = false) -> void:
		var n := pts.size()
		if n < 2:
			return
		var base := v.size()
		var ibase := idx.size()
		var prev := Vector3.ZERO
		var frames := []
		for i in n:
			var t: Vector3 = (pts[mini(i + 1, n - 1)] as Vector3) - (pts[maxi(i - 1, 0)] as Vector3)
			t = t.normalized()
			var up: Vector3
			if not ups.is_empty():
				up = ups[mini(i, ups.size() - 1)]
			elif i == 0:
				up = Vector3.BACK if absf(t.z) < 0.9 else Vector3.UP
			else:
				up = prev
			var side := t.cross(up)
			if side.length_squared() < 1e-9:
				side = t.cross(Vector3.RIGHT if absf(t.x) < 0.9 else Vector3.BACK)
			side = side.normalized()
			var nrm := side.cross(t).normalized()
			prev = nrm
			frames.append([side, nrm])
		for i in n:
			var p: Vector3 = pts[i]
			var side: Vector3 = frames[i][0]
			var nrm: Vector3 = frames[i][1]
			var r = rad[mini(i, rad.size() - 1)]
			var rs: float
			var rn: float
			if r is Vector2:
				rs = (r as Vector2).x
				rn = (r as Vector2).y
			else:
				rs = float(r)
				rn = float(r)
			var c: Color = colors[mini(i, colors.size() - 1)] if colors is Array else colors
			for k in seg:
				var th := TAU * float(k) / float(seg)
				var cs := cos(th)
				var sn := sin(th)
				vert(p + side * (cs * rs) + nrm * (sn * rn), side * (cs / maxf(rs, 1e-4)) + nrm * (sn / maxf(rn, 1e-4)), c)
		for i in n - 1:
			for k in seg:
				var k2 := (k + 1) % seg
				var a := base + i * seg + k
				var b := base + i * seg + k2
				var c2 := base + (i + 1) * seg + k2
				var d := base + (i + 1) * seg + k
				tri(a, b, c2)
				tri(a, c2, d)
		if cap_a:
			var t0: Vector3 = ((pts[0] as Vector3) - (pts[1] as Vector3)).normalized()
			var c0: Color = colors[0] if colors is Array else colors
			var ci := vert(pts[0], t0, c0)
			for k in seg:
				nr[base + k] = (nr[base + k] + t0 * 0.5).normalized()
				tri(ci, base + (k + 1) % seg, base + k)
		if cap_b:
			var t1: Vector3 = ((pts[n - 1] as Vector3) - (pts[n - 2] as Vector3)).normalized()
			var c1: Color = colors[colors.size() - 1] if colors is Array else colors
			var cj := vert(pts[n - 1], t1, c1)
			var off := base + (n - 1) * seg
			for k in seg:
				nr[off + k] = (nr[off + k] + t1 * 0.5).normalized()
				tri(cj, off + k, off + (k + 1) % seg)
		if double:
			_double(base, ibase)

	func ellipsoid(c: Vector3, r: Vector3, color: Color, seg: int = 10, rows: int = 7, xf: Transform3D = Transform3D()) -> void:
		var base := v.size()
		for j in rows + 1:
			var phi := PI * float(j) / float(rows) - PI * 0.5
			for k in seg + 1:
				var th := TAU * float(k) / float(seg)
				var dir := Vector3(cos(phi) * cos(th), sin(phi), cos(phi) * sin(th))
				var p := c + dir * r
				var n := Vector3(dir.x / r.x, dir.y / r.y, dir.z / r.z)
				vert(xf * p, xf.basis * n, color)
		for j in rows:
			for k in seg:
				var a := base + j * (seg + 1) + k
				var b := a + 1
				var d := a + seg + 1
				var e := d + 1
				tri(a, b, e)
				tri(a, e, d)

	## Rounded slab (pouches, pockets, plates): a box whose edges are bevelled by a squareness loft.
	func slab(c: Vector3, s: Vector3, color: Color, xf: Transform3D = Transform3D(), sq: float = 0.35) -> void:
		var h := s * 0.5
		var e := minf(minf(h.x, h.z), h.y) * 0.35
		loft([[c + Vector3(0, -h.y, 0), h.x - e, h.z - e, color], [c + Vector3(0, -h.y + e, 0), h.x, h.z, color],
			[c + Vector3(0, h.y - e, 0), h.x, h.z, color], [c + Vector3(0, h.y, 0), h.x - e, h.z - e, color]], 12, xf, true, true, sq)

	func box(c: Vector3, s: Vector3, color: Color, xf: Transform3D = Transform3D()) -> void:
		var h := s * 0.5
		var faces := [[Vector3.RIGHT, Vector3.UP, Vector3.BACK], [Vector3.LEFT, Vector3.UP, Vector3.FORWARD],
			[Vector3.UP, Vector3.BACK, Vector3.RIGHT], [Vector3.DOWN, Vector3.FORWARD, Vector3.RIGHT],
			[Vector3.BACK, Vector3.UP, Vector3.LEFT], [Vector3.FORWARD, Vector3.UP, Vector3.RIGHT]]
		for f in faces:
			var n: Vector3 = f[0]
			var u: Vector3 = f[1]
			var w: Vector3 = f[2]
			var center := c + n * h
			var uu := u * h
			var ww := w * h
			var b0 := vert(xf * (center - uu - ww), xf.basis * n, color)
			var b1 := vert(xf * (center + uu - ww), xf.basis * n, color)
			var b2 := vert(xf * (center + uu + ww), xf.basis * n, color)
			var b3 := vert(xf * (center - uu + ww), xf.basis * n, color)
			tri(b0, b1, b2)
			tri(b0, b2, b3)

	## Cylinder from a to b (used for barrels, bottles).
	func tube(a: Vector3, b: Vector3, r: float, color: Color, seg: int = 8) -> void:
		var d := b - a
		var y := d.normalized()
		var x := y.cross(Vector3.FORWARD if absf(y.z) < 0.9 else Vector3.RIGHT).normalized()
		var z := x.cross(y)
		var xf := Transform3D(Basis(x, y, z), a)
		loft([[Vector3.ZERO, r, r, color], [Vector3(0, d.length(), 0), r, r, color]], seg, xf, true, true)


# ---------------------------------------------------------------- ring helpers
static func _c(col: Color, id: float) -> Color:
	return Color(col.r, col.g, col.b, id)


## Builds rings from a profile [[y, rx, rz_front, cz, rz_back], ...]. Above cut_y the rings are cloth
## (loosened by `loose`), below it skin / other - a doubled ring makes a crisp hem with no colour bleed.
static func _rings(profile: Array, cut_y: float, upper: Color, lower: Color, loose: float, scale_xz: float, cx: float = 0.0) -> Array:
	var out := []
	var prev: Array = []
	for p in profile:
		var y: float = p[0]
		var pb: float = float(p[4]) if p.size() > 4 else float(p[2])
		if not prev.is_empty() and float(prev[0]) > cut_y and y <= cut_y:
			var t := (float(prev[0]) - cut_y) / maxf(float(prev[0]) - y, 0.0001)
			var prb: float = float(prev[4]) if prev.size() > 4 else float(prev[2])
			var rx := lerpf(float(prev[1]), float(p[1]), t) * scale_xz
			var rz := lerpf(float(prev[2]), float(p[2]), t) * scale_xz
			var rb := lerpf(prb, pb, t) * scale_xz
			var cz := lerpf(float(prev[3]) if prev.size() > 3 else 0.0, float(p[3]) if p.size() > 3 else 0.0, t)
			out.append([Vector3(cx, cut_y, cz), rx + loose, rz + loose, upper, rb + loose])
			out.append([Vector3(cx, cut_y - 0.0015, cz), rx + loose * 0.4, rz + loose * 0.4, lower, rb + loose * 0.4])
			out.append([Vector3(cx, cut_y - 0.003, cz), rx, rz, lower, rb])
		var above := y > cut_y
		var czv: float = float(p[3]) if p.size() > 3 else 0.0
		var l := loose if above else 0.0
		out.append([Vector3(cx, y, czv), float(p[1]) * scale_xz + l, float(p[2]) * scale_xz + l, upper if above else lower, pb * scale_xz + l])
		prev = p
	return out


# ============================================================================ setup
func _pivot(parent: Node3D, pname: String, pos: Vector3) -> Node3D:
	var n := Node3D.new()
	n.name = pname
	n.position = pos
	parent.add_child(n)
	return n


func _attach(parent: Node3D, mesh: ArrayMesh, mname: String) -> MeshInstance3D:
	if mesh == null or not is_instance_valid(mesh):
		return null
	if mesh.get_surface_count() == 0:
		return null
	var mi := MeshInstance3D.new()
	mi.name = mname
	mi.mesh = mesh
	mi.layers = RENDER_LAYER
	mi.material_override = body_mat
	parent.add_child(mi)
	return mi


## Detailed mesh up close, light mesh beyond LOD_DIST (only one of the two is ever drawn).
func _attach_lod(parent: Node3D, hi_mesh: ArrayMesh, lo_mesh: ArrayMesh, mname: String) -> MeshInstance3D:
	var hi := _attach(parent, hi_mesh, mname)
	var lo := _attach(parent, lo_mesh, mname + "Lo")
	if hi != null and lo != null:
		hi.visibility_range_end = LOD_DIST
		hi.visibility_range_end_margin = 1.0
		lo.visibility_range_begin = LOD_DIST
		lo.visibility_range_begin_margin = 1.0
	return hi


static func _to_mesh(m: Mesher) -> ArrayMesh:
	var am := ArrayMesh.new()
	if not m.is_empty():
		am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, m.arrays())
	return am


## Outfit keys that only feed shaders - left out of the mesh cache key so lookalikes share meshes.
const _SHADER_ONLY := ["seed", "eye", "brow", "beard", "skin", "hair"]


func _mesh_key() -> String:
	var o := outfit.duplicate()
	for k in _SHADER_ONLY:
		o.erase(k)
	var f: Dictionary = o.get("face", {})
	var fg := {}
	for k in FACE_GEO:
		fg[k] = snappedf(float(f.get(k, 0.0)), 0.01)
	fg["np"] = bool(f.get("nose_pin", false))
	fg["er"] = int(f.get("earrings", 0))
	o["face"] = fg
	return role + "|" + str(o)

func anim_hand_gag() -> void:
	# Hands stay tied behind the back, so we DO NOT touch reach_target.
	# The hostage fights back using their body.
	
	# 1. Head struggle (pulling away from the hand and shaking)
	if head != null:
		head.rotation.x = -0.25 
		head.rotation.z = sin(_t * 15.0) * 0.1 # Rapid side-to-side shaking
		
	# 2. Chest/Torso struggle (twisting and leaning back)
	if chest != null:
		chest.rotation.y = sin(_t * 8.0) * 0.15 # Twisting upper body
		chest.rotation.x = -0.1 # Arching back
		
	# 3. Legs (kicking out in panic since hips are pinned)
	if knee_l != null and knee_r != null:
		knee_l.rotation.x = maxf(0.0, sin(_t * 12.0)) * 0.6
		knee_r.rotation.x = maxf(0.0, sin(_t * 12.0 + PI)) * 0.6
		
	# 4. Gagged struggle (mouth stays shut under the tape)
	if head_mat != null:
		head_mat.set_shader_parameter("mouth_open", 0.0) # Keep lips sealed
func anim_pain() -> void:
	is_in_pain = true
	breath_rate = 3.5 # Breathe heavily and rapidly
	
	# Keep the lips sealed shut under the tape
	if head_mat != null:
		head_mat.set_shader_parameter("mouth_open", 0.0) 

func stop_pain() -> void:
	is_in_pain = false
	breath_rate = 1.6
	if head_mat != null:
		head_mat.set_shader_parameter("mouth_open", 0.0) # Always 0 while gagged
var groin_bulge: Node3D = null
var bulge_tip: Node3D = null

func apply_skin_bulge() -> void:
	if groin_bulge != null: return
	groin_bulge = Node3D.new()
	groin_bulge.name = "GroinBulge"
	
	var bulge_mat := StandardMaterial3D.new()
	if body_mat != null and body_mat.get_shader_parameter("skin_color") != null:
		bulge_mat.albedo_color = body_mat.get_shader_parameter("skin_color")
	else:
		bulge_mat.albedo_color = Color(0.64, 0.47, 0.36)
	bulge_mat.roughness = 0.85
	
	# --- 1. The Base ( / \ ) ---
	var left_mesh := SphereMesh.new()
	left_mesh.radius = 0.035
	left_mesh.height = 0.07
	var left_inst := MeshInstance3D.new()
	left_inst.mesh = left_mesh
	left_inst.material_override = bulge_mat
	left_inst.position = Vector3(-0.02, -0.02, -0.02)
	groin_bulge.add_child(left_inst)
	
	var right_mesh := SphereMesh.new()
	right_mesh.radius = 0.035
	right_mesh.height = 0.07
	var right_inst := MeshInstance3D.new()
	right_inst.mesh = right_mesh
	right_inst.material_override = bulge_mat
	right_inst.position = Vector3(0.02, -0.02, -0.02)
	groin_bulge.add_child(right_inst)
	
	# --- 2. The Upward Tip ( o ) ---
	bulge_tip = Node3D.new()
	bulge_tip.name = "BulgeTip"
	
	var shaft_mesh := SphereMesh.new()
	shaft_mesh.radius = 0.022
	shaft_mesh.height = 0.08
	var shaft_inst := MeshInstance3D.new()
	shaft_inst.mesh = shaft_mesh
	shaft_inst.material_override = bulge_mat
	bulge_tip.add_child(shaft_inst)
	
	# Position the tip forward and up
	bulge_tip.position = Vector3(0, 0.0, -0.03)
	bulge_tip.rotation.x = deg_to_rad(35.0)
	groin_bulge.add_child(bulge_tip)
	
	# Position the whole assembly LOWER into the actual crotch area
	groin_bulge.position = Vector3(0, -0.15, -0.04) 
	hips.add_child(groin_bulge)

func get_bulge_tip() -> Node3D:
	return bulge_tip
func setup(p_role: String, p_outfit: Dictionary) -> void:
	role = p_role
	outfit = p_outfit
	# Clothes now come from the outfit itself (outfit_for applies the chosen clothing mode).
	# An outfit made by hand is honoured as-is; it is never silently replaced with beachwear.
	if outfit.is_read_only():
		outfit = outfit.duplicate()
	clothing_mode = str(outfit.get("clothing_mode", "outfit"))
	build = str(outfit.get("build", "average"))
	if not BUILDS.has(build):
		build = "average"
	_female = bool(outfit.get("female", false))
	_fp = outfit.get("face", {})
	_g = _geo(_fp, _female)
	var skin: Color = outfit.get("skin", Color(0.56, 0.39, 0.29))
	body_mat = ShaderMaterial.new()
	body_mat.shader = BODY_SHADER
	body_mat.set_shader_parameter("skin_color", skin)
	body_mat.set_shader_parameter("hair_color", Color(0.05, 0.04, 0.035))
	head_mat = ShaderMaterial.new()
	head_mat.shader = HEAD_SHADER
	head_mat.set_shader_parameter("has_photo", false)
	head_mat.set_shader_parameter("skin_color", skin)
	var hair: Color = outfit.get("hair", Color(0.05, 0.04, 0.035))
	head_mat.set_shader_parameter("hair_color", hair)
	body_mat.set_shader_parameter("hair_color", hair)
	body_mat.set_shader_parameter("pattern_seed", float(outfit.get("seed", 0.0)))
	head_mat.set_shader_parameter("beard", float(outfit.get("beard", 0.0)))
	head_mat.set_shader_parameter("brow_thick", float(outfit.get("brow", 1.0)))
	head_mat.set_shader_parameter("face_seed", float(outfit.get("seed", 0.0)))
	head_mat.set_shader_parameter("eye_color", outfit.get("eye", Color(0.2, 0.12, 0.06)))
	_set_head_params(head_mat)

	var b: Dictionary = BUILDS[build]
	var key := _mesh_key()
	var meshes: Dictionary = _mesh_cache.get(key, {})
	if meshes.is_empty():
		meshes = _build_meshes(b)
		if _mesh_cache.size() > 160:
			_mesh_cache.clear()
		_mesh_cache[key] = meshes

	hips = _pivot(self, "Hips", Vector3(0, HIP_Y, 0))
	_attach(hips, meshes["pelvis"], "Pelvis")
	skirt = _pivot(hips, "Skirt", Vector3.ZERO)
	_attach(skirt, meshes["skirt"], "SkirtMesh")
	leg_l = _pivot(hips, "LegL", Vector3(-HIP_X, -HIP_DROP, 0))
	leg_r = _pivot(hips, "LegR", Vector3(HIP_X, -HIP_DROP, 0))
	knee_l = _pivot(leg_l, "KneeL", Vector3(0, -THIGH, 0))
	knee_r = _pivot(leg_r, "KneeR", Vector3(0, -THIGH, 0))
	_attach(leg_l, meshes["thigh_l"], "Thigh")
	_attach(leg_r, meshes["thigh_r"], "Thigh")
	_attach(knee_l, meshes["shin"], "Shin")
	_attach(knee_r, meshes["shin"], "Shin")
	foot_l = _pivot(knee_l, "FootL", Vector3(0, -SHIN, 0))
	foot_r = _pivot(knee_r, "FootR", Vector3(0, -SHIN, 0))
	_attach(foot_l, meshes["foot_l"], "Foot")
	_attach(foot_r, meshes["foot_r"], "Foot")
	torso = _pivot(hips, "Torso", Vector3(0, TORSO_UP, 0))
	_attach(torso, meshes["abdomen"], "Abdomen")
	chest = _pivot(torso, "Chest", Vector3(0, CHEST_UP, 0))
	_attach(chest, meshes["chest"], "ChestMesh")
	head = _pivot(chest, "Head", Vector3(0, NECK_UP, 0))
	_attach(head, meshes["neck"], "Neck")
	var hair_mi := _attach_lod(head, meshes["hair"], meshes["hair_lo"], "Hair")
	# the hair shell dips under the skin outside the hairline; as a shadow caster it would darken the
	# whole face (only the nose tip poked out into the light), so it casts no shadow
	if hair_mi != null:
		hair_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var hl := head.get_node_or_null("HairLo")
		if hl is GeometryInstance3D:
			(hl as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	face = _attach_lod(head, meshes["skull"], meshes["skull_lo"], "Face")
	face_lo = head.get_node_or_null("FaceLo")
	for f in [face, face_lo]:
		if f != null:
			f.material_override = head_mat
			# the hair, ears and neck still cast the head's shadow; a low-res shadow map would otherwise
			# paint a hard black wedge beside the nose in side light
			f.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	features = face
	var sx := SHOULDER_X * float(b["sh"])
	arm_l = _pivot(chest, "ArmL", Vector3(-sx, SHOULDER_Y, 0.005))
	arm_r = _pivot(chest, "ArmR", Vector3(sx, SHOULDER_Y, 0.005))
	fore_l = _pivot(arm_l, "ForeL", Vector3(0, -UPPER_ARM, 0))
	fore_r = _pivot(arm_r, "ForeR", Vector3(0, -UPPER_ARM, 0))
	_attach(arm_l, meshes["upper_l"], "Upper")
	_attach(arm_r, meshes["upper_r"], "Upper")
	_attach_lod(fore_l, meshes["fore_l"], meshes["fore_l_lo"], "Fore")
	_attach_lod(fore_r, meshes["fore_r"], meshes["fore_r_lo"], "Fore")
	if role == "hostage":
		_build_restraints(b)
	if bool(outfit.get("armed", false)):
		gun = _pivot(chest, "Gun", Vector3(0.11, 0.16, -0.12))
		_attach(gun, meshes["gun"], "Rifle")
		muzzle = _pivot(gun, "Muzzle", Vector3(0, 0.012, -0.86))
	var sc: float = float(outfit.get("scale", 1.0))
	scale = Vector3(sc, sc, sc)
	# Phase 4: outer radius of the thigh (with its cloth) just above the knee, for the carrier's grip
	var pst := str(outfit.get("pants_style", "trousers"))
	var loose := 0.012
	if pst == "salwar":
		loose = 0.03
	elif pst == "cargo":
		loose = 0.018
	elif pst == "jeans" or pst == "lungi":
		loose = 0.008
	elif pst == "shorts" or pst == "bare" or pst == "briefs" or pst == "bikini":
		loose = 0.0
	thigh_radius = 0.066 * float(b["leg"]) * (float(b["hip"]) * 0.4 + 0.6) + loose
	_rest_pose()
	_try_skinned()


# ---------------------------------------------------------------- clothing on / off
## Put the outfit on, switch to beachwear or show the anatomical body. Only the per-segment
## meshes are regenerated: the pivots, restraints, gun, animation state and carry pose are
## untouched, so this is safe to call on a live character (hostage, Alpha or the player).
func set_clothing_mode(mode: String) -> bool:
	if not CLOTHING_MODES.has(mode) or mode == clothing_mode:
		return false
	var o := outfit.duplicate(true)
	var srng := RandomNumberGenerator.new()
	srng.seed = int(float(o.get("seed", 0.0)) * 7919.0) + 1
	apply_clothing(o, srng, mode)
	_rebuild_outfit(o, mode)
	return true


func wear_clothes() -> bool:
	return set_clothing_mode("outfit")


func remove_clothes() -> bool:
	return set_clothing_mode("bare")


# ---------------------------------------------------------------- Phase 7: garment swap
## The clothing keys of an outfit - everything a garment swap moves between two people.
## Body, build, face, skin, hair, hat, vest and rifle stay with their owner.
const CLOTHING_KEYS := ["top", "sleeve", "pants_style", "shirt", "pants", "shoes", "clothing_mode", "dupatta", "check", "tie"]


func clothing_dict() -> Dictionary:
	var g := {}
	for k in CLOTHING_KEYS:
		if outfit.has(k):
			g[k] = outfit[k]
	return g


## Put on a garment taken from somebody else (the bomb-procedure transfer, the clothes-swap order).
func wear_garment(g: Dictionary) -> void:
	var o := outfit.duplicate(true)
	for k in CLOTHING_KEYS:
		o.erase(k)
	for k in g.keys():
		o[k] = g[k]
	_rebuild_outfit(o, str(o.get("clothing_mode", "outfit")))


## Exchange clothes with another live character (hostage <-> Freelancer / Alpha). Both bodies keep
## their own face, build and gear; only the garment meshes are rebuilt.
func swap_clothes(other: Node) -> void:
	if other == null or other == self or not other.has_method("clothing_dict"):
		return
	var mine := clothing_dict()
	var theirs: Dictionary = other.clothing_dict()
	wear_garment(theirs)
	other.wear_garment(mine)


func _rebuild_outfit(o: Dictionary, mode: String) -> void:
	outfit = o
	clothing_mode = mode
	build = str(outfit.get("build", "average"))
	if not BUILDS.has(build):
		build = "average"
	_female = bool(outfit.get("female", false))
	var b: Dictionary = BUILDS[build]
	var meshes: Dictionary = _build_meshes(b)
	var swaps: Array = [
		["Hips/Pelvis", meshes.get("pelvis")],
		["Hips/Skirt/SkirtMesh", meshes.get("skirt")],
		["Hips/Torso/Abdomen", meshes.get("abdomen")],
		["Hips/Torso/Chest/ChestMesh", meshes.get("chest")],
		["Hips/Torso/Chest/Head/Neck", meshes.get("neck")],
		["Hips/LegL/Thigh", meshes.get("thigh_l")],
		["Hips/LegR/Thigh", meshes.get("thigh_r")],
		["Hips/LegL/KneeL/Shin", meshes.get("shin")],
		["Hips/LegR/KneeR/Shin", meshes.get("shin")],
		["Hips/LegL/KneeL/FootL/Foot", meshes.get("foot_l")],
		["Hips/LegR/KneeR/FootR/Foot", meshes.get("foot_r")],
		["Hips/Torso/Chest/ArmL/Upper", meshes.get("upper_l")],
		["Hips/Torso/Chest/ArmR/Upper", meshes.get("upper_r")],
		["Hips/Torso/Chest/ArmL/ForeL/Fore", meshes.get("fore_l")],
		["Hips/Torso/Chest/ArmR/ForeR/Fore", meshes.get("fore_r")],
		["Hips/Torso/Chest/ArmL/ForeL/ForeLo", meshes.get("fore_l_lo")],
		["Hips/Torso/Chest/ArmR/ForeR/ForeLo", meshes.get("fore_r_lo")],
	]
	for sw in swaps:
		var mi := get_node_or_null(str(sw[0])) as MeshInstance3D
		if mi != null and sw[1] is Mesh:
			mi.mesh = sw[1]
	# the carrier's hand grip rides the cloth over the thigh, so refresh that radius too
	var pst := str(outfit.get("pants_style", "trousers"))
	var loose := 0.012
	if pst == "salwar":
		loose = 0.03
	elif pst == "cargo":
		loose = 0.018
	elif pst == "jeans" or pst == "lungi":
		loose = 0.008
	elif pst == "shorts" or pst == "bare" or pst == "briefs" or pst == "bikini":
		loose = 0.0
	thigh_radius = 0.066 * float(b["leg"]) * (float(b["hip"]) * 0.4 + 0.6) + loose


## High-resolution .glb / .fbx body for this role when the player supplied one (see SkinnedModel.gd).
## Hostages and Alpha Team women always keep the built-in body.
var skinned: Node3D = null


func _try_skinned() -> void:
	if role == "hostage" or (role == "ally" and _female):
		return
	var key := role
	if not SkinnedModel.ROLE_FILES.has(key):
		return
	var path := SkinnedModel.find_model(key)
	if path == "":
		return
	var scene := SkinnedModel.instantiate_file(path)
	if scene == null:
		return
	var sm: Node3D = SkinnedModel.new()
	sm.name = "Skinned"
	add_child(sm)
	if sm.attach(self, scene):
		skinned = sm
	else:
		sm.queue_free()


func _set_head_params(m: ShaderMaterial) -> void:
	m.set_shader_parameter("head_center", HEAD_C)
	m.set_shader_parameter("head_radii", HEAD_R)
	m.set_shader_parameter("eye_y", EYE_Y)
	m.set_shader_parameter("long_hair", 1.0 if _female else 0.0)
	m.set_shader_parameter("hair_line", 0.12 if _female else 0.2)
	var f := _fp
	m.set_shader_parameter("eye_x", 0.031 * (1.0 + 0.07 * float(f.get("eye_sp", 0.0))))
	m.set_shader_parameter("eye_scale", 1.0 + 0.13 * float(f.get("eye_size", 0.0)))
	m.set_shader_parameter("eye_tilt", 0.09 * float(f.get("eye_tilt", 0.0)))
	m.set_shader_parameter("brow_arch", float(f.get("brow_arch", 0.0)))
	m.set_shader_parameter("nose_w", float(f.get("nose_w", 0.0)))
	m.set_shader_parameter("nose_l", float(f.get("nose_l", 0.0)))
	m.set_shader_parameter("lip_w", float(f.get("lip_w", 0.0)))
	m.set_shader_parameter("lip_full", float(f.get("lip_full", 0.0)))
	m.set_shader_parameter("kajal", float(f.get("kajal", 0.0)))
	m.set_shader_parameter("blush", float(f.get("blush", 0.0)))
	m.set_shader_parameter("age", float(f.get("age", 0.0)))
	m.set_shader_parameter("mole", 1.0 if bool(f.get("mole", false)) else 0.0)
	m.set_shader_parameter("lip_tint", LIP_COLORS[clampi(int(f.get("lip_color", 0)), 0, LIP_COLORS.size() - 1)] if _female or int(f.get("lip_color", 0)) > 0 else Color(0.5, 0.3, 0.3, 0.0))
	m.set_shader_parameter("bindi_color", BINDI_COLORS[clampi(int(f.get("bindi", 0)), 0, BINDI_COLORS.size() - 1)])
	m.set_shader_parameter("female", 1.0 if _female else 0.0)


## Packed skull parameters: [fw, jaw, chin, cheek, nose_w, nose_l, lip_full, lip_w, eye_size, eye_sp, age, female]
static func _geo(fp: Dictionary, female: bool) -> PackedFloat32Array:
	var g := PackedFloat32Array()
	for k in FACE_GEO:
		g.append(float(fp.get(k, 0.0)))
	g.append(1.0 if female else 0.0)
	return g


# ============================================================================ body meshes
func _build_meshes(b: Dictionary) -> Dictionary:
	var out := {}
	var top := str(outfit.get("top", "shirt"))
	var pst := str(outfit.get("pants_style", "trousers"))
	var shoes := str(outfit.get("shoes", "shoes"))
	# swimwear (_swimwear): bare skin on the trunk; the briefs / bikini are shells built over it below
	var swim := pst == "briefs" or pst == "bikini"
	# "bare" clothing mode (bare trousers + no top) shows the full anatomical body as well.
	var bare := pst == "bare" and top == "none"
	var skin_trunk := swim or bare
	var cloth_id := PRINT if (top == "kameez" or top == "dress" or top == "beachshirt") else CLOTH
	var cloth: Color = _c(outfit.get("shirt", Color.GRAY), cloth_id)
	var pants: Color = _c(outfit.get("pants", Color.DIM_GRAY), CLOTH)
	var skin := Color(1, 1, 1, SKIN)
	var leather := Color(0.09, 0.075, 0.06, LEATHER)
	var hipf: float = b["hip"]
	var chf: float = b["ch"]
	var shf: float = b["sh"]
	var bel: float = b["bel"]
	var armf: float = b["arm"]
	var legf: float = b["leg"]
	var nf: float = b["neck"]
	var id := Transform3D()
	var pant_loose := 0.012
	if pst == "salwar":
		pant_loose = 0.03
	elif pst == "cargo":
		pant_loose = 0.018
	elif pst == "jeans":
		pant_loose = 0.008
	elif pst == "shorts":
		pant_loose = 0.016
	elif pst == "bare" or swim:
		pant_loose = 0.0
	if pst == "bare":
		# under a dress: skin all the way up to the hem (the pelvis keeps a slip in the dress colour)
		pants = _c(cloth.darkened(0.1), CLOTH)
	if bool(outfit.get("check", false)) or pst == "lungi":
		pants = _c(pants.lightened(0.06), CHECK)
	var long_top := top == "panjabi" or top == "kameez" or top == "dress"
	# cloth thickness on the trunk and the abdomen profile (defined here: the swim bottom needs it too)
	var tl := 0.0 if skin_trunk else (0.014 if long_top else 0.007)
	# bare trunk (beachwear or anatomy mode): muscles and forms on top of the lofted sections (_relief)
	var rp: Dictionary = _relief_params(b, _female, build) if skin_trunk else {}
	var trunk_col := skin if skin_trunk else cloth
	var waist := 0.128 if _female else 0.137
	var abd := [[-0.06, 0.15 * hipf, 0.094 * hipf, 0.002, 0.092], [0.0, 0.142 * lerpf(hipf, 1.0, 0.5), 0.094 + bel, -bel * 0.5, 0.084],
		[0.05, waist * lerpf(hipf, chf, 0.5), 0.095 + bel, -bel * 0.5, 0.081], [0.1, 0.138 * chf, 0.097 + bel * 0.8, -bel * 0.4, 0.085],
		[0.165, 0.149 * chf, 0.1 * chf, 0.0, 0.095]]

	# ---------------- pelvis (hips pivot): iliac crest, hip, glutes rounding out the back, crotch
	var m := Mesher.new()
	var gl := 1.35 if _female else 1.0
	var pl := pant_loose * 0.5
	var prof := [[-0.02, 0.05, 0.045, -0.05, 0.045, 1.0], 
		[-0.01, 0.105, 0.064, -0.03, 0.08 * gl],
		[0.02, 0.142 * hipf, 0.08 * hipf, -0.015, 0.112 * hipf * gl], 
		[0.06, 0.158 * hipf, 0.088 * hipf, 0.0, 0.124 * hipf * gl],
		[0.09, 0.164 * hipf, 0.093 * hipf, 0.004, 0.12 * hipf * gl], 
		[0.12, 0.161 * hipf, 0.096 * hipf, 0.003, 0.106 * hipf],
		[0.15, 0.153 * hipf, 0.096 * hipf, 0.0, 0.095 * hipf], 
		[0.18, 0.146 * hipf, 0.094, 0.0, 0.09]]
	var rings := []
	for p in prof:
		var r := [Vector3(0, float(p[0]), float(p[3])), float(p[1]) + pl, float(p[2]) + pl, skin if swim else pants, float(p[4]) + pl]
		if p.size() > 5:
			r.append(p[5])
		rings.append(r)
	if skin_trunk:
		_relief_loft(m, prof, 0.86, 64, skin, 0, rp, true, false)
		if swim:
			_build_swim_bottom(m, pants, prof, abd, rp, pst == "bikini")
	else:
		m.loft(rings, 34, id, true, false, 0.86)
	if top == "suit" or top == "shirt" or top == "tshirt" or top == "beachshirt":
		# belt with buckle and loops
		var bz := 0.104 * hipf + pl
		m.loft([[Vector3(0, 0.052, 0.004), 0.158 * hipf + pl + 0.005, 0.1 * hipf + pl + 0.005, leather, 0.104 * hipf + pl + 0.005],
			[Vector3(0, 0.088, 0.0), 0.151 * hipf + pl + 0.005, 0.097 * hipf + pl + 0.005, leather, 0.095 * hipf + pl + 0.005]], 26, id, false, false, 0.86)
		m.slab(Vector3(0, 0.07, -bz - 0.002), Vector3(0.05, 0.034, 0.008), Color(0.62, 0.6, 0.52, METAL))
		if pst == "jeans" or pst == "trousers" or pst == "cargo" or pst == "shorts" or pst == "capri":
			# fly seam and front pockets
			m.box(Vector3(0, -0.02, -0.095 * hipf - pl - 0.001), Vector3(0.004, 0.09, 0.003), pants.darkened(0.25))
	if pst == "cargo":
		for s: float in [-1.0, 1.0]:
			m.box(Vector3(0.12 * s * hipf, 0.0, -0.06 * hipf - pl), Vector3(0.004, 0.08, 0.05), pants.darkened(0.2), Transform3D(Basis(Vector3.UP, 0.5 * s), Vector3.ZERO))
	out["pelvis"] = _to_mesh(m)

	# ---------------- tunic / lungi skirt (skirt pivot follows the thighs)
	m = Mesher.new()
	if long_top:
		var hem_c: Color = _c(outfit.get("dupatta", Color(0.95, 0.88, 0.6)), CLOTH) if top == "kameez" else cloth.darkened(0.12 if top == "dress" else 0.06)
		var flare := 0.035
		var sp := [[0.11, 0.164, 0.104, 0.0, 0.122], [-0.04, 0.178, 0.114, 0.003, 0.142], [-0.16, 0.19, 0.124, 0.006, 0.152],
			[-0.28, 0.2, 0.132, 0.008, 0.158], [-0.37, 0.207, 0.137, 0.009, 0.162], [-0.4, 0.209, 0.139, 0.009, 0.163], [-0.44, 0.212, 0.142, 0.01, 0.165]]
		rings = []
		for i in sp.size():
			var p: Array = sp[i]
			var f := flare * (0.35 + 0.65 * float(i) / float(sp.size() - 1))
			var cc: Color = cloth if float(p[0]) > -0.395 else hem_c
			if i == 5:
				rings.append([Vector3(0, -0.3985, float(p[3])), float(p[1]) * hipf + f, float(p[2]) * hipf + f, cloth, float(p[4]) * hipf + f])
			rings.append([Vector3(0, float(p[0]), float(p[3])), float(p[1]) * hipf + f, float(p[2]) * hipf + f, cc, float(p[4]) * hipf + f])
		m.loft(rings, 30, id, false, false, 0.92, true)
	if pst == "lungi":
		m.loft([[Vector3(0, 0.11, 0.0), 0.163 * hipf + 0.02, 0.103 * hipf + 0.02, pants, 0.125 * hipf + 0.02], [Vector3(0, -0.1, 0.004), 0.185 * hipf + 0.016, 0.125 * hipf + 0.012, pants, 0.15 * hipf + 0.012],
			[Vector3(0, -0.4, 0.008), 0.198 * hipf + 0.012, 0.142 * hipf, pants, 0.152 * hipf], [Vector3(0, -0.84, 0.01), 0.205 * hipf + 0.012, 0.155 * hipf, pants, 0.158 * hipf]], 26, id, false, false, 0.9, true)
		# the knot / fold tucked at the waist
		m.ellipsoid(Vector3(0.02, 0.07, -0.118 * hipf - 0.02), Vector3(0.03, 0.022, 0.012), pants.darkened(0.08), 8, 5)
	out["skirt"] = _to_mesh(m)

	# ---------------- abdomen (torso pivot): waist narrower than ribcage, belly forward, lumbar curve
	m = Mesher.new()
	rings = []
	for p in abd:
		rings.append([Vector3(0, float(p[0]), float(p[3])), float(p[1]) + tl, float(p[2]) + tl, trunk_col, float(p[4]) + tl])
	if skin_trunk:
		_relief_loft(m, abd, 0.82, 56, skin, 1, rp, false, false)
	else:
		m.loft(rings, 34, id, false, false, 0.82)
	if top == "shirt" or top == "panjabi":
		for y: float in [0.02, 0.1]:
			m.ellipsoid(Vector3(0, y, -0.096 - tl - (bel * 0.9 if y < 0.05 else bel * 0.7)), Vector3(0.0045, 0.0045, 0.0022), cloth.lightened(0.25), 6, 4)
	# --- abdominal detail: one build-driven pass on the exposed trunk (no stacked z-fighting) ---
	if skin_trunk and not _female:
		_build_abs_detail(m, rp, tl, bel, trunk_col)
	out["abdomen"] = _to_mesh(m)

	# ---------------- chest (chest pivot): ribcage, pectorals, lats, trapezius slope to the neck
	m = Mesher.new()
	var shw := lerpf(chf, shf, 0.5)
	var chp := [[-0.05, 0.146 * chf, 0.1 * chf, 0.0, 0.098 * chf, 0.82], [0.03, 0.153 * chf, 0.106 * chf, -0.004, 0.104 * chf, 0.82],
		[0.1, 0.161 * shw, 0.112 * chf, -0.008, 0.108 * chf, 0.8], [0.16, 0.167 * shf, 0.11 * chf, -0.006, 0.108 * chf, 0.8],
		[0.2, 0.173 * shf, 0.102 * chf, -0.002, 0.1 * chf, 0.82], [0.232, 0.178 * shf, 0.09 * chf, 0.004, 0.09 * chf, 0.8],
		[0.252, 0.165 * shf, 0.078, 0.007, 0.078, 0.82], [0.266, 0.132 * shf, 0.068, 0.009, 0.069, 0.94],
		[0.278, 0.094 * nf, 0.06, 0.011, 0.062, 1.0], [0.29, 0.068 * nf, 0.055, 0.012, 0.057, 1.0]]
			# --- MALE PECTORALS (Defined, sculpted shelf) ---
	if not _female:
		# Increased depth from 0.112 to 0.125 (better than normal, but not huge)
		# Lowered the center slightly (-0.01) to create a pec shelf
		chp[2] = [0.09, 0.161 * shw, 0.125 * chf, -0.01, 0.108 * chf, 0.78] 
		chp[3] = [0.15, 0.167 * shf, 0.120 * chf, -0.008, 0.108 * chf, 0.78]
	# ------------------------------------------------

	if _female:
		chp[1] = [0.03, 0.152 * chf, 0.115 * chf, -0.006, 0.1 * chf, 0.8]
		chp[2] = [0.09, 0.160 * chf, 0.145, -0.015, 0.1 * chf, 0.75]
		chp[3] = [0.15, 0.165 * shf, 0.135, -0.012, 0.1 * chf, 0.78]
		if skin_trunk:
			# bare: the breasts come from the relief, so the ribcage under them is flatter
			chp[2] = [0.09, 0.152 * chf, 0.106 * chf, -0.006, 0.1 * chf, 0.78]
			chp[3] = [0.15, 0.158 * shf, 0.106 * chf, -0.006, 0.1 * chf, 0.8]
	rings = []
	for p in chp:
		rings.append([Vector3(0, float(p[0]), float(p[3])), float(p[1]) + tl, float(p[2]) + tl, trunk_col, float(p[4]) + tl, p[5]])
	if skin_trunk:
		_relief_loft(m, chp, 0.82, 64, skin, 2, rp, false, true)
	else:
		m.loft(rings, 36, id, false, true, 0.82)
	if top == "bikini":
		_build_bikini_top(m, cloth, chp, nf, rp)
	var fz := -0.112 * chf - tl - 0.008
	match top:
		"suit":
			var white := Color(0.93, 0.93, 0.92, CLOTH)
			var tie: Color = _c(outfit.get("tie", Color(0.5, 0.1, 0.1)), CLOTH)
			# shirt V, tie (knot + blade lying on the chest), lapels
			m.box(Vector3.ZERO, Vector3(0.07, 0.1, 0.004), white, Transform3D(Basis(Vector3.RIGHT, -0.5), Vector3(0, 0.232, -0.09 * chf - tl - 0.006)))
			m.ellipsoid(Vector3.ZERO, Vector3(0.014, 0.012, 0.008), tie, 8, 5, Transform3D(Basis(), Vector3(0, 0.248, -0.086 * chf - tl - 0.006)))
			m.slab(Vector3.ZERO, Vector3(0.034, 0.21, 0.006), tie, Transform3D(Basis(Vector3.RIGHT, -0.1), Vector3(0, 0.14, -0.111 * chf - tl - 0.006)))
			for s: float in [-1.0, 1.0]:
				m.box(Vector3.ZERO, Vector3(0.036, 0.16, 0.005), cloth.darkened(0.14), Transform3D(Basis.from_euler(Vector3(-0.2, 0.0, -0.3 * s)), Vector3(0.05 * s, 0.17, -0.106 * chf - tl - 0.004)))
		"shirt", "beachshirt":
			# placket with buttons and two chest pockets with flaps (a printed beach shirt has none)
			m.box(Vector3(0, 0.1, fz + 0.007), Vector3(0.022, 0.32, 0.004), cloth.darkened(0.06))
			for y: float in [0.03, 0.1, 0.17, 0.23]:
				m.ellipsoid(Vector3(0, y, fz + 0.004), Vector3(0.0045, 0.0045, 0.0022), cloth.lightened(0.25), 6, 4)
			if outfit.get("vest") == null and top == "shirt":
				for s: float in [-1.0, 1.0]:
					m.slab(Vector3(0.068 * s, 0.135, fz + 0.01), Vector3(0.06, 0.07, 0.006), cloth.darkened(0.04))
					m.slab(Vector3(0.068 * s, 0.17, fz + 0.006), Vector3(0.064, 0.018, 0.007), cloth.darkened(0.1))
		"tshirt":
			m.loft([[Vector3(0, 0.272, 0.012), 0.083 * nf + tl, 0.064 + tl, cloth.darkened(0.12), 0.066 + tl], [Vector3(0, 0.29, 0.012), 0.07 * nf + tl, 0.057 + tl, cloth.darkened(0.12), 0.059 + tl]], 20, id, false, false)
	if top == "shirt" or top == "suit" or top == "beachshirt":
		# turned-down collar: band round the neck, flaring out, with two points at the front
		var cc := Color(0.93, 0.93, 0.92, CLOTH) if top == "suit" else cloth
		m.loft([[Vector3(0, 0.268, 0.012), 0.08 * nf + 0.012, 0.066 + 0.012, cc, 0.07 + 0.01], [Vector3(0, 0.3, 0.013), 0.07 * nf + 0.014, 0.06 + 0.013, cc, 0.064 + 0.012],
			[Vector3(0, 0.312, 0.014), 0.066 * nf + 0.014, 0.057 + 0.012, cc, 0.061 + 0.012]], 22, id, false, false, 1.0, true)
		for s: float in [-1.0, 1.0]:
			m.box(Vector3(0.026 * s, 0.272, -0.07 * nf - 0.016), Vector3(0.036, 0.05, 0.004), cc, Transform3D(Basis.from_euler(Vector3(-0.5, 0.0, 0.55 * s)), Vector3.ZERO))
	elif top == "panjabi" or top == "kameez" or top == "dress":
		# mandarin band (panjabi) or a soft round neckline (kameez embroidery / a dress's piping)
		var emb := cloth.darkened(0.22) if top == "panjabi" else (cloth.darkened(0.18) if top == "dress" else _c(outfit.get("dupatta", Color(0.95, 0.88, 0.6)), CLOTH))
		if top == "panjabi":
			m.loft([[Vector3(0, 0.27, 0.012), 0.078 * nf + 0.011, 0.064 + 0.011, cloth, 0.068 + 0.01], [Vector3(0, 0.305, 0.013), 0.067 * nf + 0.012, 0.058 + 0.012, cloth, 0.061 + 0.011]], 22, id, false, false, 1.0, true)
			m.box(Vector3(0, 0.18, fz + 0.007), Vector3(0.026, 0.19, 0.004), emb)
			for y: float in [0.12, 0.17, 0.22]:
				m.ellipsoid(Vector3(0, y, fz + 0.004), Vector3(0.005, 0.005, 0.0025), Color(0.85, 0.75, 0.45, METAL), 6, 4)
		else:
			var pts := []
			var ups := []
			for i in 15:
				var a := lerpf(-PI * 0.97, -PI * 0.03, float(i) / 14.0)
				var dip := -sin(a)
				pts.append(Vector3(cos(a) * 0.072 * nf, 0.279 - dip * 0.046, lerpf(-0.045, -0.097, dip)))
				ups.append(Vector3(0, 0.35 - 0.2 * dip, -1).normalized())
			m.sweep(pts, [Vector2(0.0045, 0.0014)], emb, 6, false, false, ups)
	if outfit.get("vest") != null:
		var bust := float(rp.get("breast", 0.0))
		_build_vest(m, _c(outfit["vest"], CLOTH), chf, shf, tl, 0.45 * bust + (0.002 if bust > 0.0 else 0.0))
	if outfit.has("dupatta"):
		_build_dupatta(m, _c(outfit["dupatta"], PRINT), chf, shf, tl)
	out["chest"] = _to_mesh(m)

	# ---------------- neck + ears + hair + hat + jewellery (head pivot, body material)
	m = Mesher.new()
	m.loft([[Vector3(0, -0.04, 0.012), 0.074 * nf, 0.062 * nf, skin, 0.068 * nf], [Vector3(0, 0.0, 0.015), 0.065 * nf, 0.058 * nf, skin, 0.064 * nf],
		[Vector3(0, 0.05, 0.015), 0.059 * nf, 0.055 * nf, skin, 0.061 * nf], [Vector3(0, 0.09, 0.014), 0.057 * nf, 0.052 * nf, skin, 0.059 * nf],
		[Vector3(0, 0.125, 0.012), 0.053 * nf, 0.047 * nf, skin, 0.054 * nf]], 20, id, false, false)
	if not _female:
		# laryngeal prominence
		m.ellipsoid(Vector3(0, 0.045, -0.05 * nf + 0.012), Vector3(0.009, 0.013, 0.008), skin, 8, 5)
	var hat0 := str(outfit.get("hat", "none"))
	if hat0 != "hijab":
		for s: float in [-1.0, 1.0]:
			_build_ear(m, s, skin)
	var hair_len := int(outfit.get("hair_len", 2 if _female else 0))
	if hat0 == "hijab":
		hair_len = -1
	var hkey := "%s|%d|%s|%s|%s" % [str(_g), hair_len, _female, hat0 != "none", str(outfit.get("dupatta", ""))]
	if not _hair_cache.has(hkey):
		if _hair_cache.size() > 120:
			_hair_cache.clear()
		var hm := Mesher.new()
		var hl := Mesher.new()
		if hair_len >= 0:
			_build_hair(hm, hair_len, hat0 != "none", false)
			_build_hair(hl, hair_len, hat0 != "none", true)
		_hair_cache[hkey] = [_to_mesh(hm), _to_mesh(hl)]
	out["hair"] = _hair_cache[hkey][0]
	out["hair_lo"] = _hair_cache[hkey][1]
	var hc: Color = _c(outfit.get("hat_color", Color(0.1, 0.1, 0.1)), CLOTH)
	var top_y := HEAD_C.y + HEAD_R.y
	match hat0:
		"hijab":
			_build_hijab(m, hc, b, _g)
		"cap":
			m.loft([[Vector3(0, top_y - 0.075, 0.004), HEAD_R.x + 0.011, HEAD_R.z + 0.011, hc], [Vector3(0, top_y - 0.04, 0.006), HEAD_R.x + 0.006, HEAD_R.z + 0.006, hc],
				[Vector3(0, top_y - 0.012, 0.008), HEAD_R.x - 0.02, HEAD_R.z - 0.02, hc], [Vector3(0, top_y + 0.004, 0.01), 0.03, 0.03, hc]], 22, id, false, true)
			var brim := []
			for i in 9:
				var a := lerpf(-1.0, 1.0, float(i) / 8.0)
				brim.append(Vector3(a * 0.075, top_y - 0.07 - absf(a) * 0.004, -HEAD_R.z - 0.01 - 0.055 * (1.0 - a * a * 0.6)))
			m.sweep(brim, [Vector2(0.002, 0.03)], hc.darkened(0.05), 6, true, true, [Vector3(0, 0, -1)])
			m.ellipsoid(Vector3(0, top_y + 0.004, 0.008), Vector3(0.008, 0.004, 0.008), hc, 6, 3)
		"helmet":
			m.loft([[Vector3(0, top_y - 0.09, 0.006), HEAD_R.x + 0.032, HEAD_R.z + 0.034, hc], [Vector3(0, top_y - 0.05, 0.006), HEAD_R.x + 0.03, HEAD_R.z + 0.032, hc],
				[Vector3(0, top_y - 0.01, 0.006), HEAD_R.x + 0.01, HEAD_R.z + 0.012, hc], [Vector3(0, top_y + 0.012, 0.006), 0.03, 0.03, hc]], 22, id, true, true)
			m.slab(Vector3(0, top_y - 0.07, -HEAD_R.z - 0.036), Vector3(0.04, 0.03, 0.012), Color(0.06, 0.06, 0.06, METAL))
		"bandana":
			m.loft([[Vector3(0, top_y - 0.075, 0.0), HEAD_R.x + 0.006, HEAD_R.z + 0.006, hc], [Vector3(0, top_y - 0.04, 0.004), HEAD_R.x + 0.002, HEAD_R.z + 0.003, hc],
				[Vector3(0, top_y - 0.01, 0.006), HEAD_R.x - 0.03, HEAD_R.z - 0.03, hc], [Vector3(0, top_y + 0.004, 0.006), 0.02, 0.02, hc]], 22, id, false, true)
			m.ellipsoid(Vector3(0, top_y - 0.07, HEAD_R.z + 0.012), Vector3(0.018, 0.014, 0.012), hc, 8, 5)
			m.sweep([Vector3(0.005, top_y - 0.072, HEAD_R.z + 0.02), Vector3(0.012, top_y - 0.11, HEAD_R.z + 0.03), Vector3(0.016, top_y - 0.15, HEAD_R.z + 0.026)],
				[Vector2(0.014, 0.002), Vector2(0.012, 0.002), Vector2(0.008, 0.002)], hc, 6, false, true, [Vector3.BACK], true)
		"beret":
			m.ellipsoid(Vector3(0.022, top_y - 0.015, 0.0), Vector3(HEAD_R.x + 0.03, 0.03, HEAD_R.z + 0.022), hc, 18, 8)
			m.loft([[Vector3(0, top_y - 0.05, 0.004), HEAD_R.x + 0.008, HEAD_R.z + 0.008, Color(0.05, 0.05, 0.05, LEATHER)], [Vector3(0, top_y - 0.04, 0.004), HEAD_R.x + 0.006, HEAD_R.z + 0.006, Color(0.05, 0.05, 0.05, LEATHER)]], 22, id, false, false)
			m.slab(Vector3(-0.045, top_y - 0.03, -HEAD_R.z + 0.012), Vector3(0.022, 0.026, 0.006), GOLD, Transform3D(Basis(Vector3.UP, 0.45), Vector3.ZERO))
		"sunhat":
			# woven sun hat: a low crown and a wide, slightly drooping brim
			m.loft([[Vector3(0, top_y - 0.06, 0.006), HEAD_R.x + 0.012, HEAD_R.z + 0.012, hc], [Vector3(0, top_y - 0.02, 0.006), HEAD_R.x + 0.006, HEAD_R.z + 0.006, hc],
				[Vector3(0, top_y + 0.012, 0.006), HEAD_R.x - 0.02, HEAD_R.z - 0.02, hc], [Vector3(0, top_y + 0.02, 0.006), 0.02, 0.02, hc]], 22, id, false, true)
			m.loft([[Vector3(0, top_y - 0.072, 0.006), HEAD_R.x + 0.075, HEAD_R.z + 0.075, hc.darkened(0.05)], [Vector3(0, top_y - 0.058, 0.006), HEAD_R.x + 0.014, HEAD_R.z + 0.014, hc],
				[Vector3(0, top_y - 0.054, 0.006), HEAD_R.x + 0.012, HEAD_R.z + 0.012, hc]], 26, id, false, false)
			m.loft([[Vector3(0, top_y - 0.05, 0.006), HEAD_R.x + 0.013, HEAD_R.z + 0.013, hc.darkened(0.35)], [Vector3(0, top_y - 0.035, 0.006), HEAD_R.x + 0.01, HEAD_R.z + 0.01, hc.darkened(0.35)]], 22, id, false, false)
		"tupi":
			m.loft([[Vector3(0, top_y - 0.06, 0.006), HEAD_R.x + 0.006, HEAD_R.z + 0.006, hc], [Vector3(0, top_y - 0.03, 0.006), HEAD_R.x + 0.004, HEAD_R.z + 0.004, hc],
				[Vector3(0, top_y - 0.005, 0.006), HEAD_R.x - 0.025, HEAD_R.z - 0.025, hc], [Vector3(0, top_y + 0.004, 0.006), 0.02, 0.02, hc]], 22, id, false, true)
	_build_jewellery(m)
	out["neck"] = _to_mesh(m)

	# ---------------- skull (head material; the photo or the painted face goes onto this)
	var skey := str(_g)
	if not _skull_cache.has(skey):
		var sm := Mesher.new()
		_build_skull(sm, _g, 54, 42)
		var sl := Mesher.new()
		_build_skull(sl, _g, 22, 14)
		if _skull_cache.size() > 120:
			_skull_cache.clear()
		_skull_cache[skey] = [_to_mesh(sm), _to_mesh(sl)]
	out["skull"] = _skull_cache[skey][0]
	out["skull_lo"] = _skull_cache[skey][1]

	# ---------------- arms: deltoid cap, biceps / triceps, elbow, brachioradialis, flat wrist, hand
	var sleeve := str(outfit.get("sleeve", "long"))
	var gloves := bool(outfit.get("gloves", false))
	var upper_prof := [[-0.004, 0.012, 0.012, 0.0, 0.012], [-0.008, 0.03, 0.032, 0.0, 0.032], [-0.016, 0.042, 0.045, 0.0, 0.045],
		[-0.03, 0.048, 0.05, 0.0, 0.05], [-0.05, 0.049, 0.049, -0.001, 0.05], [-0.095, 0.046, 0.047, -0.002, 0.049],
		[-0.14, 0.043, 0.047, -0.004, 0.045], [-0.19, 0.041, 0.045, -0.003, 0.041], [-0.24, 0.039, 0.04, -0.001, 0.039], [-0.3, 0.037, 0.035, 0.002, 0.039]]
	var fore_prof := [[0.03, 0.037, 0.037, 0.003, 0.04], [0.0, 0.041, 0.04, 0.0, 0.044], [-0.035, 0.044, 0.046, -0.004, 0.04],
		[-0.08, 0.041, 0.044, -0.004, 0.037], [-0.13, 0.035, 0.038, -0.002, 0.032], [-0.18, 0.029, 0.033, 0.0, 0.029],
		[-0.225, 0.023, 0.03, 0.0, 0.027], [-0.255, 0.021, 0.028, 0.0, 0.026]]
	if _female:
		upper_prof[3] = [-0.03, 0.045, 0.046, 0.0, 0.047]
		upper_prof[4] = [-0.05, 0.045, 0.045, -0.001, 0.047]
		upper_prof[6] = [-0.14, 0.04, 0.042, -0.003, 0.045]
		fore_prof[2] = [-0.035, 0.04, 0.041, -0.003, 0.039]
	var up_cut := 1.0
	var fo_cut := 1.0
	match sleeve:
		"long":
			up_cut = -1.0
			fo_cut = -0.235
		"3q":
			up_cut = -1.0
			fo_cut = -0.1
		"short":
			up_cut = -0.13
			fo_cut = 1.0
	var sl := 0.009 if top != "tshirt" else 0.007
	if top == "kameez" or top == "dress":
		sl = 0.006
	var armed := bool(outfit.get("armed", false))
	for side: String in ["l", "r"]:
		var sgn := -1.0 if side == "l" else 1.0
		m = Mesher.new()
		var ur := _rings(upper_prof, up_cut, cloth, skin, sl, armf, 0.002 * sgn)
		m.loft(ur, 22, id, true, false)
		if up_cut > -0.5 and up_cut < 0.5:
			# short sleeve: a turned hem
			m.loft([[Vector3(0.006 * sgn, up_cut + 0.012, -0.003), 0.047 * armf + sl + 0.002, 0.051 * armf + sl + 0.002, cloth.darkened(0.08), 0.048 * armf + sl + 0.002],
				[Vector3(0.006 * sgn, up_cut, -0.003), 0.046 * armf + sl + 0.002, 0.05 * armf + sl + 0.002, cloth.darkened(0.08), 0.047 * armf + sl + 0.002]], 18, id, false, false)
		out["upper_" + side] = _to_mesh(m)
		m = Mesher.new()
		var elbow_col := cloth if fo_cut < 0.0 else skin
		var el := sl if fo_cut < 0.0 else 0.0
		m.ellipsoid(Vector3(0, 0.0, 0.006), Vector3(0.039 * armf + el, 0.042, 0.042 * armf + el), elbow_col, 14, 8)
		m.loft(_rings(fore_prof, fo_cut, cloth, skin, sl, armf), 20, id, false, false)
		if fo_cut > -0.5 and fo_cut < 0.5:
			# cuff
			var cy := fo_cut
			m.loft([[Vector3(0, cy + 0.02, 0), 0.038 * armf + sl, 0.041 * armf + sl, cloth.darkened(0.08), 0.037 * armf + sl],
				[Vector3(0, cy, 0), 0.036 * armf + sl, 0.039 * armf + sl, cloth.darkened(0.08), 0.035 * armf + sl]], 16, id, false, false)
		var hand_col := Color(0.07, 0.07, 0.07, LEATHER) if gloves else skin
		_build_hand(m, sgn, hand_col, armf, armed or (role == "hostage" and sgn > 0.0), gloves)
		out["fore_" + side] = _to_mesh(m)
		# distant version: fewer sides, a mitten hand
		m = Mesher.new()
		m.loft(_rings(fore_prof, fo_cut, cloth, skin, sl, armf), 10, id, true, false)
		var hs := 0.92 if _female else 1.0
		var gg := 0.004 if gloves else 0.0
		m.loft([[Vector3(0, -0.25, 0.0), 0.02 * hs + gg, 0.027 * hs + gg, hand_col], [Vector3(0, -0.29, -0.002), 0.017 * hs + gg, 0.04 * hs + gg, hand_col],
			[Vector3(0, -0.34, 0.0), 0.014 * hs + gg, 0.042 * hs + gg, hand_col], [Vector3(0, -0.4, 0.002), 0.011 * hs + gg, 0.034 * hs + gg, hand_col],
			[Vector3(0, -0.425, 0.004), 0.008 * hs, 0.02 * hs, hand_col]], 8, id, false, true, 0.85)
		out["fore_" + side + "_lo"] = _to_mesh(m)

	# ---------------- legs: thighs (mirrored: inner-thigh mass and vastus medialis), knee, calf, feet
	var thigh_prof := [[0.07, 0.095, 0.10, 0.006, 0.105], [0.0, 0.096, 0.10, 0.004, 0.104], [-0.08, 0.092, 0.097, 0.0, 0.098],
		[-0.16, 0.085, 0.09, -0.004, 0.088], [-0.24, 0.076, 0.082, -0.006, 0.076], [-0.31, 0.068, 0.073, -0.006, 0.066],
		[-0.37, 0.06, 0.065, -0.005, 0.058], [-0.43, 0.054, 0.058, -0.002, 0.052]] 
	var shin_prof := [[0.03, 0.05, 0.053, -0.004, 0.05], [-0.03, 0.049, 0.05, 0.004, 0.056], [-0.09, 0.048, 0.046, 0.012, 0.068],
		[-0.15, 0.046, 0.042, 0.013, 0.067], [-0.21, 0.041, 0.038, 0.009, 0.055], [-0.28, 0.034, 0.034, 0.005, 0.041],
		[-0.35, 0.029, 0.03, 0.002, 0.032], [-0.395, 0.027, 0.029, 0.0, 0.029], [-0.425, 0.031, 0.033, 0.0, 0.032]]
	var tf := legf * (hipf * 0.4 + 0.6)
	for side: String in ["l", "r"]:
		var med := 1.0 if side == "l" else -1.0
		m = Mesher.new()
		var tr: Array
		if pst == "lungi" or pst == "bare" or swim:
			tr = _rings(thigh_prof, 9.0, pants, skin, 0.0, tf, 0.018 * med)
		elif pst == "shorts":
			# shorts: cloth to a hand above the knee, a turned hem, bare skin below
			tr = _rings(thigh_prof, -0.24, pants, skin, pant_loose, tf, 0.018 * med)
		else:
			tr = _rings(thigh_prof, -9.0, pants, pants, pant_loose, tf, 0.018 * med)
		m.loft(tr, 26, id, false, false, 0.95)
		if pst == "shorts":
			m.loft([[Vector3(0.008 * med, -0.225, -0.003), 0.071 * tf + pant_loose + 0.003, 0.077 * tf + pant_loose + 0.003, pants.darkened(0.1), 0.072 * tf + pant_loose + 0.003],
				[Vector3(0.008 * med, -0.24, -0.004), 0.07 * tf + pant_loose + 0.003, 0.076 * tf + pant_loose + 0.003, pants.darkened(0.1), 0.071 * tf + pant_loose + 0.003]], 22, id, false, false)
			m.box(Vector3(-0.08 * med * tf - pant_loose * med, -0.11, 0.0), Vector3(0.003, 0.22, 0.004), pants.darkened(0.2))
		elif pst != "lungi" and pst != "salwar" and pst != "bare" and not swim:
			# outer seam
			m.box(Vector3(-0.08 * med * tf - pant_loose * med, -0.2, 0.0), Vector3(0.003, 0.4, 0.004), pants.darkened(0.2))
		if pst == "cargo":
			m.slab(Vector3(-0.085 * med * tf - pant_loose * med - 0.008 * med, -0.2, -0.01), Vector3(0.016, 0.1, 0.075), pants.darkened(0.08), Transform3D(Basis(Vector3.FORWARD, 0.0), Vector3.ZERO), 0.4)
		out["thigh_" + side] = _to_mesh(m)
	m = Mesher.new()
	var bare_shin := pst == "lungi" or pst == "shorts" or pst == "bare" or swim
	var knee_col := skin if bare_shin else pants
	var kl := 0.0 if bare_shin else pant_loose
	m.ellipsoid(Vector3(0, 0.0, -0.004), Vector3(0.05 * legf + kl, 0.056, 0.053 * legf + kl), knee_col, 14, 8)
	m.ellipsoid(Vector3(0, 0.012, -0.044 * legf - kl * 0.8), Vector3(0.024, 0.03, 0.014), knee_col, 10, 6)
	var hem := -0.39
	if bare_shin:
		hem = 9.0
	elif shoes == "boots":
		hem = -0.3
	if pst == "capri":
		# capri / three-quarter trousers: the hem at mid-shin
		hem = -0.2
	if bare_shin:
		m.loft(_rings(shin_prof, 9.0, skin, skin, 0.0, legf), 22, id, false, false)
	else:
		var sp2: Array = shin_prof
		if pst == "salwar":
			# salwar: loose, gathered into a narrow cuff above the ankle
			m.loft(_rings(shin_prof, -0.33, pants, skin, pant_loose, legf), 18, id, false, false)
			m.loft([[Vector3(0, -0.29, 0.002), 0.04, 0.042, pants, 0.044], [Vector3(0, -0.33, 0.002), 0.036, 0.037, pants.darkened(0.05), 0.038]], 18, id, false, false)
		else:
			m.loft(_rings(sp2, hem, pants, skin, pant_loose, legf), 18, id, false, false)
	out["shin"] = _to_mesh(m)
	for side: String in ["l", "r"]:
		m = Mesher.new()
		_build_foot(m, shoes, legf, 1.0 if side == "l" else -1.0)
		out["foot_" + side] = _to_mesh(m)

	# ---------------- rifle
	if armed:
		m = Mesher.new()
		var metal := Color(0.07, 0.07, 0.075, METAL)
		var poly := Color(0.09, 0.085, 0.08, LEATHER)
		var wood := Color(0.32, 0.19, 0.09, LEATHER)
		var furn := wood if role == "villain" or role == "boss" else poly
		m.box(Vector3(0, -0.01, -0.1), Vector3(0.04, 0.07, 0.2), furn)
		m.box(Vector3(0, -0.035, -0.015), Vector3(0.042, 0.11, 0.03), Color(0.05, 0.05, 0.05, LEATHER))
		m.box(Vector3(0, 0.0, -0.32), Vector3(0.05, 0.075, 0.26), metal)
		m.box(Vector3(0, 0.05, -0.32), Vector3(0.02, 0.022, 0.16), metal)
		m.box(Vector3(0, -0.075, -0.26), Vector3(0.032, 0.09, 0.04), furn, Transform3D(Basis(Vector3.RIGHT, 0.3), Vector3.ZERO))
		m.box(Vector3(0, -0.095, -0.38), Vector3(0.03, 0.12, 0.055), metal, Transform3D(Basis(Vector3.RIGHT, -0.22), Vector3.ZERO))
		m.box(Vector3(0, -0.005, -0.54), Vector3(0.046, 0.06, 0.18), furn)
		m.tube(Vector3(0, 0.012, -0.6), Vector3(0, 0.012, -0.84), 0.011, metal)
		m.tube(Vector3(0, 0.012, -0.82), Vector3(0, 0.012, -0.87), 0.016, metal)
		m.box(Vector3(0, 0.05, -0.7), Vector3(0.012, 0.045, 0.012), metal)
		m.box(Vector3(0.0, -0.05, -0.3), Vector3(0.008, 0.008, 0.06), metal)
		out["gun"] = _to_mesh(m)
	return out


## Plate carrier: front and back plates, cummerbund, shoulder straps, magazine pouches, radio.
## bust: extra depth at the front over a bare bust (women in swimwear).
func _build_vest(m: Mesher, vc: Color, chf: float, shf: float, tl: float, bust: float = 0.0) -> void:
	var id := Transform3D()
	m.loft([[Vector3(0, -0.04, 0.0), 0.153 * chf + 0.026, 0.104 * chf + 0.026 + bust * 0.3, vc, 0.102 * chf + 0.026], [Vector3(0, 0.02, -0.002), 0.158 * chf + 0.027, 0.108 * chf + 0.028 + bust * 0.8, vc, 0.106 * chf + 0.027],
		[Vector3(0, 0.12, -0.006), 0.165 * chf + 0.026, 0.115 * chf + 0.03 + bust, vc, 0.11 * chf + 0.028], [Vector3(0, 0.2, -0.002), 0.15 * shf + 0.012, 0.106 * chf + 0.028 + bust * 0.6, vc, 0.104 * chf + 0.026],
		[Vector3(0, 0.235, 0.002), 0.12 * shf, 0.094 * chf + 0.024 + bust * 0.2, vc, 0.094 * chf + 0.022]], 26, id, true, true, 0.6)
	for s: float in [-1.0, 1.0]:
		m.sweep([Vector3(0.085 * s, 0.215, -0.1 * chf - 0.028 - bust * 0.7), Vector3(0.11 * s, 0.262, -0.05), Vector3(0.115 * s, 0.272, 0.02), Vector3(0.1 * s, 0.24, 0.1 * chf + 0.026)],
			[Vector2(0.024, 0.006)], vc.darkened(0.1), 6, false, false, [Vector3(0, 0.3, -1).normalized(), Vector3(0.2, 1, 0).normalized(), Vector3(0.2, 1, 0).normalized(), Vector3(0, 0.3, 1).normalized()])
	var pz := -0.118 * chf - 0.045 - bust
	for i in 3:
		m.slab(Vector3(-0.07 + 0.07 * i, 0.03, pz), Vector3(0.058, 0.1, 0.035), vc.darkened(0.15))
		m.slab(Vector3(-0.07 + 0.07 * i, 0.075, pz - 0.002), Vector3(0.06, 0.016, 0.038), vc.darkened(0.25))
	m.slab(Vector3(-0.1, 0.17, pz + 0.01), Vector3(0.045, 0.07, 0.03), Color(0.05, 0.05, 0.05, LEATHER))
	m.box(Vector3(-0.1, 0.225, pz + 0.01), Vector3(0.008, 0.06, 0.008), Color(0.05, 0.05, 0.05, METAL))
	# MOLLE webbing rows on the back panel
	for y: float in [0.04, 0.09, 0.14]:
		m.box(Vector3(0, y, 0.11 * chf + 0.03), Vector3(0.2, 0.012, 0.004), vc.darkened(0.2))


## Dupatta (orna): worn across the chest in a soft U, over both shoulders, the ends hanging down the back.
func _build_dupatta(m: Mesher, du: Color, chf: float, shf: float, tl: float) -> void:
	var fz := -0.118 * chf - tl - 0.016
	var half := [Vector3(-0.07, -0.21, 0.108), Vector3(-0.08, -0.07, 0.112), Vector3(-0.094, 0.05, 0.116), Vector3(-0.103, 0.17, 0.104), Vector3(-0.112, 0.238, 0.062),
		Vector3(-0.116, 0.262, 0.0), Vector3(-0.11, 0.236, -0.07), Vector3(-0.092, 0.18, fz + 0.03), Vector3(-0.058, 0.12, fz + 0.002), Vector3(-0.024, 0.09, fz - 0.004)]
	var hup := [Vector3(0, 0, 1), Vector3(0, 0, 1), Vector3(0, 0, 1), Vector3(0, 0.25, 1), Vector3(-0.2, 1, 0.8), Vector3(-0.25, 1, 0), Vector3(-0.2, 1, -0.8),
		Vector3(0, 0.3, -1), Vector3(0, 0.1, -1), Vector3(0, 0, -1)]
	var widths := [0.046, 0.044, 0.04, 0.036, 0.03, 0.026, 0.032, 0.042, 0.048, 0.05]
	var pts := []
	var ups := []
	var rad := []
	var cols := []
	var border := du.darkened(0.3)
	for i in half.size():
		pts.append(half[i])
		ups.append((hup[i] as Vector3).normalized())
		rad.append(Vector2(float(widths[i]) * lerpf(shf, 1.0, 0.5), 0.0025))
		cols.append(border if i == 0 else du)
	pts.append(Vector3(0, 0.082, fz - 0.005))
	ups.append(Vector3(0, 0, -1))
	rad.append(Vector2(0.052, 0.0025))
	cols.append(du)
	for i in range(half.size() - 1, -1, -1):
		var p: Vector3 = half[i]
		var u: Vector3 = hup[i]
		pts.append(Vector3(-p.x, p.y, p.z))
		ups.append(Vector3(-u.x, u.y, u.z).normalized())
		rad.append(rad[i])
		cols.append(cols[i])
	m.sweep(pts, rad, cols, 8, true, true, ups, true)


# ---------------------------------------------------------------- swimwear (see _swimwear)
## Section of a loft profile [[y, rx, rz_front, cz, rz_back(, squareness)], ...] (rows bottom-up) at height
## y, clamped to the profile: [rx, rz_front, cz, rz_back, squareness].
static func _prof_at(prof: Array, y: float, sq_def: float) -> Array:
	var i := 0
	while i < prof.size() - 2 and y > float((prof[i + 1] as Array)[0]):
		i += 1
	var a: Array = prof[i]
	var b: Array = prof[i + 1]
	var t := clampf((y - float(a[0])) / maxf(float(b[0]) - float(a[0]), 1e-5), 0.0, 1.0)
	return [lerpf(float(a[1]), float(b[1]), t), lerpf(float(a[2]), float(b[2]), t),
		lerpf(float(a[3]) if a.size() > 3 else 0.0, float(b[3]) if b.size() > 3 else 0.0, t),
		lerpf(float(a[4]) if a.size() > 4 else float(a[2]), float(b[4]) if b.size() > 4 else float(b[2]), t),
		lerpf(float(a[5]) if a.size() > 5 else sq_def, float(b[5]) if b.size() > 5 else sq_def, t)]


## Point of the lofted surface at height y and loft angle th (the same formula as Mesher.loft).
static func _prof_pt(prof: Array, y: float, th: float, sq_def: float) -> Vector3:
	var s := _prof_at(prof, y, sq_def)
	var sq := float(s[4])
	var cs := cos(th)
	var sn := sin(th)
	var ex := signf(cs) * pow(absf(cs), sq)
	var ez := signf(sn) * pow(absf(sn), sq)
	var yc := clampf(y, float((prof[0] as Array)[0]), float((prof[prof.size() - 1] as Array)[0]))
	return Vector3(float(s[0]) * ex, yc, float(s[2]) + (float(s[3]) if sn > 0.0 else float(s[1])) * ez)


## Point on the front (back = true: the back) of the lofted surface at sideways position x and height y.
static func _prof_xy(prof: Array, x: float, y: float, sq_def: float, back: bool = false) -> Vector3:
	var s := _prof_at(prof, y, sq_def)
	var a := acos(pow(clampf(absf(x) / maxf(float(s[0]), 1e-4), 0.0, 0.999), 1.0 / float(s[4])))
	var th := a if back else -a
	if x < 0.0:
		th = PI - a if back else a - PI
	return _prof_pt(prof, y, th, sq_def)


## The same point pushed out from the section centre by off.
static func _prof_out(prof: Array, p: Vector3, sq_def: float, off: float) -> Vector3:
	var cz := float(_prof_at(prof, p.y, sq_def)[2])
	return p + Vector3(p.x, 0.0, p.z - cz).normalized() * off


# ---- relief: muscles and forms of the bare trunk (swimwear only; clothed bodies keep the plain lofts)
## One flat six-pack + linea alba + V-cut, scaled by the build's ANATOMY entry. Replaces the
## three overlapping ab blocks that used to z-fight on the same surface.
static func _build_abs_detail(m: Mesher, rp: Dictionary, tl: float, bel: float, col: Color) -> void:
	var a := float(rp.get("abs", 0.0))
	if a <= 0.0:
		return
	var strength := clampf(a / 0.0042, 0.0, 3.2)
	var front := -0.103 - tl - bel * 0.5
	for y: float in [0.02, 0.07, 0.12]:
		for x: float in [-0.038, 0.038]:
			m.ellipsoid(Vector3(x, y, front), Vector3(0.038, 0.024, 0.012 * clampf(strength, 0.4, 1.6)), col, 10, 6)
	m.box(Vector3(0, 0.07, front - 0.005), Vector3(0.005, 0.15, 0.005), col.darkened(0.35))
	for y: float in [0.045, 0.095]:
		m.box(Vector3(0, y, front - 0.004), Vector3(0.075, 0.004, 0.004), col.darkened(0.3))
	var v := float(rp.get("vline", 0.0))
	if v > 0.0:
		var vs := clampf(v / 0.003, 0.0, 3.0)
		for s: float in [-1.0, 1.0]:
			var pts := [Vector3(0.078 * s, 0.125, -0.082), Vector3(0.055 * s, 0.045, -0.094), Vector3(0.016 * s, -0.01, -0.09)]
			m.sweep(pts, [0.017 * vs, 0.014 * vs, 0.009 * vs], col.darkened(0.15), 8, true, true)


## Relief strengths for a build: glutes and the cleft between them, abs, the V lines over the hips,
## pectorals (both genders now, tuned through ANATOMY), breasts (women). A belly (heavy builds)
## hides most of the abs and the V lines. Female Powerful / Actress carry more gluteal and
## pectoral definition than the male average; male Muscular leads on abs and the V-line.
static func _relief_params(b: Dictionary, female: bool, build_name: String = "") -> Dictionary:
	var hipf := float(b["hip"])
	var chf := float(b["ch"])
	var lean := clampf(1.0 - float(b["bel"]) / 0.035, 0.15, 1.0)
	var mus := clampf(float(b["arm"]), 0.8, 1.45)
	var an: Dictionary = ANATOMY.get(build_name, {})
	if an.is_empty():
		an = ANATOMY.get("female" if female else "average", {})
	var gw := float(an.get("glute_w", 1.0))
	var cleft := (0.017 if female else 0.013) * float(an.get("cleft", 1.0))
	var abs_v := float(an.get("abs", 1.0)) * (0.0026 if female else 0.0042) * lean * mus
	var vline := float(an.get("vline", 1.0)) * (0.0016 if female else 0.003) * lean
	var pec_base := 0.011 if female else 0.0085
	return {
		"glute": float(an.get("glute", 0.012)),
		"glute_x": (0.064 if female else 0.058) * hipf,
		"glute_w": (0.056 if female else 0.05) * gw * hipf,
		"cleft": cleft, "abs": abs_v, "vline": vline,
		"pec": float(an.get("pec", 1.0)) * pec_base * mus * clampf(chf, 0.9, 1.3),
		"breast": 0.034 * chf if female else 0.0,
		"breast_x": 0.074 * chf if female else 0.0,
		"breast_y": 0.098 if female else 0.0,
	}

## Relief (metres, + outwards) at base point p of a bare trunk section. part 0 pelvis (hips space),
## 1 abdomen (torso space), 2 chest (chest space); cz, rf, rb: the section's centre and its front / back
## depth. Where two sections overlap (pelvis / abdomen, abdomen / chest) both get the same relief.
static func _relief(part: int, p: Vector3, cz: float, rf: float, rb: float, rp: Dictionary) -> float:
	var ax := absf(p.x)
	var nf := clampf((cz - p.z) / maxf(rf, 1e-4), 0.0, 1.0)
	var nb := clampf((p.z - cz) / maxf(rb, 1e-4), 0.0, 1.0)
	var front := smoothstep(0.3, 0.8, nf)
	var d := 0.0
	if part == 0:
		# glutes: a rounded mass each side, fuller low down and tucking in at the fold; the cleft between
		var back := smoothstep(0.25, 0.75, nb)
		if back > 0.0:
			var dy := p.y + 0.062
			var wy := 0.06 if dy > 0.0 else 0.034
			var lobe := float(rp["glute"]) * exp(-pow((ax - float(rp["glute_x"])) / float(rp["glute_w"]), 2.0)) * exp(-pow(dy / wy, 2.0))
			var cl := float(rp["cleft"]) * smoothstep(0.045, -0.04, p.y) * (1.0 - smoothstep(-0.118, -0.138, p.y)) * exp(-pow(ax / 0.011, 2.0))
			d += back * (lobe - cl)
	if front > 0.0 and part <= 1:
		# the V lines over the hips, from the front of the iliac crest down towards the pubis (hips space)
		var vl := float(rp["vline"])
		if vl > 0.0:
			var q := Vector2(ax, p.y + (TORSO_UP if part == 1 else 0.0))
			var a := Vector2(0.118, 0.07)
			var e := Vector2(0.03, -0.075) - a
			var t := clampf((q - a).dot(e) / e.length_squared(), 0.0, 1.0)
			d -= front * vl * sin(PI * t) * exp(-pow(q.distance_to(a + e * t) / 0.008, 2.0))
	if front > 0.0 and part >= 1:
		# abs (torso space): two columns, the line between them, three crossing grooves, the navel
		var y := p.y + (CHEST_UP if part == 2 else 0.0)
		var env := smoothstep(-0.05, -0.02, y) * (1.0 - smoothstep(0.15, 0.175, y))
		if env > 0.0:
			var inter := 0.0
			for yi: float in [0.055, 0.095, 0.135]:
				inter += exp(-pow((y - yi) / 0.0055, 2.0))
			inter *= exp(-pow((ax - 0.036) / 0.03, 2.0))
			d += front * float(rp["abs"]) * env * (exp(-pow((ax - 0.036) / 0.022, 2.0)) - 1.1 * exp(-pow(ax / 0.0065, 2.0)) - 0.9 * inter)
		d -= front * 0.0035 * exp(-(ax * ax + pow(y - 0.018, 2.0)) / 0.00002)
	if front > 0.0 and part == 2:
		var pec := float(rp["pec"])
		if pec > 0.0:
			# pectorals: a plate each side with a firm lower edge, the groove over the breastbone
			var env_v := smoothstep(0.055, 0.09, p.y) * (1.0 - smoothstep(0.17, 0.235, p.y))
			var groove := exp(-pow(ax / 0.009, 2.0)) * smoothstep(0.06, 0.1, p.y) * (1.0 - smoothstep(0.2, 0.24, p.y))
			d += front * pec * (exp(-pow((ax - 0.06) / 0.045, 2.0)) * env_v - 0.4 * groove)
	if part == 2 and float(rp["breast"]) > 0.0:
		# breasts: rounded, a gentle upper slope and a fuller lower half ending in a crisp fold
		var bx := (ax - float(rp["breast_x"])) / 0.058
		var by := p.y - float(rp["breast_y"])
		by /= 0.068 if by > 0.0 else 0.046
		var qq := bx * bx + by * by
		if qq < 1.0:
			d += smoothstep(0.15, 0.55, nf) * float(rp["breast"]) * pow(1.0 - qq, 1.4)
	return d


## Base point p of a profile pushed out by the relief (none when rp is empty: clothed bodies).
static func _relieve(prof: Array, p: Vector3, sq_def: float, part: int, rp: Dictionary) -> Vector3:
	if rp.is_empty():
		return p
	var s := _prof_at(prof, p.y, sq_def)
	var d := _relief(part, p, float(s[2]), float(s[1]), float(s[3]), rp)
	if absf(d) < 1e-7:
		return p
	return p + Vector3(p.x, 0.0, p.z - float(s[2])).normalized() * d


static func _surf_pt(prof: Array, y: float, th: float, sq_def: float, part: int, rp: Dictionary) -> Vector3:
	return _relieve(prof, _prof_pt(prof, y, th, sq_def), sq_def, part, rp)


static func _surf_xy(prof: Array, x: float, y: float, sq_def: float, part: int, rp: Dictionary, back: bool = false) -> Vector3:
	return _relieve(prof, _prof_xy(prof, x, y, sq_def, back), sq_def, part, rp)


## A trunk section lofted from its profile with the relief, as one grid: rows about every centimetre of
## height, seg columns all the way round; cap_a / cap_b close the bottom / top. Without relief it is the
## same surface Mesher.loft makes from these rings.
static func _relief_loft(m: Mesher, prof: Array, sq_def: float, seg: int, col: Color, part: int, rp: Dictionary, cap_a: bool, cap_b: bool) -> void:
	var ys := []
	for i in prof.size() - 1:
		var y0 := float((prof[i] as Array)[0])
		var y1 := float((prof[i + 1] as Array)[0])
		var n := maxi(1, ceili((y1 - y0) / 0.011))
		for k in n:
			ys.append(lerpf(y0, y1, float(k) / float(n)))
	ys.append(float((prof[prof.size() - 1] as Array)[0]))
	var rows := ys.size()
	var pts := []
	for j in rows:
		for k in seg:
			pts.append(_surf_pt(prof, float(ys[j]), TAU * float(k) / float(seg), sq_def, part, rp))
	var nrm := _grid_normals(pts, seg, rows, true, Vector3.ZERO)
	var base := m.v.size()
	for k in pts.size():
		m.vert(pts[k], nrm[k], col)
	for j in rows - 1:
		for i in seg:
			var a := base + j * seg + i
			var b := base + j * seg + (i + 1) % seg
			m.tri(a, b, b + seg)
			m.tri(a, b + seg, a + seg)
	if cap_a:
		var s0 := _prof_at(prof, float(ys[0]), sq_def)
		var c0 := m.vert(Vector3(0, float(ys[0]), float(s0[2])), Vector3.DOWN, col)
		for i in seg:
			m.tri(c0, base + (i + 1) % seg, base + i)
	if cap_b:
		var s1 := _prof_at(prof, float(ys[rows - 1]), sq_def)
		var c1 := m.vert(Vector3(0, float(ys[rows - 1]), float(s1[2])), Vector3.UP, col)
		var off := base + (rows - 1) * seg
		for i in seg:
			m.tri(c1, off + i, off + (i + 1) % seg)


## Bare trunk in hips space with its relief: the pelvis, or the belly above it where that stands out more
## (heavy builds), compared along the same direction out from the body axis.
static func _trunk_pt(prof: Array, abd: Array, y: float, th: float, rp: Dictionary) -> Vector3:
	var p := _surf_pt(prof, y, th, 0.86, 0, rp)
	var ya := y - TORSO_UP
	if ya >= float((abd[0] as Array)[0]):
		var want := atan2(p.z, p.x)
		var ta := th
		var q := _surf_pt(abd, ya, ta, 0.82, 1, rp)
		for i in 5:
			ta += wrapf(want - atan2(q.z, q.x), -PI, PI)
			q = _surf_pt(abd, ya, ta, 0.82, 1, rp)
		if q.x * q.x + q.z * q.z > p.x * p.x + p.z * p.z:
			p = Vector3(q.x, y, q.z)
	return p


static func _table(tab: Array, u: float) -> float:
	for i in tab.size() - 1:
		var a: Array = tab[i]
		var b: Array = tab[i + 1]
		if u <= float(b[0]):
			return lerpf(float(a[1]), float(b[1]), clampf((u - float(a[0])) / maxf(float(b[0]) - float(a[0]), 1e-5), 0.0, 1.0))
	return float((tab[tab.size() - 1] as Array)[1])


## Normals of a cols x rows point grid (row-major, j * cols + i) by finite differences, facing away from
## the vertical axis through `axis`. wrap: the last column joins the first.
static func _grid_normals(g: Array, cols: int, rows: int, wrap: bool, axis: Vector3) -> Array:
	var out := []
	for j in rows:
		for i in cols:
			var p: Vector3 = g[j * cols + i]
			var il := (i + cols - 1) % cols if wrap else maxi(i - 1, 0)
			var ir := (i + 1) % cols if wrap else mini(i + 1, cols - 1)
			var tu: Vector3 = (g[j * cols + ir] as Vector3) - (g[j * cols + il] as Vector3)
			var tv: Vector3 = (g[mini(j + 1, rows - 1) * cols + i] as Vector3) - (g[maxi(j - 1, 0) * cols + i] as Vector3)
			var n := tu.cross(tv)
			var radial := Vector3(p.x - axis.x, 0.0, p.z - axis.z)
			if n.length_squared() < 1e-12:
				n = radial
			if n.dot(radial) < 0.0:
				n = -n
			out.append(n.normalized())
	return out


## A garment shell: pts is a cols x rows grid of points on the skin, offs how far each stands off it
## (along the surface normal). One colour, so its edges are crisp against the skin underneath.
static func _shell(m: Mesher, pts: Array, offs: Array, cols: int, rows: int, wrap: bool, col: Color, axis: Vector3) -> void:
	var sn := _grid_normals(pts, cols, rows, wrap, axis)
	var lifted := []
	for k in pts.size():
		lifted.append((pts[k] as Vector3) + (sn[k] as Vector3) * float(offs[k]))
	var ln := _grid_normals(lifted, cols, rows, wrap, axis)
	var base := m.v.size()
	for k in lifted.size():
		m.vert(lifted[k], ln[k], col)
	for j in rows - 1:
		for i in (cols if wrap else cols - 1):
			var a := base + j * cols + i
			var b := base + j * cols + (i + 1) % cols
			m.tri(a, b, b + cols)
			m.tri(a, b + cols, a + cols)


## A frill: a gathered ribbon along a line of skin points (a cup edge, a waistband), standing a little off
## the skin and waving in and out.
static func _frill(m: Mesher, col: Color, edge: Array, axis: Vector3, lift: float, waves: int) -> void:
	var n := edge.size()
	if n < 3:
		return
	var pts := []
	var ups := []
	for i in n:
		var p: Vector3 = edge[i]
		var nn := Vector3(p.x - axis.x, 0.0, p.z - axis.z).normalized()
		pts.append(p + nn * (lift + 0.0018 * sin(TAU * float(waves) * float(i) / float(n - 1))))
		ups.append(nn)
	m.sweep(pts, [Vector2(0.0045, 0.0007)], col, 6, false, false, ups)


## A small bow (knot, two loops, two tails) at c; right / up span the surface it lies on, out points away.
static func _build_bow(m: Mesher, col: Color, c: Vector3, right: Vector3, up: Vector3, out: Vector3) -> void:
	m.ellipsoid(c + out * 0.002, Vector3(0.0055, 0.0045, 0.0035), col, 8, 5)
	for s: float in [-1.0, 1.0]:
		var loop := []
		for i in 13:
			var a := TAU * float(i) / 12.0
			loop.append(c + out * 0.002 + right * (s * (0.011 - 0.009 * cos(a))) + up * (0.0055 * sin(a)))
		m.sweep(loop, [Vector2(0.0008, 0.0032)], col, 6, false, false, [out])
		m.sweep([c + right * (s * 0.003), c + right * (s * 0.008) - up * 0.017 + out * 0.002, c + right * (s * 0.012) - up * 0.032 + out * 0.003],
			[Vector2(0.0034, 0.0008)], col, 6, false, true, [out])


## Cut of the swim bottom: a front and a back panel, each pinched to a point at a corner on each hip,
## joined over the hips by cords and a ring (bikini) or a narrow band (briefs). Leg lines [[u, height], ...]
## run from the crotch (u = 0, centre front / back) to the corner (last u); u = |cos| of the pelvis loft
## angle, heights in hips space. wf / wb: the waistband at the centre front / back; yc: the corners, kept
## above the tops of the thighs (hips + 0.04) so the sides are never hidden in them.
## Minimal cover: the back is a narrow V, so the glutes are mostly bare.
func _build_swim_bottom(m: Mesher, col: Color, prof: Array, abd: Array, rp: Dictionary, bikini: bool) -> void:
	var thick := 0.015 if bikini else 0.025 # Thinner for bikini, thicker for briefs
	
	# --- 1. FRONT V-SHAPE ---
	var front_pts = []
	for i in range(15):
		var t = float(i) / 14.0
		var x = lerpf(-0.12, 0.12, t)
		# The V-Shape: Center dips to -0.01, sides go up to 0.08
		var y = 0.08 - 0.09 * (1.0 - absf(x) / 0.12) 
		var z = -0.11 * (1.0 - pow(absf(x) / 0.15, 1.5)) # Curve around the body
		front_pts.append(Vector3(x, y, z))
		
	# Draw the front ribbon
	m.sweep(front_pts, [Vector2(0.025, thick)], col, 8, true, true, [], true)

	# --- 2. BACK V-SHAPE (Cheeky cut) ---
	var back_pts = []
	for i in range(15):
		var t = float(i) / 14.0
		var x = lerpf(-0.12, 0.12, t)
		# The back V is usually a bit higher
		var y = 0.08 - 0.08 * (1.0 - absf(x) / 0.12) 
		var z = 0.12 * (1.0 - pow(absf(x) / 0.15, 1.5))
		back_pts.append(Vector3(x, y, z))
		
	# Draw the back ribbon
	m.sweep(back_pts, [Vector2(0.025, thick)], col, 8, true, true, [], true)

	# --- 3. SIDE STRAPS ---
	var left_strap = [Vector3(-0.12, 0.08, -0.06), Vector3(-0.15, 0.08, 0.0), Vector3(-0.12, 0.08, 0.07)]
	var right_strap = [Vector3(0.12, 0.08, -0.06), Vector3(0.15, 0.08, 0.0), Vector3(0.12, 0.08, 0.07)]
	
	# Draw the side straps connecting front and back
	m.sweep(left_strap, [Vector2(0.02, thick)], col, 8, true, true, [], true)
	m.sweep(right_strap, [Vector2(0.02, thick)], col, 8, true, true, [], true)


## One panel of the swim bottom (front or back): columns across it from one hip corner to the other, each
## from the leg line up to the waistband, pinched to a point at the corners where the sides attach.
static func _cut_hw(cut: Dictionary, front: bool, angle: float) -> Vector2:
	# This helper calculates the top and bottom bounds of the swimsuit
	# based on the angle around the waist.
	var base_y: float = float(cut.get("front" if front else "back", 0.0))
	var h: float = float(cut.get("h", 0.1)) 
	
	# A standard V-cut shape equation
	var top = base_y + (h * 0.5)
	var bottom = base_y - (h * 0.5) * angle
	
	return Vector2(bottom, top)
static func _swim_panel(m: Mesher, col: Color, prof: Array, abd: Array, rp: Dictionary, cut: Dictionary, front: bool, bikini: bool) -> void:
	var tab: Array = cut["front"] if front else cut["back"]
	var al := acos(float((tab[tab.size() - 1] as Array)[0]))
	var t0 := PI + al if front else al
	var t1 := TAU - al if front else PI - al
	var cols := 45
	var rows := 10
	var off := float(cut["off"])
	var pts := []
	var offs := []
	for j in rows + 2:
		for i in cols:
			var th := lerpf(t0, t1, float(i) / float(cols - 1))
			var hw := _cut_hw(cut, front, absf(cos(th)))
			var lip := minf(0.004, (hw.y - hw.x) * 0.5)
			var y := lerpf(hw.x, hw.y, float(j - 1) / float(rows - 1))
			var o := off
			if j == 0:
				y = hw.x - lip
				o = -0.0008
			elif j == rows + 1:
				y = hw.y + lip
				o = -0.0008
			var p := _trunk_pt(prof, abd, y, th, rp)
			if front and not bikini and j > 0 and j <= rows:
				# the front of the briefs stands out a little, low down at the centre
				o += 0.009 * exp(-pow(p.x / 0.03, 2.0)) * exp(-pow((y + 0.085) / 0.035, 2.0))
			pts.append(p)
			offs.append(o)
	_shell(m, pts, offs, cols, rows + 2, false, col, Vector3(0, 0, 0.005))
	if bikini and front:
		# a frill along the top of the front
		_frill(m, col, pts.slice(rows * cols, (rows + 1) * cols), Vector3(0, 0, 0.005), 0.0035, 10)


## The side of the swim bottom over one hip (sd +1 / -1): a cord from the front corner to a metal ring and
## on to the back corner (bikini), or a narrow band all the way (briefs).
static func _swim_side(m: Mesher, col: Color, prof: Array, abd: Array, rp: Dictionary, cut: Dictionary, sd: float, bikini: bool) -> void:
	var ff: Array = cut["front"]
	var bb: Array = cut["back"]
	var af := acos(float((ff[ff.size() - 1] as Array)[0]))
	var ab := acos(float((bb[bb.size() - 1] as Array)[0]))
	var yc := float(cut["yc"])
	var ta := -af if sd > 0.0 else PI + af
	var tb := ab if sd > 0.0 else PI - ab
	var n := 14
	var pts := []
	var ups := []
	for i in n + 1:
		var p := _trunk_pt(prof, abd, yc, lerpf(ta, tb, float(i) / float(n)), rp)
		var rad := Vector3(p.x, 0.0, p.z - 0.005).normalized()
		pts.append(p + rad * (0.0022 if bikini else 0.002))
		ups.append(rad)
	if not bikini:
		m.sweep(pts, [Vector2(0.006, 0.0015)], col, 6, true, true, ups)
		return
	# metal ring at the side; the cord in two pieces from the corners to its rim
	var mid := 7
	var nrm: Vector3 = ups[mid]
	var c: Vector3 = (pts[mid] as Vector3) + nrm * 0.0018
	var tg := ((pts[mid + 1] as Vector3) - (pts[mid - 1] as Vector3)).normalized()
	var ring := []
	for i in 17:
		var a := TAU * float(i) / 16.0
		ring.append(c + (tg * cos(a) + Vector3.UP * sin(a)) * 0.0085)
	m.sweep(ring, [Vector2(0.0018, 0.0018)], GOLD, 6, false, false, [nrm])
	var fr := pts.slice(0, mid)
	fr.append(c - tg * 0.0085)
	var bk := [c + tg * 0.0085]
	bk.append_array(pts.slice(mid + 1))
	m.sweep(fr, [Vector2(0.0022, 0.0016)], col, 6, true, true, ups.slice(0, mid + 1))
	m.sweep(bk, [Vector2(0.0022, 0.0016)], col, 6, true, true, ups.slice(mid))


static func _cup_r(a: float, r0: float, apex: float) -> float:
	return r0 * (1.0 + 0.38 * pow(maxf(cos(a - apex), 0.0), 6.0))


## Padded halter bikini top, chest space: a rounded, padded cup over each breast with a frill round it, a
## cord between the cups, cords round the ribs tied in a bow at the back, and halter straps from the tips
## of the cups round the back of the neck, tied in a bow at the nape. chp: the chest profile as lofted;
## rp: the body's relief (the breasts).
static func _build_bikini_top(m: Mesher, col: Color, chp: Array, _nf: float, rp: Dictionary) -> void:
	var bx := float(rp.get("breast_x", 0.066))
	var cy := float(rp.get("breast_y", 0.098)) - 0.006
	var r0 := 0.039
	var apex := PI * 0.5 + 0.2
	var nang := 32
	var radii := [0.0, 0.25, 0.45, 0.62, 0.76, 0.87, 0.95, 1.0, 1.06]
	var tips := []
	var outer := []
	var inner := []
	for sgn: float in [-1.0, 1.0]:
		var pts := []
		var offs := []
		for j in radii.size():
			var r := float(radii[j])
			for i in nang:
				var a := TAU * float(i) / float(nang)
				var lp := Vector2(cos(a), sin(a)) * _cup_r(a, r0, apex) * r
				pts.append(_surf_xy(chp, sgn * (bx + lp.x), cy + lp.y, 0.82, 2, rp))
				offs.append(-0.0008 if r > 1.0 else 0.0009 + 0.0062 * (1.0 - r * r))
		_shell(m, pts, offs, nang, radii.size(), true, col, Vector3(0, 0, -0.005))
		var edge := pts.slice(7 * nang, 8 * nang)
		edge.append(edge[0])
		_frill(m, col, edge, Vector3(0, 0, -0.005), 0.0016, 9)
		for e in [[apex, tips], [-0.55, outer], [PI + 0.5, inner]]:
			var ea := float(e[0])
			var ep := Vector2(cos(ea), sin(ea)) * _cup_r(ea, r0, apex)
			(e[1] as Array).append(_surf_xy(chp, sgn * (bx + ep.x), cy + ep.y, 0.82, 2, rp))
	# a cord between the cups, bridging the cleavage
	var i0 := _prof_out(chp, inner[0], 0.82, 0.002)
	var i1 := _prof_out(chp, inner[1], 0.82, 0.002)
	m.sweep([i0, (i0 + i1) * 0.5 + Vector3(0, -0.003, 0.004), i1], [Vector2(0.0022, 0.0016)], col, 6, true, true, [Vector3.FORWARD])
	# cords round the ribs from the outer edge of each cup to a bow at the back
	var yb := cy - 0.03
	var bow_b := _prof_out(chp, _surf_pt(chp, yb, PI * 0.5, 0.82, 2, rp), 0.82, 0.004)
	for k in 2:
		var sgn := -1.0 if k == 0 else 1.0
		var o: Vector3 = outer[k]
		var pts := [_prof_out(chp, o, 0.82, 0.002)]
		var ups := [Vector3(o.x, 0.0, o.z).normalized()]
		for i in 9:
			var t := float(i) / 8.0
			var th := lerpf(-0.45, PI * 0.5 - 0.12, t) if sgn > 0.0 else lerpf(PI + 0.45, PI * 0.5 + 0.12, t)
			var p := _surf_pt(chp, lerpf(o.y, yb, t), th, 0.82, 2, rp)
			pts.append(_prof_out(chp, p, 0.82, 0.0022))
			ups.append(Vector3(p.x, 0.0, p.z).normalized())
		pts.append(bow_b + Vector3(0.004 * sgn, 0.0, 0.0))
		ups.append(Vector3.BACK)
		m.sweep(pts, [Vector2(0.0022, 0.0016)], col, 6, true, true, ups)
	_build_bow(m, col, bow_b, Vector3.RIGHT, Vector3.UP, Vector3.BACK)
	# halter straps: from the tip of each cup up the chest, round the base of the neck to the nape
	var nape := _prof_out(chp, _prof_pt(chp, 0.289, PI * 0.5, 0.82), 0.82, 0.009)
	for k in 2:
		var sgn := -1.0 if k == 0 else 1.0
		var pts := [_prof_out(chp, tips[k], 0.82, 0.004)]
		var ups := [Vector3(0.0, 0.3, -1.0).normalized()]
		# closely spaced so the strap follows the chest where it curves into the shoulder
		for i in 10:
			var t := float(i) / 9.0
			pts.append(_prof_out(chp, _surf_xy(chp, (0.052 + 0.012 * t) * sgn, 0.17 + 0.109 * t, 0.82, 2, rp), 0.82, 0.0045))
			ups.append(Vector3(0.0, 0.3, -1.0).normalized())
		for th: float in [-0.55, 0.0, 0.6, 1.15]:
			var a := th if sgn > 0.0 else PI - th
			var p := _prof_out(chp, _prof_pt(chp, 0.289, a, 0.82), 0.82, 0.007)
			pts.append(p)
			ups.append(Vector3(p.x, 0.25, p.z).normalized())
		pts.append(nape + Vector3(0.006 * sgn, 0.0, 0.0))
		ups.append(Vector3(0.0, 0.2, 1.0).normalized())
		m.sweep(pts, [Vector2(0.0045, 0.0014)], col, 6, true, true, ups)
	_build_bow(m, col, nape + Vector3(0, 0, 0.002), Vector3.RIGHT, Vector3(0.0, 1.0, -0.15).normalized(), Vector3.BACK)


## Ear: concha body, helix rim, antihelix ridge and a fleshy lobe; angled back from the skull.
func _build_ear(m: Mesher, s: float, skin: Color) -> void:
	var fw := float(_fp.get("fw", 0.0))
	var root := Vector3(s * HEAD_R.x * (1.0 + 0.05 * fw) * 0.94, EYE_Y - 0.01, 0.012)
	var out_dir := Vector3(s, 0, 0.32).normalized()
	var up := Vector3.UP
	var back := Vector3(0, 0, 1)
	var basis := Basis(out_dir, up, back)
	var xf := Transform3D(basis, root)
	var sk := Color(0.97, 0.93, 0.92, SKIN)
	# ear body (flattened along the out axis)
	m.ellipsoid(Vector3(0.006, 0.002, 0.009), Vector3(0.0065, 0.027, 0.014), sk, 10, 8, xf)
	# helix rim
	var rim := []
	var rad := []
	for i in 13:
		var a := lerpf(-0.35, 3.5, float(i) / 12.0)
		var vv := 0.009 + 0.015 * sin(a) * 0.9
		var uu := 0.0 + 0.029 * cos(a)
		rim.append(xf * Vector3(0.012 + 0.006 * sin(a), uu, vv))
		rad.append(0.0034 + 0.0008 * sin(a))
	m.sweep(rim, rad, sk, 6, true, true)
	# lobe
	m.ellipsoid(Vector3(0.008, -0.025, 0.006), Vector3(0.004, 0.0085, 0.0075), sk, 8, 5, xf)
	# tragus
	m.ellipsoid(Vector3(0.004, -0.004, -0.004), Vector3(0.004, 0.006, 0.004), sk, 6, 4, xf)


## Height (in skull units, -1 chin .. 1 crown) of the hairline at this point of the head: a natural
## front hairline, slight temple recession, sideburns in front of the ears, hair above and behind the
## ears and down to the nape. The face shader (hairline()) uses the same curve for the painted scalp.
const _HL_A := [0.0, 0.45, 0.95, 1.25, 1.5, 1.75, 2.0, 2.4, PI]
const _HL_M := [0.56, 0.6, 0.42, 0.2, 0.12, 0.16, -0.15, -0.5, -0.6]
const _HL_F := [0.5, 0.5, 0.4, 0.22, 0.15, 0.15, -0.2, -0.62, -0.72]


static func hairline(q: Vector3, female: bool) -> float:
	var az := absf(atan2(q.x, -q.z))
	var hh: Array = _HL_F if female else _HL_M
	var i := 1
	while i < 8 and az > float(_HL_A[i]):
		i += 1
	var a0: float = _HL_A[i - 1]
	var a1: float = _HL_A[i]
	var h := lerpf(float(hh[i - 1]), float(hh[i]), clampf((az - a0) / (a1 - a0), 0.0, 1.0))
	if not female:
		var t := (az - 1.38) / 0.07
		h -= 0.32 * exp(-t * t)
	return h


## Hair: a shell over the skull following the hairline (it sinks under the skin outside the hair, so the
## hairline is smooth), plus long hair / bun / braid. 0 short, 1 medium, 2 long, 3 bun, 4 braid.
func _build_hair(m: Mesher, hair_len: int, hatted: bool, lo: bool) -> void:
	var hc := Color(1, 1, 1, HAIR)
	var thick := 0.0055
	if hair_len == 1:
		thick = 0.012
	elif hair_len >= 2:
		thick = 0.009 if _female else 0.014
	if hatted:
		thick = minf(thick, 0.006)
	var seg := 24 if lo else 52
	var rows := 12 if lo else 30
	var base := m.v.size()
	var pts := []
	for j in rows + 1:
		var phi := lerpf(-0.85, PI * 0.5, float(j) / float(rows))
		var row := []
		for k in seg + 1:
			var th := TAU * float(k) / float(seg) - PI * 0.5
			var q := _skull_macro(phi, th, _g)
			var p := HEAD_C + q
			q = q / HEAD_R
			var hline := hairline(q, _female)
			# a wide ramp: the shell rises gently out of the scalp; the crisp hairline is painted on the skull
			var w := smoothstep(hline - 0.06, hline + 0.14, q.y)
			var t := thick * (0.55 + 0.45 * smoothstep(-0.3, 0.7, q.y))
			if _female:
				# centre parting
				t *= 1.0 - 0.45 * exp(-pow(p.x / 0.008, 2.0)) * smoothstep(0.15, -0.4, q.z) * smoothstep(0.3, 0.7, q.y)
			var dirn := Vector3(q.x / HEAD_R.x, q.y / HEAD_R.y, q.z / HEAD_R.z).normalized()
			row.append(p + dirn * lerpf(-0.005, t, w))
		pts.append(row)
	for j in rows + 1:
		for k in seg + 1:
			var p: Vector3 = pts[j][k]
			var pu: Vector3 = pts[mini(j + 1, rows)][k]
			var pd: Vector3 = pts[maxi(j - 1, 0)][k]
			var pr: Vector3 = pts[j][mini(k + 1, seg) if k < seg else 1]
			var pl: Vector3 = pts[j][maxi(k - 1, 0) if k > 0 else seg - 1]
			var n := (pr - pl).cross(pu - pd)
			if n.dot(p - HEAD_C) < 0.0:
				n = -n
			if n.length_squared() < 1e-12:
				n = p - HEAD_C
			m.vert(p, n, hc)
	m.grid(base, rows, seg, HEAD_C)
	if hatted and hair_len >= 2:
		hair_len = 4 if hair_len == 4 else 3
	var id := Transform3D()
	match hair_len:
		2:
			# long hair falling behind the shoulders, slightly wavy, tapered tips
			var ring := []
			var spec := [[0.27, 0.07, 0.03, 0.04], [0.21, 0.09, 0.05, 0.065], [0.13, 0.092, 0.04, 0.09], [0.05, 0.088, 0.03, 0.104],
				[-0.03, 0.084, 0.024, 0.112], [-0.11, 0.08, 0.02, 0.118], [-0.19, 0.072, 0.016, 0.122], [-0.25, 0.055, 0.012, 0.124], [-0.28, 0.03, 0.008, 0.124]]
			if not _female:
				spec = spec.slice(0, 5)
			for sp in spec:
				ring.append([Vector3(0, float(sp[0]), float(sp[3])), float(sp[1]), float(sp[2]), hc])
			m.loft(ring, 8 if lo else 18, id, true, true, 1.0)
		3:
			# khopa (bun) at the nape, wrapped
			m.ellipsoid(Vector3(0, 0.165, 0.112), Vector3(0.042, 0.036, 0.03), hc, 8 if lo else 14, 5 if lo else 9)
			if lo:
				return
			m.loft([[Vector3(0, 0.15, 0.13), 0.028, 0.018, hc], [Vector3(0, 0.165, 0.142), 0.03, 0.02, hc], [Vector3(0, 0.18, 0.13), 0.026, 0.016, hc]], 12, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, 0.165, 0.0)) * Transform3D(Basis(), Vector3(0, -0.165, 0)), false, false)
		4:
			# beni (plait) down the back with a ribbon tie
			if lo:
				m.sweep([Vector3(0, 0.13, 0.103), Vector3(0, 0.0, 0.118), Vector3(0, -0.15, 0.125), Vector3(0, -0.33, 0.125)], [0.017, 0.016, 0.014, 0.008], hc, 6, false, true)
				return
			var n := 19
			for i in n:
				var t := float(i) / float(n - 1)
				var y := lerpf(0.13, -0.31, t)
				var z := 0.103 + 0.022 * smoothstep(0.0, 0.35, t)
				var s := -1.0 if i % 2 == 0 else 1.0
				var r := lerpf(0.018, 0.011, t)
				m.ellipsoid(Vector3.ZERO, Vector3(r, 0.019, r * 0.75), hc, 7, 4, Transform3D(Basis(Vector3.BACK, 0.42 * s), Vector3(0.005 * s, y, z)))
			var rib := _c(outfit.get("dupatta", Color(0.8, 0.1, 0.2)), CLOTH)
			m.loft([[Vector3(0, -0.325, 0.124), 0.012, 0.01, rib], [Vector3(0, -0.338, 0.124), 0.012, 0.01, rib]], 8, id, true, true)
			m.sweep([Vector3(0, -0.335, 0.124), Vector3(0.008, -0.37, 0.126), Vector3(0.006, -0.4, 0.124)], [Vector2(0.006, 0.0015)], rib, 6, false, true, [Vector3.BACK], true)
			m.ellipsoid(Vector3(0, -0.355, 0.124), Vector3(0.009, 0.016, 0.007), hc, 8, 5)


func _build_jewellery(m: Mesher) -> void:
	var er := int(_fp.get("earrings", 0))
	if er > 0 and str(outfit.get("hat", "none")) != "hijab":
		var fw := float(_fp.get("fw", 0.0))
		for s: float in [-1.0, 1.0]:
			var lobe := Vector3(s * HEAD_R.x * (1.0 + 0.05 * fw) * 0.94 + s * 0.006, EYE_Y - 0.01 - 0.026, 0.017)
			if er == 1:
				m.ellipsoid(lobe + Vector3(s * 0.0045, 0.0, -0.002), Vector3(0.0035, 0.0035, 0.0035), GOLD, 8, 5)
			else:
				# jhumka: stud, little dome bell and a bead
				m.ellipsoid(lobe + Vector3(s * 0.005, 0.0, -0.002), Vector3(0.003, 0.003, 0.003), GOLD, 6, 4)
				m.loft([[lobe + Vector3(s * 0.005, -0.008, 0.0), 0.0015, 0.0015, GOLD], [lobe + Vector3(s * 0.005, -0.013, 0.0), 0.006, 0.006, GOLD],
					[lobe + Vector3(s * 0.005, -0.021, 0.0), 0.009, 0.009, GOLD], [lobe + Vector3(s * 0.005, -0.024, 0.0), 0.0095, 0.0095, GOLD]], 10, Transform3D(), true, false, 1.0, true)
				m.ellipsoid(lobe + Vector3(s * 0.005, -0.027, 0.0), Vector3(0.0025, 0.0025, 0.0025), Color(0.7, 0.08, 0.12, METAL), 6, 4)
	if bool(_fp.get("nose_pin", false)):
		var tip_y := -0.044 - 0.004 * float(_fp.get("nose_l", 0.0))
		var aw := 0.0125 * (1.0 + 0.25 * float(_fp.get("nose_w", 0.0)))
		var p := _skull_front_point(-aw * 0.95, tip_y - 0.003, _g)
		m.ellipsoid(p + Vector3(0, 0, -0.0012), Vector3(0.0022, 0.0022, 0.0016), GOLD, 8, 5)


# ============================================================================ head
## Skull grid: longitudes and latitudes are packed densely around the face (eyes to chin).
static func _warp(u: float, a: float) -> float:
	return u * (a + (1.0 - a) * u * u)


## Overall head shape (no facial relief), relative to HEAD_C. phi: latitude (-PI/2 chin .. PI/2 crown),
## th: longitude (0 = +X, -PI/2 = front -Z). The hair shell uses this cheaper shape directly.
## g = _geo(): [fw, jaw, chin, cheek, nose_w, nose_l, lip_full, lip_w, eye_size, eye_sp, age, female]
static func _skull_macro(phi: float, th: float, g: PackedFloat32Array) -> Vector3:
	var fw: float = g[0]
	var jaw: float = g[1]
	var cheek: float = g[3]
	var age: float = g[10]
	var fem: float = g[11]
	var cp := cos(phi)
	var d := Vector3(cp * cos(th), sin(phi), cp * sin(th))
	var p := d * HEAD_R
	var y := d.y
	var front := clampf(-d.z, 0.0, 1.0)
	p.x *= 1.0 + 0.05 * fw
	# cranium: fuller occiput, the nape tucks in towards the neck
	if d.z > 0.0:
		p.z *= 1.0 + 0.1 * smoothstep(-0.3, 0.5, y)
		p.y += 0.008 * d.z * smoothstep(-0.2, 0.6, y)
		p.z *= 1.0 - 0.2 * smoothstep(-0.3, -0.9, y) * d.z
	# lower face: the jaw narrows to the chin (narrower for women; jaw slider widens it)
	if y < -0.05:
		var j := smoothstep(-0.05, -1.0, y)
		var narrow := (0.19 if fem > 0.5 else 0.16) - 0.075 * jaw
		p.x *= 1.0 - narrow * j * (0.55 + 0.45 * front)
		p.z *= 1.0 - 0.12 * j * (1.0 - front)
	# temples a little hollow, cheekbones wide
	var my0 := p.y + HEAD_C.y - EYE_Y
	var t1 := (my0 - 0.04) / 0.025
	p.x *= 1.0 - 0.03 * exp(-t1 * t1) * smoothstep(0.1, 0.5, front)
	var t2 := (my0 + 0.014) / 0.022
	p.x *= 1.0 + (0.04 + 0.025 * cheek) * exp(-t2 * t2) * (1.0 - absf(d.z) * 0.3)
	if my0 < -0.04:
		# square jaw angle (gonion), stronger on men; jowls with age
		var t3 := (my0 + 0.082) / 0.016
		p.x += signf(p.x) * (0.0035 + 0.003 * jaw) * (1.0 - fem * 0.6) * exp(-t3 * t3) * smoothstep(-0.5, 0.0, d.z) * smoothstep(0.45, 0.1, d.z)
		var t4 := (my0 + 0.095) / 0.012
		p.x += signf(p.x) * 0.003 * age * exp(-t4 * t4) * smoothstep(0.2, 0.6, front)
	return p


## Sculpted head: macro shape plus facial relief - bumps in metric face coordinates (negative dz =
## forward): brow ridge, eye sockets and lids, nose bridge / tip / alae, cheeks, lips, chin.
static func _skull_point(phi: float, th: float, g: PackedFloat32Array) -> Vector3:
	var p := _skull_macro(phi, th, g)
	var front := clampf(-cos(phi) * sin(th), 0.0, 1.0)
	if front < 0.05:
		return HEAD_C + p
	var chin: float = g[2]
	var cheek: float = g[3]
	var nose_w: float = g[4]
	var nose_l: float = g[5]
	var lip_full: float = g[6]
	var lip_w: float = g[7]
	var eye_size: float = g[8]
	var eye_sp: float = g[9]
	var age: float = g[10]
	var fem: float = g[11]
	var mx := absf(p.x)
	var my := p.y + HEAD_C.y - EYE_Y
	var dz := 0.0
	var ex := 0.031 * (1.0 + 0.07 * eye_sp)
	var es := 1.0 + 0.13 * eye_size
	var a := 0.0
	var b := 0.0
	# the sides of the face come forward a little (flatter face plane)
	dz -= 0.008 * smoothstep(0.03, 0.06, mx) * smoothstep(0.075, 0.055, mx) * smoothstep(-0.11, -0.05, my) * smoothstep(0.06, 0.01, my)
	if my > -0.03:
		# brow ridge and glabella
		a = (my - 0.02) / 0.009
		dz -= (0.0028 if fem > 0.5 else 0.0048) * exp(-a * a) * smoothstep(0.058, 0.03, mx)
		a = mx / 0.007
		b = (my - 0.005) / 0.008
		dz += 0.0022 * exp(-a * a - b * b)
		# eye sockets and the eyeball / lid volume inside them, lower lid / eye bag
		var edx := mx - ex
		a = edx / (0.0175 * es)
		b = (my + 0.001) / (0.0115 * es)
		dz += 0.0085 * exp(-a * a - b * b)
		a = edx / (0.0115 * es)
		b = (my + 0.0005) / (0.0072 * es)
		dz -= 0.0052 * exp(-a * a - b * b)
		a = edx / 0.011
		b = (my + 0.0115) / 0.004
		dz -= (0.0006 + 0.0016 * age) * exp(-a * a - b * b)
	# nose: bridge from the nasion to the tip, rounded tip, alae and the crease round them
	var tip_y := -0.044 - 0.004 * nose_l
	if my < 0.014 and my > tip_y - 0.016 and mx < 0.035:
		var proj := (0.021 if fem > 0.5 else 0.025) * (1.0 + 0.22 * nose_l)
		var tn := clampf((0.004 - my) / (0.004 - tip_y), 0.0, 1.0)
		var bridge := proj * (0.22 + 0.78 * pow(tn, 1.25))
		bridge *= smoothstep(tip_y - 0.0105, tip_y - 0.001, my) * smoothstep(0.012, 0.003, my)
		a = (my - tip_y) / 0.0055
		bridge += 0.0035 * exp(-a * a)
		var nw := lerpf(0.0068, 0.0108, tn) * (1.0 + 0.18 * nose_w)
		a = mx / nw
		dz -= bridge * exp(-a * a)
		var aw := 0.0125 * (1.0 + 0.25 * nose_w)
		a = (mx - aw * 0.78) / (0.0058 * (1.0 + 0.2 * nose_w))
		b = (my - tip_y + 0.0035) / 0.0062
		dz -= 0.0082 * (1.0 + 0.25 * nose_w) * exp(-a * a - b * b)
		a = (mx - aw * 1.32) / 0.0025
		b = (my - tip_y + 0.001) / 0.008
		dz += 0.0018 * exp(-a * a - b * b)
	# cheeks (malar fat pads) and the hollow below the cheekbone
	a = (mx - 0.038) / 0.018
	b = (my + 0.026) / 0.021
	dz -= (0.0062 + 0.0035 * cheek) * exp(-a * a - b * b)
	a = (mx - 0.05) / 0.012
	b = (my + 0.058) / 0.014
	dz += (0.0028 * (1.0 - fem * 0.6) + 0.002 * age) * exp(-a * a - b * b)
	if my < -0.03:
		# nasolabial fold (age), muzzle (dental arch), lips, mouth seam, philtrum, mentolabial sulcus, chin
		if age > 0.01:
			var nl_x := 0.017 + (-my - 0.045) * 0.55
			a = (mx - nl_x) / 0.003
			dz += 0.0022 * age * exp(-a * a) * smoothstep(-0.04, -0.05, my) * smoothstep(-0.088, -0.074, my)
		var lw := 0.024 * (1.0 + 0.15 * lip_w) * (0.9 if fem > 0.5 else 1.0)
		a = mx / 0.034
		b = (my + 0.068) / 0.028
		dz -= 0.0072 * exp(-a * a - b * b)
		var l4 := mx / lw
		l4 = l4 * l4
		l4 = l4 * l4
		var ul := 0.0045 * (1.0 + 0.45 * lip_full)
		b = (my + 0.0662) / (0.0042 * (1.0 + 0.2 * lip_full))
		dz -= ul * exp(-l4) * exp(-b * b)
		var l4b := mx / (lw * 0.88)
		l4b = l4b * l4b
		l4b = l4b * l4b
		var ll := 0.0056 * (1.0 + 0.5 * lip_full)
		b = (my + 0.0758 + 0.001 * lip_full) / (0.0046 * (1.0 + 0.25 * lip_full))
		dz -= ll * exp(-l4b) * exp(-b * b)
		var l4c := mx / (lw * 1.05)
		l4c = l4c * l4c
		l4c = l4c * l4c
		b = (my + 0.0712) / 0.0012
		dz += 0.0022 * exp(-b * b) * exp(-l4c)
		a = mx / 0.0016
		dz += 0.0007 * exp(-a * a) * smoothstep(-0.066, -0.06, my) * smoothstep(-0.05, -0.056, my)
		a = mx / 0.018
		b = (my + 0.087) / 0.005
		dz += 0.0028 * exp(-a * a - b * b)
		var chin_y := -0.103 - 0.005 * chin
		a = mx / (0.017 * (1.0 - 0.25 * fem))
		b = (my - chin_y) / 0.012
		dz -= (0.0062 + 0.0035 * chin) * exp(-a * a - b * b)
	p.z += dz * smoothstep(0.05, 0.45, front)
	# longer / shorter chin
	p.y -= 0.007 * chin * smoothstep(-0.085, -0.12, my) * smoothstep(0.0, 0.5, front)
	return HEAD_C + p


static func _build_skull(m: Mesher, g: PackedFloat32Array, seg: int, rows: int) -> void:
	var base := m.v.size()
	var pts := []
	var phi0 := -0.32
	for j in rows + 1:
		var u := -1.0 + 2.0 * float(j) / float(rows)
		var phi := phi0 + (PI * 0.5 + phi0 if u < 0.0 else PI * 0.5 - phi0) * _warp(u, 0.45)
		var row := []
		for k in seg + 1:
			var uk := -1.0 + 2.0 * float(k) / float(seg)
			var th := -PI * 0.5 + PI * _warp(uk, 0.38)
			row.append(_skull_point(phi, th, g))
		pts.append(row)
	for j in rows + 1:
		for k in seg + 1:
			var p: Vector3 = pts[j][k]
			var pu: Vector3 = pts[mini(j + 1, rows)][k]
			var pd: Vector3 = pts[maxi(j - 1, 0)][k]
			var pr: Vector3 = pts[j][k + 1 if k < seg else 1]
			var pl: Vector3 = pts[j][k - 1 if k > 0 else seg - 1]
			var n := (pr - pl).cross(pu - pd)
			var radial := p - HEAD_C
			if n.length_squared() < 1e-12:
				n = radial
			if n.dot(radial) < 0.0:
				n = -n
			m.vert(p, n, Color(1, 1, 1, 1))
	m.grid(base, rows, seg, HEAD_C)


## Point on the front of the sculpted face at metric (x, y-from-the-eye-line) - for jewellery.
static func _skull_front_point(x: float, my: float, g: PackedFloat32Array) -> Vector3:
	var ty := my + EYE_Y - HEAD_C.y
	var phi := asin(clampf(ty / HEAD_R.y, -0.99, 0.99))
	var th := -PI * 0.5 + asin(clampf(x / (HEAD_R.x * cos(phi)), -0.99, 0.99))
	var p := _skull_point(phi, th, g)
	for i in 6:
		var dp := p - HEAD_C
		phi += (ty - dp.y) / (HEAD_R.y * maxf(cos(phi), 0.2))
		th += (x - dp.x) / (HEAD_R.x * maxf(cos(phi), 0.2))
		p = _skull_point(phi, th, g)
	return p


## Hijab: a hood following the skull with an opening for the face, falling over neck and shoulders.
static func _build_hijab(m: Mesher, hc: Color, b: Dictionary, g: PackedFloat32Array) -> void:
	var seg := 34
	var rows := 18
	var base := m.v.size()
	var keep := []
	for j in rows + 1:
		var phi := lerpf(-1.05, PI * 0.5, float(j) / float(rows))
		for k in seg + 1:
			var th := TAU * float(k) / float(seg)
			var p := _skull_point(phi, th, g)
			var front := -sin(th)
			var open := phi > -0.82 and phi < 0.42 and front > 0.55
			keep.append(not open)
			var n := p - HEAD_C
			m.vert(HEAD_C + n * 1.1 + Vector3(0, 0, 0.004), n, hc)
	for j in rows:
		for k in seg:
			var a := base + j * (seg + 1) + k
			var ka := a - base
			if keep[ka] and keep[ka + 1] and keep[ka + seg + 1] and keep[ka + seg + 2]:
				m.tri(a, a + 1, a + seg + 2)
				m.tri(a, a + seg + 2, a + seg + 1)
	var shf: float = float(b["sh"])
	m.loft([[Vector3(0, -0.02, 0.012), 0.18 * shf, 0.125, hc], [Vector3(0, 0.03, 0.012), 0.14 * shf, 0.11, hc], [Vector3(0, 0.07, 0.014), 0.1, 0.092, hc],
		[Vector3(0, 0.1, 0.015), 0.085, 0.085, hc]], 24, Transform3D(), false, false, 1.0, true)


## Foot at the ankle pivot; toes point -Z. med = +1 for the left foot (big toe towards +X), -1 right.
static func _build_foot(m: Mesher, shoes: String, legf: float, med: float) -> void:
	var sole_col := Color(0.05, 0.045, 0.04, LEATHER)
	var col := Color(0.08, 0.07, 0.06, LEATHER)
	if shoes == "shoes":
		col = Color(0.12, 0.08, 0.05, LEATHER)
	var skin := Color(1, 1, 1, SKIN)
	var xf := Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), Vector3.ZERO)
	if shoes == "sandals":
		# bare foot: heel, high medial arch, ball, five toes; thin sole with a toe post and strap
		var fr := [[-0.066, 0.019, 0.017, -0.048, 0.017], [-0.052, 0.027, 0.021, -0.046, 0.026], [-0.028, 0.031, 0.022, -0.042, 0.04],
			[0.01, 0.033, 0.02, -0.042, 0.04], [0.05, 0.037, 0.016, -0.048, 0.029], [0.09, 0.041, 0.015, -0.053, 0.021],
			[0.125, 0.044, 0.013, -0.056, 0.015], [0.145, 0.043, 0.011, -0.058, 0.012]]
		var rings := []
		for f in fr:
			rings.append([Vector3(0.004 * med * smoothstep(0.0, 0.12, float(f[0])), float(f[0]), float(f[3])), float(f[1]), float(f[2]), skin, float(f[4])])
		m.loft(rings, 16, xf, true, true, 0.85)
		var toes := [[0.026, 0.142, 0.042, 0.0115], [0.008, 0.143, 0.034, 0.0078], [-0.007, 0.141, 0.03, 0.0072], [-0.02, 0.137, 0.026, 0.0067], [-0.032, 0.131, 0.021, 0.006]]
		for t in toes:
			var tx: float = float(t[0]) * med
			var f0: float = t[1]
			var ln: float = t[2]
			var rr: float = t[3]
			var spread: float = float(t[0]) * 0.25 * med
			m.sweep([Vector3(tx, -0.058, -f0 + 0.01), Vector3(tx + spread * 0.3, -0.06, -f0 - ln * 0.45), Vector3(tx + spread, -0.0635, -f0 - ln * 0.85), Vector3(tx + spread, -0.064, -f0 - ln)],
				[Vector2(rr, rr * 0.85), Vector2(rr, rr * 0.8), Vector2(rr * 0.9, rr * 0.72), Vector2(rr * 0.5, rr * 0.4)], skin, 7, false, true, [Vector3.UP])
		var strap := Color(0.32, 0.2, 0.12, LEATHER)
		m.loft([[Vector3(0, -0.075, 0.0), 0.044, 0.004, Color(0.22, 0.15, 0.1, LEATHER)], [Vector3(0, -0.06, 0.0), 0.046, 0.004, Color(0.22, 0.15, 0.1, LEATHER)],
			[Vector3(0, 0.2, 0.0), 0.04, 0.004, Color(0.22, 0.15, 0.1, LEATHER)], [Vector3(0, 0.208, 0.0), 0.03, 0.004, Color(0.22, 0.15, 0.1, LEATHER)]],
			14, Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), Vector3(0, -0.0735, 0)), true, true, 0.7)
		var post := Vector3(0.018 * med, -0.064, -0.15)
		m.sweep([Vector3(0.044 * med, -0.07, -0.085), Vector3(0.03 * med, -0.042, -0.1), post], [Vector2(0.004, 0.0018)], strap, 6, true, true, [Vector3.UP])
		m.sweep([Vector3(-0.045 * med, -0.07, -0.08), Vector3(-0.01 * med, -0.038, -0.11), post], [Vector2(0.004, 0.0018)], strap, 6, true, true, [Vector3.UP])
		return
	if shoes == "boots":
		m.loft([[Vector3(0, -0.035, 0.002), 0.042, 0.046, col, 0.05], [Vector3(0, 0.06, 0.004), 0.04 * legf + 0.006, 0.042 * legf + 0.006, col, 0.044 * legf + 0.006],
			[Vector3(0, 0.15, 0.004), 0.037 * legf + 0.008, 0.04 * legf + 0.008, col, 0.042 * legf + 0.008], [Vector3(0, 0.16, 0.004), 0.039 * legf + 0.009, 0.042 * legf + 0.009, col.lightened(0.05), 0.044 * legf + 0.009]], 16, Transform3D(), false, false)
		for i in 5:
			m.box(Vector3(0, 0.0 + i * 0.03, -0.04 * legf - 0.012), Vector3(0.026, 0.004, 0.004), Color(0.03, 0.03, 0.03, LEATHER))
	var sh := [[-0.072, 0.026, 0.018, -0.046, 0.022], [-0.058, 0.035, 0.023, -0.045, 0.036], [-0.03, 0.04, 0.025, -0.042, 0.048],
		[0.01, 0.042, 0.026, -0.042, 0.046], [0.05, 0.045, 0.022, -0.048, 0.034], [0.1, 0.048, 0.019, -0.053, 0.024],
		[0.15, 0.046, 0.016, -0.056, 0.018], [0.19, 0.037, 0.013, -0.058, 0.014], [0.213, 0.021, 0.009, -0.059, 0.009]]
	var srings := []
	for f in sh:
		srings.append([Vector3(0.004 * med * smoothstep(0.05, 0.18, float(f[0])), float(f[0]), float(f[3])), float(f[1]), float(f[2]), col, float(f[4])])
	m.loft(srings, 18, xf, true, true, 0.8)
	m.loft([[Vector3(0, -0.076, -0.067), 0.032, 0.006, sole_col], [Vector3(0, -0.06, -0.067), 0.04, 0.006, sole_col], [Vector3(0, 0.16, -0.067), 0.049, 0.006, sole_col],
		[Vector3(0, 0.21, -0.067), 0.032, 0.006, sole_col], [Vector3(0, 0.222, -0.066), 0.016, 0.005, sole_col]], 16, xf, true, true, 0.6)
	# laces / tongue line
	m.sweep([Vector3(0, -0.012, -0.045), Vector3(0, -0.028, -0.08), Vector3(0, -0.04, -0.115)], [Vector2(0.012, 0.0025)], col.darkened(0.35), 6, true, true, [Vector3(0, 1, -0.6).normalized()])


## Hand in forearm space below the wrist: palm (thin across, wide front-back), thenar pad, four jointed
## fingers curled towards the palm (more when gripping a rifle) and an opposed thumb. sgn = +1 right.
func _build_hand(m: Mesher, sgn: float, hc: Color, armf: float, armed: bool, gloves: bool) -> void:
	var id := Transform3D()
	var hs := 0.92 if _female else 1.0
	var g := 0.004 if gloves else 0.0
	m.loft([[Vector3(0, -0.25, 0.0), 0.02 * hs + g, 0.027 * hs + g, hc], [Vector3(0, -0.268, -0.002), 0.019 * hs + g, 0.034 * hs + g, hc],
		[Vector3(0, -0.295, -0.002), 0.0165 * hs + g, 0.04 * hs + g, hc], [Vector3(0, -0.322, -0.001), 0.0145 * hs + g, 0.043 * hs + g, hc],
		[Vector3(0, -0.338, 0.0), 0.0135 * hs + g, 0.043 * hs + g, hc], [Vector3(0, -0.345, 0.0), 0.011 * hs + g, 0.038 * hs + g, hc]], 12, id, false, true, 0.8)
	var palm := Vector3(-sgn, 0, 0)
	# thenar eminence on the palm side towards the thumb
	m.ellipsoid(Vector3(-0.007 * sgn, -0.288, -0.024 * hs), Vector3(0.011, 0.024, 0.012) * hs, hc, 8, 5)
	var curl: Array = [0.55, 0.95, 0.6] if armed else [0.2, 0.38, 0.22]
	var fingers := [[-0.029, -0.336, [0.041, 0.024, 0.019], 0.0092, -0.06], [-0.0095, -0.341, [0.046, 0.028, 0.021], 0.0095, -0.01],
		[0.0095, -0.338, [0.043, 0.026, 0.02], 0.009, 0.04], [0.027, -0.331, [0.033, 0.02, 0.018], 0.008, 0.1]]
	for f in fingers:
		var p := Vector3(0.0, float(f[1]) + 0.006, float(f[0]) * hs)
		var dir := Vector3(0, -1, 0).rotated(Vector3.RIGHT, float(f[4]))
		var lens: Array = f[2]
		var r0: float = float(f[3]) * hs + g * 0.6
		var pts := [p]
		var rad := [Vector2(r0 * 1.06, r0 * 0.95)]
		for j in 3:
			var axis := dir.cross(palm).normalized()
			dir = dir.rotated(axis, float(curl[j]))
			var ln: float = float(lens[j]) * hs
			if j == 0:
				pts.append(p + dir * ln * 0.5)
				rad.append(Vector2(r0, r0 * 0.9))
			p = p + dir * ln
			pts.append(p)
			rad.append(Vector2(r0 * (0.98 - 0.1 * j), r0 * (0.9 - 0.09 * j)))
		pts.append(p + dir * r0 * 0.55)
		rad.append(Vector2(r0 * 0.55, r0 * 0.45))
		m.sweep(pts, rad, hc, 6, false, true, [palm])
	# thumb: from the base of the palm, forward and across the palm
	var tcurl := 0.5 if armed else 0.2
	var tp := Vector3(-0.006 * sgn, -0.266, -0.026 * hs)
	var tdir := Vector3(-0.35 * sgn, -0.75, -0.55).normalized()
	var tpts := [tp]
	var trad := [Vector2(0.0125, 0.011) * hs]
	var tl := [0.035, 0.03, 0.024]
	for j in 3:
		if j > 0:
			tdir = tdir.rotated(tdir.cross(palm).normalized(), tcurl * 0.6)
		tp = tp + tdir * float(tl[j]) * hs
		tpts.append(tp)
		var rr := (0.0115 - 0.0012 * j) * hs + g * 0.6
		trad.append(Vector2(rr, rr * 0.9))
	tpts.append(tp + tdir * 0.005)
	trad.append(Vector2(0.005, 0.0045))
	m.sweep(tpts, trad, hc, 6, true, true, [palm])
	if gloves:
		# glove cuff over the wrist
		m.loft([[Vector3(0, -0.205, 0.0), 0.029, 0.034, hc], [Vector3(0, -0.25, 0.0), 0.026, 0.032, hc]], 12, id, false, false)

func _build_restraints(b: Dictionary) -> void:
	var rope := Color(0.6, 0.47, 0.28, CLOTH)
	var id := Transform3D()
	var armf: float = b["arm"]
	for f in [fore_l, fore_r]:
		var m := Mesher.new()
		for y: float in [-0.205, -0.232]:
			m.loft([[Vector3(0, y + 0.006, 0), 0.03 * armf + 0.008, 0.026 * armf + 0.008, rope], [Vector3(0, y, 0), 0.032 * armf + 0.01, 0.028 * armf + 0.01, rope],
				[Vector3(0, y - 0.006, 0), 0.03 * armf + 0.008, 0.026 * armf + 0.008, rope]], 10, id, false, false)
		var r := _attach(f, _to_mesh(m), "Rope")
		ropes.append(r)
	for k in [knee_l, knee_r]:
		var m2 := Mesher.new()
		for y: float in [-0.35, -0.375]:
			m2.loft([[Vector3(0, y + 0.007, 0), 0.05, 0.05, rope], [Vector3(0, y, 0), 0.054, 0.054, rope], [Vector3(0, y - 0.007, 0), 0.05, 0.05, rope]], 10, id, false, false)
		ropes.append(_attach(k, _to_mesh(m2), "Rope"))
	# small strip of tape over the lips only
	var tm := Mesher.new()
	var tape := Color(0.72, 0.72, 0.7, LEATHER)
	var cols := 8
	var rws := 4
	var base := tm.v.size()
	for j in rws:
		var phi := lerpf(-0.76, -0.5, float(j) / float(rws - 1))
		for k in cols:
			var th := -PI * 0.5 + lerpf(-0.52, 0.52, float(k) / float(cols - 1))
			var p := _skull_point(phi, th, _g)
			var n := (p - HEAD_C).normalized()
			n.y *= 0.4
			tm.vert(HEAD_C + (p - HEAD_C) * 1.045, n, tape)
			_tape_v.append(HEAD_C + (p - HEAD_C) * 1.045)
			_tape_n.append(n.normalized())
	for j in rws - 1:
		for k in cols - 1:
			var a2 := base + j * cols + k
			tm.tri(a2, a2 + 1, a2 + cols + 1)
			tm.tri(a2, a2 + cols + 1, a2 + cols)
	_tape_cols = cols
	_tape_rows = rws
	gag = _attach(head, _to_mesh(tm), "TapeGag")
	_tape_mesh0 = gag.mesh
	gag.material_override = _tape_material()
	gag.visible = false
	_gag_pivot = HEAD_C + (_skull_point(-0.63, -PI * 0.5 + 0.52, _g) - HEAD_C) * 1.045
	# water bottle for the rescue drink
	var bm := Mesher.new()
	var plastic := Color(0.7, 0.82, 0.92, LEATHER)
	bm.loft([[Vector3(0, -0.1, 0), 0.03, 0.03, plastic], [Vector3(0, 0.07, 0), 0.031, 0.031, plastic], [Vector3(0, 0.1, 0), 0.016, 0.016, plastic],
		[Vector3(0, 0.12, 0), 0.013, 0.013, plastic]], 12, id, true, false)
	bm.loft([[Vector3(0, 0.12, 0), 0.015, 0.015, Color(0.1, 0.3, 0.75, LEATHER)], [Vector3(0, 0.14, 0), 0.015, 0.015, Color(0.1, 0.3, 0.75, LEATHER)]], 10, id, false, true)
	bm.loft([[Vector3(0, -0.02, 0), 0.0315, 0.0315, Color(0.2, 0.55, 0.85, CLOTH)], [Vector3(0, 0.04, 0), 0.0315, 0.0315, Color(0.2, 0.55, 0.85, CLOTH)]], 12, id, false, false)
	var bp := _pivot(fore_r, "BottleHold", Vector3(0, -0.31, -0.03))
	bottle = _attach(bp, _to_mesh(bm), "Bottle")
	bottle.rotation = Vector3(PI * 0.5, 0, 0)
	bottle.visible = false
	for r in ropes:
		(r as Node3D).visible = false
	# Phase 7: X-bed straps - a short rope from each wrist / ankle out towards the bed corner.
	# Only shown while the body is tied spread-eagle on a bed (pose "bed_x").
	for sp in [[fore_l, -0.31, 0.34], [fore_r, -0.31, 0.34], [knee_l, -0.46, 0.32], [knee_r, -0.46, 0.32]]:
		var sm := Mesher.new()
		var y0: float = sp[1]
		var ln: float = sp[2]
		sm.loft([[Vector3(0, y0, 0), 0.013, 0.013, rope], [Vector3(0, y0 - ln, 0), 0.011, 0.011, rope]], 6, id, false, false)
		var strap := _attach(sp[0], _to_mesh(sm), "BedStrap")
		if strap != null:
			strap.visible = false
			bed_straps.append(strap)


# ============================================================================ public API
## A photo fit measures the real face (width, jaw, chin, eyes, nose, lips) in
## FaceAlign.shape_from_landmarks().  Push those numbers into the sculpted skull
## so the 3-D head matches the person instead of wearing their photo like a mask.
func apply_face_shape(shape: Dictionary) -> void:
	if shape.is_empty() or outfit == null:
		return
	var f: Dictionary = outfit.get("face", {})
	for k in shape.keys():
		f[k] = shape[k]
	outfit["face"] = f
	_fp = f
	_g = _geo(_fp, _female)
	var skey := str(_g)
	if not _skull_cache.has(skey):
		var sm := Mesher.new()
		_build_skull(sm, _g, 54, 42)
		var sl := Mesher.new()
		_build_skull(sl, _g, 22, 14)
		if _skull_cache.size() > 120:
			_skull_cache.clear()
		_skull_cache[skey] = [_to_mesh(sm), _to_mesh(sl)]
	var pair: Array = _skull_cache[skey]
	if face != null and is_instance_valid(face):
		face.mesh = pair[0]
	if face_lo != null and is_instance_valid(face_lo):
		face_lo.mesh = pair[1]
	# the tape and jewellery follow the old skull; rebuild their pivot from the new one
	_gag_pivot = HEAD_C + (_skull_point(-0.63, -PI * 0.5 + 0.52, _g) - HEAD_C) * 1.045
	if head_mat != null:
		_set_head_params(head_mat)


func apply_photo(m: ShaderMaterial) -> void:
	_face_mat = m
	_set_head_params(m)
	var sk = m.get_shader_parameter("skin_color")
	var hc = m.get_shader_parameter("hair_color")
	if sk is Color:
		body_mat.set_shader_parameter("skin_color", sk)
	if hc is Color:
		body_mat.set_shader_parameter("hair_color", hc)
	face.material_override = m
	if face_lo != null:
		face_lo.material_override = m
	head_mat = m
	face.visible = true


func set_tied(value: bool) -> void:
	tied = value
	for i in ropes.size():
		(ropes[i] as Node3D).visible = value
		if i < _rope_rest.size():
			(ropes[i] as Node3D).transform = _rope_rest[i]


static var _tape_mat: StandardMaterial3D = null


## Grey cloth duct tape: woven scrim texture in the normal map, satin sheen, a little translucency.
static func _tape_material() -> StandardMaterial3D:
	if _tape_mat != null:
		return _tape_mat
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.6, 0.61, 0.6)
	m.metallic = 0.18
	m.roughness = 0.42
	m.metallic_specular = 0.55
	var n := FastNoiseLite.new()
	n.noise_type = FastNoiseLite.TYPE_CELLULAR
	n.frequency = 0.25
	var nt := NoiseTexture2D.new()
	nt.width = 128
	nt.height = 128
	nt.seamless = true
	nt.as_normal_map = true
	nt.bump_strength = 3.0
	nt.noise = n
	m.normal_enabled = true
	m.normal_texture = nt
	m.normal_scale = 0.6
	m.uv1_triplanar = true
	m.uv1_scale = Vector3(60, 60, 60)
	var d := NoiseTexture2D.new()
	d.width = 128
	d.height = 128
	d.seamless = true
	var dn := FastNoiseLite.new()
	dn.frequency = 0.08
	d.noise = dn
	var gr := Gradient.new()
	gr.set_color(0, Color(0.86, 0.86, 0.86))
	gr.set_color(1, Color(1.0, 1.0, 1.0))
	d.color_ramp = gr
	m.albedo_texture = d
	_tape_mat = m
	return m


## First-person carry: hide the parts of this body right in front of the camera (see shaders).
func set_near_fade(m: float) -> void:
	if body_mat != null:
		body_mat.set_shader_parameter("near_fade", m)
	if head_mat != null:
		head_mat.set_shader_parameter("near_fade", m)


func set_gagged(value: bool) -> void:
	if gag != null:
		gag.visible = value
		gag.transform = Transform3D()
		# never flash a half-peeled strip when a new piece of tape goes on
		if _tape_mesh0 != null:
			gag.mesh = _tape_mesh0


## Phase 7: the X-bed tie. The body lies on its back (Hostage places the root on the bed), arms and
## legs spread to the four corners so the whole body reads as an X; the corner straps show.
func set_bed_x(value: bool) -> void:
	pose = "bed_x" if value else ""
	for s in bed_straps:
		(s as Node3D).visible = value
	if not value:
		_rest_pose()


func _pose_bed_x(delta: float) -> void:
	_t += delta
	# Ease into the X instead of snapping on the first frame; the straps and the
	# breathing keep the pose alive while the limbs settle.
	var k := clampf(delta * 7.0, 0.0, 1.0)
	hips.position = hips.position.lerp(Vector3(0, 0.5, 0), k)
	hips.rotation = hips.rotation.lerp(Vector3.ZERO, k)
	torso.rotation = torso.rotation.lerp(Vector3.ZERO, k)
	chest.rotation = Vector3(sin(_breath_ph) * 0.012, 0, 0)
	chest.scale = Vector3(1.0 + sin(_breath_ph) * 0.008, 1.0, 1.0 + sin(_breath_ph) * 0.01)
	head.rotation = head.rotation.lerp(Vector3(0.04, sin(_t * 0.5) * 0.05, 0), k)
	# legs spread down-and-out, arms up-and-out: the X
	leg_l.rotation = leg_l.rotation.lerp(Vector3(0, 0, -0.42), k)
	leg_r.rotation = leg_r.rotation.lerp(Vector3(0, 0, 0.42), k)
	knee_l.rotation = knee_l.rotation.lerp(Vector3.ZERO, k)
	knee_r.rotation = knee_r.rotation.lerp(Vector3.ZERO, k)
	foot_l.rotation = foot_l.rotation.lerp(Vector3(0.3, 0, 0), k)
	foot_r.rotation = foot_r.rotation.lerp(Vector3(0.3, 0, 0), k)
	arm_l.rotation = arm_l.rotation.lerp(Vector3(0, 0, -2.45), k)
	arm_r.rotation = arm_r.rotation.lerp(Vector3(0, 0, 2.45), k)
	fore_l.rotation = fore_l.rotation.lerp(Vector3(0.08, 0, 0), k)
	fore_r.rotation = fore_r.rotation.lerp(Vector3(0.08, 0, 0), k)
	skirt.rotation = skirt.rotation.lerp(Vector3.ZERO, k)
	# a nod / head shake must still read while the patient is strapped down
	head_signal_tick(delta, true)
	for s in bed_straps:
		(s as Node3D).visible = true


## Tape strip application/removal. k = 0 pressed flat on the lips, k = 1 fully
## peeled away. The strip eases out from one corner, lifts slightly off the face
## and curls as it comes free, then hides. A short press-in at the start of an
## application makes the strip settle onto the lips instead of popping in.
func set_gag_anim(k: float) -> void:
	if gag == null:
		return
	k = clampf(k, 0.0, 1.0)
	gag.visible = k < 0.985
	gag.transform = Transform3D()
	if k <= 0.001 or _tape_v.is_empty():
		gag.mesh = _tape_mesh0
		gag.transform = Transform3D()
		return
	# the lifted curl from the peel geometry, plus a small forward lift as it comes off
	# (32 cached steps: the strip curls smoothly without rebuilding a mesh every frame)
	gag.mesh = _tape_peeled(snappedf(k, 1.0 / 32.0))
	var lift := 0.012 * smoothstep(0.15, 1.0, k)
	gag.transform = Transform3D(Basis.IDENTITY, Vector3(0.0, 0.0, -lift))


## The strip peels progressively from one corner: everything behind the moving peel line folds back
## around it (a tight curl at the line), the rest stays stuck to the skin.
func _tape_peeled(k: float) -> ArrayMesh:
	if _tape_mesh_cache.has(k):
		return _tape_mesh_cache[k]
	var cols := _tape_cols
	var rws := _tape_rows
	var line := k * float(cols - 1) * 1.25
	var vs := PackedVector3Array()
	var ns := PackedVector3Array()
	var cs := PackedColorArray()
	var idx := PackedInt32Array()
	var tape := Color(0.72, 0.72, 0.7, LEATHER)
	for j in rws:
		var cl := clampi(int(ceil(line)), 0, cols - 1)
		var ap: Vector3 = _tape_v[j * cols + cl]
		for c in cols:
			var i := j * cols + c
			var p: Vector3 = _tape_v[i]
			var n: Vector3 = _tape_n[i]
			var behind := line - float(c)
			if behind > 0.0:
				var d := p - ap
				var ang := minf(behind * 0.75, PI * 0.82) * (1.0 if d.x >= 0.0 else -1.0)
				var b := Basis(Vector3.UP, ang)
				p = ap + b * d + n * 0.004 * minf(behind, 1.0)
				n = b * n
			vs.append(p)
			ns.append(n)
			cs.append(tape)
	for j in rws - 1:
		for c in cols - 1:
			var a2 := j * cols + c
			# both windings: the curled-back part shows its other side
			for q: int in [a2, a2 + 1, a2 + cols + 1, a2, a2 + cols + 1, a2 + cols, a2, a2 + cols + 1, a2 + 1, a2, a2 + cols, a2 + cols + 1]:
				idx.append(q)
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = vs
	arr[Mesh.ARRAY_NORMAL] = ns
	arr[Mesh.ARRAY_COLOR] = cs
	arr[Mesh.ARRAY_INDEX] = idx
	var am := ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	_tape_mesh_cache[k] = am
	return am


## Ropes loosening (k -> 1, sliding off and hidden at the end) or pulling tight (k -> 0).
func set_rope_anim(k: float) -> void:
	k = clampf(k, 0.0, 1.0)
	if _rope_rest.is_empty():
		for r in ropes:
			_rope_rest.append((r as Node3D).transform)
	for i in ropes.size():
		var r: Node3D = ropes[i]
		var t0: Transform3D = _rope_rest[i]
		var s := 1.0 + 0.55 * k
		# k = 0 tight on the wrists, k = 1 loosened and slid off.  Visibility follows
		# the animation itself, not the lagging `tied` flag, so loops appear while
		# the player is still holding X and slide away as the knot comes undone.
		r.transform = Transform3D(t0.basis.scaled(Vector3(s, 1.0, s)), t0.origin + Vector3(0, -0.05 * k, 0))
		r.visible = k < 0.985


func set_bottle(value: bool) -> void:
	if bottle != null:
		bottle.visible = value


func flash_hit() -> void:
	var tw := create_tween()
	tw.tween_method(_set_flash, 0.7, 0.0, 0.25)


func _set_flash(v: float) -> void:
	body_mat.set_shader_parameter("hit_flash", v)
	if head_mat != null:
		head_mat.set_shader_parameter("hit_flash", v)


func muzzle_position() -> Vector3:
	if muzzle != null:
		return muzzle.global_position
	return global_position + Vector3(0, 1.4, 0)


## Fireman's carry: hips over the carrier's shoulder, torso hanging down his back, legs hanging in front.
## Hostage.gd places the root; this folds the body. Arms dangle towards the ground.
func pose_carried(value: bool) -> void:
	carried = value
	pose = ""
	_carry_reset()
	if value:
		hips.position = Vector3(0, HIP_Y, 0)
		hips.rotation = Vector3.ZERO
		torso.rotation = Vector3(-0.08, 0, 0)
		chest.rotation = Vector3(-0.12, 0, 0)
		head.rotation = Vector3(-0.15, 0, 0)
		# hips folded over the shoulder; tied ankles keep the legs together
		var spread := 0.0 if tied else 0.05
		leg_l.basis = Basis.from_euler(Vector3(2.0, 0, -spread))
		leg_r.basis = Basis.from_euler(Vector3(2.03 if tied else 2.06, 0, spread))
		knee_l.basis = Basis.from_euler(Vector3(-0.22, 0, 0))
		knee_r.basis = Basis.from_euler(Vector3(-0.2 if tied else -0.16, 0, 0))
		if tied:
			# wrists stay tied behind her back, forearms resting on the small of the back
			for side: float in [-1.0, 1.0]:
				var ua: Node3D = arm_r if side > 0.0 else arm_l
				var fa: Node3D = fore_r if side > 0.0 else fore_l
				_ik(ua, fa, UPPER_ARM, FOREARM, Vector3(0.03 * side, -0.16, 0.13), Vector3(side, 0.25, 0.55), false)
		else:
			# free arms hang towards the ground past her head
			arm_l.basis = Basis.from_euler(Vector3(2.35, 0, -0.18))
			arm_r.basis = Basis.from_euler(Vector3(2.45, 0, 0.14))
			fore_l.basis = Basis.from_euler(Vector3(0.15, 0, 0))
			fore_r.basis = Basis.from_euler(Vector3(0.1, 0, 0))
		foot_l.rotation = Vector3(0.5, 0, 0)
		foot_r.rotation = Vector3(0.45, 0, 0)
		# the tunic wraps the thighs instead of flaring out
		skirt.rotation = Vector3(2.03, 0, 0)
		skirt.scale = Vector3(0.82, 1.0, 0.62)
	else:
		_rest_pose()

func set_carried_pose(carrier: Node3D) -> void:
	is_carried = true
	carrier_node = carrier
	
	# Pitch the body forward to drape over the shoulder (approx 80 degrees)
	rotation.x = -PI / 2.2
	rotation.z = PI / 8.0 # Slight tilt so they don't look like a plank of wood
	
	# Bend the knees so the legs wrap around the carrier's chest
	if knee_l != null and knee_r != null:
		knee_l.rotation.x = 1.2
		knee_r.rotation.x = 1.2
		
	# Keep the tied hands behind the back, but let the head hang slightly
	if head != null:
		head.rotation.x = 0.2
		head.rotation.z = -0.1

func clear_carried_pose() -> void:
	is_carried = false
	carrier_node = null
	rotation.x = 0.0
	rotation.z = 0.0
	# restore everything the two carry systems touched, or the body is left
	# floating / sunken and hunched after being put down
	position.y = 0.0
	hips.position = Vector3(0, HIP_Y, 0)
	hips.rotation = Vector3.ZERO
	torso.rotation = Vector3.ZERO
	chest.rotation = Vector3.ZERO
	chest.scale = Vector3.ONE
	skirt.rotation = Vector3.ZERO
	skirt.scale = Vector3.ONE
	if knee_l != null: knee_l.rotation.x = 0.0
	if knee_r != null: knee_r.rotation.x = 0.0
	if head != null:
		head.rotation.x = 0.0
		head.rotation.z = 0.0
	_sig_off = Vector2.ZERO


func _rest_pose() -> void:
	skirt.scale = Vector3.ONE
	chest.scale = Vector3.ONE
	for n in [hips, skirt, torso, chest, head, leg_l, leg_r, knee_l, knee_r, foot_l, foot_r, arm_l, arm_r, fore_l, fore_r]:
		if n != null:
			(n as Node3D).rotation = Vector3.ZERO
	hips.position = Vector3(0, HIP_Y, 0)
	arm_l.rotation = Vector3(0, 0, -0.07)
	arm_r.rotation = Vector3(0, 0, 0.07)
	fore_l.rotation = Vector3(0.12, 0, 0)
	fore_r.rotation = Vector3(0.12, 0, 0)


# ============================================================================ over-the-shoulder carry (Phase 4)
## The carried body is the static fold above (pose_carried) plus a small physical simulation driven by
## the carrier (Hostage._do_carried calls carry_springs, places the root, then carry_pose):
##  * inertial weight - the hanging body is a damped pendulum about the hip joint on the shoulder: it
##    swings out from the carrier's back when he starts or speeds up, comes back against it (and bounces
##    off) when he stops, rolls to the outside of turns and with each footfall. Heavier bodies swing
##    slower; running lowers the damping, so the bounce gets heavier and looser. A soft-tissue contact
##    spring lets the hips lift off the shoulder at each running step and land again, which jolts the
##    torso and swings the shins.
##  * head tracking - a two-joint look-at (chest 25 %, neck / head 75 %, both within joint limits)
##    towards the nearest gunman, the camera or a scan of the surroundings, switching every 1-3.5 s. It
##    lags the carrier's momentum, rises and falls with the breath, lifts with each bounce and pitches
##    back (face towards the camera behind the carrier) the faster he runs.
##  * struggle (carry_struggle 0..1, set by Hostage) - kicks from the knees (both legs together while
##    the ankles are tied), hip pushes, torso twists and head shakes, with impulses into the pendulum.
##  * hand grip - carry_grip() gives the carrier's wrist position so the palm rests on the cloth at the
##    front of the thighs just above the knees; the carrier's arm reaches it with two-bone IK.
const CARRY_G := 13.0
var thigh_radius := 0.07
var carry_struggle := 0.0
var _cs_ang := Vector2.ZERO
var _cs_vel := Vector2.ZERO
var _cs_by := 0.0
var _cs_byv := 0.0
var _cs_ys := 0.0
var _cs_contact := true
var _cs_twist := 0.0
var _cs_twist_v := 0.0
var _cs_look := Vector2(-0.15, 0.0)
var _cs_look_v := Vector2.ZERO
var _cs_mode := 0
var _cs_mode_t := 1.0
var _cs_scan := Vector2.ZERO
var _cs_kick := 0.0
var _cs_arm := 0.0
var _cs_arm_v := 0.0
var _cs_shin := 0.0
var _cs_shin_v := 0.0
var _cs_afwd := 0.0


func _carry_reset() -> void:
	_cs_ang = Vector2.ZERO
	_cs_vel = Vector2.ZERO
	_cs_by = 0.0
	_cs_byv = 0.0
	_cs_ys = 0.0
	_cs_contact = true
	_cs_twist = 0.0
	_cs_twist_v = 0.0
	_cs_look = Vector2(-0.15, 0.0)
	_cs_look_v = Vector2.ZERO
	_cs_mode = 0
	_cs_mode_t = randf_range(0.6, 1.6)
	_cs_arm = 0.0
	_cs_arm_v = 0.0
	_cs_shin = 0.0
	_cs_shin_v = 0.0
	carry_struggle = 0.0


## One step of the carry springs. acc: the carrier's acceleration in his own frame (m/s2, -z forward);
## yaw_rate: his turn rate (rad/s); run_k 0 walk .. 1 run; phase: his step phase; cmv: gait amplitude;
## mass: her / his kg; active: false while being lifted or put down (the springs rest).
## Returns (pitch about his right axis, roll about his back axis, lift-off of the hips in metres).
func carry_springs(delta: float, acc: Vector3, yaw_rate: float, run_k: float, phase: float, cmv: float, mass_kg: float, active: bool) -> Vector3:
	var dt := clampf(delta, 0.001, 0.034)
	var mk := 60.0 / clampf(mass_kg, 40.0, 150.0)
	if not active:
		_cs_ang = _cs_ang.move_toward(Vector2.ZERO, dt * 1.5)
		_cs_vel = Vector2.ZERO
		_cs_by = 0.0
		_cs_byv = 0.0
		_cs_ys = 0.0
		_cs_contact = true
		return Vector3(_cs_ang.x, _cs_ang.y, 0.0)
	_cs_afwd = lerpf(_cs_afwd, -acc.z, clampf(dt * 12.0, 0.0, 1.0))
	# ---- vertical: the shoulder dips with each step; the hips rest on it through a soft contact spring
	# and leave it when it drops away faster than gravity (running) - then land again
	var ys := -absf(sin(phase)) * 0.022 * cmv
	var ysv := (ys - _cs_ys) / dt
	_cs_ys = ys
	var k := lerpf(950.0, 560.0, run_k) * mk
	var c := lerpf(42.0, 17.0, run_k) * sqrt(mk)
	_cs_byv -= CARRY_G * dt
	var pen := ys - _cs_by
	var touching := pen > 0.0
	if touching:
		if not _cs_contact:
			# landing back on the shoulder: the hanging torso swings out and the shins kick forward
			var impact := maxf(ysv - _cs_byv, 0.0)
			_cs_vel.x -= impact * 0.9
			_cs_shin_v += impact * 3.0
		_cs_byv += (k * pen - c * (_cs_byv - ysv)) * dt
	_cs_contact = touching
	_cs_by += _cs_byv * dt
	if _cs_by < ys - 0.03:
		_cs_by = ys - 0.03
		_cs_byv = ysv
	if _cs_by > ys + 0.07:
		_cs_by = ys + 0.07
		_cs_byv = minf(_cs_byv, ysv)
	# the static sag on the shoulder (gravity / stiffness) is part of the rest pose, not of the bounce
	var lift := _cs_by - ys + CARRY_G / k
	# ---- pendulum about the hip joint: pitch (x) and roll (y)
	var w := lerpf(6.4, 4.4, run_k) * sqrt(mk)
	var z := lerpf(0.55, 0.24, run_k)
	var tgt := Vector2(clampf(-_cs_afwd * 0.014, -0.26, 0.05), clampf(-acc.x * 0.016 + sin(phase) * 0.04 * cmv - yaw_rate * 0.02, -0.25, 0.25))
	_cs_kick += dt * (6.5 + 4.0 * carry_struggle)
	if carry_struggle > 0.01:
		# pushing and twisting against the carrier's grip
		_cs_vel += Vector2(sin(_cs_kick * 1.7) - 0.3, cos(_cs_kick * 1.1)) * carry_struggle * 2.6 * dt
	_cs_vel += (w * w * (tgt - _cs_ang) - 2.0 * z * w * _cs_vel) * dt
	_cs_ang += _cs_vel * dt
	# the carrier's back: she cannot swing into him - a soft bounce off it instead
	if _cs_ang.x > 0.06:
		_cs_ang.x = 0.06
		if _cs_vel.x > 0.0:
			_cs_vel.x *= -0.3
	_cs_ang.x = maxf(_cs_ang.x, -0.5)
	_cs_ang.y = clampf(_cs_ang.y, -0.38, 0.38)
	# the loose upper body twists against his turns
	var tw_t := clampf(-yaw_rate * 0.06, -0.3, 0.3)
	_cs_twist_v += (36.0 * (tw_t - _cs_twist) - 4.8 * _cs_twist_v) * dt
	_cs_twist += _cs_twist_v * dt
	# shins hang from the knees: a pendulum pushed by his starts / stops and by each landing
	_cs_shin_v += (60.0 * (clampf(_cs_afwd * 0.02, -0.3, 0.3) - _cs_shin) - lerpf(7.0, 3.5, run_k) * _cs_shin_v) * dt
	_cs_shin += _cs_shin_v * dt
	_cs_shin = clampf(_cs_shin, -0.5, 0.5)
	return Vector3(_cs_ang.x, _cs_ang.y, lift)


## Joints of the carried body for this frame (after the root has been placed).
## threat: the nearest gunman's eyes (or INF); viewer: the camera position (or INF).
func carry_pose(delta: float, threat: Vector3, viewer: Vector3, run_k: float, tied_now: bool) -> void:
	if not carried:
		return
	var dt := clampf(delta, 0.001, 0.05)
	var s := carry_struggle
	# ---- where to look: threat / camera / scan / rest, switching like real glances
	_cs_mode_t -= dt
	if _cs_mode_t <= 0.0:
		_cs_mode_t = randf_range(1.0, 3.5) * (0.6 if s > 0.3 else 1.0)
		var r := randf()
		if threat != Vector3.INF and r < 0.55:
			_cs_mode = 1
		elif viewer != Vector3.INF and r < 0.75:
			_cs_mode = 2
		elif r < 0.9:
			_cs_mode = 3
			_cs_scan = Vector2(randf_range(0.05, 0.6), randf_range(-0.9, 0.9))
		else:
			_cs_mode = 0
	var want := Vector2(-0.15, 0.0)
	var look_pt := Vector3.INF
	if _cs_mode == 1:
		look_pt = threat
	elif _cs_mode == 2:
		look_pt = viewer
	elif _cs_mode == 3:
		want = _cs_scan
	if look_pt != Vector3.INF:
		var la := _look_angles(look_pt)
		# a point behind her head cannot be seen from a hanging position: keep resting then (no flip)
		if absf(la.y) < 1.7:
			want = la
	# momentum, bounce and breath move the head; running pitches it back (the face comes round)
	want.x += 0.24 * run_k + sin(_breath_ph) * 0.035 + clampf(-_cs_vel.x * 0.12, -0.15, 0.2) + clampf(_cs_byv * 0.12, -0.08, 0.12)
	want.y += sin(_cs_kick * 1.3) * 0.35 * s
	want.x = clampf(want.x, -0.22, lerpf(0.5, 0.95, head_limit))
	want.y = clampf(want.y, -1.05 * head_limit, 1.05 * head_limit)
	# neck muscles: a quick, critically damped follow (never a snap)
	var wn := 9.0 + 5.0 * s
	_cs_look_v += (wn * wn * (want - _cs_look) - 2.0 * wn * _cs_look_v) * dt
	_cs_look += _cs_look_v * dt
	var chest_x := clampf(_cs_look.x * 0.25, -0.05, 0.22)
	var chest_lag := clampf(-_cs_vel.x * 0.05, -0.12, 0.12)
	var kick := sin(_cs_kick * 2.0)
	# ---- spine: the body drapes over the carrier's shoulder. Breathe and sway add
	# a small continuous motion so the pose never looks frozen while being carried.
	var drape := 0.05 * sin(_cs_kick * 0.5) + 0.03 * sin(_breath_ph)
	torso.rotation = Vector3(-0.08 + chest_lag * 0.4 + drape * 0.5, _cs_twist * 0.5 + sin(_cs_kick) * 0.12 * s, -_cs_ang.y * 0.25)
	chest.rotation = Vector3(-0.12 + chest_x + chest_lag - drape, _cs_look.y * 0.18 + _cs_twist * 0.4, sin(_cs_kick * 0.7) * 0.06 * s)
	head.rotation = Vector3(_cs_look.x - chest_x + drape * 0.4, _cs_look.y * 0.82, -_cs_ang.y * 0.4 + sin(_cs_kick * 1.3) * 0.05 * s)
	# ---- arms: tied wrists rest on the small of the back; free arms hang towards the ground and swing
	var sway := _cs_ang.x - (chest.rotation.x + 0.12)
	_cs_arm_v += (40.0 * (sway - _cs_arm) - lerpf(5.0, 2.6, run_k) * _cs_arm_v) * dt
	_cs_arm += _cs_arm_v * dt
	if tied_now:
		for side: float in [-1.0, 1.0]:
			var ua: Node3D = arm_r if side > 0.0 else arm_l
			var fa: Node3D = fore_r if side > 0.0 else fore_l
			var wt := Vector3(0.03 * side + sin(_cs_kick * 1.5) * 0.02 * s, -0.16 + _cs_arm * 0.03, 0.13 + absf(kick) * 0.03 * s)
			_ik(ua, fa, UPPER_ARM, FOREARM, wt, Vector3(side, 0.25, 0.55), false)
	else:
		arm_l.rotation = Vector3(2.35 + _cs_arm * 0.85 + kick * 0.15 * s, 0, -0.18 - _cs_ang.y * 0.5)
		arm_r.rotation = Vector3(2.45 + _cs_arm * 0.85 - kick * 0.15 * s, 0, 0.14 - _cs_ang.y * 0.5)
		fore_l.rotation = Vector3(0.15 + absf(_cs_arm) * 0.3 + maxf(kick, 0.0) * 0.4 * s, 0, 0)
		fore_r.rotation = Vector3(0.1 + absf(_cs_arm) * 0.3 + maxf(-kick, 0.0) * 0.4 * s, 0, 0)
	# ---- legs: thighs pinned by his arm (only a small push), shins swing and kick from the knees
	var kl := kick
	var kr := kick if tied_now else sin(_cs_kick * 2.0 + PI)
	var spread := 0.0 if tied_now else 0.05
	leg_l.rotation = Vector3(2.0 + maxf(kl, 0.0) * 0.1 * s, 0, -spread)
	leg_r.rotation = Vector3((2.03 if tied_now else 2.06) + maxf(kr, 0.0) * 0.1 * s, 0, spread)
	# knees bend (kick) but never over-straighten
	knee_l.rotation = Vector3(minf(-0.22 + _cs_shin - (0.5 + 0.5 * kl) * 0.6 * s, -0.03), 0, 0)
	knee_r.rotation = Vector3(minf((-0.2 if tied_now else -0.16) + _cs_shin * 0.9 - (0.5 + 0.5 * kr) * 0.6 * s, -0.03), 0, 0)
	foot_l.rotation = Vector3(0.5 + kl * 0.25 * s, 0, 0)
	foot_r.rotation = Vector3(0.45 + kr * 0.25 * s, 0, 0)


## Head angles (pitch, yaw) in the chest's frame that would point the face at a world point.
func _look_angles(p: Vector3) -> Vector2:
	var lp := chest.global_transform.affine_inverse() * p - head.position
	return Vector2(atan2(lp.y, Vector2(lp.x, lp.z).length()), atan2(-lp.x, -lp.z))


## World position for the carrier's wrist: the palm on the cloth over the front of her thighs just
## above the knees (thigh radius + fabric + half a hand out from the bone), towards the inner thigh,
## the hand pointing across the legs. fwd: the carrier's forward; inward: from his loaded shoulder
## towards his middle.
func carry_grip(fwd: Vector3, inward: Vector3) -> Vector3:
	var a := leg_l.global_transform * Vector3(0, -THIGH * 0.74, 0)
	var b := leg_r.global_transform * Vector3(0, -THIGH * 0.74, 0)
	var axis := (leg_l.global_transform.basis * Vector3.DOWN + leg_r.global_transform.basis * Vector3.DOWN).normalized()
	var n := fwd - axis * fwd.dot(axis)
	if n.length_squared() < 1e-6:
		n = fwd
	n = n.normalized()
	var across := inward - axis * inward.dot(axis)
	across = across - n * across.dot(n)
	if across.length_squared() < 1e-6:
		across = inward
	across = across.normalized()
	var mid := (a + b) * 0.5
	var half := absf((b - a).dot(across)) * 0.5
	var r := thigh_radius * scale.x
	var palm := mid + n * (r * 0.92 + 0.026) + across * (half * 0.6)
	return palm - across * 0.075 - n * 0.006


## The carrier's arm on the loaded side (sd +1 right, -1 left) to the carried body's grip point.
func _grip_arm(sd: float, gl, par: Node) -> void:
	var ua: Node3D = arm_r if sd > 0.0 else arm_l
	var fa: Node3D = fore_r if sd > 0.0 else fore_l
	var tgt := Vector3(0.07 * sd, 0.12, -0.25)
	if gl is Vector3 and par is Node3D:
		var g3: Vector3 = gl
		if g3 != Vector3.INF:
			var wpt: Vector3 = (par as Node3D).global_transform * g3
			var lt: Vector3 = ua.get_parent().to_local(wpt)
			if (lt - ua.position).length() < (UPPER_ARM + FOREARM) * 1.15:
				tgt = lt
	_ik(ua, fa, UPPER_ARM, FOREARM, tgt, Vector3(sd * 0.9, -0.3, -0.55), false)


# ============================================================================ IK
## Orients a limb pivot so its -Y axis points along `dir` (parent space); z_hint fixes the twist.
static func _limb_basis(dir: Vector3, z_hint: Vector3) -> Basis:
	var y := -dir.normalized()
	var z := z_hint - y * z_hint.dot(y)
	if z.length_squared() < 1e-6:
		z = Vector3.BACK - y * y.z
		if z.length_squared() < 1e-6:
			z = Vector3.RIGHT
	z = z.normalized()
	var x := y.cross(z).normalized()
	z = x.cross(y)
	return Basis(x, y, z)


## Two-bone IK. target and pole are in the parent space of `upper`. Elbows / knees bend towards pole.
## knee=true keeps the leg mesh facing forward (knee cap front, calf back).
func _ik(upper: Node3D, lower: Node3D, la: float, lb: float, target: Vector3, pole: Vector3, knee: bool) -> void:
	var s := upper.position
	var to := target - s
	var d := clampf(to.length(), 0.03, la + lb - 0.002)
	var dir := to.normalized() if to.length_squared() > 1e-8 else Vector3.DOWN
	var cos_a := clampf((la * la + d * d - lb * lb) / (2.0 * la * d), -1.0, 1.0)
	var sin_a := sqrt(maxf(1.0 - cos_a * cos_a, 0.0))
	var perp := pole - dir * pole.dot(dir)
	if perp.length_squared() < 1e-6:
		perp = Vector3.FORWARD - dir * dir.z
	perp = perp.normalized()
	var elbow := s + (dir * cos_a + perp * sin_a) * la
	var wrist := s + dir * d
	var zh := -perp if knee else perp
	upper.basis = _limb_basis(elbow - s, zh)
	var inv := upper.basis.inverse()
	lower.basis = _limb_basis(inv * (wrist - elbow), inv * zh)


# ============================================================================ animation
static func _thigh_pitch(leg: Node3D) -> float:
	var d := leg.basis * Vector3.DOWN
	return atan2(-d.z, -d.y)


func set_expression(fear: float, anger: float, relief: float, struggle: float) -> void:
	_expr_goal = Vector4(clampf(fear, 0.0, 1.0), clampf(anger, 0.0, 1.0), clampf(relief, 0.0, 1.0), clampf(struggle, 0.0, 1.0))


func head_signal(yes: bool) -> void:
	_sig_yes = yes
	_sig_t = 1.3


## Adds this frame's nod / shake to the head. absolute: the caller set the head rotation outright this
## frame (carry pose); otherwise last frame's offset is taken out first so it never adds up.
func head_signal_tick(delta: float, absolute: bool) -> void:
	if head == null or (_sig_t <= 0.0 and _sig_off == Vector2.ZERO):
		return
	if not absolute:
		head.rotation.x -= _sig_off.x
		head.rotation.y -= _sig_off.y
	_sig_t = maxf(_sig_t - delta, 0.0)
	var k := 1.0 - _sig_t / 1.3
	var env := sin(k * PI)
	var w := sin(k * TAU * 3.0)
	var lim := clampf(head_limit, 0.3, 1.0)
	var off := Vector2(w * 0.22 * env * lim, 0.0) if _sig_yes else Vector2(0.0, w * 0.34 * env * lim)
	if _sig_t <= 0.0:
		off = Vector2.ZERO
	head.rotation.x += off.x
	head.rotation.y += off.y
	_sig_off = off


## Blinks, eye saccades and breathing; also runs while carried (not when dead).
func _face_life(delta: float) -> void:
	_breath_ph += delta * breath_rate
	var br := sin(_breath_ph)
	if head_mat == null:
		return
	_blink_t -= delta
	if _blink_t <= 0.0:
		_blink = 1.0
		_blink_t = randf_range(2.0, 6.0) if randf() > 0.15 else 0.25
	else:
		_blink = move_toward(_blink, 0.0, delta * 7.0)
	var b := clampf(_blink * 1.6 - 0.3, 0.0, 1.0)
	# expressions: eased, sent to the shader only when they change; anger and struggle narrow the eyes
	# (Vector4 has no move_toward() in Godot 4.3: the same step, written out)
	var de := _expr_goal - _expr
	var step := delta * 2.2
	var dl := de.length()
	_expr = _expr_goal if dl <= step else _expr + de * (step / dl)
	if _expr.distance_squared_to(_expr_sent) > 0.0004:
		_expr_sent = _expr
		head_mat.set_shader_parameter("expr", Vector4(_expr.x, _expr.y, _expr.z, _expr.w))
	b = maxf(b, 0.16 * _expr.y + 0.24 * _expr.w + 0.1 * _expr.z)
	_saccade_t -= delta
	if _saccade_t <= 0.0:
		_saccade_t = randf_range(0.6, 2.4)
		_gaze_goal = Vector2(randf_range(-0.0022, 0.0022), randf_range(-0.0012, 0.001))
		if look_at_target != null and is_instance_valid(look_at_target) and randf() < 0.7:
			var lp := head.global_transform.affine_inverse() * (look_at_target.global_position + Vector3(0, 1.5, 0))
			_gaze_goal = Vector2(clampf(-lp.x * 0.01, -0.0026, 0.0026), clampf(lp.y * 0.004, -0.0014, 0.0012))
	_gaze = _gaze.move_toward(_gaze_goal, delta * 0.06)
	if carried:
		_gaze.y = 0.0012
	head_mat.set_shader_parameter("blink", 1.0 if _dead else b)
	if tape_mark > 0.0:
		tape_mark = maxf(tape_mark - delta / 30.0, 0.0)
		head_mat.set_shader_parameter("tape_mark", tape_mark)
	head_mat.set_shader_parameter("gaze", _gaze)
	head_mat.set_shader_parameter("nostril", clampf(br * 0.5 + 0.5, 0.0, 1.0) * clampf((breath_rate - 1.0) * 0.6, 0.15, 1.0))

	if is_carried:
		_t += delta * 12.0
		# Bounce the body up and down as the carrier walks
		position.y = sin(_t) * 0.04 
		# Make the legs swing slightly
		if knee_l != null: knee_l.rotation.x = 1.2 + sin(_t) * 0.1
		if knee_r != null: knee_r.rotation.x = 1.2 - sin(_t) * 0.1
		
		# If the character is struggling or gagged, animate the head slightly
		if head != null:
			head.rotation.z = -0.1 + sin(_t * 0.5) * 0.05
		return # Skip the normal walking animation
	# --- DYNAMIC NOSTRIL BREATHING --- (phase already advanced at the top of this function)
	var base_breath = (br + 1.0) * 0.5 # 0.0 to 1.0
	
	# If the character is in pain, they breathe faster and nostrils flare wider
	if is_in_pain:
		base_breath = clampf(base_breath * 1.8, 0.0, 1.0)
		# Make the body twitch in pain
		if chest != null: chest.rotation.x = sin(_t * 20.0) * 0.05
		if head != null: head.rotation.x = -0.2 + sin(_t * 15.0) * 0.05
		
	nostril_flare = lerpf(nostril_flare, base_breath, delta * 15.0)
	
	if head_mat != null:
		head_mat.set_shader_parameter("nostril_flare", nostril_flare)
func animate(delta: float, speed: float, crouching: bool, aiming: bool) -> void:
	if _dead:
		# keep the face alive after death: the closed eye, expression and tape mark
		# still need their shader uniforms updated even though the body is still.
		_face_life(delta)
		return
	if carried:
		_face_life(delta)
		return
	if pose == "bed_x":
		_pose_bed_x(delta)
		_face_life(delta)
		return
	# Face life (blinks, breathing, expression) runs EVERY frame.  Only the body
	# pose is throttled at distance, so distant characters never freeze mid-blink
	# and then jump when their LOD bucket comes up.
	_face_life(delta)
	var cam := get_viewport().get_camera_3d()
	if cam != null:
		var dd := cam.global_position.distance_squared_to(global_position)
		var every := 1 if dd < 1225.0 else (3 if dd < 6400.0 else 6)
		_lod_acc += delta
		_lod_skip += 1
		if _lod_skip < every:
			return
		_lod_skip = 0
		delta = _lod_acc
		_lod_acc = 0.0
	_t += delta
	# reach curve: hands travel out (~0.35 s), stay while the job lasts, travel back (~0.3 s)
	if reach_target != Vector3.INF:
		_reach_last = reach_target
	_reach_k = move_toward(_reach_k, 1.0 if reach_target != Vector3.INF else 0.0, delta * (2.9 if reach_target != Vector3.INF else 3.4))
	crouch_amount = move_toward(crouch_amount, 1.0 if (crouching or kneel) else 0.0, delta * 5.0)
	aim_amount = move_toward(aim_amount, 1.0 if aiming else 0.0, delta * 6.0)
	var v := clampf(speed, 0.0, 7.0)
	var mv := clampf(v / 1.2, 0.0, 1.0)
	var amp := clampf(0.12 + 0.1 * v, 0.0, 0.42) * mv
	if v > 0.05:
		_phase += delta * PI * v / (2.0 * maxf(amp, 0.12))
	var carrying_someone := false
	var par := get_parent()
	var load_side := 1.0
	var squat_goal := 0.0
	var load := 0.0
	if par != null and par.get("carrying") != null:
		carrying_someone = true
		var cn = par.get("carrying")
		if cn is Node and is_instance_valid(cn):
			if cn.has_method("lift_squat"):
				squat_goal = cn.lift_squat()
			load_side = float(cn.get("carry_side")) if cn.get("carry_side") != null else 1.0
		if par.has_method("carry_load"):
			load = par.carry_load()
	# lifting / lowering technique: squat with a straight back and drive up through the legs
	if squat_goal > _squat:
		_squat = lerpf(_squat, squat_goal, clampf(delta * 14.0, 0.0, 1.0))
	else:
		_squat = move_toward(_squat, squat_goal, delta * 1.9)
	if carrying_someone:
		# under a load: shorter, flatter steps
		amp *= lerpf(0.82, 0.6, clampf(load, 0.0, 1.4) / 1.4)

	# ---- legs + hips
	var h: float
	if kneel:
		h = lerpf(HIP_Y - 0.05 * mv, 0.5, crouch_amount)
	else:
		h = lerpf(HIP_Y - 0.05 * mv, 0.64, crouch_amount) - absf(sin(_phase)) * 0.03 * mv
	h += sin(_t * 1.6) * 0.004
	if pose == "sit" or pose == "seat_carried":
		h = 0.5
	if _squat > 0.001:
		h = lerpf(h, SQUAT_HIP, _squat)
	hips.position = Vector3(0, h, 0)
	hips.rotation = Vector3(0, sin(_phase) * 0.08 * mv, 0)
	for side: float in [-1.0, 1.0]:
		var leg: Node3D = leg_r if side > 0.0 else leg_l
		var kn: Node3D = knee_r if side > 0.0 else knee_l
		var ph := _phase + (PI if side > 0.0 else 0.0)
		var target: Vector3
		var pole := Vector3(0, -0.3, -1)
		if pose == "sit":
			# seated on a chair: thighs level, shins down, feet flat a little apart
			target = Vector3(0.13 * side, ANKLE_Y, -0.43)
			pole = Vector3(0, 0.6, -1)
		elif pose == "seat_carried":
			# sitting on the carriers' joined hands: thighs level, shins hanging and swinging a little
			target = Vector3(0.15 * side, 0.12 + sin(_t * 2.2 + side) * 0.02, -0.36)
			pole = Vector3(0, 0.6, -1)
		elif kneel and crouch_amount > 0.5:
			target = Vector3(0.1 * side, ANKLE_Y, 0.37)
			pole = Vector3(0, -1, -1)
		elif _squat > 0.05:
			# lifting stance: feet shoulder-width apart, one a little ahead of the other
			target = Vector3(0.17 * side, ANKLE_Y, 0.06 if side < 0.0 else -0.12)
			pole = Vector3(0.35 * side, -0.2, -1)
		elif crouch_amount > 0.01:
			var stag := 0.1 if side < 0.0 else -0.16
			target = Vector3(0.13 * side, ANKLE_Y, lerpf(-amp * sin(ph), stag, crouch_amount))
		else:
			var lift := maxf(cos(ph), 0.0) * (0.05 + 0.025 * v) * mv
			target = Vector3(0.1 * side, ANKLE_Y + lift, -amp * sin(ph))
		var hb := hips.basis.inverse()
		_ik(leg, kn, THIGH, SHIN, hb * (target - hips.position), hb * pole, true)
	var kneeling := kneel and crouch_amount > 0.5
	foot_l.rotation = Vector3(-1.35 if kneeling else 0.0, 0, 0)
	foot_r.rotation = Vector3(-1.35 if kneeling else 0.0, 0, 0)
	skirt.rotation = Vector3(clampf((_thigh_pitch(leg_l) + _thigh_pitch(leg_r)) * 0.5, -0.25, 1.6) * 0.85, 0, 0)

	# ---- spine + head
	torso.rotation = Vector3(-0.05 * mv - crouch_amount * (0.05 if kneel else 0.22), -sin(_phase) * 0.05 * mv, 0)
	chest.rotation = Vector3(sin(_breath_ph) * (0.012 + 0.006 * clampf(breath_rate - 1.6, 0.0, 2.0)) - 0.04 * mv, -sin(_phase) * 0.06 * mv, 0)
	chest.scale = Vector3(1.0 + sin(_breath_ph) * 0.008, 1.0, 1.0 + sin(_breath_ph) * 0.012)
	var head_x := 0.04 * mv
	if aiming:
		head_x = -0.08
	if unconscious:
		head_x = 0.55
	match pose:
		"drink":
			head_x = 0.32
		"talk":
			head_x = sin(_t * 3.1) * 0.06 - 0.05
	head.rotation.x = lerpf(head.rotation.x, head_x, clampf(delta * 6.0, 0.0, 1.0))
	head.rotation.z = 0.0
	var look := head_target
	if look == Vector3.INF and _reach_k > 0.05 and _reach_last != Vector3.INF:
		look = _reach_last
	if look != Vector3.INF and head.get_parent() is Node3D:
		# eyes on the job: turn and tilt the head towards the point (within a natural range)
		var lp: Vector3 = (head.get_parent() as Node3D).to_local(look) - head.position
		var yaw := clampf(atan2(-lp.x, -lp.z), -1.2, 1.2)
		var pitch := clampf(atan2(lp.y, Vector2(lp.x, lp.z).length()), -0.9, 0.6)
		var hk := clampf(delta * 8.0, 0.0, 1.0)
		head.rotation.y = lerpf(head.rotation.y, yaw, hk)
		head.rotation.x = lerpf(head.rotation.x, pitch, hk)
		look_at_target = null

	# ---- arms
	if pose == "seat_carried" and hand_targets.size() == 2:
		# arms around the two carriers' shoulders
		for side: float in [-1.0, 1.0]:
			var uas: Node3D = arm_r if side > 0.0 else arm_l
			var fas: Node3D = fore_r if side > 0.0 else fore_l
			var ht2: Vector3 = hand_targets[1] if side > 0.0 else hand_targets[0]
			_ik(uas, fas, UPPER_ARM, FOREARM, uas.get_parent().to_local(ht2), Vector3(side * 0.6, -1.0, 0.4), false)
		return
	if reach_side != 0.0 and _reach_k > 0.01 and _reach_last != Vector3.INF:
		# one arm under the carried person's thighs, the other hand on her back
		var kk1 := _reach_k * _reach_k * (3.0 - 2.0 * _reach_k)
		for side: float in [-1.0, 1.0]:
			var ua6: Node3D = arm_r if side > 0.0 else arm_l
			var fa6: Node3D = fore_r if side > 0.0 else fore_l
			var rest6 := Vector3(0.14 * side, -0.3, -0.16)
			var goal: Vector3 = _reach_last if signf(side) == signf(reach_side) else reach_target2
			if goal == Vector3.INF:
				_ik(ua6, fa6, UPPER_ARM, FOREARM, Vector3(0.16 * side, -0.5, 0.02), Vector3(side, 0, 1), false)
				continue
			_ik(ua6, fa6, UPPER_ARM, FOREARM, rest6.lerp(ua6.get_parent().to_local(goal), kk1), Vector3(side, -0.8, 0.3), false)
		if gun != null:
			gun.position = Vector3(-0.13 * reach_side, 0.02, 0.17)
			gun.rotation = Vector3(-PI * 0.5 + 0.15, 0, 0.25 * reach_side)
		return
	if _reach_k > 0.01 and _reach_last != Vector3.INF:
		# both hands out to the mouth / wrists along an eased curve; small working motions at the end
		var kk := _reach_k * _reach_k * (3.0 - 2.0 * _reach_k)
		for side: float in [-1.0, 1.0]:
			var ua4: Node3D = arm_r if side > 0.0 else arm_l
			var fa4: Node3D = fore_r if side > 0.0 else fore_l
			var gt := _reach_last + global_transform.basis.x * (0.045 * side) + Vector3(0, sin(_t * 11.0 + side) * 0.012 * kk, 0)
			var rest := Vector3(0.14 * side, -0.3, -0.16)
			_ik(ua4, fa4, UPPER_ARM, FOREARM, rest.lerp(ua4.get_parent().to_local(gt), kk), Vector3(side, -0.6, 0.2), false)
		if gun != null:
			gun.position = Vector3(-0.13, 0.02, 0.17)
			gun.rotation = Vector3(-PI * 0.5 + 0.15, 0, 0.25)
		return
	if pose == "hands_head":
		# police surrender: kneeling, fingers laced behind the head, elbows out
		for side: float in [-1.0, 1.0]:
			var ua5: Node3D = arm_r if side > 0.0 else arm_l
			var fa5: Node3D = fore_r if side > 0.0 else fore_l
			var ht := head.global_transform * (HEAD_C + Vector3(0.03 * side, 0.05, 0.075))
			_ik(ua5, fa5, UPPER_ARM, FOREARM, ua5.get_parent().to_local(ht), Vector3(side * 1.0, 0.1, -0.35), false)
		return
	if unconscious:
		# chloroformed / fainted: arms hang loose, no muscle tone
		arm_l.rotation = Vector3(0.1, 0, -0.12)
		arm_r.rotation = Vector3(0.12, 0, 0.1)
		fore_l.rotation = Vector3(0.25, 0, 0)
		fore_r.rotation = Vector3(0.22, 0, 0)
		return
	if tied:
		for side: float in [-1.0, 1.0]:
			var ua: Node3D = arm_r if side > 0.0 else arm_l
			var fa: Node3D = fore_r if side > 0.0 else fore_l
			_ik(ua, fa, UPPER_ARM, FOREARM, Vector3(0.04 * side, -0.22, 0.14), Vector3(side * 0.45, -0.3, 1.0), false)
		return
	if hands_up:
		arm_l.rotation = Vector3(0.25, 0, -2.6)
		arm_r.rotation = Vector3(0.25, 0, 2.6)
		fore_l.rotation = Vector3(0.35, 0, 0)
		fore_r.rotation = Vector3(0.35, 0, 0)
		return
	if pose == "drink":
		_ik(arm_r, fore_r, UPPER_ARM, FOREARM, Vector3(0.035, 0.42, -0.2), Vector3(1, -1, 0.2), false)
		_ik(arm_l, fore_l, UPPER_ARM, FOREARM, Vector3(-0.13, -0.27, -0.2), Vector3(-1, 0, 1), false)
		return
	if pose == "sit":
		# hands resting on the thighs
		for side: float in [-1.0, 1.0]:
			var ua3: Node3D = arm_r if side > 0.0 else arm_l
			var fa3: Node3D = fore_r if side > 0.0 else fore_l
			_ik(ua3, fa3, UPPER_ARM, FOREARM, Vector3(0.14 * side, -0.4, -0.3), Vector3(side, 0, 1), false)
		return
	if pose == "talk":
		var g := sin(_t * 2.3)
		_ik(arm_l, fore_l, UPPER_ARM, FOREARM, Vector3(-0.12, 0.02 + g * 0.05, -0.27), Vector3(-1, -1, 0.3), false)
		_ik(arm_r, fore_r, UPPER_ARM, FOREARM, Vector3(0.13, -0.27, -0.2), Vector3(1, 0, 1), false)
		return
	if kneel and crouch_amount > 0.5:
		for side: float in [-1.0, 1.0]:
			var ua2: Node3D = arm_r if side > 0.0 else arm_l
			var fa2: Node3D = fore_r if side > 0.0 else fore_l
			_ik(ua2, fa2, UPPER_ARM, FOREARM, Vector3(0.13 * side, -0.27, -0.2), Vector3(side, 0, 1), false)
		return
	if carrying_someone:
		# fireman's carry: the arm on each loaded shoulder locks over the front of the thighs just
		# above the knees, pinning the legs to the chest. Phase 4: the hand goes to the grip point the
		# carried body reports every frame (on the cloth: thigh radius + fabric + hand), so it rides the
		# bounce and the kicks instead of floating or sinking in; a free arm swings with the step.
		var loads: Array = []
		var lst = par.get("carried")
		if lst is Array and not (lst as Array).is_empty():
			loads = lst
		else:
			loads = [par.get("carrying")]
		var used_r := false
		var used_l := false
		for cn in loads:
			if not is_instance_valid(cn) or not (cn is Node):
				continue
			var sd := 1.0
			if cn.get("carry_side") != null and float(cn.get("carry_side")) < 0.0:
				sd = -1.0
			if sd > 0.0:
				used_r = true
			else:
				used_l = true
			_grip_arm(sd, cn.get("grip_local"), par)
		var sw := sin(_phase) * 0.45 * mv
		if not used_l:
			arm_l.rotation = Vector3(sw, 0, -0.08)
			fore_l.rotation = Vector3(0.2 + maxf(sw, 0.0) * 0.4, 0, 0)
		if not used_r:
			arm_r.rotation = Vector3(-sw, 0, 0.08)
			fore_r.rotation = Vector3(0.2 + maxf(-sw, 0.0) * 0.4, 0, 0)
		# lean the trunk slightly forward and away from the loaded shoulder to keep the combined centre
		# of mass over the feet; a deeper hip hinge while squatting, back kept straight
		torso.rotation.x -= 0.06 + 0.07 * clampf(load, 0.0, 1.5) + 0.28 * _squat
		torso.rotation.z = -0.045 * load_side * clampf(load, 0.3, 1.2)
		chest.rotation.x += 0.1 * _squat
		if gun != null:
			# rifle slung muzzle-down across the back, on the side away from the load
			gun.position = Vector3(-0.13 * load_side, 0.02, 0.17)
			gun.rotation = Vector3(-PI * 0.5 + 0.15, 0, 0.25 * load_side)
		return
	if gun != null:
		# low ready <-> shouldered; both hands IK'd onto the rifle
		var low_p := Vector3(0.1, 0.13 - crouch_amount * 0.02, -0.15)
		var low_r := Vector3(-0.55, 0.38, 0.12)
		var aim_p := Vector3(0.1, 0.27, -0.06)
		var aim_r := Vector3(0.0, 0.0, 0.0)
		var bob := Vector3(0, sin(_phase * 2.0) * 0.01 * mv, 0)
		gun.position = low_p.lerp(aim_p, aim_amount) + bob
		gun.rotation = low_r.lerp(aim_r, aim_amount)
		var grip := gun.transform * Vector3(0, -0.075, -0.25)
		var fore := gun.transform * Vector3(0, -0.03, -0.52)
		_ik(arm_r, fore_r, UPPER_ARM, FOREARM, grip + Vector3(0, -0.02, 0.04), Vector3(1, -1, 0.6), false)
		_ik(arm_l, fore_l, UPPER_ARM, FOREARM, fore + Vector3(0, -0.03, 0.03), Vector3(-1, -1, 0.1), false)
		return
	var swing := sin(_phase) * 0.45 * mv
	arm_l.rotation = Vector3(swing - crouch_amount * 0.3, 0, -0.08)
	arm_r.rotation = Vector3(-swing - crouch_amount * 0.3, 0, 0.08)
	fore_l.rotation = Vector3(0.15 + maxf(swing, 0.0) * 0.5 + crouch_amount * 0.4, 0, 0)
	fore_r.rotation = Vector3(0.15 + maxf(-swing, 0.0) * 0.5 + crouch_amount * 0.4, 0, 0)


func die(from_dir: Vector3) -> void:
	if _dead:
		return
	_dead = true
	pose = ""
	var local_dir := global_transform.basis.inverse() * from_dir
	var fall_x := PI * 0.5 if local_dir.z > 0.0 else -PI * 0.5
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "rotation:x", fall_x, 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(self, "position:y", position.y + 0.12, 0.6)
	tw.tween_property(hips, "position:y", HIP_Y, 0.4)
	tw.tween_property(arm_l, "rotation", Vector3(2.4, 0, -0.5), 0.5)
	tw.tween_property(arm_r, "rotation", Vector3(2.2, 0, 0.6), 0.5)
	tw.tween_property(fore_l, "rotation", Vector3(0.3, 0, 0), 0.5)
	tw.tween_property(fore_r, "rotation", Vector3(0.5, 0, 0), 0.5)
	tw.tween_property(leg_l, "rotation", Vector3(0.25, 0, -0.1), 0.5)
	tw.tween_property(leg_r, "rotation", Vector3(-0.1, 0, 0.12), 0.5)
	tw.tween_property(knee_l, "rotation", Vector3(-0.4, 0, 0), 0.5)
	tw.tween_property(knee_r, "rotation", Vector3(-0.15, 0, 0), 0.5)
	tw.tween_property(head, "rotation", Vector3(0.3, 0.4, 0), 0.5)


## A dressing / blood stain on the left shin (injured hostage); false removes it.
var _wound: MeshInstance3D = null

func set_wound(on: bool, bandaged: bool = false) -> void:
	if _wound == null and on:
		_wound = MeshInstance3D.new()
		var bm := CylinderMesh.new()
		bm.top_radius = 0.062
		bm.bottom_radius = 0.058
		bm.height = 0.12
		bm.radial_segments = 14
		_wound.mesh = bm
		knee_l.add_child(_wound)
		_wound.position = Vector3(0, -SHIN * 0.42, 0)
		_wound.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if _wound != null:
		_wound.visible = on
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.93, 0.92, 0.88) if bandaged else Color(0.42, 0.06, 0.05)
		m.roughness = 0.85 if bandaged else 0.45
		_wound.material_override = m
