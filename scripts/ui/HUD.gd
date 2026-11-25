extends CanvasLayer
## In-mission HUD (Bengali): health + hero portrait, ammo, objectives, compass with objective marker,
## Bengali subtitles, stealth detection meter, team / hostage status, interaction prompt,
## damage direction, hit markers, screen effects, loading, pause and debrief screens.
## Phase 4: intel-beacon markers over hostages who remembered something (arrows at the screen edge
## when off screen), and on the minimap the gang's patrol routes (walkie-talkie / intel), the hidden
## stash and the VIP.
## Cox's Bazar: dialogue boxes (text only - no voices): the last three lines, each a card with the
## speaker's name, fading out after their time; the tourist police post and tied-up gang members on the
## minimap. No shop.
## UI (UIStyle.gd): every panel is a card in the coastal palette; the Alpha Team roster (gender, state,
## health per member); the tape-type bar (7 cycles - unlimited) with the score / medkit / police chips;
## stacked notices; the order menu with key caps; the interaction prompt on a pill.

const UIStyle := preload("res://scripts/ui/UIStyle.gd")
const MapGeo := preload("res://scripts/world/MapGeo.gd")
const GREEN := Color(0.13, 0.75, 0.68)
const RED := Color(0.98, 0.33, 0.33)
const GOLD := Color(1.0, 0.78, 0.36)

class Overlay extends Control:
	var spread := 2.0
	var show_cross := true
	var hit_t := 0.0
	var hit_kill := false
	var dmg_marks: Array = []
	var compass_yaw := 0.0
	var obj_angle := INF
	var obj_dist := 0.0
	var detect := 0.0
	var font: Font
	## [screen pos, on screen, edge angle, flash 0..1.2, distance m] per signalling hostage
	var beacons: Array = []

	func _draw_beacons() -> void:
		var c0 := size * 0.5
		for b in beacons:
			var fl: float = float(b[3])
			var col := Color(0.45, 0.85, 1.0, 0.95)
			var faint := Color(0.45, 0.85, 1.0, 0.55)
			var dist_txt := "তথ্য • %s মি" % Game.bn(int(b[4]))
			if bool(b[1]):
				var q: Vector2 = b[0]
				var r := 12.0 + fl * 9.0
				draw_arc(q, r, 0.0, TAU, 28, col, 2.5)
				# signal waves on both sides
				draw_arc(q, r + 7.0, -0.8, 0.8, 10, faint, 2.0)
				draw_arc(q, r + 7.0, PI - 0.8, PI + 0.8, 10, faint, 2.0)
				draw_arc(q, r + 13.0, -0.6, 0.6, 10, faint, 1.5)
				draw_arc(q, r + 13.0, PI - 0.6, PI + 0.6, 10, faint, 1.5)
				draw_circle(q, 4.0, col)
				if font != null:
					draw_string(font, q + Vector2(-60, -r - 10), dist_txt, HORIZONTAL_ALIGNMENT_CENTER, 120, 15, col)
			else:
				var a: float = float(b[2])
				var dir := Vector2(sin(a), -cos(a))
				var edge := c0 + dir * (minf(size.x, size.y) * 0.42)
				var side := Vector2(-dir.y, dir.x)
				draw_colored_polygon(PackedVector2Array([edge + dir * (14.0 + fl * 6.0), edge - dir * 6.0 + side * 10.0, edge - dir * 6.0 - side * 10.0]), col)
				if font != null:
					draw_string(font, edge - dir * 30.0 + Vector2(-60, 5), dist_txt, HORIZONTAL_ALIGNMENT_CENTER, 120, 14, col)

	func _draw() -> void:
		_draw_beacons()
		var c := size * 0.5
		if show_cross:
			var gap := 6.0 + spread * 7.0
			var col := Color(1, 1, 1, 0.85)
			draw_line(c + Vector2(-gap - 10, 0), c + Vector2(-gap, 0), col, 2.0)
			draw_line(c + Vector2(gap, 0), c + Vector2(gap + 10, 0), col, 2.0)
			draw_line(c + Vector2(0, -gap - 10), c + Vector2(0, -gap), col, 2.0)
			draw_line(c + Vector2(0, gap), c + Vector2(0, gap + 10), col, 2.0)
		draw_circle(c, 1.6, Color(1, 1, 1, 0.9))
		if hit_t > 0.0:
			var hc := Color(0.96, 0.16, 0.25) if hit_kill else Color(1, 1, 1)
			for s in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
				draw_line(c + s * 6.0, c + s * 14.0, hc, 2.5)
		for m in dmg_marks:
			var a: float = m[0]
			var alpha: float = clampf(float(m[1]), 0.0, 1.0)
			var dir := Vector2(sin(a), -cos(a))
			var p := c + dir * 130.0
			var side := Vector2(-dir.y, dir.x)
			draw_colored_polygon(PackedVector2Array([p + side * 28.0, p - side * 28.0, p + dir * 22.0]), Color(1, 0.1, 0.05, 0.75 * alpha))
		# compass
		var cw := 460.0
		var cx := size.x * 0.5
		var cy := 26.0
		draw_rect(Rect2(cx - cw * 0.5, cy - 14, cw, 28), Color(0, 0, 0, 0.45))
		var dirs := [["উ", 0.0], ["পূ", PI * 0.5], ["দ", PI], ["প", -PI * 0.5]]
		for d in dirs:
			var rel := wrapf(float(d[1]) - compass_yaw, -PI, PI)
			if absf(rel) < PI * 0.5:
				var x := cx + rel / (PI * 0.5) * cw * 0.5
				if font != null:
					draw_string(font, Vector2(x - 8, cy + 8), str(d[0]), HORIZONTAL_ALIGNMENT_CENTER, -1, 20, Color(1, 1, 1, 0.9))
		for i in 24:
			var rel2 := wrapf(TAU * i / 24.0 - compass_yaw, -PI, PI)
			if absf(rel2) < PI * 0.5:
				var x2 := cx + rel2 / (PI * 0.5) * cw * 0.5
				draw_line(Vector2(x2, cy + 9), Vector2(x2, cy + 14), Color(1, 1, 1, 0.5), 1.0)
		if obj_angle != INF:
			var rel3 := clampf(obj_angle, -PI * 0.5, PI * 0.5)
			var x3 := cx + rel3 / (PI * 0.5) * cw * 0.5
			draw_colored_polygon(PackedVector2Array([Vector2(x3, cy - 12), Vector2(x3 + 8, cy), Vector2(x3, cy + 12), Vector2(x3 - 8, cy)]), Color(1.0, 0.82, 0.3))
			if font != null:
				draw_string(font, Vector2(x3 - 40, cy + 34), Game.bn(int(obj_dist)) + " মি", HORIZONTAL_ALIGNMENT_CENTER, 80, 16, Color(1.0, 0.82, 0.3))
		# stealth detection meter
		if detect > 0.02:
			var w := 160.0
			var r := Rect2(cx - w * 0.5, cy + 46, w, 8)
			draw_rect(r, Color(0, 0, 0, 0.5))
			var col2 := Color(1.0, 0.85, 0.2).lerp(Color(0.96, 0.16, 0.25), detect)
			draw_rect(Rect2(r.position, Vector2(w * clampf(detect, 0.0, 1.0), 8)), col2)
			if font != null:
				draw_string(font, Vector2(cx - 80, cy + 76), "শত্রুর সন্দেহ" if detect < 1.0 else "ধরা পড়েছেন!", HORIZONTAL_ALIGNMENT_CENTER, 160, 16, col2)


