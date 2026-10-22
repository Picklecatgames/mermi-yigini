shader_type spatial;
render_mode cull_disabled;

// The roof's old fibreglass skylight strips, years unwashed: a yellowed, grimy translucent sheet
// that glows dull with the daylight behind it, darker where dirt and moss sit in the laps.
// Panels in `holes` (x0, z0, x1, z1 world rects) are broken out with ragged edges; the sun
// (build_arena.gd _sun) shines through those only.

uniform sampler2D grime_tex : hint_default_white, filter_linear_mipmap, repeat_enable;  // seamless noise
uniform vec3 sheet : source_color = vec3(0.62, 0.6, 0.48);
uniform vec3 daylight : source_color = vec3(0.78, 0.84, 0.92);
uniform float glow = 0.55;
uniform float panel = 3.5;  // m along the building per sheet
uniform vec4 holes[8];
uniform int hole_count = 0;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float ragged(vec2 p) {
	return texture(grime_tex, p * 0.9).r * 0.7 + texture(grime_tex, p * 3.1 + 0.2).r * 0.3;
}

void fragment() {
	vec2 p = world_pos.xz;
	for (int i = 0; i < hole_count; i++) {
		vec4 h = holes[i];
		vec2 c = (h.xy + h.zw) * 0.5;
		vec2 e = (h.zw - h.xy) * 0.5;
		vec2 d = abs(p - c) / e;
		if (max(d.x, d.y) < 0.78 + 0.32 * ragged(p)) {
			discard;
		}
	}
	// Dirt washed down the slope (along x) in streaks, and big soft stains.
	float g = texture(grime_tex, vec2(p.x * 0.02, p.y * 0.35)).r * 0.5 + texture(grime_tex, p * 0.04 + 0.5).r * 0.5;
	float lap = smoothstep(0.08, 0.0, abs(fract(p.y / panel) - 0.5) - 0.44);  // dirt in the overlaps
	float rib = 0.5 + 0.5 * sin(p.x * TAU / 0.2);  // corrugation
	float dirt = clamp(mix(0.25, 0.85, smoothstep(0.2, 0.85, g)) + lap * 0.5, 0.0, 1.0);
	float pane = fract(sin(dot(floor(p / vec2(3.0, panel)), vec2(12.9898, 78.233))) * 43758.5453);
	ALBEDO = mix(sheet, vec3(0.12, 0.13, 0.08), dirt * 0.8) * (0.85 + 0.15 * rib);
	ROUGHNESS = 0.7;
	EMISSION = daylight * glow * (1.0 - dirt * 0.85) * mix(0.45, 1.0, pane) * (0.9 + 0.1 * rib);
}
