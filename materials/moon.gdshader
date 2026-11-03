shader_type spatial;
// A moon's disc (scripts/day_night.gd): a quad far off that always faces the eye, unlit and out of
// the fog, its face a small unfiltered picture (the PS1's), lit as far as the phase goes, darker at
// its edge as a ball is. Round it a faint halo (the haze it lights). `eclipse` darkens the face to
// next to nothing but a thin burning rim. The disc fills DISC of the quad; the rest is halo.
render_mode unshaded, fog_disabled, cull_disabled, shadows_disabled, depth_draw_never, blend_mix;

const float DISC = 0.55;

uniform sampler2D face : source_color, filter_nearest;
uniform float phase = 1.0;  // 1 full, 0.5 half (lit on the right), 0 new
uniform float fade = 1.0;  // 0 by day
uniform vec3 tint : source_color = vec3(0.85, 0.9, 1.0);
uniform float limb = 0.35;  // how much darker the edge is
uniform float halo = 0.0;  // the halo's strength
uniform vec3 halo_color : source_color = vec3(0.5, 0.5, 0.55);
uniform float eclipse = 0.0;  // 0 none, 1 the face dark but for its rim
uniform float steps = 24.0;  // the halo comes in rings this many to its edge (no smooth PS1 gradients)

void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
}

void fragment() {
	vec2 q = UV * 2.0 - 1.0;
	float r = length(q) / DISC;
	if (r > 1.0) {
		float h = clamp(1.0 - (r - 1.0) / (1.0 / DISC - 1.0), 0.0, 1.0);
		h = floor(h * steps) / steps;
		h = h * h * h * halo;
		if (h <= 0.004) {
			discard;
		}
		ALBEDO = halo_color;
		ALPHA = h * fade;
	} else {
		vec2 p = q / DISC;
		p.y = -p.y;
		vec3 n = vec3(p, sqrt(max(0.0, 1.0 - dot(p, p))));
		float a = (1.0 - phase) * PI;  // where the sun stands from the moon, round from behind the eye
		float lit = step(0.0, dot(n, vec3(sin(a), 0.0, cos(a))));
		vec2 uv = p * vec2(0.5, -0.5) + 0.5;
		vec3 c = texture(face, uv).rgb * tint * mix(1.0 - limb, 1.0, n.z) * mix(0.03, 1.0, lit);
		float rim = smoothstep(0.82, 0.98, r);
		c = mix(c, c * 0.04 + tint * rim * 1.4, eclipse);
		ALBEDO = c;
		ALPHA = fade;
	}
}