var overlay: Overlay
var minimap: Minimap
var bino_mask: TextureRect
var bino_label: Label
var fx_rect: ColorRect
var fx_mat: ShaderMaterial
var root: Control
var health_bar: ProgressBar
var health_label: Label
var portrait: TextureRect
var ammo_label: Label
var weapon_label: Label
var status_label: Label
var obj_title: Label
var obj_label: Label
var clue_label: Label
var timer_label: Label
var prompt_label: Label
var prompt_bar: ProgressBar
## Stage-by-stage medical / procedure feedback (top centre) and the bomb clock.
var procedure_panel: PanelContainer
var procedure_label: Label
var procedure_bar: ProgressBar
var procedure_timer: Label
var _proc_active := false
var thermal_overlay: ColorRect
var sub_panel: PanelContainer
var sub_label: RichTextLabel
var notify_label: Label
var team_label: Label
var hostage_label: Label
var boss_box: VBoxContainer
var boss_bar: ProgressBar
var loading: Control
var loading_status: Label
var pause_panel: Control
var end_panel: Control
var obj_list_panel: PanelContainer
var obj_list_label: Label
var _sub_t := 0.0
var _notify_t := 0.0
var _damage := 0.0
var _haze := 0.0
## Rotating minimap: building footprints from the level builder, team, hostages, spotted enemies,
## water points, exit vehicle and the current objective.
class Minimap extends Control:
	const SCALE := 2.3
	var font: Font

	func _w2m(p: Vector3, pl: Node3D) -> Vector2:
		var rel := Vector2(p.x - pl.global_position.x, p.z - pl.global_position.z)
		return size * 0.5 + rel.rotated(pl.rotation.y) * SCALE

	func _dot(p: Vector3, pl: Node3D, col: Color, r: float = 3.5) -> void:
		var q := _w2m(p, pl)
		if Rect2(Vector2.ZERO, size).grow(-3.0).has_point(q):
			draw_circle(q, r, col)

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.05, 0.04, 0.72))
		var pl := Game.player as Node3D
		var lv = Game.level
		if pl == null or lv == null:
			return
		var reach := size.length() * 0.5 / SCALE + 6.0
		var rects: Array = lv.get("map_rects") if lv.get("map_rects") != null else []
		var px := pl.global_position.x
		var pz := pl.global_position.z
		# real Kajla OpenStreetMap raster under the tactical overlay
		if bool(lv.get("is_igi_mode")):
			var map_tex := load("res://assets/maps/kajla_osm.png") as Texture2D
			if map_tex != null:
				var mp: Vector2 = MapGeo.world_to_map(Vector2(px, pz))
				var k := SCALE / MapGeo.MAP_PX_PER_M
				var b := Transform2D(pl.rotation.y, Vector2(k, k), 0.0, Vector2.ZERO)
				var o := size * 0.5 - b.basis_xform(mp)
				draw_set_transform(o, pl.rotation.y, Vector2(k, k))
				draw_texture(map_tex, Vector2.ZERO)
				draw_set_transform_matrix(Transform2D.IDENTITY)
				draw_rect(Rect2(Vector2.ZERO, size), Color(0.0, 0.03, 0.02, 0.18))
		for r in rects:
			var c: Vector2 = r[0]
			if absf(c.x - px) > reach + 12.0 or absf(c.y - pz) > reach + 12.0:
				continue
			var hh: Vector2 = r[1]
			var yaw: float = r[2]
			var pts := PackedVector2Array()
			for k in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
				var wpt: Vector2 = c + (hh * (k as Vector2)).rotated(-yaw)
				pts.append(size * 0.5 + (wpt - Vector2(px, pz)).rotated(pl.rotation.y) * SCALE)
			draw_colored_polygon(pts, r[3])
		for w in pl.get_tree().get_nodes_in_group("water_sources"):
			_dot((w as Node3D).global_position, pl, Color(0.35, 0.7, 1.0), 3.5)
		var sz: Vector3 = lv.get("safe_zone")
		var q := _w2m(sz, pl)
		q = q.clamp(Vector2(6, 6), size - Vector2(6, 6))
		draw_rect(Rect2(q - Vector2(5, 5), Vector2(10, 10)), Color(0.4, 1.0, 0.5))
		if lv.get("utils") != null and lv.utils.routes_visible():
			# Phase 4: the gang's patrol routes (walkie-talkie / a hostage's intel)
			for e in pl.get_tree().get_nodes_in_group("enemies"):
				if not e.is_alive():
					continue
				var pr: Array = e.get("patrol") if e.get("patrol") is Array else []
				if pr.size() < 2:
					continue
				var pts := PackedVector2Array()
				for wp in pr:
					pts.append(_w2m(wp, pl))
				pts.append(_w2m(pr[0], pl))
				draw_polyline(pts, Color(1.0, 0.6, 0.2, 0.75), 1.6)
				_dot((e as Node3D).global_position, pl, Color(1.0, 0.5, 0.15), 3.0)
		var blink := int(Time.get_ticks_msec() / 300) % 2 == 0
		for h in pl.get_tree().get_nodes_in_group("hostages"):
			if h.is_alive() and bool(h.get("located")):
				var hc := Color(0.5, 1.0, 0.5) if h.is_safe() else Color(1.0, 0.85, 0.25)
				if bool(h.get("companion")):
					hc = Color(0.55, 0.85, 1.0)
				elif bool(h.get("downed")):
					hc = Color(1.0, 0.3, 0.3) if blink else Color(1.0, 0.85, 0.25)
				var hq := _w2m((h as Node3D).global_position, pl)
				if bool(h.get("vip")) and Rect2(Vector2.ZERO, size).grow(-3.0).has_point(hq):
					draw_arc(hq, 6.0, 0.0, TAU, 16, Color(0.85, 0.5, 1.0), 1.8)
				if bool(h.get("intel_pending")) and Rect2(Vector2.ZERO, size).grow(-3.0).has_point(hq):
					draw_arc(hq, 5.0 + float(h.get("beacon_flash")) * 5.0, 0.0, TAU, 16, Color(0.45, 0.85, 1.0), 1.6)
				_dot((h as Node3D).global_position, pl, hc, 3.5)
		if lv.get("utils") != null:
			var u = lv.utils
			if u.stash_pos != Vector3.INF:
				var sq := _w2m(u.stash_pos, pl).clamp(Vector2(6, 6), size - Vector2(6, 6))
				draw_rect(Rect2(sq - Vector2(5, 5), Vector2(10, 10)), Color(1.0, 0.8, 0.2))
				if font != null:
					draw_string(font, sq + Vector2(-5, 5), "★", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.1, 0.1, 0.05))
			if bool(u.intel.get("key", false)) and u.key_pos != Vector3.INF and int(pl.get("keys")) == 0 and u.cage != null and not bool(u.cage.get("open")):
				var kq := _w2m(u.key_pos, pl).clamp(Vector2(6, 6), size - Vector2(6, 6))
				draw_rect(Rect2(kq - Vector2(4, 4), Vector2(8, 8)), Color(1.0, 0.85, 0.2))
			for ct in u.containers:
				var cq := _w2m(ct["info"]["inside"], pl)
				if Rect2(Vector2.ZERO, size).grow(-4.0).has_point(cq):
					draw_rect(Rect2(cq - Vector2(4, 4), Vector2(8, 8)), Color(0.4, 0.75, 1.0), false, 2.0)
		for a in pl.get_tree().get_nodes_in_group("allies"):
			if bool(a.get("alive")):
				_dot((a as Node3D).global_position, pl, Color(0.3, 0.9, 1.0), 3.5)
		# tied-up gang members (for the police) and the tourist police post
		for gc in pl.get_tree().get_nodes_in_group("enemy_captives"):
			if not bool(gc.get("police_done")):
				_dot((gc as Node3D).global_position, pl, Color(0.75, 0.75, 1.0), 3.0)
		var pol: Dictionary = lv.get("police") if lv.get("police") is Dictionary else {}
		if not pol.is_empty():
			var pq := _w2m(pol["pos"], pl).clamp(Vector2(7, 7), size - Vector2(7, 7))
			draw_rect(Rect2(pq - Vector2(5, 5), Vector2(10, 10)), Color(0.3, 0.5, 1.0))
			if font != null:
				draw_string(font, pq + Vector2(-4, 5), "P", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.WHITE)
		for e in pl.get_tree().get_nodes_in_group("enemies"):
			if not e.is_alive():
				continue
			var ep := (e as Node3D).global_position
			var st: int = int(e.get("state"))
			# only enemies the team has spotted: close by, alert or fighting
			if bool(e.get("revealed")):
				var lq := _w2m(ep, pl).clamp(Vector2(7, 7), size - Vector2(7, 7))
				draw_circle(lq, 5.5, Color(0.85, 0.45, 1.0))
			elif int(e.get("mark_until_ms")) > Time.get_ticks_msec():
				_dot(ep, pl, Color(1.0, 0.4, 0.1), 4.5)
			elif ep.distance_to(pl.global_position) < 28.0 or st == 2 or st == 3:
				_dot(ep, pl, Color(1.0, 0.55, 0.15) if e.is_in_group("villains") else Color(1.0, 0.2, 0.2), 3.5)
		var op: Vector3 = lv.get("_obj_marker_pos") if lv.get("_obj_marker_pos") != null else Vector3.INF
		if op != Vector3.INF:
			var oq := _w2m(op, pl).clamp(Vector2(7, 7), size - Vector2(7, 7))
			draw_colored_polygon(PackedVector2Array([oq + Vector2(0, -7), oq + Vector2(6, 0), oq + Vector2(0, 7), oq + Vector2(-6, 0)]), Color(1.0, 0.82, 0.3))
		var c0 := size * 0.5
		draw_colored_polygon(PackedVector2Array([c0 + Vector2(0, -9), c0 + Vector2(6, 7), c0 + Vector2(0, 3), c0 + Vector2(-6, 7)]), Color.WHITE)
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.0, 0.62, 0.45, 0.9), false, 2.0)
		if font != null:
			var npos := size * 0.5 + Vector2(0, -1).rotated(pl.rotation.y) * (size.x * 0.5 - 12.0)
			draw_string(font, npos + Vector2(-6, 6), "উ", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(1, 1, 1, 0.85))


var _flash := 0.0
var _mm_t := 0.0
var _wet := 0.0
var _obj_pos := Vector3.INF
var _timer_val := -1.0


