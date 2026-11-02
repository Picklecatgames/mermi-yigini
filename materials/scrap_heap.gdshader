shader_type spatial;

// The scrap heap's surface under its pieces (scripts/pile.gd). It is never meant to be seen: the
// pieces lie on it several deep. Where a gap still shows it, it is plain deep shadow, no texture
// (the user, 2026-11-02: only pieces, each its own).

// Rust-brown, not black: a gap between pieces reads as deep shadow in the scrap, not a hole.
uniform vec3 shade = vec3(0.026, 0.017, 0.011);

// Heap shape: height per cell, written by pile.gd as scrap is taken and slopes slide.
uniform sampler2D height_field : filter_nearest;
// Heights one physics tick earlier; slides are drawn between the two.
uniform sampler2D height_prev : filter_nearest;
uniform float blend = 1.0;  // Engine.get_physics_interpolation_fraction(), set every frame
uniform ivec2 grid = ivec2(128, 224);
uniform float cell_size = 0.25;

float field(ivec2 c) {
	ivec2 t = clamp(c, ivec2(0), grid - 1);
	return mix(texelFetch(height_prev, t, 0).r, texelFetch(height_field, t, 0).r, blend);
}

void vertex() {
	// The plane's vertices sit on cell centres.
	ivec2 c = ivec2(round(VERTEX.xz / cell_size + vec2(grid - 1) * 0.5));
	float h = field(c);
	VERTEX.y = h > 0.004 ? h : -0.05;  // empty cells tuck under the floor
	NORMAL = normalize(vec3(field(c - ivec2(1, 0)) - field(c + ivec2(1, 0)), 2.0 * cell_size,
			field(c - ivec2(0, 1)) - field(c + ivec2(0, 1))));
}

void fragment() {
	ALBEDO = shade;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	AO = 0.0;
}
