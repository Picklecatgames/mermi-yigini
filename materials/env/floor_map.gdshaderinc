// What stands on the floor sinks into it (2026-11-05, the user: moss and green, "everything looks
// planted there"): tools/build_world.gd _floor_map bakes round every trunk, rock and prop a damp dark
// (r) and moss (g); here they get ragged edges by place, and moss patches of its own wherever the
// floor is left alone. Blobs from sines, not a texture: they can't crawl, and no setting shrinks them.
uniform sampler2D floor_map : hint_default_black, filter_linear, repeat_disable;
uniform vec4 floor_rect = vec4(0.0);  // x, z, width, depth the map covers; width 0: off
uniform float floor_moss = 1.0;  // how much moss of its own

float floor_blob(vec2 p) {
	return 0.5 + 0.25 * (sin(p.x * 2.3 + 1.7 * sin(p.y * 3.1)) + sin(p.y * 2.7 + 2.0 * sin(p.x * 2.1)));
}

vec3 floor_damp(vec3 alb, vec2 p) {
	if (floor_rect.z <= 0.0) {
		return alb;
	}
	vec2 m = texture(floor_map, (p - floor_rect.xy) / floor_rect.zw).rg;
	float fine = floor_blob(p);
	float wide = floor_blob(p * 0.23 + 13.0);
	float wet = smoothstep(0.05, 0.75, m.r + (fine - 0.5) * 0.35);
	float moss = smoothstep(0.45, 0.62, m.g * 0.8 + (fine - 0.5) * 0.5 + wide * wide * 0.72 * floor_moss);
	float l = dot(alb, vec3(0.333));
	alb = mix(alb, (l + 0.01) * vec3(0.92, 1.15, 0.42), moss * 0.8);  // olive, dark: lighter or cooler read as paint
	return alb * mix(1.0, 0.45, wet);
}