func _ready() -> void:
	layer = 5
	process_mode = Node.PROCESS_MODE_ALWAYS
	fx_rect = ColorRect.new()
	fx_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	fx_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fx_mat = ShaderMaterial.new()
	fx_mat.shader = load("res://shaders/screen_fx.gdshader")
	fx_rect.material = fx_mat
	fx_rect.visible = Game.quality() > 0
	add_child(fx_rect)
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	overlay = Overlay.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.font = Game.ui_font
	root.add_child(overlay)
	minimap = Minimap.new()
	minimap.anchor_left = 1.0
	minimap.anchor_right = 1.0
	minimap.offset_left = -232
	minimap.offset_right = -22
	minimap.offset_top = 72
	minimap.offset_bottom = 282
	minimap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	minimap.clip_contents = true
	minimap.font = Game.ui_font
	root.add_child(minimap)
	bino_mask = TextureRect.new()
	bino_mask.set_anchors_preset(Control.PRESET_FULL_RECT)
	bino_mask.stretch_mode = TextureRect.STRETCH_SCALE
	bino_mask.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bino_mask.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bino_mask.texture = _binocular_mask()
	bino_mask.visible = false
	root.add_child(bino_mask)
	bino_label = make_label("", 22, Color(0.7, 1.0, 0.7))
	bino_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	bino_label.offset_top = -150
	bino_label.offset_left = -240
	bino_label.offset_right = 240
	bino_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bino_label.visible = false
	root.add_child(bino_label)
	_build_status()
	_build_objective()
	_build_center()
	_build_subtitles()
	_build_pause()
	_build_obj_list()
	_build_orders()
	_build_kits()
	_build_roster()
	Game.tape_changed.connect(_update_tape_bar)
	_update_tape_bar()
	AudioManager.subtitle.connect(_on_subtitle)


## Two overlapping circles cut out of black: the binocular view.
func _binocular_mask() -> ImageTexture:
	var w := 640
	var h := 360
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var r := h * 0.47
	var c1 := Vector2(w * 0.5 - r * 0.62, h * 0.5)
	var c2 := Vector2(w * 0.5 + r * 0.62, h * 0.5)
	for y in h:
		for x in w:
			var p := Vector2(x, y)
			var d := minf(p.distance_to(c1), p.distance_to(c2))
			var a := clampf((d - r + 6.0) / 10.0, 0.0, 1.0)
			img.set_pixel(x, y, Color(0, 0, 0, a))
	return ImageTexture.create_from_image(img)


## A card in the coastal style (UIStyle.card): accent outline and strip.
static func panel_style(border: Color = GREEN, alpha: float = 0.62) -> StyleBoxFlat:
	return UIStyle.card(border, clampf(alpha + 0.16, 0.55, 0.96))


static func make_label(text: String, size: int, color: Color = Color.WHITE) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	l.add_theme_constant_override("shadow_offset_x", 2)
	l.add_theme_constant_override("shadow_offset_y", 2)
	return l


static func make_button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(320, 52)
	UIStyle.style_button(b, UIStyle.TEAL, 22)
	b.mouse_entered.connect(func(): AudioManager.play_2d("sfx_ui", -20.0, 1.6))
	b.pressed.connect(func():
		AudioManager.play_2d("sfx_ui", -4.0)
		cb.call())
	return b


func _build_status() -> void:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", panel_style())
	p.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	p.position = Vector2(20, -150)
	p.grow_vertical = Control.GROW_DIRECTION_BEGIN
	root.add_child(p)
	p.anchor_top = 1.0
	p.anchor_bottom = 1.0
	p.offset_top = -132
	p.offset_bottom = -20
	p.offset_left = 20
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 12)
	p.add_child(hb)
	portrait = TextureRect.new()
	portrait.custom_minimum_size = Vector2(76, 95)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	portrait.texture = AssetLoader.hero_texture()
	portrait.visible = portrait.texture != null
	hb.add_child(portrait)
	var vb := VBoxContainer.new()
	hb.add_child(vb)
	vb.add_child(make_label("ফ্রিল্যান্সার", 18, GOLD))
	health_label = make_label(Game.t("health") + ": ১২৫", 18)
	vb.add_child(health_label)
	health_bar = ProgressBar.new()
	health_bar.custom_minimum_size = Vector2(250, 14)
	health_bar.max_value = 125
	UIStyle.style_bar(health_bar, UIStyle.OK, 14)
	vb.add_child(health_bar)
	team_label = make_label("", 15, Color(0.6, 1.0, 0.6))
	vb.add_child(team_label)
	hostage_label = make_label("", 15, GOLD)
	vb.add_child(hostage_label)
	# ammo (bottom right)
	var ap := PanelContainer.new()
	ap.add_theme_stylebox_override("panel", panel_style(RED))
	root.add_child(ap)
	ap.anchor_left = 1.0
	ap.anchor_right = 1.0
	ap.anchor_top = 1.0
	ap.anchor_bottom = 1.0
	ap.offset_left = -300
	ap.offset_right = -20
	ap.offset_top = -120
	ap.offset_bottom = -20
	var av := VBoxContainer.new()
	ap.add_child(av)
	weapon_label = make_label("", 20, GOLD)
	weapon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	av.add_child(weapon_label)
	ammo_label = make_label("", 40)
	ammo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	av.add_child(ammo_label)
	status_label = make_label("", 16, Color(1, 0.6, 0.5))
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	av.add_child(status_label)


func _build_objective() -> void:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", panel_style(GOLD))
	p.position = Vector2(20, 70)
	p.custom_minimum_size = Vector2(380, 0)
	root.add_child(p)
	var vb := VBoxContainer.new()
	p.add_child(vb)
	obj_title = make_label(Game.t("objective"), 16, GOLD)
	vb.add_child(obj_title)
	obj_label = make_label("", 19)
	obj_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	obj_label.custom_minimum_size = Vector2(380, 0)
	vb.add_child(obj_label)
	clue_label = make_label("", 16, Color(0.55, 0.9, 1.0))
	clue_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	clue_label.custom_minimum_size = Vector2(380, 0)
	clue_label.visible = false
	vb.add_child(clue_label)
	timer_label = make_label("", 28, RED)
	timer_label.visible = false
	vb.add_child(timer_label)
	boss_box = VBoxContainer.new()
	boss_box.anchor_left = 0.5
	boss_box.anchor_right = 0.5
	boss_box.offset_left = -260
	boss_box.offset_right = 260
	boss_box.offset_top = 96
	boss_box.visible = false
	root.add_child(boss_box)
	var bl := make_label("শকুন — কালো ছায়ার প্রধান", 20, RED)
	bl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_box.add_child(bl)
	boss_bar = ProgressBar.new()
	boss_bar.custom_minimum_size = Vector2(520, 14)
	boss_bar.show_percentage = false
	var fg := StyleBoxFlat.new()
	fg.bg_color = RED
	boss_bar.add_theme_stylebox_override("fill", fg)
	boss_box.add_child(boss_bar)


func set_thermal(on: bool) -> void:
	if thermal_overlay == null:
		thermal_overlay = ColorRect.new()
		thermal_overlay.color = Color(0.05, 0.35, 0.16, 0.16)
		thermal_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		thermal_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(thermal_overlay)
	thermal_overlay.visible = on


func _build_center() -> void:
	# Medical / interaction procedures: always visible while a nurse or Alpha works,
	# with the current stage, a real progress bar and (for bombs) the time left.
	procedure_panel = PanelContainer.new()
	procedure_panel.add_theme_stylebox_override("panel", panel_style(Color(0.45, 1.0, 0.72), 0.88))
	procedure_panel.anchor_left = 0.5
	procedure_panel.anchor_right = 0.5
	procedure_panel.anchor_top = 0.0
	procedure_panel.anchor_bottom = 0.0
	procedure_panel.offset_left = -280
	procedure_panel.offset_right = 280
	procedure_panel.offset_top = 18
	procedure_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	procedure_panel.visible = false
	root.add_child(procedure_panel)
	var mv := VBoxContainer.new()
	mv.add_theme_constant_override("separation", 4)
	procedure_panel.add_child(mv)
	procedure_label = make_label("", 19, Color(0.75, 1.0, 0.86))
	procedure_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	procedure_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	mv.add_child(procedure_label)
	procedure_bar = ProgressBar.new()
	procedure_bar.max_value = 1.0
	procedure_bar.custom_minimum_size = Vector2(360, 12)
	procedure_bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	UIStyle.style_bar(procedure_bar, UIStyle.TEAL, 12)
	mv.add_child(procedure_bar)
	procedure_timer = make_label("", 16, GOLD)
	procedure_timer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mv.add_child(procedure_timer)

	prompt_pill = PanelContainer.new()
	var ps := UIStyle.sb(Color(UIStyle.BG_DEEP.r, UIStyle.BG_DEEP.g, UIStyle.BG_DEEP.b, 0.78), 999, Color(1, 1, 1, 0.14), 1, 22.0, 8.0)
	prompt_pill.add_theme_stylebox_override("panel", ps)
	prompt_pill.anchor_left = 0.5
	prompt_pill.anchor_right = 0.5
	prompt_pill.anchor_top = 0.5
	prompt_pill.anchor_bottom = 0.5
	prompt_pill.offset_left = -430
	prompt_pill.offset_right = 430
	prompt_pill.offset_top = 56
	prompt_pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	prompt_pill.visible = false
	root.add_child(prompt_pill)
	var pv := VBoxContainer.new()
	pv.add_theme_constant_override("separation", 6)
	prompt_pill.add_child(pv)
	prompt_label = make_label("", 20, UIStyle.SAND)
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pv.add_child(prompt_label)
	prompt_bar = ProgressBar.new()
	prompt_bar.max_value = 1.0
	prompt_bar.custom_minimum_size = Vector2(240, 8)
	prompt_bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	UIStyle.style_bar(prompt_bar, UIStyle.TEAL, 8)
	prompt_bar.visible = false
	pv.add_child(prompt_bar)
	# notices: up to four stacked cards, top centre, each fading out after its time
	toast_box = VBoxContainer.new()
	toast_box.anchor_left = 0.5
	toast_box.anchor_right = 0.5
	toast_box.offset_left = -380
	toast_box.offset_right = 380
	toast_box.offset_top = 150
	toast_box.add_theme_constant_override("separation", 6)
	toast_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(toast_box)
	# kept for older code paths: never shown
	notify_label = make_label("", 1)
	notify_label.visible = false
	root.add_child(notify_label)


