extends RefCounted
## Native 3-point face alignment for photo faces - pure GDScript and Godot's Image / Transform2D, no
## external tools or models.
##
## The player clicks three points on a photo, in this order: the eye on the LEFT of the picture, the eye
## on the RIGHT of the picture, the centre of the mouth. alignment() turns them into one Transform2D
## (photo pixels -> aligned-image pixels):
##   * rotation - minus the angle of the eye line, so the eyes end up exactly horizontal;
##   * scale    - ONE factor for both directions, from the eyes-to-mouth distance measured at right angles
##                to the eye line, so the face is never stretched one way only;
##   * offset   - the point midway between the eyes goes to EYE_MID.
## render_aligned() then crops the part of the photo it needs (Image.get_region), shrinks it with a
## Lanczos filter (Image.resize) when the photo has more detail than the output, and resamples it through
## the rotation (bilinear). The saved 512 x 512 image is straight, square and to scale before the shader
## ever sees it. head_to_aligned() / shader_matrix() give the face shader its flat (planar) projection:
## head metres -> image UV, from the same constants.

const OUT_SIZE := 512
## where the midpoint between the eyes lands in the aligned image (pixels)
const EYE_MID := Vector2(256.0, 246.0)
## eye line -> centre of the mouth in the aligned image (pixels)
const MOUTH_DIST := 136.0
## the sculpted head (CharacterModel / face.gdshader): the lips' seam is 0.0712 m below the eye line and
## the eyes sit 0.031 m either side of the middle
const HEAD_MOUTH_M := 0.0712
const HEAD_EYE_X := 0.031
## aligned-image pixels per metre of head
const PX_PER_M := MOUTH_DIST / HEAD_MOUTH_M


## Puts the clicks in the right order: the eyes as [left of the picture, right of the picture], decided by
## which side of the eye line the mouth is on (works for sideways or upside-down photos too).
static func order_points(a: Vector2, b: Vector2, m: Vector2) -> Array:
	var mid := (a + b) * 0.5
	var eye_vec := b - a
	var down := Vector2(-eye_vec.y, eye_vec.x)   # eye_vec turned 90 degrees towards the chin
	if (m - mid).dot(down) < 0.0:
		return [b, a, m]
	return [a, b, m]


## Photo pixels -> aligned-image pixels. l / r: the eyes on the left / right of the picture, m: the centre
## of the mouth - all in photo pixels.
static func alignment(l: Vector2, r: Vector2, m: Vector2) -> Transform2D:
	var mid := (l + r) * 0.5                       # centre point between the eyes
	var eye_vec := r - l
	var angle := atan2(eye_vec.y, eye_vec.x)       # tilt of the eye line in radians (0 = level)
	var down := Vector2(-sin(angle), cos(angle))   # unit vector at right angles to the eye line, chinwards
	var mouth_d := (m - mid).dot(down)             # eyes-to-mouth distance (a click off to one side is ignored)
	if mouth_d < 1.0:
		mouth_d = maxf(eye_vec.length() * 1.15, 1.0)
	var s := MOUTH_DIST / mouth_d                  # the same scale across and down
	# rotate by -angle (eyes level) and scale by s, then move the eye midpoint onto EYE_MID
	var xf := Transform2D(-angle, Vector2(s, s), 0.0, Vector2.ZERO)
	xf.origin = EYE_MID - xf.basis_xform(mid)
	return xf


## Plausibility of the three clicks; "" when they look like a face, otherwise what to fix (Bengali).
static func check_points(l: Vector2, r: Vector2, m: Vector2) -> String:
	var eye_d := l.distance_to(r)
	if eye_d < 12.0:
		return "দুই চোখের বিন্দু প্রায় একই জায়গায় — 'আবার শুরু' চেপে দুই চোখের মণিতে ক্লিক করুন।"
	var mid := (l + r) * 0.5
	var angle := atan2(r.y - l.y, r.x - l.x)
	var down := Vector2(-sin(angle), cos(angle))
	var along := Vector2(cos(angle), sin(angle))
	var md := (m - mid).dot(down)
	if md < eye_d * 0.45 or md > eye_d * 2.6:
		return "মুখের বিন্দুটি চোখ থেকে অস্বাভাবিক কাছে বা দূরে — 'আবার শুরু' চেপে ঠোঁটের ঠিক মাঝখানে ক্লিক করুন।"
	if absf((m - mid).dot(along)) > eye_d * 0.6:
		return "মুখের বিন্দুটি মুখের মাঝ বরাবর নয় — 'আবার শুরু' চেপে ঠোঁটের মাঝখানে ক্লিক করুন।"
	return ""


