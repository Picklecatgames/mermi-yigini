shader_type spatial;
render_mode cull_disabled, depth_draw_never, blend_premul_alpha;

// The glass lantern's panes (build_arena.gd _lantern). Premultiplied: alpha thins only the dusty
// diffuse film, the reflection stays whole, so the glass mirrors the lamps and the heap's glow and
// goes to a mirror at grazing angles, as real glass does. Each pane sits a hair off true in its
// frame, so the reflections break pane by pane; years of dust in patches and streaks dull them.

uniform sampler2D grime_tex : hint_default_white, filter_linear_mipmap, repeat_enable;  // seamless noise
uniform vec3 tint : source_color = vec3(0.42, 0.44, 0.4);
uniform float pane_skew = 0.05;  // how far a pane leans off its neighbours
uniform vec3 sheen : source_color = vec3(0.55, 0.4, 0.25);  // the hall's warm lamplight caught in the glass

varying vec3 world_pos;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = world_pos.xz + world_pos.y;
	// Two scales, the second turned, and the streaks masked by a third: the noise never shows its repeat.
	float dust = smoothstep(0.35, 0.8, texture(grime_tex, p * 0.023).r * 0.6 + texture(grime_tex, mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8)) * p * 0.061).r * 0.4);
	float streak = smoothstep(0.55, 0.9, texture(grime_tex, vec2(p.x * 0.13, p.y * 0.011)).r)  // run down the slope
		* smoothstep(0.3, 0.7, texture(grime_tex, p * 0.017 + 0.5).r);
	float dirt = clamp(dust * 0.8 + streak * 0.5, 0.0, 1.0);
	// One pane per glazing-bar cell (2 m along the ridge, ~1.7 m up the slope): its own small lean,
	// and old glass's faint ripple on top.
	vec2 cell = floor(vec2(world_pos.z / 2.0, world_pos.y / 1.7 + abs(world_pos.x) / 5.0));
	vec3 lean = (vec3(hash(cell), 0.0, hash(cell + 3.7)) - 0.5) * 2.0 * pane_skew;
	lean += (texture(grime_tex, p * 0.9).rgb - 0.5) * 0.02;
	NORMAL = normalize(NORMAL + (VIEW_MATRIX * vec4(lean, 0.0)).xyz);
	// The sheen: faint face on, strong at grazing angles; each pane's lean gives it its own brightness.
	float fresnel = pow(1.0 - abs(dot(NORMAL, VIEW)), 5.0);
	float pane = 0.5 + hash(cell + 9.1);  // no two panes catch the light alike
	EMISSION = sheen * ((0.1 + 2.0 * fresnel) * pane * (1.0 - 0.5 * dirt) + 0.25 * dirt);  // the dust glows dull in the light too
	ALBEDO = tint;
	ALPHA = 0.06 + 0.45 * dirt;
	ROUGHNESS = mix(0.02, 0.6, dirt);
	SPECULAR = 0.5;
}