## Dialogue box: every spoken line (text only) with the speaker's name; up to three lines stay, the
## newest at the bottom, each for its own time.
var _dlg: Array = []
var _dlg_sig := ""
var dlg_box: VBoxContainer
var prompt_pill: PanelContainer
var toast_box: VBoxContainer
var _toasts: Array = []


func _build_subtitles() -> void:
	dlg_box = VBoxContainer.new()
	dlg_box.anchor_left = 0.5
	dlg_box.anchor_right = 0.5
	dlg_box.anchor_top = 1.0
	dlg_box.anchor_bottom = 1.0
	dlg_box.offset_left = -480
	dlg_box.offset_right = 480
	dlg_box.offset_top = -330
	dlg_box.offset_bottom = -158
	dlg_box.alignment = BoxContainer.ALIGNMENT_END
	dlg_box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	dlg_box.add_theme_constant_override("separation", 6)
	dlg_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(dlg_box)
	# the old single box (kept so nothing else breaks; the cards above replace it)
	sub_panel = PanelContainer.new()
	sub_panel.visible = false
	root.add_child(sub_panel)
	sub_label = RichTextLabel.new()
	sub_panel.add_child(sub_label)


func _build_obj_list() -> void:
	obj_list_panel = PanelContainer.new()
	obj_list_panel.add_theme_stylebox_override("panel", panel_style(GOLD, 0.85))
	obj_list_panel.anchor_left = 0.5
	obj_list_panel.anchor_right = 0.5
	obj_list_panel.anchor_top = 0.5
	obj_list_panel.anchor_bottom = 0.5
	obj_list_panel.offset_left = -420
	obj_list_panel.offset_right = 420
	obj_list_panel.offset_top = -200
	obj_list_panel.visible = false
	root.add_child(obj_list_panel)
	obj_list_label = make_label("", 20)
	obj_list_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	obj_list_panel.add_child(obj_list_label)


## Above the status panel (bottom left): the tape-type bar (7 picks the next type - unlimited, no
## stock) and chips for the score, medkits, gang members handed to the police and the safe hostages.
var kit_panel: PanelContainer
var kit_label: Label
var _tape_chips: Array = []
var _pause_tape_btns: Array = []
var _stat_labels := {}


func _build_kits() -> void:
	kit_panel = PanelContainer.new()
	kit_panel.add_theme_stylebox_override("panel", UIStyle.card(UIStyle.SKY, 0.8))
	kit_panel.anchor_top = 1.0
	kit_panel.anchor_bottom = 1.0
	kit_panel.offset_left = 20
	kit_panel.offset_top = -232
	kit_panel.offset_bottom = -146
	kit_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	kit_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(kit_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 7)
	kit_panel.add_child(v)
	var igi := Game.level != null and bool(Game.level.get("is_igi_mode"))
	var tr := HBoxContainer.new()
	tr.add_theme_constant_override("separation", 6)
	v.add_child(tr)
	_tape_chips.clear()
	if not igi:
		tr.add_child(make_label("টেপ", 15, UIStyle.MUTED))
		for t in range(1, Game.TAPE_TYPES.size()):
			var short := Game.tape_name(t).trim_suffix(" টেপ")
			var c: Color = Game.tape_info(t)["color"]
			var chip := UIStyle.chip_label(short, c, 14)
			tr.add_child(chip)
			_tape_chips.append(chip)
		tr.add_child(UIStyle.keycap("৭", 13))
	var sr := HBoxContainer.new()
	sr.add_theme_constant_override("separation", 6)
	v.add_child(sr)
	var chips: Array = [["score", "পয়েন্ট", UIStyle.SUN], ["objective", "লক্ষ্য", UIStyle.TEAL],
		["alarm", "অ্যালার্ম", RED], ["money", "টাকা", UIStyle.SUN], ["time", "সময়", UIStyle.SKY]] if igi else [
		["score", "পয়েন্ট", UIStyle.SUN], ["med", "মেডকিট", UIStyle.OK],
		["police", "পুলিশে", UIStyle.SKY], ["safe", "নিরাপদ", UIStyle.TEAL]]
	for k in chips:
		var cp := UIStyle.chip_label("%s —" % str(k[1]), k[2], 14)
		sr.add_child(cp)
		_stat_labels[k[0]] = cp.get_child(0)
	var hr := HBoxContainer.new()
	hr.add_theme_constant_override("separation", 6)
	v.add_child(hr)
	var keys: Array = [["E", "ইন্টারঅ্যাক্ট"], ["Tab", "লক্ষ্য"], ["M", "মানচিত্র"], ["Esc", "বিরতি"]] if igi else [
		["I", "হ্যাঁ/না প্রশ্ন"], ["M", "ওয়াকি-টকি"], ["J", "আলফা"], ["Tab", "লক্ষ্য"]]
	for k in keys:
		hr.add_child(UIStyle.keycap(str(k[0]), 12, UIStyle.MUTED))
		hr.add_child(make_label(str(k[1]), 13, UIStyle.MUTED))
	if not igi:
		var mr := HBoxContainer.new()
		mr.add_theme_constant_override("separation", 6)
		v.add_child(mr)
		for k in [["bomb", "বোম", RED], ["virus", "ভাইরাস", Color(0.4, 1.0, 0.5)],
				["cured", "ভাইরাস ধরা", UIStyle.TEAL], ["nurse", "নার্স", UIStyle.SKY]]:
			var cp := UIStyle.chip_label("%s —" % str(k[1]), k[2], 14)
			mr.add_child(cp)
			_stat_labels[k[0]] = cp.get_child(0)
	kit_label = make_label("", 1)
	kit_label.visible = false
	v.add_child(kit_label)
	_update_tape_bar()


func _update_kits() -> void:
	if _stat_labels.is_empty():
		return
	if Game.level != null and bool(Game.level.get("is_igi_mode")):
		var lv = Game.level
		(_stat_labels["score"] as Label).text = "পয়েন্ট %s" % Game.bn(Game.score())
		(_stat_labels["objective"] as Label).text = "লক্ষ্য %s/%s" % [Game.bn(int(lv.get("obj_index")) + 1), Game.bn((lv.get("objectives") as Array).size())]
		(_stat_labels["alarm"] as Label).text = "অ্যালার্ম " + ("হ্যাঁ" if bool(lv.get("alarm_raised")) else "না")
		(_stat_labels["money"] as Label).text = "টাকা %s" % Game.bn(Game.money)
		(_stat_labels["time"] as Label).text = "সময় %s" % Game.bn_time(float(lv.get("mission_time")))
		return
	var safe := 0
	var total := 0
	for h in get_tree().get_nodes_in_group("hostages"):
		total += 1
		if h.is_safe():
			safe += 1
	(_stat_labels["score"] as Label).text = "পয়েন্ট %s" % Game.bn(Game.score())
	(_stat_labels["med"] as Label).text = "মেডকিট %s" % Game.bn(Game.medkits)
	(_stat_labels["police"] as Label).text = "পুলিশে %s" % Game.bn(int(Game.stats.get("police", 0)))
	(_stat_labels["safe"] as Label).text = "নিরাপদ %s/%s" % [Game.bn(safe), Game.bn(total)]
	if Game.level != null and Game.level.get("utils") != null and Game.level.utils.has_method("medical_counts"):
		var mc: Dictionary = Game.level.utils.medical_counts()
		(_stat_labels["bomb"] as Label).text = "বোম %s/%s" % [Game.bn(int(mc["bomb_left"])), Game.bn(int(mc["bomb_total"]))]
		(_stat_labels["virus"] as Label).text = "ভাইরাস %s/%s" % [Game.bn(int(mc["virus_left"])), Game.bn(int(mc["virus_total"]))]
		(_stat_labels["cured"] as Label).text = "ভাইরাস ধরা %s" % Game.bn(int(Game.stats.get("viruses", 0)))
		var nurse: Node = Game.level.utils.get("nurse")
		var ntxt := "অনুপস্থিত"
		if nurse != null and is_instance_valid(nurse):
			ntxt = str(nurse.call("nurse_job_text"))
		(_stat_labels["nurse"] as Label).text = "নার্স: %s" % ntxt


