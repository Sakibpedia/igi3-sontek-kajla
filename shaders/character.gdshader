// Body shader for the procedural humanoids (CharacterModel.gd).
// Vertex colour alpha selects the material so one draw call covers a whole body segment:
//   a = 0.00 skin   -> rgb * skin_color   (skin tone is sampled from the character's photo)
//   a = 0.25 hair   -> rgb * hair_color   (hair colour sampled from the photo)
//   a = 0.50 metal  -> rgb, metallic (rifles, buckles, gold jewellery)
//   a = 0.75 leather / rubber / tape
//   a = 0.90 cloth with a woven check (lungi)
//   a = 0.95 printed cloth (kameez, dupatta): small floral motif
//   a = 1.00 plain cloth  -> weave + soft fold relief
shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec4 skin_color : source_color = vec4(0.56, 0.39, 0.29, 1.0);
uniform vec4 hair_color : source_color = vec4(0.05, 0.04, 0.035, 1.0);
uniform float hit_flash = 0.0;
// first-person carry: fragments closer to the camera than this (m) are dropped (stipple fade), so
// the hostage on the Freelancer's own shoulder never fills the screen from inside
uniform float near_fade = 0.0;
uniform float pattern_seed = 0.0;

global uniform vec4 fog_color;
global uniform float fog_density;
global uniform float fog_start;
global uniform float world_wetness;
global uniform float thermal;

varying vec3 v_obj;

float hash13(vec3 p3) {
	p3 = fract(p3 * 0.1031);
	p3 += dot(p3, p3.zyx + 31.32);
	return fract((p3.x + p3.y) * p3.z);
}

float vnoise3(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	vec3 u = f * f * (3.0 - 2.0 * f);
	float a = mix(mix(hash13(i), hash13(i + vec3(1, 0, 0)), u.x), mix(hash13(i + vec3(0, 1, 0)), hash13(i + vec3(1, 1, 0)), u.x), u.y);
	float b = mix(mix(hash13(i + vec3(0, 0, 1)), hash13(i + vec3(1, 0, 1)), u.x), mix(hash13(i + vec3(0, 1, 1)), hash13(i + vec3(1, 1, 1)), u.x), u.y);
	return mix(a, b, u.z);
}

// anti-aliased band: 1 inside [0, w) of each period
float band(float x, float w) {
	float f = fract(x);
	float aa = max(fwidth(x), 0.0005) * 1.5;
	return smoothstep(0.0, aa, f) * (1.0 - smoothstep(w - aa, w, f));
}

void vertex() {
	v_obj = VERTEX;
}

