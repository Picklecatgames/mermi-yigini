shader_type spatial;
render_mode unshaded;

// The scrap heap's surface under its pieces (scripts/pile.gd). Never mud (the user, 2026-11-02:
// only scrap shows): drawn flat black and sunk under where the pieces lie, so a chink between the
// boxed pieces (2026-11-03) looks into the dark, and it casts the heap's shadow so the light stays
// out of its inside. Collision is the heap's real height, not this.

uniform float sink = 0.15;  // m under the heap's real height

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
	float h = field(c) - sink;
	VERTEX.y = h > 0.004 ? h : -0.05;  // thin and empty cells tuck under the floor
}

void fragment() {
	ALBEDO = vec3(0.0);
}