## The picked noise-dampening tape tier is a filled chip; the others are outlined.
func _update_tape_bar() -> void:
	for i in _tape_chips.size():
		var t: int = i + 1
		var chip: PanelContainer = _tape_chips[i]
		var c: Color = Game.tape_info(t)["color"]
		var on := t == Game.tape_type
		chip.add_theme_stylebox_override("panel", UIStyle.chip(c, on))
		var l := chip.get_child(0) as Label
		l.add_theme_color_override("font_color", UIStyle.BG_DEEP if on else c.lightened(0.25))
	for i in _pause_tape_btns.size():
		(_pause_tape_btns[i] as Button).set_pressed_no_signal(i + 1 == Game.tape_type)


## Alpha Team roster (left): one card per member - gender, call sign, what she / he is doing, health.
var roster_box: VBoxContainer
var _roster_rows := {}
var _roster_t := 0.0


func _build_roster() -> void:
	roster_box = VBoxContainer.new()
	roster_box.anchor_top = 0.5
	roster_box.anchor_bottom = 0.5
	roster_box.offset_left = 20
	roster_box.offset_right = 300
	roster_box.offset_top = -10
	roster_box.add_theme_constant_override("separation", 5)
	roster_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(roster_box)


func _ally_state(a: Node) -> String:
	if not bool(a.get("alive")):
		return "আহত — সরে গেছেন"
	if a.get("hand_on") != null and is_instance_valid(a.get("hand_on")):
		return "মুখ চেপে ধরে আছেন"
	var c = a.get("carrying")
	if c != null and is_instance_valid(c):
		return "কাঁধে: " + str(c.get("name_bn"))
	if bool(a.get("scripted")):
		return "বিশেষ কাজে"
	var at = a.get("attend_target")
	if at != null and is_instance_valid(at):
		return "আদেশের অপেক্ষায় — " + str(at.get("name_bn"))
	if a.get("_para") != null:
		return "প্যারাস্যুটে নামছেন"
	if bool(a.get("holding")):
		return "অবস্থান ধরে আছেন"
	return "অনুসরণ করছেন"


func _update_roster() -> void:
	var seen := {}
	for a in get_tree().get_nodes_in_group("allies"):
		if str(a.get("role")) != "ally":
			continue
		var id := a.get_instance_id()
		seen[id] = true
		var row: Dictionary = _roster_rows.get(id, {})
		if row.is_empty():
			var card := PanelContainer.new()
			var fem := bool(a.get("female"))
			var accent := UIStyle.CORAL if fem else UIStyle.SKY
			card.add_theme_stylebox_override("panel", UIStyle.card(accent, 0.72))
			card.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var v := VBoxContainer.new()
			v.add_theme_constant_override("separation", 3)
			card.add_child(v)
			var h := HBoxContainer.new()
			h.add_theme_constant_override("separation", 7)
			v.add_child(h)
			h.add_child(UIStyle.chip_label("নারী" if fem else "পুরুষ", accent, 12, true))
			var nm := make_label(str(a.get("callsign")), 16, UIStyle.SAND)
			h.add_child(nm)
			var stl := make_label("", 13, UIStyle.MUTED)
			v.add_child(stl)
			var bar := ProgressBar.new()
			bar.max_value = float(a.get("max_health"))
			bar.custom_minimum_size = Vector2(240, 6)
			UIStyle.style_bar(bar, UIStyle.OK, 6)
			v.add_child(bar)
			roster_box.add_child(card)
			row = {"card": card, "state": stl, "bar": bar}
			_roster_rows[id] = row
		var hp := float(a.get("health"))
		var mx := maxf(float(a.get("max_health")), 1.0)
		var b: ProgressBar = row["bar"]
		b.max_value = mx
		b.value = hp if bool(a.get("alive")) else 0.0
		UIStyle.tint_bar(b, UIStyle.health_color(hp / mx))
		(row["state"] as Label).text = _ally_state(a)
		(row["card"] as Control).modulate.a = 1.0 if bool(a.get("alive")) else 0.45
	for id in _roster_rows.keys():
		if not seen.has(id):
			var gone: Dictionary = _roster_rows[id]
			(gone["card"] as Node).queue_free()
			_roster_rows.erase(id)


## Order menu for an Alpha member (J): numbered orders, chosen with keys 1..6.
var order_panel: PanelContainer
var order_label: Label


func _build_orders() -> void:
	order_panel = PanelContainer.new()
	order_panel.add_theme_stylebox_override("panel", UIStyle.card(UIStyle.TEAL, 0.92))
	order_panel.anchor_left = 1.0
	order_panel.anchor_right = 1.0
	order_panel.anchor_top = 0.5
	order_panel.anchor_bottom = 0.5
	order_panel.offset_left = -440
	order_panel.offset_right = -22
	order_panel.offset_top = -60
	order_panel.visible = false
	order_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(order_panel)
	order_rows = VBoxContainer.new()
	order_rows.add_theme_constant_override("separation", 6)
	order_panel.add_child(order_rows)
	order_label = make_label("", 1)
	order_label.visible = false
	order_rows.add_child(order_label)


var order_rows: VBoxContainer


func show_orders(title: String, options: Array) -> void:
	for c in order_rows.get_children():
		if c != order_label:
			c.queue_free()
	var tl := make_label(title, 19, UIStyle.SUN)
	tl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tl.custom_minimum_size = Vector2(380, 0)
	order_rows.add_child(tl)
	order_rows.add_child(HSeparator.new())
	for i in options.size():
		var r := HBoxContainer.new()
		r.add_theme_constant_override("separation", 10)
		r.add_child(UIStyle.keycap(Game.bn(i + 1), 15, UIStyle.TEAL.lightened(0.3)))
		var ol := make_label(str(options[i][1]), 18, UIStyle.SAND)
		ol.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		ol.custom_minimum_size = Vector2(320, 0)
		r.add_child(ol)
		order_rows.add_child(r)
	var f := HBoxContainer.new()
	f.add_theme_constant_override("separation", 10)
	f.add_child(UIStyle.keycap("J", 13, UIStyle.MUTED))
	f.add_child(make_label("মেনু বন্ধ", 15, UIStyle.MUTED))
	order_rows.add_child(f)
	order_label.text = title
	order_panel.visible = true


func hide_orders() -> void:
	if order_panel != null:
		order_panel.visible = false
	hide_consent()


# ---------------------------------------------------------------- Phase 7: the consent form
var consent_panel: Control = null


## The full medical consent form the hostage signs before the bomb-rigged garment comes off.
## Keys 1 / 2 (Mission.choose_order) sign or decline; the game keeps running while it is open.
func show_consent(who: String) -> void:
	hide_consent()
	consent_panel = _overlay_panel()
	var vb := _overlay_card(consent_panel, 660.0, UIStyle.SUN)
	var tl := make_label("চিকিৎসা সম্মতিপত্র", 36, UIStyle.SUN)
	tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(tl)
	var sl := make_label("জরুরি বোম অপসারণ পদ্ধতি — মেডিক্যাল নার্স কর্তৃক সম্পাদিত", 18, UIStyle.MUTED)
	sl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(sl)
	vb.add_child(HSeparator.new())
	var body := make_label("রোগী: %s\n\n১। আমার পোশাকের সঙ্গে সংযুক্ত বোমটি জীবনরক্ষাকারী চিকিৎসার অংশ হিসেবে খুলে ফেলা হবে।\n২। খোলা পোশাকটি (বিকিনি / শর্টস) উদ্ধারকারীকে পরতে হবে; নার্স সেটিতে থাকা বোমটি নিষ্ক্রিয় করবেন।\n৩। স্বাক্ষরের পর ৫ মিনিটের মধ্যে পদ্ধতিটি শেষ করতে হবে — ব্যর্থ হলে বিস্ফোরণ।\n৪। আমি স্বেচ্ছায় সম্মতি দিতে বা প্রত্যাখ্যান করতে পারি; প্রত্যাখ্যান করলে বিকল্প চিকিৎসা নেওয়া হবে।" % who, 19, UIStyle.SAND)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size = Vector2(580, 0)
	vb.add_child(body)
	vb.add_child(make_label("স্বাক্ষর: ______________________   (%s)" % who, 20, UIStyle.TEAL))
	vb.add_child(HSeparator.new())
	for o in [["১", "সম্মতি দিচ্ছি — স্বাক্ষর করুন"], ["২", "এখন না (প্রত্যাখ্যান)"]]:
		var r := HBoxContainer.new()
		r.add_theme_constant_override("separation", 10)
		r.add_child(UIStyle.keycap(str(o[0]), 15, UIStyle.TEAL.lightened(0.3)))
		r.add_child(make_label(str(o[1]), 19, UIStyle.SAND))
		vb.add_child(r)


func hide_consent() -> void:
	if consent_panel != null and is_instance_valid(consent_panel):
		consent_panel.queue_free()
	consent_panel = null


func _overlay_panel() -> Control:
	var c := ColorRect.new()
	c.color = Color(0.015, 0.035, 0.055, 0.86)
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(c)
	return c


