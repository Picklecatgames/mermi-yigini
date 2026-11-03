// A looping flipbook on a quad that turns round its own up axis to face the camera, as the old
// consoles drew a fire: a few low-res frames, unfiltered, stepped (2026-11-03, the user: the barrel's
// fire looked new and out of place; scripts/barrel_fire.gd). The sheet is `cols` x `rows` frames,
// left to right, top to bottom.
shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, depth_draw_never;

uniform sampler2D sheet : source_color, filter_nearest;
uniform int cols = 6;
uniform int rows = 5;
uniform float fps = 15.0;  // half the source's 30: stepped, as the PS1 ran its sprites
uniform float offset = 0.0;  // frames, so quads side by side are out of step
uniform vec4 tint : source_color = vec4(1.0);
uniform float energy = 1.4;  // over 1 the fire stays the brightest thing round it

void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
		vec4(normalize(cross(vec3(0.0, 1.0, 0.0), INV_VIEW_MATRIX[2].xyz)), 0.0),
		vec4(0.0, 1.0, 0.0, 0.0),
		vec4(normalize(cross(INV_VIEW_MATRIX[0].xyz, vec3(0.0, 1.0, 0.0))), 0.0),
		MODEL_MATRIX[3]);
}

void fragment() {
	float count = float(cols * rows);
	float f = floor(mod(TIME * fps + offset, count));
	vec2 cell = vec2(mod(f, float(cols)), floor(f / float(cols)));
	vec4 c = texture(sheet, (cell + UV) / vec2(float(cols), float(rows))) * tint;
	ALBEDO = c.rgb * energy;
	ALPHA = c.a;
}
