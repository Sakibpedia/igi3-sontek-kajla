extends Node3D
## Optional high-resolution human models (.glb / .gltf / .fbx) in place of the procedural body.
##
## Where the game looks (first match wins), file name = role:
##   <folder of SilentRescueDhaka.exe>/models/   (no rebuild needed)
##   user://models/
##   res://assets/models/                         (rebuild needed)
## Roles: hero.glb (the Freelancer), ally.glb (Alpha Team men), villain.glb (gunmen and villains),
## boss.glb (the boss; falls back to villain), civilian.glb, vip.glb. Hostages and Alpha Team women
## always keep the built-in bodies.
##
## The model needs a humanoid skeleton with Mixamo-style bone names (mixamorig:Hips, Spine, Spine1,
## Spine2, Neck, Head, LeftArm, LeftForeArm, LeftHand, LeftUpLeg, LeftLeg, LeftFoot, ... - the prefix
## is optional). Download any rigged character from Mixamo as FBX or convert it to .glb in Blender.
##
## How it moves: the procedural rig keeps running invisibly (walk, crouch, aim, kneel, carry, reach,
## surrender ...). Every frame this node poses the skeleton from it - limbs by aiming each bone along
## the procedural limb, hips / spine / neck / head by copying their rotation from rest - so every
## animation in the game drives the model.

const ROLE_FILES := {"hero": ["hero"], "ally": ["ally"], "villain": ["villain"], "boss": ["boss", "villain"], "civilian": ["civilian"], "vip": ["vip"]}
const EXTS := ["glb", "gltf", "fbx"]

static var _cache := {}

var rig: Node3D            # the CharacterModel
var skel: Skeleton3D
var _scene: Node3D
var _map := {}             # bone index -> [kind, data]
var _order: Array = []     # bone indices, parents first
var _rest_g := {}          # bone index -> rest Basis in skeleton space
var _pivot_rest := {}      # pivot node -> rest Basis in rig space
var _hips := -1
var _hips_rest_pos := Vector3.ZERO
var _hip_y := 0.94


## Path of the model to use for this role, or "".
static func find_model(role: String) -> String:
	var names: Array = ROLE_FILES.get(role, [])
	if names.is_empty():
		return ""
	var dirs: Array = []
	if not OS.has_feature("editor"):
		dirs.append(OS.get_executable_path().get_base_dir().path_join("models"))
	dirs.append(ProjectSettings.globalize_path("user://models"))
	dirs.append("res://assets/models")
	for n in names:
		for d in dirs:
			for e in EXTS:
				var p: String = str(d).path_join("%s.%s" % [n, e])
				if p.begins_with("res://"):
					if ResourceLoader.exists(p):
						return p
				elif FileAccess.file_exists(p):
					return p
	return ""


## Loads (once) and instantiates a model file: imported scenes from res://, glTF / FBX at runtime.
static func instantiate_file(path: String) -> Node3D:
	if _cache.has(path):
		var ps: PackedScene = _cache[path]
		return ps.instantiate() if ps != null else null
	var root: Node = null
	if path.begins_with("res://"):
		var res = load(path)
		if res is PackedScene:
			_cache[path] = res
			return (res as PackedScene).instantiate()
	else:
		var doc: Object = null
		var state: Object = null
		if path.get_extension().to_lower() == "fbx":
			if ClassDB.class_exists("FBXDocument"):
				doc = ClassDB.instantiate("FBXDocument")
				state = ClassDB.instantiate("FBXState")
		else:
			doc = GLTFDocument.new()
			state = GLTFState.new()
		if doc != null and doc.append_from_file(path, state) == OK:
			root = doc.generate_scene(state)
	if root == null:
		push_warning("SkinnedModel: could not load %s" % path)
		_cache[path] = null
		return null
	for n in _all(root):
		if n != root:
			n.owner = root
	var packed := PackedScene.new()
	packed.pack(root)
	_cache[path] = packed
	root.free()
	return packed.instantiate()


static func _all(n: Node) -> Array:
	var out := [n]
	for c in n.get_children():
		out.append_array(_all(c))
	return out