## A centred card on an overlay; returns the VBox inside it.
func _overlay_card(parent: Control, w: float, accent: Color = GREEN) -> VBoxContainer:
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	parent.add_child(cc)
	var pc := PanelContainer.new()
	var st := UIStyle.panel(0.96)
	st.border_color = Color(accent.r, accent.g, accent.b, 0.7)
	st.border_width_top = 4
	pc.add_theme_stylebox_override("panel", st)
	pc.custom_minimum_size = Vector2(minf(w, maxf(get_viewport().size.x - 48.0, 320.0)), 0)
	pc.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	cc.add_child(pc)
	var vb := VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 12)
	pc.add_child(vb)
	return vb


func _build_pause() -> void:
	pause_panel = _overlay_panel()
	pause_panel.visible = false
	var vb := _overlay_card(pause_panel, 720.0, GOLD)
	var t := make_label(Game.t("paused"), 46, GOLD)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(t)
	var mt := make_label("%s — %s" % [str(Game.mission_data(Game.current_mission)["title"]), str(Game.mission_data(Game.current_mission)["place"])], 18, UIStyle.MUTED)
	mt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(mt)
	for bdef in [[Game.t("resume"), func(): set_paused(false)], [Game.t("restart"), func(): Game.restart_mission()], [Game.t("main_menu"), func(): Game.goto_menu()]]:
		var bt := make_button(bdef[0], bdef[1])
		bt.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		vb.add_child(bt)
	if Game.level == null or not bool(Game.level.get("is_igi_mode")):
		var tr := HBoxContainer.new()
		tr.alignment = BoxContainer.ALIGNMENT_CENTER
		tr.add_theme_constant_override("separation", 8)
		vb.add_child(tr)
		tr.add_child(make_label("পরের টেপ:", 17, UIStyle.MUTED))
		for ti in range(1, Game.TAPE_TYPES.size()):
			var tb := Button.new()
			tb.text = Game.tape_name(ti).trim_suffix(" টেপ")
			tb.toggle_mode = true
			tb.button_pressed = ti == Game.tape_type
			var tcol: Color = Game.tape_info(ti)["color"]
			UIStyle.style_button(tb, tcol, 16)
			tb.add_theme_stylebox_override("pressed", UIStyle.sb(tcol, 10, tcol.lightened(0.3), 1, 14.0, 7.0))
			tb.pressed.connect(func(): Game.set_tape_type(ti))
			tr.add_child(tb)
			_pause_tape_btns.append(tb)
	var sens := HSlider.new()
	sens.min_value = 0.03
	sens.max_value = 0.4
	sens.step = 0.01
	sens.value = float(Game.settings["mouse_sensitivity"])
	sens.custom_minimum_size = Vector2(320, 24)
	sens.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	sens.value_changed.connect(func(v: float):
		Game.settings["mouse_sensitivity"] = v
		Game.save_settings())
	var sl := make_label(Game.t("mouse_sensitivity"), 17, UIStyle.MUTED)
	sl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(sl)
	vb.add_child(sens)
	vb.add_child(HSeparator.new())
	var c := make_label(Game.t("controls"), 14, Color(0.8, 0.86, 0.88))
	c.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	c.custom_minimum_size = Vector2(660, 0)
	c.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(c)


func set_paused(p: bool) -> void:
	if loading != null and loading.visible:
		return
	if end_panel != null and end_panel.visible:
		return
	get_tree().paused = p
	pause_panel.visible = p
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if p else Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		set_paused(not get_tree().paused)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("objectives"):
		obj_list_panel.visible = true
		_refresh_obj_list()
	elif event.is_action_released("objectives"):
		obj_list_panel.visible = false


func _refresh_obj_list() -> void:
	var lv := Game.level
	if lv == null:
		return
	var objs: Array = lv.get("objectives")
	var idx: int = int(lv.get("obj_index"))
	var txt := "মিশন %s — %s\n\n" % [Game.bn(Game.current_mission), str(Game.mission_data(Game.current_mission)["title"])]
	for i in objs.size():
		var mark := "✔ " if i < idx else ("➤ " if i == idx else "○ ")
		txt += mark + str(objs[i]["text"]) + "\n"
	obj_list_label.text = txt


# ------------------------------------------------------------------ API used by Mission
func show_loading(idx: int, data: Dictionary) -> void:
	loading = ColorRect.new()
	(loading as ColorRect).color = UIStyle.BG_DEEP
	loading.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(loading)
	# a dusk-to-sea gradient behind the briefing
	var grad := Gradient.new()
	grad.set_color(0, Color(0.12, 0.10, 0.20))
	grad.set_color(1, Color(0.02, 0.10, 0.14))
	grad.add_point(0.55, Color(0.35, 0.18, 0.22))
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(0, 1)
	var bgt := TextureRect.new()
	bgt.texture = gt
	bgt.set_anchors_preset(Control.PRESET_FULL_RECT)
	bgt.stretch_mode = TextureRect.STRETCH_SCALE
	bgt.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	loading.add_child(bgt)
	var stripe := ColorRect.new()
	stripe.color = UIStyle.CORAL
	stripe.anchor_right = 1.0
	stripe.offset_bottom = 6
	loading.add_child(stripe)
	var vb := VBoxContainer.new()
	vb.set_anchors_preset(Control.PRESET_FULL_RECT)
	vb.offset_left = 90
	vb.offset_right = -90
	vb.offset_top = 70
	vb.offset_bottom = -60
	vb.add_theme_constant_override("separation", 14)
	loading.add_child(vb)
	vb.add_child(UIStyle.chip_label("মিশন %s / %s" % [Game.bn(idx), Game.bn(Game.MISSION_COUNT)], UIStyle.SUN, 18, true))
	vb.add_child(make_label(str(data["title"]), 58, UIStyle.SAND))
	vb.add_child(make_label(str(data["place"]), 26, UIStyle.TEAL.lightened(0.25)))
	var brief := make_label(str(data["brief"]), 22, Color(0.92, 0.92, 0.88))
	brief.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(brief)
	var tips := ["টিপস: ◆ নিশানা ও মানচিত্রের হলুদ বিন্দু অনুসরণ করে লক্ষ্য খুঁজুন।", "টিপস: E চাপে ছবি তুলুন, নথি নিন, ওয়্যারট্যাপ লাগান বা চার্জ বসান।", "টিপস: T চাপে থার্মাল ভিশন — দেয়ালের ওপারের শত্রুও দেখা যাবে।", "টিপস: বাড়িতে ঢুকে সিঁড়ি বেয়ে ওপরের তলা ও ছাদে যান; শত্রু সব জায়গায় আছে।", "টিপস: E চাপে গাড়ি চালান — WASD স্টিয়ারিং, Space ব্রেক, আবার E চাপে নামুন।", "টিপস: ব্রাউজার/স্নাইপার স্কোপে ডান ক্লিক চেপে দূরের শত্রু লক্ষ্য করুন।", "টিপস: BCS গেটে ১–৪ চাপে সঠিক উত্তর দিয়ে গেট খুলুন।", "টিপস: Esc চাপলে মেনু থেকে আবার শুরু বা প্রধান মেনুতে ফিরে যেতে পারেন।"]
	var tl := make_label(tips[randi() % tips.size()], 20, GOLD)
	tl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(tl)
	var ctl := make_label(Game.t("controls"), 16, Color(0.7, 0.8, 0.75))
	ctl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(ctl)
	loading_status = make_label(Game.t("loading"), 24, Color(1, 1, 1))
	vb.add_child(loading_status)
	root.visible = false


func set_progress_text(t: String) -> void:
	if loading_status != null:
		loading_status.text = t


## Live stage + progress for a nurse / Alpha procedure. `detail` names the exact
## step in Bengali; `seconds` optionally shows a countdown.
func set_procedure(title: String, progress: float, detail: String = "", seconds: float = -1.0) -> void:
	if procedure_panel == null:
		return
	_proc_active = true
	procedure_panel.visible = true
	procedure_label.text = title + ("   •   " + detail if detail != "" else "")
	procedure_bar.value = clampf(progress, 0.0, 1.0)
	procedure_timer.text = ("⏱ %s সে" % Game.bn(maxi(0, int(seconds)))) if seconds >= 0.0 else ""


func hide_procedure() -> void:
	_proc_active = false
	if procedure_panel != null:
		procedure_panel.visible = false
	if procedure_bar != null:
		procedure_bar.value = 0.0


## The five-minute bomb clock stays on screen while no step is being performed.
func set_bomb_countdown(seconds: float) -> void:
	if procedure_panel == null or _proc_active or seconds <= 0.0:
		return
	procedure_panel.visible = true
	procedure_label.text = "বোম — সম্মতিপত্র স্বাক্ষরিত, নার্সের অপেক্ষায়"
	procedure_bar.value = 1.0 - clampf(seconds / 300.0, 0.0, 1.0)
	procedure_timer.text = "⏱ %s মিনিট %s সে বাকি" % [Game.bn(int(seconds) / 60), Game.bn(int(seconds) % 60)]
	if seconds < 30.0:
		procedure_label.text = "⚠ বোম — তাড়াতাড়ি নার্সকে ডাকুন!"


func hide_loading() -> void:
	if loading != null:
		var tw := create_tween()
		tw.tween_property(loading, "modulate:a", 0.0, 0.8)
		tw.tween_callback(loading.hide)
	root.visible = true


