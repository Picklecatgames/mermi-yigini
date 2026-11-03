// PS1 horror look (2026-11-02, the user: low poly but close to realistic gore horror, not mobile):
// the real texture kept but small and unfiltered, lit per vertex, vertices snapped to a coarse
// screen grid so they jitter as on the old console. tools/lowpoly_zombie.gd psx hands it out.
// The one shared PS1 material; the screen itself (small, 15-bit, dithered) is scripts/psx_screen.gd.
//
// Uniforms (the first four are the zombies' and keep their names):
//   albedo_tex  the real, dirty texture, 128-256 px; drawn unfiltered (filter_nearest, repeats)
//   tint        multiplies it; its alpha too
//   snap        vertex jitter: the screen grid vertices snap to, steps per screen height (180 the
//               zombies; 225 = one pixel of the default "PS1 ekranı"). 0: no screen snap
//   alpha_cut   above 0: a cutout (hair, torn cloth, leaves); below it the pixel is not drawn, in
//               the shadow too
//   snap_world  metres; above 0 the vertices also snap to a grid of this size in view space, so the
//               wobble is the same size in the world near or far (props, walls); 0: off
//   affine      0..1, the PS1's warped texture (no perspective correction): 0 straight, 1 the full
//               swim; 0.2-0.4 hints at it without tearing big faces. Long faces warp most, split them
//   emission_tex / emission / emission_energy  what glows (a lamp's glass, embers, a screen):
//               emission_tex times emission times energy, added unlit. Black (default) is off
//   uv_scale    tiles the texture (ground, walls)
//
// Fog: the Environment's depth and volumetric fog lay over it like any material, nothing to set.
// Skinned meshes: Godot skins before vertex(), so the snap and the warp follow the bones as is.
// Lights: per vertex (vertex_lighting), so a lamp needs vertices near it to show; split floors.
shader_type spatial;
render_mode vertex_lighting, specular_disabled, diffuse_lambert;

uniform sampler2D albedo_tex : source_color, filter_nearest, repeat_enable;
uniform vec4 tint : source_color = vec4(1.0);
uniform float snap = 180.0;
uniform float alpha_cut = 0.0;
uniform float snap_world = 0.0;
uniform float affine : hint_range(0.0, 1.0) = 0.0;
uniform sampler2D emission_tex : source_color, filter_nearest, repeat_enable, hint_default_white;
uniform vec4 emission : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float emission_energy = 1.0;
uniform vec2 uv_scale = vec2(1.0);

varying vec3 affine_uv;  // uv * w and w: divided back per pixel it is interpolated on screen, not in depth

void vertex() {
	UV *= uv_scale;
	vec4 view = MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	if (snap_world > 0.0) {
		view.xyz = round(view.xyz / snap_world) * snap_world;
	}
	vec4 clip = PROJECTION_MATRIX * view;
	if (snap > 0.0) {
		vec2 grid = vec2(snap * VIEWPORT_SIZE.x / VIEWPORT_SIZE.y, snap) * 0.5;
		clip.xy = round(clip.xy / clip.w * grid) / grid * clip.w;
	}
	POSITION = clip;
	affine_uv = vec3(UV * clip.w, clip.w);
}

void fragment() {
	vec2 uv = mix(UV, affine_uv.xy / affine_uv.z, affine);
	vec4 c = texture(albedo_tex, uv) * tint;
	if (alpha_cut > 0.0 && c.a < alpha_cut) {
		discard;
	}
	ALBEDO = c.rgb;
	ROUGHNESS = 1.0;
	EMISSION = texture(emission_tex, uv).rgb * emission.rgb * emission_energy;
}
