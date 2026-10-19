shader_type spatial;
// One frame of a smoke flipbook (Unity Labs CC0 sequences) on a camera-facing quad, blended
// with the next frame so slow playback stays smooth. fixed_y keeps the quad upright, for
// plumes that rise from a point.
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

uniform sampler2D sheet : source_color, filter_linear_mipmap;
uniform vec2 grid = vec2(8.0, 8.0);
uniform float frame = 0.0;       // fractional frame index
uniform float brightness = 1.5;  // the sheets are lit for a dark scene; daylight needs more
uniform float alpha = 1.0;
uniform bool fixed_y = false;

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
	float f = floor(frame);
	vec4 c = mix(cell(UV, f), cell(UV, f + 1.0), fract(frame));
	ALBEDO = c.rgb * brightness;
	ALPHA = clamp(c.a * alpha, 0.0, 1.0);
}
