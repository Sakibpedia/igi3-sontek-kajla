extends Node3D
## IGI-2 style wanted poster / leaflet.  The generated poster is always available;
## dropping a real photo at user://posters/sakib.png makes the face on it exact.

var kind := "poster"
var slogan := ""

## IGI-style wanted / propaganda slogans seen around Kajla.
const SLOGANS := [
	"WANTED — S M NAZMUZ SAKIB",
	"IGI 3 — এক অপারেটিভ, পনেরোটি অভিযান",
	"সাহসী হৃদয়, নিঃশব্দ পদচারণা",
	"ঢাকার অন্ধকারে সত্যের আলো — IGI 3",
	"লক্ষ্য অর্জনই আমাদের পরিচয়",
	"SONTEK•KAJLA — OPERATION ACTIVE",
]


static func make(p_kind: String, pos: Vector3, yaw: float) -> Node3D:
	var n := Node3D.new()
	n.set_script(preload("res://scripts/world/PropagandaProp.gd"))
	n.kind = p_kind
	n.global_position = pos
	n.rotation.y = yaw
	return n


func _ready() -> void:
	add_to_group("interactables")
	var seed_i: int = int(global_position.x) + int(global_position.z) * 3 + int(rotation.y * 10.0)
	slogan = SLOGANS[absi(seed_i) % SLOGANS.size()]
	var is_poster := kind == "poster"
	var tex := _poster_texture() if is_poster else load("res://assets/textures/leaflet_kajla.png") as Texture2D
	var mesh := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(1.15, 1.72, 0.04) if is_poster else Vector3(0.9, 0.68, 0.03)
	mesh.mesh = bm
	var mat := StandardMaterial3D.new()
	if tex != null:
		var img := tex.get_image()
		var imat := ImageTexture.create_from_image(img)
		mat.albedo_texture = imat
	else:
		mat.albedo_color = Color(0.7, 0.65, 0.5)
	mat.roughness = 0.95
	mesh.material_override = mat
	mesh.position = Vector3(0, 1.0 if is_poster else 0.85, 0)
	add_child(mesh)

	var lbl := Label3D.new()
	lbl.font = load("res://assets/fonts/NotoSansBengali-Regular.ttf")
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.no_depth_test = true
	lbl.font_size = 20
	lbl.pixel_size = 0.002
	lbl.outline_size = 8
	lbl.position = Vector3(0, 2.0 if is_poster else 1.4, 0)
	lbl.modulate = Color(1.0, 0.85, 0.5)
	lbl.text = slogan if is_poster else "BULLETIN — কাজলা নিরাপত্তা সতর্কতা"
	add_child(lbl)


func _poster_texture() -> Texture2D:
	var base_tex := load("res://assets/textures/poster_sakib.png") as Texture2D
	if base_tex == null:
		return null
	var photo_path := "user://posters/sakib.png"
	if not FileAccess.file_exists(photo_path):
		return base_tex
	var photo := Image.new()
	if photo.load(photo_path) != OK:
		return base_tex
	if photo.is_compressed():
		photo.decompress()
	photo.convert(Image.FORMAT_RGBA8)
	photo.resize(212, 328, Image.INTERPOLATE_LANCZOS)
	var img := base_tex.get_image()
	img.convert(Image.FORMAT_RGBA8)
	img.blend_rect(photo, Rect2i(0, 0, 212, 328), Vector2i(70, 172))
	return ImageTexture.create_from_image(img)


func can_interact() -> bool:
	return true


func prompt_text() -> String:
	return "[E] " + ("পোস্টার পড়ুন" if kind == "poster" else "বুলেটিন পড়ুন")


func on_interact_pressed(_p: Node) -> void:
	AudioManager.play_2d("sfx_pa_static", -14.0, 1.2)
	if Game.level != null and Game.level.get("hud") != null:
		Game.level.hud.notify("পোস্টার: " + slogan, Color(1.0, 0.85, 0.5))
