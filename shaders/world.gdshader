// Shared surface shader for every static mesh and character part.
// - Procedural patterns (brick, panels, windows, planks, water...) so the game needs no texture files.
// - Vertex colour carries BAKED lighting: rgb = baked lamp light, a = ambient occlusion.
// - Fog is computed here (works the same on every GPU, including old Intel iGPUs).
shader_type spatial;
render_mode cull_back, diffuse_lambert, specular_schlick_ggx;

uniform vec4 albedo : source_color = vec4(0.7, 0.7, 0.7, 1.0);
uniform vec4 albedo2 : source_color = vec4(0.4, 0.4, 0.4, 1.0);
uniform int pattern = 0;
uniform float pattern_scale = 1.0;
uniform float roughness : hint_range(0.0, 1.0) = 0.9;
uniform float metallic : hint_range(0.0, 1.0) = 0.0;
uniform vec4 emission_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float emission_energy = 0.0;
uniform bool use_baked = true;
uniform bool receives_wet = true;

global uniform vec4 fog_color;
global uniform float fog_density;
global uniform float fog_start;
global uniform float world_wetness;
global uniform float baked_strength;
global uniform float night_factor;
global uniform float thermal;

varying vec3 v_wpos;
varying vec3 v_wnrm;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	float a = hash12(i);
	float b = hash12(i + vec2(1.0, 0.0));
	float c = hash12(i + vec2(0.0, 1.0));
	float d = hash12(i + vec2(1.0, 1.0));
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

