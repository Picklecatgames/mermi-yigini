shader_type spatial;
render_mode blend_add, unshaded, cull_disabled, depth_draw_never, shadows_disabled;

// A visible spotlight beam on an open cone (CylinderMesh, no caps, narrow end at the lens).
// Additive glow that is strongest at the lens and fades down the beam, soft at the silhouette
// so the cone has no hard outline, and faded where it meets the heap or the floor so it never
// shows a cut line.

uniform vec3 color : source_color = vec3(1.0);
uniform float strength = 0.8;
uniform float fade_power = 0.9;    // how fast it dims down the beam
uniform float edge_softness = 0.9; // higher = thinner-looking edges
uniform float contact_fade = 0.6;  // m over which it fades into surfaces it touches
uniform sampler2D depth_texture : hint_depth_texture, filter_linear_mipmap;

void fragment() {
	// CylinderMesh side UV: v runs 0 at the top (lens) to 0.5 at the bottom (the caps get the rest).
	float along = clamp(UV.y * 2.0, 0.0, 1.0);
	float fade = pow(1.0 - along, fade_power) * smoothstep(0.0, 0.04, along);
	float facing = pow(abs(dot(normalize(NORMAL), normalize(VIEW))), edge_softness);

	float scene_z = texture(depth_texture, SCREEN_UV).r;
	vec4 scene = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, scene_z, 1.0);
	float scene_dist = -scene.z / scene.w;
	float contact = clamp((scene_dist - (-VERTEX.z)) / contact_fade, 0.0, 1.0);

	ALBEDO = color;
	ALPHA = strength * fade * facing * contact;
}