## Rotation (degrees) and scale the alignment applies - shown to the player.
static func describe(xf: Transform2D) -> Vector2:
	return Vector2(rad_to_deg(xf.get_rotation()), xf.x.length())


## Head space (metres: x across, y up from the eye line) -> aligned-image pixels. The model faces -Z, so
## its right side (+x) shows on the LEFT of a frontal photo; image y grows downwards.
static func head_to_aligned() -> Transform2D:
	return Transform2D(Vector2(-PX_PER_M, 0.0), Vector2(0.0, -PX_PER_M), EYE_MID)


## Where an old, unaligned photo was assumed to sit: cover-fitted into a 400 x 512 crop with the eyes at
## (200, 269) and 2100 crop pixels per metre of head. Returned as the three points [left eye, right eye,
## mouth] in photo pixels, so old photos go through exactly the same (undistorted) math.
static func default_points(size: Vector2) -> Array:
	var target := 400.0 / 512.0
	var crop := Rect2(Vector2.ZERO, size)
	if size.x / maxf(size.y, 1.0) > target:
		var w := size.y * target
		crop = Rect2(Vector2((size.x - w) * 0.5, 0.0), Vector2(w, size.y))
	else:
		var h := size.x / target
		crop = Rect2(Vector2(0.0, (size.y - h) * 0.5), Vector2(size.x, h))
	var k := 2100.0 * crop.size.y / 512.0
	var mid := crop.position + Vector2(0.5, 0.526) * crop.size
	return [mid - Vector2(HEAD_EYE_X * k, 0.0), mid + Vector2(HEAD_EYE_X * k, 0.0), mid + Vector2(0.0, HEAD_MOUTH_M * k)]


## Head space -> photo pixels for a photo with this alignment (photo -> aligned).
static func head_to_photo(xf: Transform2D) -> Transform2D:
	return xf.affine_inverse() * head_to_aligned()


## The face shader's `face_xform` (mat4): head metres (x, y - eye_y, 0, 1) -> photo UV. Dividing by the
## image size per axis only converts pixels to 0..1 texture coordinates - it does not stretch anything.
static func shader_matrix(head_to_px: Transform2D, size: Vector2) -> Transform3D:
	var to_uv := Transform2D(Vector2(1.0 / maxf(size.x, 1.0), 0.0), Vector2(0.0, 1.0 / maxf(size.y, 1.0)), Vector2.ZERO)
	var t := to_uv * head_to_px
	return Transform3D(Basis(Vector3(t.x.x, t.x.y, 0.0), Vector3(t.y.x, t.y.y, 0.0), Vector3(0.0, 0.0, 1.0)), Vector3(t.origin.x, t.origin.y, 0.0))


