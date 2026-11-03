shader_type spatial;
render_mode unshaded, fog_disabled;

// The scrap heap's surface under its pieces (scripts/pile.gd). Never mud (the user, 2026-11-02:
// only scrap shows): drawn flat dark rust-earth and sunk under where the pieces lie, so a chink between the
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

// Its own haze, as the mountain's pieces (materials/psx_far.gdshader; scrap_hills.gd sets these).
global uniform vec4 psx_haze_colour;
global uniform vec2 psx_haze_range;
global uniform float psx_haze_max;
global uniform float psx_haze_day;  // 1 by day, 0 by night: unshaded, it darkens with the light by hand

void fragment() {
	// Dark rust-earth, not black: black read as holes in the sand at the heap's foot (2026-11-03,
	// the PS1 critic). Still never mud: no texture, the dark between pieces.
	float haze = smoothstep(psx_haze_range.x, psx_haze_range.y, length(VERTEX)) * psx_haze_max;
	ALBEDO = mix(vec3(0.07, 0.045, 0.03) * mix(0.12, 1.0, psx_haze_day), psx_haze_colour.rgb, haze);
}
