shader_type spatial;
render_mode cull_disabled, depth_draw_never;

// The glass lantern's panes (build_arena.gd _lantern): years of dust in soft patches and streaks
// that catch the lamps, clean enough between them to see the stars through.

uniform sampler2D grime_tex : hint_default_white, filter_linear_mipmap, repeat_enable;  // seamless noise
uniform vec3 tint : source_color = vec3(0.42, 0.44, 0.4);

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = world_pos.xz + world_pos.y;
	float dust = smoothstep(0.35, 0.8, texture(grime_tex, p * 0.06).r);
	float streak = smoothstep(0.55, 0.9, texture(grime_tex, vec2(p.x * 0.6, p.y * 0.04)).r);  // run down the slope
	float dirt = clamp(dust * 0.8 + streak * 0.5, 0.0, 1.0);
	ALBEDO = tint;
	ALPHA = 0.05 + 0.4 * dirt;
	ROUGHNESS = mix(0.04, 0.7, dirt);
	SPECULAR = 0.6;  // clean glass mirrors the lamps and the heap
}