## The aligned face image (out_size x out_size; OUT_SIZE for saving, smaller for a quick preview):
##   1) crop  - only the part of the photo the output square comes from (+ a 2 px border for the filter);
##   2) shrink - when the photo has more pixels than the output needs, Lanczos-resize the crop first so
##      the result is not aliased;
##   3) rotate / scale / move - every output pixel is mapped back through the alignment and the photo is
##      sampled bilinearly. Outside the photo the nearest edge pixel is repeated (the shader fades the
##      edges out anyway).
static func render_aligned(src: Image, xf: Transform2D, out_size: int = OUT_SIZE) -> Image:
	var img: Image = src.duplicate()
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGB8)
	var k := float(out_size) / float(OUT_SIZE)
	# output pixel -> aligned pixel -> photo pixel
	var inv := xf.affine_inverse() * Transform2D(Vector2(1.0 / k, 0.0), Vector2(0.0, 1.0 / k), Vector2.ZERO)
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for c in [Vector2.ZERO, Vector2(out_size, 0), Vector2(0, out_size), Vector2(out_size, out_size)]:
		var p: Vector2 = inv * (c as Vector2)
		lo = lo.min(p)
		hi = hi.max(p)
	var full := Rect2i(Vector2i.ZERO, img.get_size())
	var want := Rect2i(Vector2i(floori(lo.x) - 2, floori(lo.y) - 2), Vector2i(ceili(hi.x - lo.x) + 5, ceili(hi.y - lo.y) + 5))
	var cut := full.intersection(want)
	if cut.size.x < 2 or cut.size.y < 2:
		var blank := Image.create(out_size, out_size, false, Image.FORMAT_RGB8)
		blank.fill(Color(0.56, 0.39, 0.29))
		return blank
	# 1) crop
	var crop := img.get_region(cut)
	# 2) shrink when the photo is more detailed than the output
	var src_per_out := inv.x.length()
	if src_per_out > 1.2:
		var nw := maxi(2, int(round(float(cut.size.x) / src_per_out)))
		var nh := maxi(2, int(round(float(cut.size.y) / src_per_out)))
		crop.resize(nw, nh, Image.INTERPOLATE_LANCZOS)
	var cw := crop.get_width()
	var ch := crop.get_height()
	var fx := float(cw) / float(cut.size.x)
	var fy := float(ch) / float(cut.size.y)
	# 3) output pixel centre -> crop pixel index, one affine map stepped across the rows
	var to_crop := Transform2D(Vector2(fx, 0.0), Vector2(0.0, fy), Vector2(-float(cut.position.x) * fx, -float(cut.position.y) * fy)) * inv
	var ax := to_crop.x
	var ay := to_crop.y
	var o0 := to_crop.origin + (ax + ay) * 0.5 - Vector2(0.5, 0.5)
	var data := crop.get_data()
	var out := PackedByteArray()
	out.resize(out_size * out_size * 3)
	var maxx := float(cw - 1)
	var maxy := float(ch - 1)
	var w := 0
	for y in range(out_size):
		var row := o0 + ay * float(y)
		for x in range(out_size):
			var q := row + ax * float(x)
			var qx := clampf(q.x, 0.0, maxx)
			var qy := clampf(q.y, 0.0, maxy)
			var x0 := int(qx)
			var y0 := int(qy)
			var x1 := mini(x0 + 1, cw - 1)
			var y1 := mini(y0 + 1, ch - 1)
			var tx := qx - float(x0)
			var ty := qy - float(y0)
			var i00 := (y0 * cw + x0) * 3
			var i10 := (y0 * cw + x1) * 3
			var i01 := (y1 * cw + x0) * 3
			var i11 := (y1 * cw + x1) * 3
			var t0 := float(data[i00]) + (float(data[i10]) - float(data[i00])) * tx
			var b0 := float(data[i01]) + (float(data[i11]) - float(data[i01])) * tx
			out[w] = int(t0 + (b0 - t0) * ty + 0.5)
			var t1 := float(data[i00 + 1]) + (float(data[i10 + 1]) - float(data[i00 + 1])) * tx
			var b1 := float(data[i01 + 1]) + (float(data[i11 + 1]) - float(data[i01 + 1])) * tx
			out[w + 1] = int(t1 + (b1 - t1) * ty + 0.5)
			var t2 := float(data[i00 + 2]) + (float(data[i10 + 2]) - float(data[i00 + 2])) * tx
			var b2 := float(data[i01 + 2]) + (float(data[i11 + 2]) - float(data[i01 + 2])) * tx
			out[w + 2] = int(t2 + (b2 - t2) * ty + 0.5)
			w += 3
	return Image.create_from_data(out_size, out_size, false, Image.FORMAT_RGB8, out)


# =============================================================================
#  41-LANDMARK FIT  —  the real photo -> 3-D head conversion
# =============================================================================
## Canonical positions of the 41 landmarks on the sculpted head, in head metres
## (x across, y up from the eye line).  The model faces -Z, so the person's LEFT
## eye is on the RIGHT of a frontal photo (negative head x).  These numbers come
## from the same constants the skull and the face shader use, so a fit maps the
## photo straight onto the geometry instead of guessing from three clicks.
static var _canon_cache: PackedVector2Array = PackedVector2Array()

