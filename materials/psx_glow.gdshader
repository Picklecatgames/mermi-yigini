// An added glow over a PS1 mesh (the pistol on the spawn desk, scripts/gun_table.gd): snapped to the
// same screen grid as materials/psx.gdshader, so the overlay sits on the jittering mesh.
shader_type spatial;
render_mode unshaded, blend_add, shadows_disabled;

uniform vec4 glow : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float snap = 180.0;
global uniform float psx_jitter;

void vertex() {
	vec4 clip = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	vec2 grid = vec2(snap * VIEWPORT_SIZE.x / VIEWPORT_SIZE.y, snap) * 0.5;
	if (psx_jitter > 0.0) {
		clip.xy = round(clip.xy / clip.w * grid) / grid * clip.w;
	}
	POSITION = clip;
}

void fragment() {
	ALBEDO = glow.rgb;
}
