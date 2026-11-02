shader_type spatial;
render_mode unshaded;

// The scrap heap's surface under its pieces (scripts/pile.gd). It must never be seen, only the
// scrap (the user, 2026-11-02). Pieces lie on it several deep and tools/build_scrap_face.gd fills
// the gaps; it is drawn sunk under where they lie and unlit, so what a last chink shows is the
// deep shadow between pieces, never a lit smooth slope, and the thin skirt at the foot, where
// pieces don't stay, sinks under the floor. Collision is the heap's real height, not this.

uniform vec3 shade = vec3(0.006, 0.0045, 0.0035);
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
	ALBEDO = shade;
}
