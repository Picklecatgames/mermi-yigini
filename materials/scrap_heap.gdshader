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
	VERTEX.y = h > 0.1 ? h : -0.05;  // thin and empty cells tuck under the floor: at the foot only pieces show, on the ground
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
	// Near, under the tight heap, a chink is nearly black. Far off a chink is under a pixel: there it is
	// the shade of the mountain's own scrap, or the gaps between its pieces read as sand (2026-11-05).
	vec3 dark = mix(vec3(0.016, 0.011, 0.008), vec3(0.06, 0.035, 0.024), smoothstep(14.0, 45.0, length(VERTEX)));
	ALBEDO = mix(dark * mix(0.12, 1.0, psx_haze_day), psx_haze_colour.rgb, haze);
}
