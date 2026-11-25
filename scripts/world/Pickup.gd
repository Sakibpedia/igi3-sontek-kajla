extends Area3D
## Ammo kit / medkit / dropped Type-56 rifle. Area3D picked up by walking over it.
## Phase 4: "cash" - the gang's hidden stash a hostage told about (points on the mission score).

const CharacterModel := preload("res://scripts/actors/CharacterModel.gd")

var kind := "ammo"
var _t := 0.0
var _visual: Node3D
var _life := 120.0


func setup(p_kind: String) -> void:
	kind = p_kind


func _ready() -> void:
	add_to_group("pickups")
	collision_layer = Game.L_PICKUP
	collision_mask = Game.L_PLAYER
	monitoring = true
	var cs := CollisionShape3D.new()
	var sh := SphereShape3D.new()
	sh.radius = 0.9
	cs.shape = sh
	cs.position = Vector3(0, 0.4, 0)
	add_child(cs)
	_visual = Node3D.new()
	add_child(_visual)
	match kind:
		"ammo":
			_box(Vector3(0.5, 0.28, 0.32), Vector3(0, 0.14, 0), Color(0.28, 0.33, 0.18))
			_box(Vector3(0.52, 0.05, 0.1), Vector3(0, 0.29, 0), Color(0.75, 0.6, 0.15))
		"medkit":
			_box(Vector3(0.42, 0.24, 0.3), Vector3(0, 0.12, 0), Color(0.92, 0.92, 0.9))
			_box(Vector3(0.24, 0.02, 0.07), Vector3(0, 0.25, 0), Color(0.8, 0.05, 0.05))
			_box(Vector3(0.07, 0.02, 0.24), Vector3(0, 0.25, 0), Color(0.8, 0.05, 0.05))
		"key":
			_box(Vector3(0.05, 0.02, 0.2), Vector3(0, 0.1, 0), Color(0.85, 0.7, 0.25))
			_box(Vector3(0.12, 0.02, 0.12), Vector3(0, 0.1, -0.12), Color(0.85, 0.7, 0.25))
		"radio":
			_box(Vector3(0.09, 0.22, 0.05), Vector3(0, 0.13, 0), Color(0.1, 0.1, 0.1))
			_box(Vector3(0.015, 0.14, 0.015), Vector3(0.03, 0.3, 0), Color(0.1, 0.1, 0.1))
		"cash":
			_box(Vector3(0.3, 0.12, 0.2), Vector3(0, 0.07, 0), Color(0.36, 0.5, 0.3))
			_box(Vector3(0.06, 0.13, 0.21), Vector3(0, 0.07, 0), Color(0.85, 0.75, 0.4))
		"first_aid":
			_box(Vector3(0.3, 0.18, 0.12), Vector3(0, 0.1, 0), Color(0.85, 0.12, 0.1))
			_box(Vector3(0.14, 0.02, 0.04), Vector3(0, 0.1, -0.065), Color(0.95, 0.95, 0.95))
			_box(Vector3(0.04, 0.12, 0.02), Vector3(0, 0.1, -0.065), Color(0.95, 0.95, 0.95))
		"type56":
			_box(Vector3(0.08, 0.1, 0.9), Vector3(0, 0.06, 0), Color(0.08, 0.08, 0.08))
			_box(Vector3(0.09, 0.1, 0.3), Vector3(0, 0.06, 0.4), Color(0.35, 0.2, 0.08))
			_life = 90.0
		"sniper":
			_box(Vector3(0.07, 0.08, 1.15), Vector3(0, 0.06, 0), Color(0.08, 0.08, 0.08))
			_box(Vector3(0.05, 0.05, 0.36), Vector3(0, 0.14, -0.05), Color(0.05, 0.05, 0.05))
			_box(Vector3(0.09, 0.1, 0.3), Vector3(0, 0.05, 0.42), Color(0.22, 0.25, 0.16))
			_life = 120.0
	body_entered.connect(_on_body)


func _box(size: Vector3, pos: Vector3, color: Color) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = CharacterModel.mat(color, 0.6)
	mi.position = pos
	mi.layers = 2
	_visual.add_child(mi)


func _process(delta: float) -> void:
	_t += delta
	_visual.rotation.y += delta * 1.2
	_visual.position.y = 0.05 + sin(_t * 2.5) * 0.05
	_life -= delta
	if _life <= 0.0 and kind != "medkit" and kind != "key" and kind != "radio" and kind != "first_aid" and kind != "cash":
		queue_free()


func _on_body(body: Node) -> void:
	if not body.is_in_group("player"):
		return
	var w = body.get("weapon")
	match kind:
		"ammo":
			if w == null:
				return
			w.add_ammo("rifle", 60)
			w.add_ammo("pistol", 16)
			AudioManager.say("", "গুলির বাক্স: +৬০ রাইফেল, +১৬ পিস্তল", 2.0)
		"key":
			body.set("keys", int(body.get("keys")) + 1)
			AudioManager.say("", "খাঁচার চাবি পাওয়া গেছে — খাঁচার কাছে E চাপলে নিঃশব্দে খুলবে।", 2.6)
		"radio":
			body.set("radios", int(body.get("radios")) + 1)
			AudioManager.say("", "ওদের একটা ওয়াকি-টকি পেলেন — সংকেত-শব্দ জানা থাকলে O চেপে ভুয়া আদেশ দেওয়া যাবে।", 3.0)
		"cash":
			Game.add_score(int(Game.SCORE["stash"]), "চক্রের লুকানো মাল উদ্ধার")
			AudioManager.play_2d("sfx_coin", -4.0)
			if Game.level != null and Game.level.get("utils") != null:
				Game.level.utils.set("stash_pos", Vector3.INF)
		"first_aid":
			body.set("first_aid", int(body.get("first_aid")) + 1)
			AudioManager.say("", "প্রাথমিক চিকিৎসার বাক্স (+১) — নিজের স্বাস্থ্য ফিরে পেতে Y।", 2.4)
		"medkit":
			if float(body.get("health")) >= float(body.get("max_health")) - 1.0:
				return
			body.heal(50.0)
			AudioManager.say("", "মেডিকিট: +৫০ স্বাস্থ্য", 2.0)
		"type56":
			if w == null:
				return
			if w.slots.has("type56"):
				w.add_ammo("rifle", 30)
			else:
				w.give_weapon("type56", 30)
				AudioManager.say("", "টাইপ-৫৬ রাইফেল সংগ্রহ করা হয়েছে (৩ চাপুন)", 2.5)
		"sniper":
			if w == null:
				return
			if w.slots.has("sniper"):
				w.add_ammo("rifle", 10)
			else:
				w.give_weapon("sniper", 10)
				AudioManager.say("", "স্নাইপার রাইফেল সংগ্রহ করা হয়েছে — ডান ক্লিকে স্কোপ", 2.5)
	AudioManager.play_2d("sfx_pickup", -4.0)
	queue_free()
