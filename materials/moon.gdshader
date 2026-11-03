shader_type spatial;
// The moon's disc (scripts/day_night.gd): a quad far off that always faces the eye, unlit and out of
// the fog, its face a small unfiltered picture (the PS1's), lit as far as the phase goes.
render_mode unshaded, fog_disabled, cull_disabled, shadows_disabled, depth_draw_never, blend_mix;

uniform sampler2D face : source_color, filter_nearest;
uniform float phase = 1.0;  // 1 full, 0.5 half (lit on the right), 0 new
uniform float fade = 1.0;  // 0 by day
uniform vec3 tint : source_color = vec3(0.85, 0.9, 1.0);

void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	p.y = -p.y;
	float r2 = dot(p, p);
	if (r2 > 1.0) {
		discard;
	}
	vec3 n = vec3(p, sqrt(1.0 - r2));
	float a = (1.0 - phase) * PI;  // where the sun stands from the moon, round from behind the eye
	float lit = step(0.0, dot(n, vec3(sin(a), 0.0, cos(a))));
	ALBEDO = texture(face, UV).rgb * tint * mix(0.03, 1.0, lit);
	ALPHA = fade;
}
