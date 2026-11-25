// Head shader: puts a face photo on the sculpted 3D head built by CharacterModel.gd.
// - Strict planar (flat) projection: one affine matrix, face_xform, maps head-space metres (x across,
//   y up from the eye line; z is ignored) to the photo's UV - rotation, ONE uniform scale and an offset,
//   so the photo is never stretched in one direction (FaceAlign.gd builds it). Photos aligned in the
//   customiser are already cropped, straightened and scaled to a 512 x 512 layout before they get here.
// - Soft edges: the photo fades into the skin towards the border of its rectangle (vignette), outside
//   the face oval (in head metres, independent of the photo) and where the head turns away from the
//   projection direction.
// - In-shader unsharp mask keeps small photos crisp; runtime mipmaps keep them stable at distance.
// - Outside the face oval the head is shaded with the skin and hair colours sampled from the same
//   photo, so the photo melts into the neck, ears and scalp instead of looking like a sticker.
// - Background pixels near the edge of the photo are rejected by colour distance.
// - Without a photo (generic civilians) the same head gets procedural eyes, brows and lips.
shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

uniform sampler2D face_tex : source_color, filter_linear_mipmap, repeat_disable;
uniform bool has_photo = false;
uniform vec2 tex_size = vec2(512.0, 512.0);
// head metres -> photo UV (planar): uv = (face_xform * vec4(x, y - eye_y, 0, 1)).xy. The default is the
// customiser's aligned 512 x 512 layout: eyes' midpoint at (256, 246) px, mouth 136 px below it.
uniform mat4 face_xform = mat4(vec4(-3.730688, 0.0, 0.0, 0.0), vec4(0.0, -3.730688, 0.0, 0.0), vec4(0.0, 0.0, 1.0, 0.0), vec4(0.5, 0.480469, 0.0, 1.0));
// width of the soft fade at the photo's border (UV)
uniform float edge_fade = 0.08;
uniform vec4 skin_color : source_color = vec4(0.56, 0.39, 0.29, 1.0);
uniform vec4 hair_color : source_color = vec4(0.05, 0.04, 0.035, 1.0);
uniform vec3 head_center = vec3(0.0, 0.19, 0.0);
uniform vec3 head_radii = vec3(0.081, 0.118, 0.1);
uniform float eye_y = 0.192;
uniform float sharpen = 0.55;
uniform float hair_line = 0.22; // legacy, the hairline now follows hairline()
uniform float long_hair = 0.0;
uniform float hit_flash = 0.0;
// first-person carry: fragments closer to the camera than this (m) are dropped (stipple fade), so
// the hostage on the Freelancer's own shoulder never fills the screen from inside
uniform float near_fade = 0.0;
// procedural face controls (used when has_photo == false). They match the sculpted skull in
// CharacterModel.gd (_skull_point), so painted eyes, nose and lips sit on the modelled ones.
uniform float face_seed = 0.0;
uniform float beard = 0.0;
uniform float brow_thick = 1.0;
uniform vec4 eye_color : source_color = vec4(0.22, 0.13, 0.07, 1.0);
uniform vec4 lip_tint : source_color = vec4(0.6, 0.25, 0.28, 0.0);
uniform float eye_x = 0.031;
uniform float eye_scale = 1.0;
uniform float eye_tilt = 0.0;
uniform float brow_arch = 0.0;
uniform float nose_w = 0.0;
uniform float nose_l = 0.0;
uniform float lip_w = 0.0;
uniform float lip_full = 0.0;
uniform float kajal = 0.0;
uniform float blush = 0.0;
uniform float age = 0.0;
uniform float mole = 0.0;
uniform float female = 0.0;
uniform vec4 bindi_color : source_color = vec4(0.0);
// living face (Phase 3): blink 0 open .. 1 closed, gaze = iris offset in metres (x right, y up),
// nostril = flare 0..1 following the breath (CharacterModel drives all three)
uniform float blink = 0.0;
uniform vec2 gaze = vec2(0.0);
uniform float nostril = 0.0;
// faint red mark on the lips and around them right after tape is peeled off (fades in ~30 s)
uniform float tape_mark = 0.0;
// facial expression (Cox's Bazar update): x fear, y anger, z relief, w struggle (0..1, eased by
// CharacterModel.set_expression). The head mesh itself moves - brows, upper cheeks, mouth corners and
// chin - so a photo face and the painted face change alike (the photo sticks to the moving skin).
uniform vec4 expr = vec4(0.0);

