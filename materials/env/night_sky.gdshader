shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, fog_disabled;

// The sky over the roof at about 21:30 (build_arena.gd _sun): the lid plane seen only through the
// roof's holes and broken skylights. Deep blue going black overhead, a last glow low in the west,
// and stars: one hashed per cell of the plane, a few bright, all twinkling a little.

uniform vec3 zenith : source_color = vec3(0.006, 0.009, 0.022);
uniform vec3 dusk : source_color = vec3(0.045, 0.055, 0.1);  // what is left of the evening, west (-x)
uniform float cells = 160.0;  // star cells across the plane: ~1 m each, a few per roof hole
uniform float star_energy = 12.0;  // the bright ones over the glow threshold, so they bloom a little

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec3 sky = mix(zenith, dusk, smoothstep(0.55, 0.0, UV.x) * 0.8);
	vec2 g = UV * cells;
	vec2 cell = floor(g);
	float h = hash(cell);
	if (h > 0.82) {  // about one cell in six has a star
		vec2 at = vec2(hash(cell + 7.3), hash(cell + 1.9)) * 0.7 + 0.15;
		float d = length(fract(g) - at);
		float size = mix(0.07, 0.24, pow(hash(cell + 3.1), 5.0));  // most faint, a few bright
		float twinkle = 0.75 + 0.25 * sin(TIME * (1.5 + 3.0 * h) + h * 40.0);
		float star = smoothstep(size, 0.0, d) * twinkle;
		vec3 tint = mix(vec3(0.75, 0.85, 1.0), vec3(1.0, 0.92, 0.8), hash(cell + 5.7));
		sky += tint * star * star_energy * mix(0.3, 1.0, hash(cell + 9.4));
	}
	ALBEDO = sky;
}
