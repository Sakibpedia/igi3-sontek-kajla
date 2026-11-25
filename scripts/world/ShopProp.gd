extends Node3D
## Colony ground-floor shop / pharmacy. IGI-style storefront that cannot be
## attacked by either side. Press E to trade: buy guns and ammunition, sell the
## loot taken from fallen enemies, or buy medicine and permanent health upgrades.

const HUD := preload("res://scripts/ui/HUD.gd")
const UIStyle := preload("res://scripts/ui/UIStyle.gd")

var kind := "shop"       # "shop" or "pharmacy"
var shop_type := "general"
var shop_name := ""
var panel: Control = null
var saved_input := true


static func make(p_kind: String, pos: Vector3, yaw: float, p_name: String) -> Node3D:
	var n := Node3D.new()
	n.set_script(preload("res://scripts/world/ShopProp.gd"))
	n.kind = p_kind
	n.shop_name = p_name
	n.shop_type = p_kind
	n.position = pos
	n.rotation.y = yaw
	return n


func _ready() -> void:
	add_to_group("interactables")
	# A safe shopfront: no "actors" group and no take_damage(), so nobody can attack it.
	var body := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(3.4, 2.6, 1.2)
	body.mesh = bm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.24, 0.33, 0.3) if kind == "pharmacy" else Color(0.33, 0.28, 0.2)
	mat.roughness = 0.9
	body.material_override = mat
	body.position.y = 1.3
	add_child(body)

	var shutter := MeshInstance3D.new()
	var sm := BoxMesh.new()
	sm.size = Vector3(3.2, 1.9, 0.08)
	shutter.mesh = sm
	var smat := StandardMaterial3D.new()
	smat.albedo_color = Color(0.12, 0.22, 0.2) if kind == "pharmacy" else Color(0.16, 0.14, 0.11)
	shutter.material_override = smat
	shutter.position = Vector3(0, 1.1, -0.64)
	add_child(shutter)

	var lbl := Label3D.new()
	lbl.font = load("res://assets/fonts/NotoSansBengali-Regular.ttf")
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.no_depth_test = true
	lbl.font_size = 34
	lbl.pixel_size = 0.003
	lbl.outline_size = 8
	lbl.modulate = Color(0.5, 1.0, 0.6) if kind == "pharmacy" else Color(1.0, 0.82, 0.45)
	lbl.position = Vector3(0, 3.05, 0)
	lbl.text = ("+" if kind == "pharmacy" else "◎") + "  " + shop_name
	add_child(lbl)


func can_interact() -> bool:
	return panel == null


func prompt_text() -> String:
	return "[E] " + shop_name + (" — ওষুধ ও স্বাস্থ্য" if kind == "pharmacy" else " — অস্ত্র ও গুলি")


