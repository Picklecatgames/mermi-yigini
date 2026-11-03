shader_type spatial;
// One frame of a smoke flipbook (Unity Labs CC0 sequences) on a camera-facing quad, blended
// with the next frame so slow playback stays smooth. fixed_y keeps the quad upright, for
// plumes that rise from a point.
// PS1 look (2026-11-02): no blend between frames, every other frame only, each cell at CELL_PX
// unfiltered texels and the alpha in a few hard steps.
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

uniform sampler2D sheet : source_color, filter_nearest;
uniform vec2 grid = vec2(8.0, 8.0);
uniform float frame = 0.0;       // fractional frame index
uniform float brightness = 1.5;  // the sheets are lit for a dark scene; daylight needs more
uniform float alpha = 1.0;
uniform bool fixed_y = false;

const float CELL_PX = 32.0;
const float LEVELS = 4.0;

void vertex() {
	if (fixed_y) {
		MODELVIEW_MATRIX = VIEW_MATRIX * mat4(vec4(normalize(cross(vec3(0.0, 1.0, 0.0), INV_VIEW_MATRIX[2].xyz)), 0.0), vec4(0.0, 1.0, 0.0, 0.0), vec4(normalize(cross(INV_VIEW_MATRIX[0].xyz, vec3(0.0, 1.0, 0.0))), 0.0), MODEL_MATRIX[3]);
	} else {
		MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	}
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0), vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0), vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0), vec4(0.0, 0.0, 0.0, 1.0));
}

vec4 cell(vec2 uv, float f) {
	f = mod(f, grid.x * grid.y);
	vec2 at = vec2(mod(f, grid.x), floor(f / grid.x));
	return texture(sheet, (uv + at) / grid);
}

void fragment() {
	vec4 c = cell((floor(UV * CELL_PX) + 0.5) / CELL_PX, floor(frame * 0.5) * 2.0);
	ALBEDO = c.rgb * brightness;
	ALPHA = floor(clamp(c.a * alpha, 0.0, 1.0) * LEVELS + 0.5) / LEVELS;
}