static func canonical_landmarks() -> PackedVector2Array:
	if _canon_cache.size() == 41:
		return _canon_cache
	var c := PackedVector2Array()
	var ex := HEAD_EYE_X
	var my := -HEAD_MOUTH_M
	# 0-8  person's LEFT eye (image right, head -x)
	c.append(Vector2(-ex + 0.0100,  0.0000)) # 0 inner corner
	c.append(Vector2(-ex + 0.0080,  0.0042)) # 1 upper-inner
	c.append(Vector2(-ex,           0.0055)) # 2 upper-mid
	c.append(Vector2(-ex - 0.0080,  0.0042)) # 3 upper-outer
	c.append(Vector2(-ex - 0.0110,  0.0000)) # 4 outer corner
	c.append(Vector2(-ex - 0.0080, -0.0034)) # 5 lower-outer
	c.append(Vector2(-ex,          -0.0045)) # 6 lower-mid
	c.append(Vector2(-ex + 0.0080, -0.0034)) # 7 lower-inner
	c.append(Vector2(-ex,           0.0000)) # 8 pupil
	# 9-17 person's RIGHT eye (image left, head +x) - mirror of the left eye
	for i in 9:
		var p: Vector2 = c[i]
		c.append(Vector2(-p.x, p.y))
	# 18-22 nose
	c.append(Vector2( 0.0000, -0.0060)) # 18 bridge top
	c.append(Vector2(-0.0125, -0.0470)) # 19 left nostril (image right)
	c.append(Vector2( 0.0000, -0.0440)) # 20 nose tip
	c.append(Vector2( 0.0125, -0.0470)) # 21 right nostril (image left)
	c.append(Vector2( 0.0000, -0.0250)) # 22 bridge mid
	# 23-31 jaw, viewer-left (head +x) -> chin -> viewer-right (head -x)
	c.append(Vector2( 0.0700, -0.0320))
	c.append(Vector2( 0.0780, -0.0580))
	c.append(Vector2( 0.0700, -0.0840))
	c.append(Vector2( 0.0500, -0.1060))
	c.append(Vector2( 0.0270, -0.1190))
	c.append(Vector2( 0.0000, -0.1240))
	c.append(Vector2(-0.0270, -0.1190))
	c.append(Vector2(-0.0500, -0.1060))
	c.append(Vector2(-0.0700, -0.0840))
	# 32-40 mouth, viewer-left (head +x) -> right, then lower lip -> centre
	c.append(Vector2( 0.0240, my          )) # 32 left corner
	c.append(Vector2( 0.0140, my + 0.0035)) # 33 upper-left
	c.append(Vector2( 0.0000, my + 0.0050)) # 34 upper-mid
	c.append(Vector2(-0.0140, my + 0.0035)) # 35 upper-right
	c.append(Vector2(-0.0240, my          )) # 36 right corner
	c.append(Vector2(-0.0140, my - 0.0045)) # 37 lower-right
	c.append(Vector2( 0.0000, my - 0.0060)) # 38 lower-mid
	c.append(Vector2( 0.0140, my - 0.0045)) # 39 lower-left
	c.append(Vector2( 0.0000, my + 0.0015)) # 40 cupid bow / centre
	_canon_cache = c
	return c


## Friendly validation of the 41 clicks.  The fit itself is robust, so this only
## catches genuinely impossible clicks (and never blocks a slightly odd face).
static func check_landmarks(pts: Array) -> String:
	if pts.size() != 41:
		return "%s/৪১ বিন্দু দেওয়া আছে — সব ৪১টি বিন্দু বসান। (Placed %d of 41 points.)" % [Game.bn(pts.size()), pts.size()]
	var le: Vector2 = pts[8]
	var re: Vector2 = pts[17]
	var mouth: Vector2 = pts[40]
	var eye_d := le.distance_to(re)
	if eye_d < 10.0:
		return "দুই চোখের মণি প্রায় একই জায়গায় — ৯ ও ১৮ নম্বর বিন্দু দুই চোখের মণিতে বসান।"
	if mouth.y <= (le.y + re.y) * 0.5 + eye_d * 0.25:
		return "ঠোঁটের বিন্দুটি চোখের ওপরে আছে — ৪১ নম্বর বিন্দু ঠোঁটের মাঝখানে বসান।"
	return ""


## Least-squares similarity (Umeyama / Procrustes) from 2-D photo points to the
## canonical 3-D head landmarks.  One rotation + ONE uniform scale + an offset -
## a photo can never be stretched.  Both the photo and its mirror are tried;
## selfies and front-camera shots are mirrored automatically.
static func _similarity(src: Array, dst: PackedVector2Array) -> Dictionary:
	var n: int = mini(src.size(), dst.size())
	if n < 3:
		return {}
	var sc := Vector2.ZERO
	var dc := Vector2.ZERO
	for i in n:
		sc += src[i] as Vector2
		dc += dst[i]
	sc /= float(n)
	dc /= float(n)
	var re := 0.0
	var im := 0.0
	var den := 0.0
	for i in n:
		var p: Vector2 = (src[i] as Vector2) - sc
		var q: Vector2 = dst[i] - dc
		re += p.x * q.x + p.y * q.y
		im += p.x * q.y - p.y * q.x
		den += p.x * p.x + p.y * p.y
	if den < 1e-8:
		return {}
	var kr := re / den
	var ki := im / den
	var s := sqrt(kr * kr + ki * ki)
	if s < 1e-9 or s > 1e6:
		return {}
	var ang := atan2(ki, kr)
	var xf := Transform2D(ang, Vector2(s, s), 0.0, dc - Transform2D(ang, Vector2(s, s), 0.0, Vector2.ZERO).basis_xform(sc))
	var e2 := 0.0
	for i in n:
		e2 += (xf * (src[i] as Vector2)).distance_squared_to(dst[i])
	return {"xf": xf, "rms": sqrt(e2 / float(n)), "scale": s, "angle": rad_to_deg(ang)}


