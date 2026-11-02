// PS1 horror look (2026-11-02, the user: low poly but close to realistic gore horror, not mobile):
// the real texture kept but small and unfiltered, lit per vertex, vertices snapped to a coarse
// screen grid so they jitter as on the old console. tools/lowpoly_zombie.gd psx hands it out.
shader_type spatial;
render_mode vertex_lighting, specular_disabled, diffuse_lambert;

uniform sampler2D albedo_tex : source_color, filter_nearest, repeat_enable;
uniform vec4 tint : source_color = vec4(1.0);
uniform float snap = 180.0;  // vertical grid the vertices snap to, in steps per screen height
uniform float alpha_cut = 0.0;  // above 0: a cutout (hair, torn cloth)

void vertex() {
	vec4 clip = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	vec2 grid = vec2(snap * VIEWPORT_SIZE.x / VIEWPORT_SIZE.y, snap) * 0.5;
	clip.xy = round(clip.xy / clip.w * grid) / grid * clip.w;
	POSITION = clip;
}

void fragment() {
	vec4 c = texture(albedo_tex, UV) * tint;
	if (alpha_cut > 0.0 && c.a < alpha_cut) {
		discard;
	}
	ALBEDO = c.rgb;
	ROUGHNESS = 1.0;
}
