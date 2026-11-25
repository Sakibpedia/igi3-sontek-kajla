extends RefCounted
## Hitscan bullets with material penetration.
## World StaticBody3D nodes carry meta "mat": concrete | brick | metal | wood | glass | cloth | water.
## Thin materials let bullets through with reduced damage; characters are over-penetrated.

const BULLET_MASK := 1 | 2 | 4 | 8 | 32
const PEN_FACTOR := {"wood": 0.6, "metal": 0.5, "glass": 0.85, "cloth": 0.95, "flesh": 0.4, "water": 0.3}
const PEN_STEP := 0.07


## Fires one bullet. Returns {"hit_actor": bool, "headshot": bool, "end": Vector3, "killed": bool}.
static func fire(world: World3D, from: Vector3, dir: Vector3, damage: float, max_range: float, max_pen: int, shooter: Node, exclude: Array, tracer: bool = false) -> Dictionary:
	var result := {"hit_actor": false, "headshot": false, "end": from + dir * max_range, "killed": false, "victim": null}
	if world == null:
		return result
	var space := world.direct_space_state
	var ex: Array[RID] = []
	for r in exclude:
		ex.append(r)
	var origin := from
	var remaining := max_range
	var dmg := damage
	var pens := 0
	var first_end := from + dir * max_range
	var fx: Node = null
	if Game.level != null and is_instance_valid(Game.level):
		fx = Game.level.get("fx")
	while remaining > 0.1 and dmg > 1.0:
		var q := PhysicsRayQueryParameters3D.create(origin, origin + dir * remaining, BULLET_MASK, ex)
		var hit := space.intersect_ray(q)
		if hit.is_empty():
			break
		var pos: Vector3 = hit["position"]
		var nrm: Vector3 = hit["normal"]
		var col = hit["collider"]
		remaining -= origin.distance_to(pos)
		if pens == 0:
			first_end = pos
		var mat := "concrete"
		if col != null and col.has_method("take_damage"):
			mat = "flesh"
			var dealt := dmg
			if remaining < max_range * 0.4:
				dealt *= 0.75
			var head := false
			if col.has_method("is_headshot") and col.is_headshot(pos):
				head = true
				dealt *= 2.6
			var was_alive: bool = col.has_method("is_alive") and col.is_alive()
			col.take_damage(dealt, from, shooter)
			if was_alive and col.has_method("is_alive") and not col.is_alive():
				result["killed"] = true
			if not result["hit_actor"]:
				result["hit_actor"] = true
				result["headshot"] = head
				result["victim"] = col
			ex.append(hit["rid"])
		elif col != null and col.has_meta("mat"):
			mat = str(col.get_meta("mat"))
		if col != null and col.has_method("bullet_hit") and mat != "flesh":
			col.bullet_hit(dmg, pos, shooter)
		if fx != null:
			fx.impact(pos, nrm, mat)
		if not PEN_FACTOR.has(mat) or pens >= max_pen:
			break
		dmg *= float(PEN_FACTOR[mat])
		pens += 1
		origin = pos + dir * PEN_STEP
		remaining -= PEN_STEP
	result["end"] = first_end
	if tracer and fx != null:
		fx.tracer(from, first_end)
	return result


## Random direction inside a cone of half-angle `spread_deg` around `forward`.
static func spread_dir(forward: Vector3, spread_deg: float) -> Vector3:
	var f := forward.normalized()
	var side := f.cross(Vector3.UP)
	if side.length() < 0.01:
		side = Vector3.RIGHT
	side = side.normalized()
	var up := side.cross(f).normalized()
	var a := deg_to_rad(spread_deg) * sqrt(randf())
	var th := randf() * TAU
	return (f + (side * cos(th) + up * sin(th)) * tan(a)).normalized()


static func has_line_of_sight(world: World3D, from: Vector3, to: Vector3, exclude: Array = []) -> bool:
	var space := world.direct_space_state
	var ex: Array[RID] = []
	for r in exclude:
		ex.append(r)
	var q := PhysicsRayQueryParameters3D.create(from, to, 1, ex)
	var hit := space.intersect_ray(q)
	if hit.is_empty():
		return true
	var col = hit["collider"]
	if col != null and col.has_meta("mat"):
		var m := str(col.get_meta("mat"))
		if m == "glass":
			return true
	return false