## Full fit.  Returns a dictionary with the photo->aligned transform, the fit
## quality and the measured 3-D face shape (for the skull mesh).
static func fit_landmarks(pts: Array) -> Dictionary:
	if pts.size() != 41:
		return {"ok": false, "error": "৪১টি বিন্দু প্রয়োজন / 41 points required"}
	var canon := canonical_landmarks()
	var best := {}
	var best_mirror := false
	for mirror in [false, true]:
		var src: Array = []
		for i in 41:
			var p: Vector2 = pts[i]
			src.append(Vector2(-p.x, p.y) if mirror else p)
		var f := _similarity(src, canon)
		if f.is_empty():
			continue
		if best.is_empty() or float(f["rms"]) < float(best["rms"]):
			best = f
			best_mirror = mirror
	if best.is_empty():
		return {"ok": false, "error": "বিন্দুগুলো থেকে মুখ মেলানো যায়নি — আবার চেষ্টা করুন।"}
	var photo_to_head: Transform2D = best["xf"]
	var rms_m: float = float(best["rms"])
	var rms_px := rms_m * PX_PER_M
	# photo -> aligned image (the saved 512 x 512 texture)
	var to_aligned: Transform2D = head_to_aligned() * photo_to_head
	return {
		"ok": true,
		"xf": to_aligned,
		"photo_to_head": photo_to_head,
		"mirrored": best_mirror,
		"rms": rms_m,
		"rms_px": rms_px,
		"scale": float(best["scale"]),
		"angle": float(best["angle"]),
		"shape": shape_from_landmarks(best_mirror, pts, photo_to_head),
	}


static func quality_text(rms_px: float) -> String:
	if rms_px < 6.0:
		return "চমৎকার (Excellent)"
	if rms_px < 12.0:
		return "ভালো (Good)"
	if rms_px < 20.0:
		return "ঠিক আছে (Acceptable)"
	return "কম নিখুঁত — বিন্দুগুলো আবার দেখুন (Check points)"


## Convert the fitted landmarks into the head-shape sliders CharacterModel uses.
## Every measurement is compared with the canonical head, so the sculpted skull
## follows the person's actual width / jaw / eye / nose / lip proportions.
static func shape_from_landmarks(mirrored: bool, pts: Array, photo_to_head: Transform2D) -> Dictionary:
	var h: Array = []
	for p in pts:
		var v: Vector2 = p
		if mirrored:
			v.x = -v.x
		h.append(photo_to_head * v)
	var canon := canonical_landmarks()
	var out := {}
	var rel := func(idx_a: int, idx_b: int, expected: float) -> float:
		if expected <= 0.0:
			return 0.0
		var got := (h[idx_a] as Vector2).distance_to(h[idx_b] as Vector2)
		return clampf((got / expected - 1.0) * 1.6, -0.55, 0.55)
	out["fw"]       = rel.call(23, 31, canon[23].distance_to(canon[31]))
	out["jaw"]      = rel.call(25, 29, canon[25].distance_to(canon[29]))
	out["chin"]     = rel.call(18, 28, canon[18].distance_to(canon[28]))
	out["cheek"]    = rel.call(24, 30, canon[24].distance_to(canon[30]))
	out["eye_size"] = rel.call(2, 6, canon[2].distance_to(canon[6]))
	out["eye_sp"]   = rel.call(8, 17, canon[8].distance_to(canon[17]))
	out["nose_w"]   = rel.call(19, 21, canon[19].distance_to(canon[21]))
	out["nose_l"]   = rel.call(18, 20, canon[18].distance_to(canon[20]))
	out["lip_full"] = rel.call(34, 38, canon[34].distance_to(canon[38]))
	out["lip_w"]    = rel.call(32, 36, canon[32].distance_to(canon[36]))
	var tilt := ((h[0] as Vector2).y - (h[4] as Vector2).y + (h[9] as Vector2).y - (h[13] as Vector2).y) * 0.25
	out["eye_tilt"] = clampf(tilt * 35.0, -0.55, 0.55)
	var got_arch := (h[2] as Vector2).y - ((h[1] as Vector2).y + (h[3] as Vector2).y) * 0.5
	var can_arch := canon[2].y - (canon[1].y + canon[3].y) * 0.5
	out["brow_arch"] = clampf((got_arch - can_arch) * 90.0, -0.55, 0.55)
	return out