static func _norm(bone_name: String) -> String:
	var s := bone_name
	var i := s.rfind(":")
	if i >= 0:
		s = s.substr(i + 1)
	for pre in ["mixamorig_", "mixamorig1_", "mixamorig", "DEF-", "def_"]:
		if s.begins_with(pre):
			s = s.substr(pre.length())
	return s


static func _find_skeleton(n: Node) -> Skeleton3D:
	if n is Skeleton3D:
		return n
	for c in n.get_children():
		var s := _find_skeleton(c)
		if s != null:
			return s
	return null


## Attaches the model to a CharacterModel and hides the procedural meshes. Returns false (and frees
## itself) when the file has no usable humanoid skeleton.
func attach(p_rig: Node3D, scene: Node3D) -> bool:
	rig = p_rig
	_scene = scene
	add_child(scene)
	skel = _find_skeleton(scene)
	if skel == null:
		push_warning("SkinnedModel: no Skeleton3D in the model")
		return false
	var idx := {}
	for b in skel.get_bone_count():
		idx[_norm(skel.get_bone_name(b))] = b
	for need in ["Hips", "Spine", "Head", "LeftArm", "LeftForeArm", "RightArm", "RightForeArm", "LeftUpLeg", "LeftLeg", "RightUpLeg", "RightLeg"]:
		if not idx.has(need):
			push_warning("SkinnedModel: bone %s missing" % need)
			return false
	_hips = idx["Hips"]
	# rest pose of the procedural rig, captured once
	rig.call("_rest_pose")
	for pv in ["hips", "torso", "chest", "head"]:
		var node: Node3D = rig.get(pv)
		_pivot_rest[pv] = (rig.global_transform.basis.inverse() * node.global_transform.basis).orthonormalized()
	# face the model the way the rig faces (-Z) and stand it on the ground at the rig's hip height
	skel.reset_bone_poses()
	var gl := func(b: int) -> Vector3: return skel.global_transform * skel.get_bone_global_rest(b).origin
	var left: Vector3 = rig.global_transform.basis.inverse() * (gl.call(idx["LeftUpLeg"]) - gl.call(idx["RightUpLeg"]))
	left.y = 0.0
	if left.length() > 1e-5:
		var ang := atan2(left.z, -left.x)
		scene.rotate_y(-ang)
	var lf: int = idx.get("LeftFoot", idx["LeftLeg"])
	var rf: int = idx.get("RightFoot", idx["RightLeg"])
	var feet_y := minf(rig.to_local(gl.call(lf)).y, rig.to_local(gl.call(rf)).y)
	var hips_y: float = rig.to_local(gl.call(_hips)).y
	var h := hips_y - feet_y
	if h > 1e-4:
		scene.scale *= float(rig.get("HIP_Y")) / h
	# ankles (foot bones) at the rig's ankle height
	var now_feet := minf(rig.to_local(gl.call(lf)).y, rig.to_local(gl.call(rf)).y)
	scene.position.y += float(rig.get("ANKLE_Y")) - now_feet
	# bone roles
	var A := func(a: String, b: String) -> Array: return ["aim", a, b]
	var plan := {
		"Hips": ["delta", "hips"], "Spine": ["delta", "torso"], "Spine1": ["delta", "torso"], "Spine2": ["delta", "chest"],
		"Neck": ["delta", "chest"], "Head": ["delta", "head"], "LeftShoulder": ["delta", "chest"], "RightShoulder": ["delta", "chest"],
		"LeftArm": A.call("arm_l", "fore_l"), "LeftForeArm": A.call("fore_l", "wrist_l"),
		"RightArm": A.call("arm_r", "fore_r"), "RightForeArm": A.call("fore_r", "wrist_r"),
		"LeftUpLeg": A.call("leg_l", "knee_l"), "LeftLeg": A.call("knee_l", "foot_l"),
		"RightUpLeg": A.call("leg_r", "knee_r"), "RightLeg": A.call("knee_r", "foot_r"),
		"LeftFoot": A.call("foot_l", "toe_l"), "RightFoot": A.call("foot_r", "toe_r"),
	}
	for k in plan.keys():
		if idx.has(k):
			_map[idx[k]] = plan[k]
	# feet aim only when a toe bone exists to define the foot direction
	for f in ["LeftFoot", "RightFoot"]:
		if idx.has(f) and not idx.has(f.replace("Foot", "ToeBase")):
			_map.erase(idx[f])
	_order = []
	var added := {}
	while _order.size() < skel.get_bone_count():
		var progressed := false
		for b in skel.get_bone_count():
			if added.has(b):
				continue
			var p := skel.get_bone_parent(b)
			if p < 0 or added.has(p):
				_order.append(b)
				added[b] = true
				progressed = true
		if not progressed:
			break
	for b in _order:
		_rest_g[b] = skel.get_bone_global_rest(b).basis.orthonormalized()
	_hips_rest_pos = skel.get_bone_rest(_hips).origin
	_hip_y = float(rig.get("HIP_Y"))
	_hide_procedural(rig)
	return true