global uniform vec4 fog_color;
global uniform float fog_density;
global uniform float fog_start;
global uniform float thermal;

varying vec3 v_obj;
varying vec3 v_onrm;

void vertex() {
	v_obj = VERTEX;
	v_onrm = NORMAL;
	if (dot(expr, expr) > 0.0001) {
		// head space: x across, y up from the eye line; only the front of the face moves
		float frontw = smoothstep(0.05, 0.5, -NORMAL.z);
		vec2 p = vec2(VERTEX.x, VERTEX.y - eye_y);
		float ax = abs(p.x);
		float sx = sign(p.x);
		vec3 d = vec3(0.0);
		// brows (about 24 mm above the eye line): fear and relief lift them (fear: the inner ends
		// most), anger and struggle pull the inner ends down and together
		float brow = exp(-pow((p.y - 0.024) / 0.013, 2.0)) * (1.0 - smoothstep(0.035, 0.06, ax));
		float inner = exp(-pow((ax - 0.012) / 0.013, 2.0));
		float raise = 0.0048 * expr.x * (0.55 + 0.9 * inner) + 0.0018 * expr.z;
		float knit = 0.0042 * (expr.y + 0.8 * expr.w) * inner;
		d.y += brow * (raise - knit);
		d.x -= brow * sx * knit * 0.5;
		// upper cheeks rise (squint) when struggling, and in a relieved smile
		float cheek = exp(-pow((p.y + 0.028) / 0.016, 2.0)) * exp(-pow((ax - 0.034) / 0.016, 2.0));
		d.y += cheek * 0.0028 * (expr.w + 0.8 * expr.z);
		d.z -= cheek * 0.0012 * expr.z;
		// mouth corners (about 71 mm below the eye line): up and back for relief, down for fear and
		// anger; fear stretches the lips sideways
		float corner = exp(-pow((p.y + 0.0712) / 0.012, 2.0)) * exp(-pow((ax - 0.025) / 0.011, 2.0));
		d.y += corner * (0.0034 * expr.z - 0.0028 * expr.x - 0.0024 * expr.y);
		d.x += corner * sx * 0.0018 * (expr.x + 0.5 * expr.z);
		// chin: jaw clenched / pushed against the tape while struggling
		float chin = (1.0 - smoothstep(-0.125, -0.085, p.y)) * (1.0 - smoothstep(0.02, 0.05, ax));
		d.y -= chin * 0.0024 * expr.w;
		d.z -= chin * 0.0015 * expr.w;
		VERTEX += d * frontw;
	}
}

float h3(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.zyx + 31.32);
	return fract((p.x + p.y) * p.z);
}

float vn3(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	vec3 u = f * f * (3.0 - 2.0 * f);
	float a = mix(mix(h3(i), h3(i + vec3(1, 0, 0)), u.x), mix(h3(i + vec3(0, 1, 0)), h3(i + vec3(1, 1, 0)), u.x), u.y);
	float b = mix(mix(h3(i + vec3(0, 0, 1)), h3(i + vec3(1, 0, 1)), u.x), mix(h3(i + vec3(0, 1, 1)), h3(i + vec3(1, 1, 1)), u.x), u.y);
	return mix(a, b, u.z);
}

// Same curve as CharacterModel.hairline(): height of the hairline round the head (0 = front, PI = back).
float hairline(vec3 q) {
	float az = abs(atan(q.x, -q.z));
	float hm[9] = float[9](0.56, 0.6, 0.42, 0.2, 0.12, 0.16, -0.15, -0.5, -0.6);
	float hf[9] = float[9](0.5, 0.5, 0.4, 0.22, 0.15, 0.15, -0.2, -0.62, -0.72);
	float a[9] = float[9](0.0, 0.45, 0.95, 1.25, 1.5, 1.75, 2.0, 2.4, 3.14159);
	float h = mix(hm[0], hf[0], long_hair);
	for (int i = 1; i < 9; i++) {
		float d = mix(hm[i], hf[i], long_hair) - mix(hm[i - 1], hf[i - 1], long_hair);
		h += d * clamp((az - a[i - 1]) / (a[i] - a[i - 1]), 0.0, 1.0);
	}
	h -= 0.32 * exp(-pow((az - 1.38) / 0.07, 2.0)) * (1.0 - long_hair);
	return h;
}

