// Full-screen post effect: heat haze (Dhaka summer), damage vignette, rain wash, lightning flash.
shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform float haze = 0.0;
uniform float damage = 0.0;
uniform float flash = 0.0;
uniform float rain = 0.0;
uniform float low_health = 0.0;
// thermal imager: luminance -> white-hot "ironbow" palette, sensor grain
uniform float thermal = 0.0;

void fragment() {
	vec2 uv = SCREEN_UV;
	if (haze > 0.001) {
		float band = smoothstep(0.35, 0.75, uv.y);
		uv.x += sin(uv.y * 90.0 + TIME * 3.1) * 0.0012 * haze * band;
		uv.y += cos(uv.x * 70.0 + TIME * 2.3) * 0.0008 * haze * band;
	}
	if (rain > 0.001) {
		float s = sin(uv.x * 160.0 + TIME * 0.7) * sin(uv.y * 23.0 - TIME * 1.9);
		uv += vec2(0.0, s * 0.0006 * rain);
	}
	vec3 col = texture(screen_tex, uv).rgb;
	vec2 c = UV - 0.5;
	float vig = smoothstep(0.25, 0.75, length(c));
	col = mix(col, vec3(0.55, 0.0, 0.0), vig * clamp(damage, 0.0, 1.0) * 0.8);
	float pulse = 0.5 + 0.5 * sin(TIME * 6.0);
	col = mix(col, col * vec3(1.0, 0.45, 0.45), vig * low_health * (0.4 + 0.3 * pulse));
	col = mix(col, vec3(0.85, 0.9, 1.0), clamp(flash, 0.0, 1.0) * 0.6);
	col *= 1.0 - vig * 0.18;
	if (thermal > 0.5) {
		float l = clamp(dot(texture(screen_tex, SCREEN_UV).rgb, vec3(0.3, 0.59, 0.11)) * 1.35, 0.0, 1.0);
		float g = fract(sin(dot(SCREEN_UV * 900.0 + TIME, vec2(12.9898, 78.233))) * 43758.5453);
		l = clamp(l + (g - 0.5) * 0.05, 0.0, 1.0);
		vec3 p = mix(vec3(0.02, 0.0, 0.12), vec3(0.42, 0.0, 0.55), smoothstep(0.0, 0.3, l));
		p = mix(p, vec3(0.92, 0.25, 0.05), smoothstep(0.3, 0.6, l));
		p = mix(p, vec3(1.0, 0.85, 0.15), smoothstep(0.6, 0.85, l));
		p = mix(p, vec3(1.0, 1.0, 0.95), smoothstep(0.85, 1.0, l));
		float scan = 0.94 + 0.06 * sin(SCREEN_UV.y * 720.0);
		col = p * scan * (1.0 - vig * 0.35);
	}
	COLOR = vec4(col, 1.0);
}
