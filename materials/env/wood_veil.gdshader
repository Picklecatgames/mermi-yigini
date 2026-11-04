shader_type spatial;
// Black between the wood's trees (tools/build_world.gd _veils): only for the eye, no collision. Drawn
// after the solid trees, so a tree in front stays in front; gone near the eye, gone towards the top
// so crowns stand against the sky; streaked up and down like trunks, not a flat wall.
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, fog_disabled, shadows_disabled;

uniform vec2 eye_fade = vec2(5.0, 22.0);  // m: nothing nearer than x, full from y
uniform vec2 top_fade = vec2(0.4, 1.0);  // of its height: full up to x, nothing from y
uniform vec3 colour : source_color = vec3(0.008, 0.008, 0.009);

varying float dist;

void vertex() {
	dist = length((MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz);
}

void fragment() {
	float streak = 0.5 + 0.5 * sin(UV.x * 5.0 + 2.0 * sin(UV.x * 1.7));  // slow: thin bands stepped into stripes at 270p
	float top = 1.0 - smoothstep(top_fade.x, top_fade.y, UV.y);
	ALBEDO = colour;
	ALPHA = COLOR.a * mix(0.9, 1.0, streak) * top * smoothstep(eye_fade.x, eye_fade.y, dist);
}