func notify(text: String, color: Color = GOLD) -> void:
	if toast_box == null:
		return
	# the same notice again only refreshes it
	for t in _toasts:
		if str(t["text"]) == text and is_instance_valid(t["node"]):
			t["t"] = 3.6
			(t["node"] as Control).modulate.a = 1.0
			return
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UIStyle.card(color, 0.88))
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := make_label(text, 20, color.lightened(0.35))
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card.add_child(l)
	toast_box.add_child(card)
	_toasts.append({"node": card, "t": 3.6, "text": text})
	while _toasts.size() > 4:
		var old: Dictionary = _toasts.pop_front()
		if is_instance_valid(old["node"]):
			(old["node"] as Node).queue_free()


func objective_started(o: Dictionary, i: int, n: int) -> void:
	obj_title.text = "%s %s/%s" % [Game.t("objective"), Game.bn(i + 1), Game.bn(n)]
	notify("নতুন লক্ষ্য: " + str(o.get("text", "")), GOLD)


var _clues: Array = []


## Keeps the hostages' clues on screen under the objective.
func set_clue(text: String) -> void:
	add_clue(text, _clues.size() + 1, 4)


func add_clue(text: String, n: int, need: int) -> void:
	if text != "":
		_clues.append(text)
	var shown := _clues.slice(maxi(0, _clues.size() - 4))
	clue_label.text = "সূত্র %s/%s:\n• %s" % [Game.bn(n), Game.bn(need), "\n• ".join(PackedStringArray(shown))]
	clue_label.visible = not _clues.is_empty()


func set_timer(sec: float) -> void:
	_timer_val = sec
	timer_label.visible = sec >= 0.0
	if sec >= 0.0:
		timer_label.text = "⏱ " + Game.bn_time(sec)


func set_objective_dir(pos: Vector3) -> void:
	_obj_pos = pos


func hitmarker(killed: bool) -> void:
	overlay.hit_t = 0.15
	overlay.hit_kill = killed
	AudioManager.play_2d("sfx_ui", -12.0, 1.6 if killed else 2.2)


func damage(dmg: float, from_pos: Vector3) -> void:
	_damage = minf(_damage + dmg / 35.0, 1.0)
	var p := Game.player as Node3D
	if p == null:
		return
	var local := p.global_transform.basis.inverse() * (from_pos - p.global_position)
	var a := atan2(local.x, -local.z)
	overlay.dmg_marks.append([a, 1.5])


func set_screen_fx(haze: float, flash: float, wet: float) -> void:
	_haze = haze
	_flash = flash
	_wet = wet


func show_end(success: bool, reason: String, idx: int) -> void:
	root.visible = false
	pause_panel.visible = false
	end_panel = _overlay_panel()
	var vb := _overlay_card(end_panel, 860.0, UIStyle.OK if success else RED)
	var final_win := success and idx >= Game.MISSION_COUNT
	var title := Game.t("mission_complete") if success else Game.t("mission_failed")
	if final_win:
		title = Game.t("victory_title")
	var tl := make_label(title, 60, Color(0.4, 1.0, 0.5) if success else RED)
	tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(tl)
	var sub := make_label(str(Game.mission_data(idx)["title"]) + " — " + str(Game.mission_data(idx)["place"]), 22, GOLD)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(sub)
	if reason != "":
		var rl := make_label(reason, 24)
		rl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		rl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vb.add_child(rl)
	if final_win:
		var fw := make_label(Game.t("victory_text"), 24, Color(0.9, 0.95, 0.9))
		fw.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		fw.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vb.add_child(fw)
	var st := Game.stats
	var shots: int = maxi(int(st["shots"]), 1)
	var acc: int = int(100.0 * float(st["hits"]) / float(shots))
	var saved := 0
	var total := 0
	for h in get_tree().get_nodes_in_group("hostages"):
		total += 1
		if h.is_safe():
			saved += 1
	var alarms_n := int(Game.level.get("alarms_raised")) if Game.level != null else 0
	var objs_n: Array = Game.level.get("objectives") if Game.level != null else []
	var lines := "%s: %s     %s: %s%%     %s: %s\n%s: %s     %s: %s     %s: %s/%s     %s: %s" % [
		Game.t("kills"), Game.bn(st["kills"]), Game.t("accuracy"), Game.bn(acc), Game.t("headshots"), Game.bn(st["headshots"]),
		Game.t("time"), Game.bn_time(float(st["time"])), Game.t("civilians"), Game.bn(alarms_n),
		Game.t("objective"), Game.bn(objs_n.size()), Game.bn(objs_n.size()), "পয়েন্ট", Game.bn(int(st.get("score", 0)))]
	if bool(Game.mission_data(idx).get("stealth", false)):
		lines += "\n" + Game.t("stealth") + ": " + ("না — আপনি ধরা পড়েছিলেন" if bool(st["detected"]) else "হ্যাঁ — কেউ টের পায়নি!")

		lines += "\n" + Game.t("stealth") + ": " + ("না — আপনি ধরা পড়েছিলেন" if bool(st["detected"]) else "হ্যাঁ — কেউ টের পায়নি!")
	var ll := make_label(lines, 22, Color(0.9, 0.95, 0.9))
	ll.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(ll)
	if success and idx < Game.MISSION_COUNT:
		var nb := make_button(Game.t("next_mission"), func(): Game.start_mission(idx + 1))
		nb.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		vb.add_child(nb)
	var rb := make_button(Game.t("retry") if not success else Game.t("restart"), func(): Game.restart_mission())
	rb.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vb.add_child(rb)
	var mb := make_button(Game.t("main_menu"), func(): Game.goto_menu())
	mb.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vb.add_child(mb)
	end_panel.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(end_panel, "modulate:a", 1.0, 0.8)


func _on_subtitle(speaker: String, text: String, duration: float) -> void:
	# the same line twice in a row only refreshes its time
	if not _dlg.is_empty() and str(_dlg[-1]["s"]) == speaker and str(_dlg[-1]["x"]) == text:
		_dlg[-1]["t"] = maxf(float(_dlg[-1]["t"]), duration + 0.8)
		return
	_dlg.append({"s": speaker, "x": text, "t": duration + 0.8})
	while _dlg.size() > 3:
		_dlg.pop_front()
	_render_dialogue()


func _render_dialogue() -> void:
	var sig := ""
	for d in _dlg:
		sig += str(d["s"]) + "|" + str(d["x"]) + "\n"
	if sig != _dlg_sig:
		_dlg_sig = sig
		for c in dlg_box.get_children():
			c.queue_free()
		for d in _dlg:
			var sp := str(d["s"])
			var col := UIStyle.MUTED
			if sp == "ফ্রিল্যান্সার":
				col = UIStyle.SKY
			elif sp.begins_with("আলফা"):
				col = UIStyle.TEAL
			elif sp != "":
				col = UIStyle.SUN
			var card := PanelContainer.new()
			card.add_theme_stylebox_override("panel", UIStyle.card(col, 0.86))
			card.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var h := HBoxContainer.new()
			h.add_theme_constant_override("separation", 12)
			card.add_child(h)
			if sp != "":
				var badge := UIStyle.chip_label(sp, col, 15, true)
				badge.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
				h.add_child(badge)
			var l := make_label(str(d["x"]), 21, UIStyle.SAND)
			l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			l.custom_minimum_size = Vector2(600, 0)
			h.add_child(l)
			dlg_box.add_child(card)
			d["node"] = card
	for d in _dlg:
		if d.has("node") and is_instance_valid(d["node"]):
			(d["node"] as Control).modulate.a = clampf(float(d["t"]), 0.0, 1.0)
	_sub_t = 1.0 if not _dlg.is_empty() else 0.0