void fragment() {
	if (near_fade > 0.0) {
		float nd = length(VERTEX);
		float st = fract(dot(floor(FRAGCOORD.xy), vec2(0.5, 0.25)));
		if (nd < near_fade - 0.3 || (nd < near_fade && st < (near_fade - nd) / 0.3)) {
			discard;
		}
	}
	float id = COLOR.a;
	vec3 col = COLOR.rgb;
	float rough = 0.9;
	float metal = 0.0;
	float spec = 0.35;
	vec3 emis = vec3(0.0);
	float n1 = vnoise3(v_obj * 38.0);
	float n2 = vnoise3(v_obj * 160.0);
	float ndv = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float dist = length(VERTEX);
	float near = 1.0 - smoothstep(8.0, 22.0, dist);
	if (id < 0.12) {
		// skin: blotches and pores, oily sheen, warm translucency at the silhouette (ears, fingers)
		col *= skin_color.rgb * (0.94 + 0.09 * n1 + 0.04 * n2);
		col = mix(col, col * vec3(1.06, 0.93, 0.9), smoothstep(0.55, 0.8, vnoise3(v_obj * 11.0)) * 0.35);
		rough = 0.5 - 0.06 * n2;
		spec = 0.42;
		float scatter = pow(1.0 - ndv, 2.2);
		emis = skin_color.rgb * (vec3(0.05, 0.022, 0.014) + vec3(0.16, 0.05, 0.025) * scatter);
		// real subsurface scattering in the HQ (Forward+) mode
		SSS_STRENGTH = 0.35;
	} else if (id < 0.37) {
		// hair: strands with an anisotropic sheen band
		float strands = vnoise3(vec3(v_obj.x * 420.0, v_obj.y * 26.0, v_obj.z * 420.0));
		float clump = vnoise3(vec3(v_obj.x * 90.0, v_obj.y * 9.0, v_obj.z * 90.0));
		col *= hair_color.rgb * (0.62 + 0.5 * strands + 0.25 * clump);
		rough = 0.74 - 0.12 * strands;
		spec = 0.26;
		emis = hair_color.rgb * 0.35 * pow(1.0 - ndv, 2.5);
	} else if (id < 0.62) {
		col *= 0.9 + 0.2 * n1;
		rough = 0.28 + 0.2 * n2;
		metal = 0.8;
		spec = 0.6;
	} else if (id < 0.87) {
		col *= 0.9 + 0.15 * n1;
		rough = 0.45 + 0.2 * n2;
		spec = 0.5;
	} else {
		// cloth
		float around = atan(v_obj.x, v_obj.z) * 0.16;
		vec2 uv = vec2(around, v_obj.y);
		if (id < 0.925) {
			// check (lungi): broad darker bands both ways + a thin light thread line
			float bx = band(uv.x * 9.0 + pattern_seed, 0.38);
			float by = band(uv.y * 9.0, 0.38);
			col *= 1.0 - 0.22 * (bx + by);
			float tx = band(uv.x * 9.0 + pattern_seed + 0.62, 0.05);
			float ty = band(uv.y * 9.0 + 0.62, 0.05);
			col = mix(col, vec3(0.92, 0.9, 0.82), clamp(tx + ty, 0.0, 1.0) * 0.45 * near);
		} else if (id < 0.975) {
			// print (kameez, dupatta): little five-petal flowers on a staggered grid
			vec2 g = uv * vec2(62.0, 62.0) + vec2(pattern_seed, 0.0);
			g.x += step(0.5, fract(g.y * 0.5)) * 0.5;
			vec2 c = fract(g) - 0.5;
			float r = length(c);
			float petals = 0.5 + 0.5 * cos(5.0 * atan(c.y, c.x) + pattern_seed);
			float aa = max(fwidth(g.x), 0.002) * 1.2;
			float flower = 1.0 - smoothstep(0.17 + 0.09 * petals - aa, 0.17 + 0.09 * petals + aa, r);
			float centre = 1.0 - smoothstep(0.05 - aa, 0.05 + aa, r);
			vec3 motif = mix(vec3(0.97, 0.93, 0.8), col * 0.45, step(0.45, fract(pattern_seed * 0.13)));
			col = mix(col, motif, flower * 0.5 * near);
			col = mix(col, vec3(0.95, 0.75, 0.2), centre * 0.5 * near);
		}
		// weave, sun fading on raised folds and soft fold relief (normal bend)
		float weave = 0.5 + 0.5 * sin(v_obj.x * 900.0) * sin(v_obj.y * 900.0 + v_obj.z * 900.0);
		vec3 fp = vec3(v_obj.x * 9.0, v_obj.y * 24.0, v_obj.z * 9.0) + vec3(pattern_seed * 0.1);
		float folds = vnoise3(fp);
		col *= 0.84 + 0.14 * folds + 0.05 * weave * near + 0.04 * n2;
		if (near > 0.01) {
			float e = 0.35;
			vec3 grad = vec3(vnoise3(fp + vec3(e, 0.0, 0.0)) - folds, vnoise3(fp + vec3(0.0, e, 0.0)) - folds, vnoise3(fp + vec3(0.0, 0.0, e)) - folds) / e;
			grad *= vec3(9.0, 24.0, 9.0) * 0.004;
			vec3 gv = (VIEW_MATRIX * MODEL_MATRIX * vec4(grad, 0.0)).xyz;
			NORMAL = normalize(NORMAL - gv * near);
		}
		rough = 0.93;
		spec = 0.22;
		// fabric sheen: fibres catch light at grazing angles
		emis = col * 0.08 * pow(1.0 - ndv, 2.5);
	}
	float wet = world_wetness * 0.6;
	col *= 1.0 - wet * 0.25;
	rough = mix(rough, 0.3, wet);
	col = mix(col, vec3(0.9, 0.08, 0.04), hit_flash);
	float fogf = clamp(1.0 - exp(-max(dist - fog_start, 0.0) * fog_density), 0.0, 1.0);
	ALBEDO = col * (1.0 - fogf);
	ROUGHNESS = rough;
	METALLIC = metal;
	SPECULAR = spec * (1.0 - fogf);
	// soft rim so silhouettes read against dark streets
	float rim = pow(1.0 - ndv, 3.0);
	EMISSION = mix(emis + col * rim * 0.1, fog_color.rgb, fogf);
	if (thermal > 0.5) {
		// body heat: bare skin hottest, clothes warm, weapons and tape cold
		float heat = id < 0.12 ? 1.0 : (id < 0.37 ? 0.6 : (id < 0.62 ? 0.18 : (id < 0.87 ? 0.35 : 0.72)));
		ALBEDO = vec3(0.0);
		SPECULAR = 0.0;
		EMISSION = vec3(heat * (0.62 + 0.38 * ndv));
	}
}
