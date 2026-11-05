shader_type spatial;

// The wasteland round the concrete pad (tools/build_world.gd), on world-space UVs: wind-blown sand
// with patches of cracked dry earth, gravel thrown out round the pad. Each texture is blended with
// a shifted copy of itself under a large noise, so no repeat lines up with the next one.

// Albedo unfiltered (2026-11-03, the user: it looked like a modern game turned down, not a PS1 game): on the PS1
// screen scripts/psx_screen.gd shrinks these to 128 px, and their texels then read hard and big.
uniform sampler2D sand_albedo : source_color, filter_nearest_mipmap, repeat_enable;
uniform sampler2D sand_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D sand_arm : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform sampler2D earth_albedo : source_color, filter_nearest_mipmap, repeat_enable;
uniform sampler2D earth_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D earth_arm : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform sampler2D gravel_albedo : source_color, filter_nearest_mipmap, repeat_enable;
uniform sampler2D gravel_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D gravel_arm : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform sampler2D noise_tex : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform float sand_size = 4.0;    // m per texture repeat
uniform float earth_size = 6.0;
uniform float gravel_size = 3.0;
uniform vec4 pad = vec4(-26.0, -14.0, 26.0, 14.0);  // the concrete (x0, z0, x1, z1): gravel round it
uniform float gravel_reach = 9.0;  // m out from the pad's edge
uniform vec3 sand_tint : source_color = vec3(1.0, 0.86, 0.66);
uniform vec3 earth_tint : source_color = vec3(0.86, 0.72, 0.56);

uniform vec4 wood_oval = vec4(0.0);  // the clearing (centre x, z; radii): the floor darkens going into the wood; radii 0: off
uniform float wood_dark = 0.45;  // how dark, deep in
uniform float wood_dark_reach = 16.0;  // m in from the clearing's edge
uniform vec2 night_shade = vec2(-14.0, 7.0);  // m from the clearing's edge: by night the floor goes dark from x to y...
uniform float night_shade_to = 0.1;  // ...to this share of its light, so it meets the trees' dark with no line
global uniform float psx_haze_day;  // 1 by day, 0 by night (scripts/scrap_hills.gd)

#include "res://materials/env/floor_map.gdshaderinc"

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

#define detile(t, uv, k) mix(texture(t, uv), texture(t, (uv) * 0.87 + vec2(0.37, 0.61)), k)

void fragment() {
	vec2 p = world_pos.xz;
	float n = texture(noise_tex, p * 0.013).r;
	float k = smoothstep(0.35, 0.65, texture(noise_tex, p * 0.031 + 0.5).r);
	// Cracked earth where the sand thins: big ragged patches.
	float earth = smoothstep(0.48, 0.62, texture(noise_tex, p * 0.0042 + 0.27).r + (n - 0.5) * 0.15);
	// Gravel spilt round the pad, thinning out ragged into the sand.
	vec2 d = max(pad.xy - p, p - pad.zw);
	float out_of_pad = length(max(d, 0.0)) + min(max(d.x, d.y), 0.0);
	float gravel = 1.0 - smoothstep(0.0, gravel_reach, out_of_pad + (n - 0.5) * 7.0);

	vec2 su = p / sand_size;
	vec2 eu = p / earth_size;
	vec2 gu = p / gravel_size;
	vec3 alb = mix(detile(sand_albedo, su, k).rgb * sand_tint, detile(earth_albedo, eu, k).rgb * earth_tint, earth);
	vec3 arm = mix(detile(sand_arm, su, k).rgb, detile(earth_arm, eu, k).rgb, earth);
	vec3 nm = mix(detile(sand_normal, su, k).rgb, detile(earth_normal, eu, k).rgb, earth);
	alb = mix(alb, detile(gravel_albedo, gu, k).rgb * vec3(0.9, 0.82, 0.7), gravel);
	arm = mix(arm, detile(gravel_arm, gu, k).rgb, gravel);
	nm = mix(nm, detile(gravel_normal, gu, k).rgb, gravel);

	// Far off the texture detail averages out: large sun-bleached and darker drifts keep the
	// desert from reading as one flat colour up to the horizon.
	float patch = smoothstep(0.3, 0.7, texture(noise_tex, p * 0.0019 + 0.13).r);
	alb *= mix(0.88, 1.12, patch) * mix(0.9, 1.06, n);
	if (wood_oval.z > 0.0) {
		float deep = (length((p - wood_oval.xy) / wood_oval.zw) - 1.0) * min(wood_oval.z, wood_oval.w);
		// Darkest at the wood's front, lighter again far in: players walk there (build_world.gd _wood_tone).
		alb *= mix(1.0, wood_dark, smoothstep(0.0, wood_dark_reach, deep + (n - 0.5) * 8.0) * (1.0 - 0.7 * smoothstep(55.0, 85.0, deep)));
		alb *= mix(1.0, night_shade_to, smoothstep(night_shade.x, night_shade.y, deep + (n - 0.5) * 6.0) * (1.0 - psx_haze_day));
	}
	ALBEDO = floor_damp(alb, p);
	AO = arm.r;
	ROUGHNESS = mix(0.82, 1.0, arm.g);
	METALLIC = 0.0;
	NORMAL_MAP = nm;
}