# ------------------------------------------------------------------ per frame
func _process(delta: float) -> void:
	if not _dlg.is_empty():
		var changed := false
		for d in _dlg:
			var before := float(d["t"])
			d["t"] = before - delta
			if (before > 1.0) != (float(d["t"]) > 1.0) or float(d["t"]) < 1.0:
				changed = true
		var n0 := _dlg.size()
		_dlg = _dlg.filter(func(d): return float(d["t"]) > 0.0)
		if changed or _dlg.size() != n0:
			_render_dialogue()
	_notify_t -= delta
	for t in _toasts:
		t["t"] = float(t["t"]) - delta
		if is_instance_valid(t["node"]):
			(t["node"] as Control).modulate.a = clampf(float(t["t"]) / 0.6, 0.0, 1.0)
	for t in _toasts.filter(func(x): return float(x["t"]) <= 0.0):
		if is_instance_valid(t["node"]):
			(t["node"] as Node).queue_free()
	_toasts = _toasts.filter(func(x): return float(x["t"]) > 0.0)
	_roster_t -= delta
	if _roster_t <= 0.0 and roster_box != null:
		_roster_t = 0.4
		_update_roster()
	_damage = maxf(_damage - delta * 0.8, 0.0)
	overlay.hit_t = maxf(overlay.hit_t - delta, 0.0)
	for m in overlay.dmg_marks:
		m[1] = float(m[1]) - delta
	overlay.dmg_marks = overlay.dmg_marks.filter(func(m): return float(m[1]) > 0.0)
	var p = Game.player
	if p != null and is_instance_valid(p):
		_update_player(p)
		_update_beacons(p)
	_update_kits()
	var thermal_on := p != null and is_instance_valid(p) and bool(p.thermal)
	fx_rect.visible = Game.quality() > 0 or thermal_on
	fx_mat.set_shader_parameter("thermal", 1.0 if thermal_on else 0.0)
	var bino_on := p != null and is_instance_valid(p) and bool(p.binoculars)
	# scoped firearms share the binocular vignette so long-range aiming is clear
	var scope_on := false
	if p != null and is_instance_valid(p) and p.weapon != null and bool(p.weapon.aiming):
		scope_on = float(p.weapon.data().get("zoom", 1.0)) <= 0.45
	var sight_on := bino_on or scope_on
	bino_mask.visible = sight_on
	bino_label.visible = sight_on
	overlay.show_cross = overlay.show_cross and not sight_on
	if bino_on:
		var r: float = float(p.bino_range)
		bino_label.text = ("দূরত্ব: %s মি" % Game.bn(int(r)) if r >= 0.0 else "দূরত্ব: — —") + ("   •   " + str(p.bino_target) if str(p.bino_target) != "" else "") + "   •   ১২×"
	elif scope_on:
		bino_label.text = "স্নাইপার স্কোপ ৪×   •   দূরের লক্ষ্য লাগানোর জন্য শ্বাস থামিয়ে Duck/chop (Ctrl) চাপুন"
	_mm_t -= delta
	if _mm_t <= 0.0:
		_mm_t = 0.1
		minimap.queue_redraw()
	if fx_rect.visible:
		var low := 0.0
		if p != null and is_instance_valid(p):
			low = clampf(1.0 - float(p.health) / 35.0, 0.0, 1.0)
		fx_mat.set_shader_parameter("haze", _haze)
		fx_mat.set_shader_parameter("damage", _damage)
		fx_mat.set_shader_parameter("flash", _flash)
		fx_mat.set_shader_parameter("rain", _wet)
		fx_mat.set_shader_parameter("low_health", low)
	overlay.queue_redraw()


## Screen markers for hostages signalling intel (on screen: rings with signal waves; off screen: an
## arrow at the edge pointing the way).
func _update_beacons(p) -> void:
	var bl: Array = []
	var cam: Camera3D = p.get("camera")
	if cam != null:
		for h in get_tree().get_nodes_in_group("hostages"):
			if not h.is_alive() or not bool(h.get("intel_pending")):
				continue
			var wp: Vector3 = h.sight_point() + Vector3(0, 0.45, 0)
			var dist := wp.distance_to(cam.global_position)
			var local := cam.global_transform.affine_inverse() * wp
			var fl := float(h.get("beacon_flash"))
			var onscreen := false
			var sp := Vector2.ZERO
			if local.z < -0.1:
				sp = cam.unproject_position(wp)
				onscreen = Rect2(Vector2.ZERO, overlay.size).grow(-24.0).has_point(sp)
			bl.append([sp, onscreen, atan2(local.x, -local.z), fl, dist])
	overlay.beacons = bl


func _update_player(p) -> void:
	var hp: float = float(p.health)
	health_bar.max_value = float(p.get("max_health"))
	health_bar.value = hp
	UIStyle.tint_bar(health_bar, UIStyle.health_color(hp / maxf(health_bar.max_value, 1.0)))
	health_label.text = "%s: %s" % [Game.t("health"), Game.bn(int(ceil(hp)))]
	var w = p.weapon
	weapon_label.text = str(w.data()["name"])
	ammo_label.text = "%s / %s" % [Game.bn(w.mag_ammo()), Game.bn(w.reserve_ammo())]
	if w.reloading:
		status_label.text = Game.t("reloading")
	elif w.mag_ammo() == 0 and w.reserve_ammo() == 0:
		status_label.text = Game.t("no_ammo")
	elif bool(p.get("swimming")):
		status_label.text = "সাঁতার কাটছেন — Space উপরে, Ctrl ডুব" + (" • দম: %s%%" % Game.bn(int(float(p.get("breath")) * 100.0)) if float(p.get("breath")) < 0.99 else "")
	elif bool(p.get("parachuting")):
		status_label.text = "প্যারাস্যুট — WASD দিক ঠিক করুন" if bool(p.get("chute_open")) else "মুক্ত পতন — Space চাপলে প্যারাস্যুট খুলবে"
	elif p.carried.size() >= 2:
		status_label.text = "দুই কাঁধে দুই জিম্মি — অস্ত্র চালানো যাবে না (G নামাতে)"
	elif p.carrying != null:
		status_label.text = "জিম্মি কাঁধে — শুধু পিস্তল (G নামাতে) • ভার %s%%" % Game.bn(int(p.carry_load() * 100.0))
	elif bool(p.get("prone")):
		status_label.text = "শুয়ে আছেন — শত্রু সহজে দেখবে না (Z উঠুন)"
	else:
		status_label.text = ""
	var gear: String = "গ্রেনেড %s • মলোটভ %s • বোমা %s" % [Game.bn(int(p.get("grenades"))), Game.bn(int(p.get("molotovs"))), Game.bn(int(p.get("bombs")))]
	if bool(AudioManager.get("headphones")):
		gear += " • হেডফোন চালু"
	if Game.level != null and bool(Game.level.get("is_igi_mode")):
		gear += "\nসময় %s • পয়েন্ট %s • অ্যালার্ম %s" % [Game.bn_time(float(Game.level.get("mission_time"))), Game.bn(Game.score()), "হ্যাঁ" if bool(Game.level.get("alarm_raised")) else "না"]
	else:
		gear += "\nপ্রাথমিক চিকিৎসা %s • ফোন %s • চাবি %s • ওয়াকি-টকি %s" % [Game.bn(int(p.get("first_aid"))), Game.bn(int(p.get("phones"))), Game.bn(int(p.get("keys"))), Game.bn(int(p.get("radios")))]
	var lv = Game.level
	if lv != null and lv.get("utils") != null:
		var st: String = lv.utils.status_text()
		if st != "":
			gear += "\n" + st
	weapon_label.text = str(w.data()["name"]) + "\n" + gear
	overlay.spread = w.current_spread()
	overlay.show_cross = not w.aiming
	overlay.compass_yaw = -float(p.rotation.y)
	if _obj_pos != Vector3.INF:
		var local: Vector3 = (p.global_transform.basis.inverse() * (_obj_pos - p.global_position))
		overlay.obj_angle = atan2(local.x, -local.z)
		overlay.obj_dist = (_obj_pos - p.global_position).length()
	else:
		overlay.obj_angle = INF
	# interaction prompt
	var it = p.interact_target
	if it != null and is_instance_valid(it) and it.has_method("prompt_text"):
		prompt_label.text = it.prompt_text()
		var pr: float = it.progress() if it.has_method("progress") else 0.0
		prompt_bar.visible = pr > 0.0
		prompt_bar.value = pr
		prompt_pill.visible = prompt_label.text != ""
	else:
		prompt_label.text = ""
		prompt_bar.visible = false
		prompt_pill.visible = false
	# detection meter, boss bar
	var det := 0.0
	var boss = null
	for e in get_tree().get_nodes_in_group("enemies"):
		if not e.is_alive():
			continue
		if (e as Node3D).global_position.distance_to(p.global_position) < 60.0:
			det = maxf(det, float(e.suspicion))
		if e.kind == "boss" and int(e.state) == 3:
			boss = e
	overlay.detect = det if Game.level != null and bool(Game.level.data.get("stealth", false)) else 0.0
	boss_box.visible = boss != null
	if boss != null:
		boss_bar.max_value = float(boss.max_health)
		boss_bar.value = float(boss.health)
	# team / hostages
	var alive := 0
	var total := 0
	for a in get_tree().get_nodes_in_group("allies"):
		if str(a.role) == "ally":
			total += 1
			if a.alive:
				alive += 1
	if total > 0:
		var mode := "অবস্থান ধরে আছে" if Game.level != null and bool(Game.level.team_hold) else "অনুসরণ করছে"
		team_label.text = "আলফা টিম: %s/%s — %s" % [Game.bn(alive), Game.bn(total), mode]
	else:
		team_label.text = "একক অভিযান"
	var hs := get_tree().get_nodes_in_group("hostages")
	if hs.size() > 0:
		var safe := 0
		for h in hs:
			if h.is_safe():
				safe += 1
		var nclue: int = int(Game.stats.get("clues", 0))
		hostage_label.text = "নিরাপদ জিম্মি: %s/%s   •   সূত্র: %s/৪\nপানির বোতল: %s/৩   •   পয়েন্ট %s" % [Game.bn(safe), Game.bn(hs.size()), Game.bn(nclue), Game.bn(int(p.water)), Game.bn(Game.score())]
	else:
		hostage_label.text = ""
	if Game.level != null and Game.level.has_method("objective_count_text"):
		var o: Dictionary = Game.level.current_objective()
		obj_label.text = Game.level.objective_text() if Game.level.has_method("objective_text") else str(o.get("text", "")) + Game.level.objective_count_text()
