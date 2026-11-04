shader_type spatial;
// Black between the wood's trees (tools/build_world.gd _veils): only for the eye, no collision. Drawn
// after the solid trees, so a tree in front stays in front; gone near the eye, gone towards the top
// so crowns stand against the sky. scripts/day_night.gd sets its colour: by night the fog's own, so a
// far tree and the gap beside it end alike. No streaks: at night they read as grey bars.
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, fog_disabled, shadows_disabled;

uniform vec2 eye_fade = vec2(9.0, 30.0);  // m: nothing nearer than x, full from y: what the head lamp reaches isn't under it
uniform vec2 top_fade = vec2(0.4, 1.0);  // of its height: full up to x, nothing from y
uniform vec3 colour : source_color = vec3(0.008, 0.008, 0.009);

varying float dist;

void vertex() {
	dist = length((MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz);
}

void fragment() {
	float top = 1.0 - smoothstep(top_fade.x, top_fade.y, UV.y);
	ALBEDO = colour;
	ALPHA = COLOR.a * top * smoothstep(eye_fade.x, eye_fade.y, dist);
}