func on_interact_pressed(_player: Node) -> void:
	if panel != null:
		return
	panel = Control.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var shade := ColorRect.new()
	shade.color = Color(0.0, 0.0, 0.0, 0.78)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	center.add_child(box)

	var title := HUD.make_label(shop_name + "  •  wallet ৳" + Game.bn(Game.money), 30, UIStyle.SUN)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	box.add_child(HUD.make_label("লুট: গুলি " + Game.bn(Game.loot_ammo) + "  •  বন্দুক " + Game.bn(Game.loot_guns),
		17, Color(0.75, 0.85, 0.78)))
	box.add_child(HSeparator.new())

	if kind == "pharmacy":
		_add(box, "ওষুধ — ৫০ HP   ৳60", 60, func(): heal(50.0))
		_add(box, "ব্যান্ডেজ — ২০ HP   ৳25", 25, func(): heal(20.0))
		_add(box, "মেডকিট   ৳120", 120, func(): Game.set_medkits(Game.medkits + 1))
		_add(box, "স্বাস্থ্য উন্নত (+25 HP)   ৳250", 250, func(): Game.buy_health_upgrade(250))
	else:
		_add(box, "রাইফেলের গুলি ৬০   ৳80", 80, func(): buy_ammo("rifle", 60))
		_add(box, "পিস্তলের গুলি ১৬   ৳40", 40, func(): buy_ammo("pistol", 16))
		_add(box, "Type-56 বন্দুক + ৪০ গুলি   ৳300", 300, func(): buy_gun("type56", 40))
		_add(box, "মেডকিট   ৳120", 120, func(): Game.set_medkits(Game.medkits + 1))
		if shop_type == "arms":
			_add(box, "AWP স্নাইপার + ২০ গুলি   ৳500", 500, func(): buy_gun("awp", 20))
			_add(box, "MP5 + ৯০ গুলি   ৳400", 400, func(): buy_gun("mp5", 90))
		elif shop_type in ["grocery", "tea", "hardware", "general"]:
			_add(box, "স্ন্যাকস — +২৫ HP   ৳15", 15, func(): heal(25.0))
		elif shop_type == "mobile":
			_add(box, "রেডিও কোড   ৳60", 60, func(): grant_radio())
		box.add_child(HUD.make_button("লুট বেচুন  (গুলি + বন্দুক → ৳)", func(): sell_loot()))

	box.add_child(HSeparator.new())
	box.add_child(HUD.make_button("বন্ধ করুন / Close", func(): close_panel()))

	get_tree().root.add_child(panel)
	var p := Game.player
	if p != null:
		saved_input = bool(p.get("input_enabled"))
		p.set("input_enabled", false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _add(box: VBoxContainer, text: String, cost: int, action: Callable) -> void:
	box.add_child(HUD.make_button(text, func():
		if Game.money < cost:
			notify("টাকা কম — " + Game.bn(cost) + " ৳ লাগবে", Color(1.0, 0.5, 0.4))
			return
		Game.add_money(-cost)
		action.call()
		refresh()
	))


func refresh() -> void:
	if panel == null:
		return
	var lbls := panel.find_children("*", "Label", true, false)
	for l in lbls:
		var t: String = (l as Label).text
		if t.begins_with(shop_name + "  •  wallet"):
			(l as Label).text = shop_name + "  •  wallet ৳" + Game.bn(Game.money)
		elif t.begins_with("লুট:"):
			(l as Label).text = "লুট: গুলি " + Game.bn(Game.loot_ammo) + "  •  বন্দুক " + Game.bn(Game.loot_guns)


func notify(msg: String, col: Color) -> void:
	if Game.level != null and Game.level.get("hud") != null:
		Game.level.hud.notify(msg, col)


func heal(amount: float) -> void:
	var p := Game.player
	if p != null and p.has_method("heal"):
		p.call("heal", amount)
	Game.medicine_used += 1
	Game.save_economy()
	notify("ওষুধ: +" + Game.bn(int(amount)) + " HP", Color(0.5, 1.0, 0.6))


func buy_ammo(kind: String, amount: int) -> void:
	var p := Game.player
	if p == null:
		return
	var w = p.get("weapon")
	if w != null and w.has_method("add_ammo"):
		w.call("add_ammo", kind, amount)
	notify("গুলি কেনা: " + Game.bn(amount), Color(1.0, 0.85, 0.4))


func buy_gun(id: String, rounds: int) -> void:
	var p := Game.player
	if p == null:
		return
	var w = p.get("weapon")
	if w != null and w.has_method("give_weapon"):
		w.call("give_weapon", id, rounds)
		(w as Node).set("current", (w as Node).get("slots").size() - 1)
	notify("বন্দুক কেনা: " + id.to_upper(), Color(1.0, 0.85, 0.4))


func grant_radio() -> void:
	var p := Game.player
	if p != null:
		p.set("radios", int(p.get("radios")) + 1)
	notify("রেডিও কোড পেলেন", Color(0.5, 0.9, 1.0))


func sell_loot() -> void:
	var total: int = Game.loot_ammo * 2 + Game.loot_guns * 120
	if total <= 0:
		notify("বেচার মতো লুট নেই", Color(1.0, 0.6, 0.4))
		return
	Game.add_money(total, "লুট বেচা")
	Game.add_loot(-Game.loot_ammo, -Game.loot_guns)
	refresh()


func close_panel() -> void:
	if panel != null:
		panel.queue_free()
		panel = null
	var p := Game.player
	if p != null:
		p.set("input_enabled", saved_input)
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
