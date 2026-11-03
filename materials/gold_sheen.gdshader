shader_type spatial;
// The gold Deagle's glint (scripts/wishlist.gd): a second pass over the gun that adds a bright
// diagonal band sweeping across the screen every few seconds, strongest where the metal turns
// away from the view.
render_mode blend_add, unshaded, depth_draw_never, cull_back, shadows_disabled;

uniform vec3 tint : source_color = vec3(1.0, 0.82, 0.45);
uniform float period = 3.2;   // s between glints
uniform float width = 0.05;   // of the screen
uniform float strength = 1.2;
uniform float snap = 180.0;  // as materials/psx.gdshader's: the pass sits on the jittering gun

void vertex() {
	vec4 clip = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	vec2 grid = vec2(snap * VIEWPORT_SIZE.x / VIEWPORT_SIZE.y, snap) * 0.5;
	clip.xy = round(clip.xy / clip.w * grid) / grid * clip.w;
	POSITION = clip;
}

void fragment() {
	float facing = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float along = SCREEN_UV.x * 0.75 + (1.0 - SCREEN_UV.y) * 0.25;
	float at = fract(TIME / period) * 1.8 - 0.4;  // off screen most of the cycle: a glint, not a stripe
	float band = smoothstep(width, 0.0, abs(along - at));
	ALBEDO = tint * (band * strength * (0.35 + 0.65 * facing));
}