func _hide_procedural(n: Node) -> void:
	for c in n.get_children():
		if c == self or c == rig.get("gun"):
			continue
		if c is MeshInstance3D:
			(c as MeshInstance3D).visible = false
		_hide_procedural(c)


## World position of a procedural joint (pivots plus derived wrist / toe points).
func _joint(key: String) -> Vector3:
	match key:
		"wrist_l":
			return (rig.get("fore_l") as Node3D).global_transform * Vector3(0, -float(rig.get("FOREARM")), 0)
		"wrist_r":
			return (rig.get("fore_r") as Node3D).global_transform * Vector3(0, -float(rig.get("FOREARM")), 0)
		"toe_l":
			return (rig.get("foot_l") as Node3D).global_transform * Vector3(0, -0.05, -0.16)
		"toe_r":
			return (rig.get("foot_r") as Node3D).global_transform * Vector3(0, -0.05, -0.16)
	return (rig.get(key) as Node3D).global_position


func _process(_delta: float) -> void:
	if skel == null or rig == null or not rig.visible:
		return
	var sk_inv := skel.global_transform.affine_inverse()
	var sk_b := skel.global_transform.basis.orthonormalized()
	var rig_b := rig.global_transform.basis.orthonormalized()
	var cur_b := {}
	var cur_p := {}
	for b in _order:
		var parent := skel.get_bone_parent(b)
		var pb: Basis = cur_b[parent] if parent >= 0 else Basis()
		var pp: Vector3 = cur_p[parent] if parent >= 0 else Vector3.ZERO
		var rest := skel.get_bone_rest(b)
		var pos := pp + pb * rest.origin
		if b == _hips:
			# hips height / sway follow the rig (crouch, kneel, squat, gait bob)
			var hp: Vector3 = (rig.get("hips") as Node3D).position - Vector3(0, _hip_y, 0)
			pos = rest.origin + sk_inv.basis * (rig.global_transform.basis * hp)
			skel.set_bone_pose_position(b, pos)
		var g := pb * rest.basis.orthonormalized()
		if _map.has(b):
			var m: Array = _map[b]
			if m[0] == "delta":
				var pv: Node3D = rig.get(m[1])
				var cur := (rig_b.inverse() * pv.global_transform.basis).orthonormalized()
				var d_local: Basis = cur * (_pivot_rest[m[1]] as Basis).inverse()
				# rig space -> skeleton space
				var to_sk := sk_b.inverse() * rig_b
				g = (to_sk * d_local * to_sk.inverse()) * (_rest_g[b] as Basis)
			else:
				var want := sk_inv.basis * (_joint(m[2]) - _joint(m[1]))
				var child_dir := _child_dir(b)
				if want.length() > 1e-5 and child_dir.length() > 1e-5:
					var now_dir := (g * child_dir).normalized()
					g = Basis(Quaternion(now_dir, want.normalized())) * g
		cur_b[b] = g.orthonormalized()
		cur_p[b] = pos
		var local: Basis = pb.inverse() * (cur_b[b] as Basis)
		skel.set_bone_pose_rotation(b, local.get_rotation_quaternion())


## Rest direction from a bone to its first child (in the bone's own space).
func _child_dir(b: int) -> Vector3:
	var kids := skel.get_bone_children(b)
	if kids.is_empty():
		return Vector3.UP
	var best := Vector3.ZERO
	for k in kids:
		var o := skel.get_bone_rest(k).origin
		if o.length() > best.length():
			best = o
	return best