void vertex() {
	v_wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 n = abs(v_wnrm);
	bool wall = n.y < 0.5;
	vec2 uv;
	if (wall) {
		uv = vec2(n.x > n.z ? v_wpos.z : v_wpos.x, v_wpos.y);
	} else {
		uv = v_wpos.xz;
	}
	uv *= pattern_scale;
	vec3 col = albedo.rgb;
	float rough = roughness;
	vec3 emis = vec3(0.0);
	float grain = vnoise(uv * 3.0) * 0.5 + vnoise(uv * 11.0) * 0.5;
	col *= 0.88 + 0.24 * grain;

	if (pattern == 1) {
		// Bangladeshi first-class brick, 240 x 70 mm faces, ~12 mm recessed mortar, stretcher bond.
		// Per-brick firing colour (salmon .. deep red .. over-burnt "jhama" purple-black), chipped
		// arrises, a shadow under each brick (recessed joints), monsoon efflorescence near the ground.
		vec2 b = uv * vec2(4.0, 13.0);
		float row = floor(b.y);
		b.x += mod(row, 2.0) * 0.5;
		vec2 f = fract(b);
		vec2 id = floor(b);
		float h = hash12(id);
		float h2 = hash12(id + 17.3);
		float aa = max(fwidth(b.x), fwidth(b.y)) * 1.2;
		float chip = vnoise(uv * 40.0) * 0.05;
		float jx = 0.045 + chip;
		float jy = 0.15 + chip * 1.5;
		float mortar = 1.0 - smoothstep(jx - aa, jx + aa, f.x) * smoothstep(jy - aa, jy + aa, f.y) * (1.0 - smoothstep(1.0 - jx * 0.3 - aa, 1.0, f.x));
		vec3 brick = albedo.rgb * (0.8 + 0.35 * h);
		brick = mix(brick, brick * vec3(1.15, 1.05, 0.95), step(0.82, h2));
		brick = mix(brick, vec3(0.2, 0.1, 0.1), step(0.95, h2) * 0.7);
		brick *= 0.88 + 0.22 * vnoise(uv * vec2(30.0, 60.0));
		vec3 mcol = albedo2.rgb * (0.85 + 0.2 * vnoise(uv * 25.0));
		col = mix(brick, mcol, mortar);
		// recessed joint: the brick above casts a thin shadow into the bed joint
		float shade = smoothstep(jy + 0.02, jy - 0.02, f.y) * smoothstep(0.0, jy * 0.5, f.y);
		col *= 1.0 - 0.35 * shade * mortar;
		if (wall) {
			float salt = smoothstep(1.2, 0.0, v_wpos.y) * smoothstep(0.45, 0.75, vnoise(uv * 1.7));
			col = mix(col, vec3(0.86, 0.84, 0.8), salt * 0.45);
			rough = mix(rough, 1.0, mortar);
		}
	} else if (pattern == 2) {
		// panels / floor tiles
		vec2 f = fract(uv * 0.5);
		float seam = clamp(step(f.x, 0.025) + step(f.y, 0.025), 0.0, 1.0);
		col = mix(col, albedo2.rgb, seam);
	} else if (pattern == 3) {
		// facade with a grid of windows (lit at night)
		if (wall) {
			vec2 cell = uv / vec2(2.6, 3.2);
			vec2 f = fract(cell);
			float win = step(0.18, f.x) * step(f.x, 0.82) * step(0.28, f.y) * step(f.y, 0.85);
			float h = hash12(floor(cell) + floor(v_wpos.xz * 0.05));
			vec3 glass = albedo2.rgb * (0.7 + 0.5 * h);
			col = mix(col, glass, win);
			rough = mix(rough, 0.15, win);
			float lit = step(0.6, h) * night_factor * win;
			emis += vec3(1.0, 0.8, 0.5) * lit * 0.85;
		}
	} else if (pattern == 4) {
		// planks / corrugated tin
		float s = fract((wall ? uv.x : uv.x + uv.y) * 4.0);
		col *= 0.78 + 0.3 * smoothstep(0.0, 0.5, s) * smoothstep(1.0, 0.5, s);
	} else if (pattern == 5) {
		// water
		float t = TIME * 0.6;
		float w = vnoise(uv * 0.8 + vec2(t, t * 0.7)) * 0.6 + vnoise(uv * 2.3 - vec2(t * 1.3, t * 0.4)) * 0.4;
		col = mix(albedo.rgb, albedo2.rgb, w);
		rough = 0.06;
	} else if (pattern == 6) {
		// asphalt with chips
		float sp = step(0.93, hash12(floor(uv * 20.0)));
		col = mix(col, albedo2.rgb, sp * 0.6);
	} else if (pattern == 7) {
		// painted cement plaster over brick (most Dhaka houses): rain streaks from slab edges and window
		// sills, monsoon fungus creeping up from the ground, hairline cracks, an RCC floor band every 3.2 m
		float streak = vnoise(vec2(uv.x * 3.0, uv.y * 0.25));
		float patchy = vnoise(uv * 0.7);
		col = mix(col, albedo2.rgb, clamp(streak * 0.5 + patchy * 0.25, 0.0, 1.0));
		if (wall) {
			float fy = fract(v_wpos.y / 3.2);
			float band = smoothstep(0.0, 0.01, fy) * (1.0 - smoothstep(0.05, 0.06, fy));
			col = mix(col, col * 0.86, band);
			float drip = smoothstep(0.55, 0.9, vnoise(vec2(uv.x * 6.0, 0.0))) * smoothstep(0.06, 0.6, fy) * (1.0 - smoothstep(0.6, 0.95, fy));
			col = mix(col, col * vec3(0.72, 0.72, 0.7), drip * 0.35);
			float fungus = smoothstep(1.4, 0.1, v_wpos.y) * smoothstep(0.35, 0.7, vnoise(uv * 2.2));
			col = mix(col, vec3(0.13, 0.15, 0.1), fungus * 0.55);
			float crack = 1.0 - smoothstep(0.0, 0.012, abs(vnoise(uv * 1.3) - 0.5));
			col = mix(col, col * 0.6, crack * step(0.6, vnoise(uv * 0.4)) * 0.5);
		}
	} else if (pattern == 8) {
		// horizontal marble bands (Kahn's Sangsad Bhaban)
		float f = fract(uv.y / 1.6);
		col = mix(col, albedo2.rgb, step(f, 0.05));
	}

	float ao = 1.0;
	vec3 baked = vec3(0.0);
	if (use_baked) {
		ao = COLOR.a;
		baked = COLOR.rgb;
	}
	col *= ao;
	if (receives_wet) {
		float wet = world_wetness * (wall ? 0.35 : 1.0);
		col *= 1.0 - wet * 0.3;
		rough = mix(rough, 0.18, wet);
	}
	emis += col * baked * baked_strength + emission_color.rgb * emission_energy;

	float dist = length(VERTEX);
	float fogf = clamp(1.0 - exp(-max(dist - fog_start, 0.0) * fog_density), 0.0, 1.0);
	ALBEDO = col * (1.0 - fogf);
	ROUGHNESS = rough;
	METALLIC = metallic;
	SPECULAR = 0.5 * (1.0 - fogf);
	EMISSION = mix(emis, fog_color.rgb, fogf);
	if (thermal > 0.5) {
		// cold background: only faint structure + warm lamps / engines
		float lum = dot(col, vec3(0.3, 0.59, 0.11));
		ALBEDO = vec3(0.0);
		SPECULAR = 0.0;
		EMISSION = vec3(0.035 + lum * 0.09 + emission_energy * 0.25 * dot(emission_color.rgb, vec3(0.33)));
	}
}