float ellipse(vec2 p, vec2 c, vec2 r) {
	vec2 d = (p - c) / r;
	return dot(d, d);
}

void fragment() {
	if (near_fade > 0.0 && length(VERTEX) < near_fade) {
		discard;
	}
	vec3 q = (v_obj - head_center) / head_radii;
	vec3 n = normalize(v_onrm);
	float front = -n.z;
	// planar projection along the face's forward axis (the model faces -Z, so its right side, +X, shows
	// on the LEFT of a frontal photo - the matrix carries that mirror)
	vec2 uv = (face_xform * vec4(v_obj.x, v_obj.y - eye_y, 0.0, 1.0)).xy;

	// base: skin with hair cap on scalp / back of the head
	float hl = hairline(q);
	float hair_w = smoothstep(hl - 0.035, hl - 0.004, q.y);
	vec3 base = mix(skin_color.rgb, hair_color.rgb, hair_w);
	float rough = mix(0.55, 0.5, hair_w);
	vec3 col = base;

	// head-to-photo falloff where the surface turns away from the projection (no smeared sides)
	float face_w = smoothstep(0.1, 0.48, front);
	// face oval in head metres (cheek to cheek 0.16 m, brow to chin 0.244 m), the same for every photo
	vec2 e = vec2(v_obj.x / 0.08, (v_obj.y - eye_y + 0.001) / 0.122);
	float oval = length(e);
	face_w *= 1.0 - smoothstep(0.8, 1.0, oval);

	if (has_photo) {
		// vignette: the photo fades out towards the edges of its rectangle, so it never shows as a sticker
		vec2 edge = smoothstep(vec2(0.0), vec2(edge_fade), uv) * (vec2(1.0) - smoothstep(vec2(1.0 - edge_fade), vec2(1.0), uv));
		float vignette = edge.x * edge.y;
		vec2 tuv = clamp(uv, vec2(0.002), vec2(0.998));
		vec2 ts = 1.0 / max(tex_size, vec2(1.0));
		vec3 c = texture(face_tex, tuv).rgb;
		vec3 blur = (texture(face_tex, tuv + vec2(ts.x, 0.0)).rgb + texture(face_tex, tuv - vec2(ts.x, 0.0)).rgb
			+ texture(face_tex, tuv + vec2(0.0, ts.y)).rgb + texture(face_tex, tuv - vec2(0.0, ts.y)).rgb) * 0.25;
		c = clamp(c + (c - blur) * sharpen, 0.0, 1.0);
		// reject photo background near the rim of the oval
		float d_skin = distance(c, skin_color.rgb);
		float d_hair = distance(c, hair_color.rgb);
		float likeness = 1.0 - smoothstep(0.2, 0.42, min(d_skin, d_hair));
		float rim = smoothstep(0.5, 0.92, oval);
		float w = face_w * vignette * mix(1.0, likeness, rim);
		col = mix(base, c, w);
		rough = mix(rough, 0.6, w);
	} else {
		// procedural face for characters without a photo (metric layout, symmetric)
		float fw = smoothstep(0.05, 0.4, front);
		float ax = abs(v_obj.x);
		float my = v_obj.y - eye_y;
		float sgnx = sign(v_obj.x);
		vec3 sp = v_obj * 900.0 + vec3(face_seed);
		float pores = vn3(sp) * 0.6 + vn3(sp * 2.7) * 0.4;
		float blot = vn3(v_obj * 60.0 + vec3(face_seed * 0.37));
		float tip_y = -0.044 - 0.004 * nose_l;
		float aw = 0.0125 * (1.0 + 0.25 * nose_w);
		// skin: warmer cheeks / nose / ears, cooler and darker round the eyes, pores, blotches
		vec3 sk = skin_color.rgb;
		sk *= 0.93 + 0.1 * blot + 0.05 * (pores - 0.5);
		float cheek = exp(-pow((ax - 0.041) / 0.019, 2.0) - pow((my + 0.03) / 0.02, 2.0));
		sk = mix(sk, sk * vec3(1.07, 0.9, 0.86), cheek * 0.5);
		sk = mix(sk, sk * vec3(1.12, 0.82, 0.82), cheek * blush * 0.85);
		float nosetip = exp(-pow(ax / 0.011, 2.0) - pow((my - tip_y) / 0.009, 2.0));
		sk = mix(sk, sk * vec3(1.06, 0.92, 0.88), nosetip * 0.6);
		float socket = exp(-pow((ax - eye_x) / (0.02 * eye_scale), 2.0) - pow((my + 0.002) / (0.015 * eye_scale), 2.0));
		sk = mix(sk, sk * vec3(0.8, 0.75, 0.78), socket * (0.5 + 0.25 * age));
		float nl_x = 0.017 + (-my - 0.045) * 0.55;
		float fold = exp(-pow((ax - nl_x) / (0.0025 + 0.0015 * age), 2.0)) * smoothstep(-0.04, -0.05, my) * smoothstep(-0.088, -0.075, my);
		sk *= 1.0 - fold * (0.05 + 0.25 * age);
		float jawshade = smoothstep(-0.07, -0.11, my) * smoothstep(0.02, 0.05, ax);
		sk *= 1.0 - jawshade * 0.12;
		// age: forehead lines, crow's feet, under-eye creases
		if (age > 0.05) {
			float fl = exp(-pow((my - 0.045) / 0.018, 2.0)) * smoothstep(0.045, 0.02, ax);
			float lines = smoothstep(0.75, 1.0, sin(my * 1250.0 + sin(ax * 90.0) * 1.5));
			sk *= 1.0 - fl * lines * 0.14 * age;
			float crow = exp(-pow((ax - eye_x - 0.019) / 0.006, 2.0) - pow(my / 0.008, 2.0));
			float rays = smoothstep(0.7, 1.0, sin(atan(my, ax - eye_x - 0.012) * 18.0));
			sk *= 1.0 - crow * rays * 0.18 * age;
			float bag = exp(-pow((ax - eye_x) / 0.012, 2.0) - pow((my + 0.0135) / 0.0018, 2.0));
			sk *= 1.0 - bag * 0.25 * age;
		}
		col = mix(col, sk, fw);
		// T-zone sheen: forehead, nose bridge, chin catch the light
		float tz = max(exp(-pow(ax / 0.006, 2.0) - pow((my + 0.02) / 0.03, 2.0)), exp(-pow(ax / 0.035, 2.0) - pow((my - 0.05) / 0.025, 2.0)));
		rough = mix(rough, 0.32, tz * fw);
		// beard / stubble / moustache: individual dots of hair
		if (beard > 0.01) {
			float jaw = smoothstep(-0.028, -0.045, my) * (smoothstep(0.022, 0.034, ax) + smoothstep(-0.075, -0.09, my));
			float stache = smoothstep(-0.069, -0.064, my) * smoothstep(-0.05, -0.056, my) * smoothstep(0.03, 0.022, ax);
			float soul = smoothstep(-0.082, -0.088, my) * smoothstep(0.012, 0.006, ax);
			float region = clamp(jaw + stache + soul, 0.0, 1.0);
			float hairs = smoothstep(0.55 - beard * 0.35, 0.75, vn3(v_obj * 2600.0 + vec3(face_seed)));
			float bw = region * mix(hairs, 1.0, smoothstep(0.6, 1.0, beard));
			col = mix(col, hair_color.rgb * 1.2, bw * fw);
			col = mix(col, col * 0.85, region * beard * 0.4 * fw);
		}
		// eyes: almond sclera tilted by eye_tilt, iris with striations and limbal ring, pupil, catchlight,
		// upper lid crease + lash line, lower lid, optional kajal along both lids with a small wing
		float ex = (ax - eye_x) / (0.0135 * eye_scale);
		float lid_tilt = 0.0006 * ex + eye_tilt * (ax - eye_x);
		float eyv = (my - lid_tilt) / (0.0056 * eye_scale * (1.0 - 0.35 * ex * ex));
		float eye = ex * ex + eyv * eyv;
		float sclera = 1.0 - smoothstep(0.75, 1.0, eye);
		vec3 skin_c = col;
		// sclera: never pure white - warm, a little veined and darker towards the corners
		vec3 white = mix(vec3(0.76, 0.72, 0.67), vec3(0.66, 0.52, 0.48), smoothstep(0.2, 1.0, abs(ex)));
		white *= 0.94 + 0.06 * vn3(vec3(ax * 3000.0, my * 3000.0, face_seed));
		white = mix(white, skin_c, 0.1);
		col = mix(col, white, sclera * fw);
		// tear duct (caruncle): small moist pink mound in the inner corner
		float car = exp(-pow((ax - (eye_x - 0.0125 * eye_scale)) / 0.0018, 2.0) - pow((my - lid_tilt) / 0.0016, 2.0));
		col = mix(col, vec3(0.62, 0.36, 0.36) * (skin_color.rgb * 0.6 + 0.5), car * fw * 0.8);
		vec2 ip = vec2(ax - eye_x - gaze.x * sgnx, (my + 0.0009 - gaze.y) * 1.05) / eye_scale;
		float ir = length(ip);
		float ang = atan(ip.y, ip.x);
		float stri = 0.85 + 0.25 * vn3(vec3(ang * 6.0, ir * 900.0, face_seed));
		float iris = (1.0 - smoothstep(0.0048, 0.0057, ir)) * sclera;
		vec3 ic = eye_color.rgb * stri * (0.65 + 0.6 * smoothstep(0.0, 0.0052, ir));
		ic = mix(ic, ic * 0.35, smoothstep(0.0042, 0.0055, ir));
		col = mix(col, ic, iris * fw);
		float pupil = (1.0 - smoothstep(0.0017, 0.0023, ir)) * sclera;
		col = mix(col, vec3(0.015), pupil * fw);
		// the upper lid and lashes shade the top of the eyeball; the lower edge is moist and pinkish
		float lidshade = smoothstep(-0.2, 0.75, eyv) * sclera;
		col = mix(col, col * 0.55, lidshade * fw * 0.8);
		col = mix(col, col * vec3(1.0, 0.85, 0.85), smoothstep(-0.55, -0.95, eyv) * sclera * fw * 0.4);
		float hl = 1.0 - smoothstep(0.0, 0.0011, length(vec2(ax - eye_x + 0.0015, my - 0.0019)));
		col = mix(col, vec3(1.0), hl * sclera * fw * 0.85);
		rough = mix(rough, 0.08, sclera * fw);
		// blink: the upper lid (skin) slides down over the eyeball, lashes riding on its edge
		float lid_line = 1.05 - 2.1 * blink;
		float cover = sclera * smoothstep(lid_line - 0.12, lid_line + 0.05, eyv);
		col = mix(col, skin_c * 0.9, cover * fw);
		float lid_edge = exp(-pow((eyv - lid_line) / 0.1, 2.0)) * step(eye, 1.0) * step(0.02, blink);
		col = mix(col, vec3(0.03, 0.025, 0.025), lid_edge * fw * 0.9);
		float lash = smoothstep(0.85, 1.0, eye) * (1.0 - smoothstep(1.0, 1.28 + 0.3 * female, eye)) * step(0.0, my - lid_tilt + 0.0008);
		lash *= 0.75 + 0.25 * step(0.4, fract(ax * 1400.0));
		col = mix(col, vec3(0.05, 0.035, 0.03), lash * fw * 0.78);
		float lower = smoothstep(0.9, 1.05, eye) * (1.0 - smoothstep(1.05, 1.5, eye)) * step(my - lid_tilt, -0.0008);
		col = mix(col, col * 0.72, lower * fw * 0.6);
		if (kajal > 0.01) {
			float ring = smoothstep(0.85, 1.0, eye) * (1.0 - smoothstep(1.15, 1.6 + kajal * 0.6, eye));
			float wing = exp(-pow((my - lid_tilt - (ax - eye_x - 0.014) * 0.35) / 0.0011, 2.0)) * smoothstep(0.012, 0.014, ax - eye_x) * smoothstep(0.024, 0.016, ax - eye_x);
			col = mix(col, vec3(0.02, 0.018, 0.02), clamp(ring + wing * kajal, 0.0, 1.0) * kajal * fw);
		}
		float crease = exp(-pow(((my - lid_tilt) - 0.0085 * eye_scale * (1.0 - 0.3 * ex * ex)) / 0.0011, 2.0)) * (1.0 - smoothstep(0.8, 1.15, abs(ex)));
		col = mix(col, col * 0.7, crease * fw * 0.7);
		// eyebrows: strands following the arch (brow_arch lifts the peak)
		float bx = (ax - eye_x + 0.001) / 0.021;
		float by = my - (0.019 + 0.004 * (1.0 - bx * bx) + 0.003 * brow_arch * exp(-pow((bx - 0.25) / 0.45, 2.0)) + lid_tilt * 0.5);
		float strands = 0.6 + 0.4 * smoothstep(0.35, 0.7, vn3(vec3(ax * 3000.0 + my * 900.0, my * 300.0, face_seed)));
		float bthick = 0.0022 + 0.0006 * brow_thick - 0.0005 * female;
		float brow = (1.0 - smoothstep(0.85, 1.0, abs(bx))) * (1.0 - smoothstep(bthick, bthick + 0.0013, abs(by))) * brow_thick * strands;
		brow *= 1.0 - 0.45 * smoothstep(0.0, 1.0, bx);
		vec3 browc = mix(hair_color.rgb, vec3(0.5, 0.48, 0.46), age * 0.4);
		col = mix(col, browc, clamp(brow, 0.0, 1.0) * fw);
		// nose: alar shadows, nostrils, bridge highlight, shadow under the tip
		float ala = exp(-pow((ax - aw * 1.0) / 0.004, 2.0) - pow((my - tip_y + 0.0) / 0.008, 2.0));
		col = mix(col, col * 0.75, ala * fw * 0.6);
		float nos = 1.0 - smoothstep(0.35, 1.0, pow((ax - aw * 0.6) / (0.0034 * (1.0 + 0.2 * nose_w + 0.22 * nostril)), 2.0) + pow((my - tip_y + 0.005) / (0.0021 * (1.0 + 0.15 * nostril)), 2.0));
		col = mix(col, col * vec3(0.38, 0.3, 0.29), nos * fw * 0.62);
		float bridge = exp(-pow(ax / 0.0035, 2.0)) * smoothstep(0.0, -0.01, my) * smoothstep(tip_y - 0.001, tip_y + 0.014, my);
		col = mix(col, col * 1.12, bridge * fw * 0.6);
		float nshadow = exp(-pow(ax / 0.012, 2.0) - pow((my - tip_y + 0.009) / 0.004, 2.0));
		col = mix(col, col * 0.8, nshadow * fw * 0.6);
		// philtrum
		float phil = exp(-pow((ax - 0.004) / 0.0015, 2.0)) * smoothstep(-0.066, -0.06, my) * smoothstep(-0.05, -0.056, my);
		col = mix(col, col * 0.88, phil * fw);
		// lips: cupid's bow, vertical lines, gloss on the lower lip, corners
		float lw = 0.024 * (1.0 + 0.15 * lip_w) * (1.0 - 0.1 * female);
		float uh = 1.0 + 0.4 * lip_full;
		float lx = ax / lw;
		float bow = 0.0015 * exp(-pow(ax / 0.004, 2.0));
		float upper = (1.0 - smoothstep(0.85, 1.0, lx)) * smoothstep(-0.0715, -0.0705, my) * (1.0 - smoothstep(-0.0712 + (0.005 - 0.002 * lx * lx) * uh + bow, -0.0712 + (0.0067 - 0.002 * lx * lx) * uh + bow * 0.5, my));
		float lowerlip = (1.0 - smoothstep(0.75, 0.95, lx)) * (1.0 - smoothstep(-0.0715, -0.0705, my)) * smoothstep(-0.0712 - (0.0083 - 0.003 * lx * lx) * uh, -0.0712 - (0.0063 - 0.003 * lx * lx) * uh, my);
		vec3 lipc = mix(skin_color.rgb * vec3(0.8, 0.55, 0.52), lip_tint.rgb, lip_tint.a);
		float lines = 0.96 + 0.04 * sin(ax * 2600.0);
		float lips = clamp(upper + lowerlip, 0.0, 1.0);
		col = mix(col, lipc * lines * (1.0 - upper * 0.12), lips * fw);
		rough = mix(rough, mix(0.28, 0.18, lip_tint.a), lowerlip * fw);
		float seam = (1.0 - smoothstep(0.0, 0.0011, abs(my + 0.0712))) * (1.0 - smoothstep(0.9, 1.05, lx));
		col = mix(col, vec3(0.1, 0.04, 0.04), seam * fw * 0.85);
		float corner = exp(-pow((ax - lw) / 0.0025, 2.0) - pow((my + 0.0715) / 0.002, 2.0));
		col = mix(col, col * 0.75, corner * fw);
		if (tape_mark > 0.0) {
			float tmr = (1.0 - smoothstep(0.03, 0.039, ax)) * smoothstep(-0.096, -0.088, my) * (1.0 - smoothstep(-0.058, -0.05, my));
			col = mix(col, col * vec3(1.16, 0.82, 0.82), tmr * tape_mark * fw * 0.85);
		}
		// beauty spot (til), placed from the face seed on one cheek
		if (mole > 0.5) {
			vec2 mp = vec2(0.03 + 0.015 * fract(face_seed * 0.71), -0.035 - 0.03 * fract(face_seed * 0.37));
			float side = fract(face_seed * 0.53) > 0.5 ? 1.0 : -1.0;
			float md = length(vec2(v_obj.x * side - mp.x, my - mp.y));
			col = mix(col, vec3(0.12, 0.07, 0.05), (1.0 - smoothstep(0.0011, 0.0017, md)) * fw);
		}
		// teep / bindi between the brows
		if (bindi_color.a > 0.01) {
			float bd = length(vec2(v_obj.x, my - 0.026));
			col = mix(col, bindi_color.rgb, (1.0 - smoothstep(0.0028, 0.0036, bd)) * bindi_color.a * fw);
		}
	}
	// hair cap: strand texture instead of a flat colour
	float strand = vn3(vec3(v_obj.x * 1400.0, v_obj.y * 160.0, v_obj.z * 1400.0) + vec3(face_seed));
	col *= mix(1.0, 0.8 + 0.3 * strand, hair_w * hair_w * (has_photo ? 0.5 : 1.0));
	col = mix(col, vec3(1.0, 0.08, 0.04), hit_flash);
	float dist = length(VERTEX);
	float fogf = clamp(1.0 - exp(-max(dist - fog_start, 0.0) * fog_density), 0.0, 1.0);
	ALBEDO = col * (1.0 - fogf) * 0.92;
	ROUGHNESS = clamp(rough + 0.06, 0.0, 1.0);
	SSS_STRENGTH = 0.4 * (1.0 - hair_w);
	SPECULAR = 0.3 * (1.0 - fogf);
	// skin micro relief (pores) when close to the camera
	if (dist < 3.0 && !has_photo) {
		vec3 pp = v_obj * 1100.0 + vec3(face_seed);
		float p0 = vn3(pp);
		vec3 g = vec3(vn3(pp + vec3(0.4, 0.0, 0.0)) - p0, vn3(pp + vec3(0.0, 0.4, 0.0)) - p0, vn3(pp + vec3(0.0, 0.0, 0.4)) - p0);
		NORMAL = normalize(NORMAL - (VIEW_MATRIX * MODEL_MATRIX * vec4(g, 0.0)).xyz * 0.35 * (1.0 - dist / 3.0));
	}
	float rimlight = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	// faces stay readable in dark interiors and at night; warm translucency at the silhouette
	EMISSION = mix(col * (0.055 + rimlight * 0.08) + skin_color.rgb * vec3(0.12, 0.04, 0.02) * rimlight, fog_color.rgb, fogf);
	if (thermal > 0.5) {
		float facing = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
		ALBEDO = vec3(0.0);
		SPECULAR = 0.0;
		EMISSION = vec3(0.68 + 0.32 * facing);
	}
}
