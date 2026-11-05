// PS1 horror props (2026-11-02, the user: the whole game in the PSX horror look): materials/psx.gdshader
// for the world's things, its uniforms under the same names and doing the same (see there), with
// what props need on top. tools/psx_props.gd hands it out; psx_prop.gdshader culls back faces,
// psx_prop_2s.gdshader draws both (sheets, cards).
//   vertex_tint: COLOR multiplies the texture: the scrap's MultiMesh copies carry their tone there
//   triplanar: the texture by world position every tri_metres (boxes with no UVs worth having)
//   uv_offset: glTF's texture offset, with uv_scale
//   far_colour, far_fade: from far_fade.x to far_fade.y metres away the piece goes over to one flat
//               colour (its texture's average; alpha 0: off), its copy's tone too: hundreds of small
//               pieces in the distance stop boiling on the 270p screen (2026-11-03, the user)
// Textures are unfiltered but mipmapped (filter_nearest_mipmap): far away they average, not sparkle.

#ifdef PSX_SOFT
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_enable, hint_default_white;
#else
uniform sampler2D albedo_tex : source_color, filter_nearest_mipmap, repeat_enable, hint_default_white;
#endif
uniform vec4 tint : source_color = vec4(1.0);
uniform float snap = 180.0;
uniform float alpha_cut = 0.0;
uniform float snap_world = 0.0;
uniform float affine : hint_range(0.0, 1.0) = 0.0;
global uniform float psx_jitter;  // 0: snap, snap_world and affine off (materials/psx.gdshader)
uniform sampler2D emission_tex : source_color, filter_nearest_mipmap, repeat_enable, hint_default_white;
uniform vec4 emission : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float emission_energy = 1.0;
uniform vec2 uv_scale = vec2(1.0);
uniform vec2 uv_offset = vec2(0.0);
uniform bool vertex_tint = false;
uniform bool triplanar = false;
uniform float tri_metres = 2.0;
uniform vec4 far_colour : source_color = vec4(0.0);
uniform vec2 far_fade = vec2(20.0, 60.0);
uniform vec2 shade_below = vec2(0.0, 1.0);  // x m above the world's floor down to it the light goes to y of itself (0: off): under a wood's canopy
uniform vec3 shade_near = vec3(0.0);  // by day, closer than x m (fading out by y) the canopy's shade lets at least z of the light through (z 0: off)
uniform float near_fill = 0.0;  // ...and in that reach the bark's own colour times this on top, the sky's bounce: a trunk with the sun behind it was black
#ifdef PSX_SOFT
// ...and in that reach a real bark's light and dark worked into the trunk's own colour, by world place
// every bark_metres: the scanned cherry's bark was a smooth brown smear at 512 px (bark_detail 0: off)
uniform sampler2D bark_tex : source_color, filter_linear_mipmap, repeat_enable, hint_default_white;
uniform float bark_detail = 0.0;
uniform float bark_metres = 1.2;
#endif
#ifdef PSX_SOFT
global uniform float psx_haze_day;  // 1 by day, 0 by night (scripts/scrap_hills.gd)
uniform float night_fill = 5.0;  // by night the sky's light on the first trees, times: the dark sky lights so little that 15-bit colour shows them as black
#endif
#ifdef PSX_HAZE
// Instead of the scene's fog (psx_far.gdshader): into psx_haze_colour from psx_haze_range.x to .y
// metres, at most psx_haze_max of the way. Globals (scrap_hills.gd sets them from the fog): the PS1
// screen hands out its own copies of materials, per-material values never reached those.
global uniform vec4 psx_haze_colour;
global uniform vec2 psx_haze_range;
global uniform float psx_haze_max;
#endif

varying vec3 affine_uv;
varying vec3 world_pos;
varying vec3 world_nrm;

void vertex() {
	UV = UV * uv_scale + uv_offset;
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_nrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vec4 view = MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	if (snap_world > 0.0 && psx_jitter > 0.0) {
		view.xyz = round(view.xyz / snap_world) * snap_world;
	}
	vec4 clip = PROJECTION_MATRIX * view;
	if (snap > 0.0 && psx_jitter > 0.0) {
		vec2 grid = vec2(snap * VIEWPORT_SIZE.x / VIEWPORT_SIZE.y, snap) * 0.5;
		clip.xy = round(clip.xy / clip.w * grid) / grid * clip.w;
	}
	POSITION = clip;
#ifdef PSX_HAZE
	// Going flat with distance, its light goes flat too: a thousand pieces each turned its own way
	// to the sun were the mountain's "ants" at 270p (2026-11-04, the user).
	if (far_colour.a > 0.0) {
		vec3 up = normalize(transpose(mat3(MODEL_MATRIX)) * vec3(0.0, 1.0, 0.0));
		NORMAL = normalize(mix(NORMAL, up, smoothstep(far_fade.x, far_fade.y, length(view.xyz))));
	}
#endif
	affine_uv = vec3(UV * clip.w, clip.w);
}

void fragment() {
	vec2 uv = mix(UV, affine_uv.xy / affine_uv.z, affine * psx_jitter);
	vec4 c;
	if (triplanar) {
		vec3 w = abs(world_nrm);
		w /= w.x + w.y + w.z;
		vec3 p = world_pos / tri_metres;
		c = texture(albedo_tex, p.zy) * w.x + texture(albedo_tex, p.xz) * w.y + texture(albedo_tex, p.xy) * w.z;
	} else {
		c = texture(albedo_tex, uv);
	}
	c *= tint;
	float shade = 1.0;
	if (vertex_tint) {
		c.rgb *= COLOR.rgb;
	}
	if (alpha_cut > 0.0 && c.a < alpha_cut) {
		discard;
	}
	float far = smoothstep(far_fade.x, far_fade.y, length(VERTEX)) * far_colour.a;
#ifdef PSX_HAZE
	// Each copy keeps its tone in the far colour too: the mountain reads as lumps of scrap, not as one
	// sandy colour with dark specks (2026-11-05, the user: every object apart).
	ALBEDO = mix(c.rgb, far_colour.rgb * (vertex_tint ? COLOR.rgb : vec3(1.0)), far);
#else
	ALBEDO = mix(c.rgb, far_colour.rgb, far);
#endif
	if (shade_below.x > 0.0) {
		shade = mix(shade_below.y, 1.0, smoothstep(0.0, shade_below.x, world_pos.y));
	}
	// The trunk you stand by reads, its bark too; the wood's depths stay dark (2026-11-05, the user:
	// up close the trunks were a black blur).
	float shade_lit = shade;
	if (shade_near.z > 0.0) {
		shade_lit = mix(max(shade, shade_near.z), shade, smoothstep(shade_near.x, shade_near.y, length(VERTEX)));
	}
#ifdef PSX_SOFT
	float nearby = shade_near.z > 0.0 ? 1.0 - smoothstep(shade_near.x, shade_near.y, length(VERTEX)) : 0.0;
	if (bark_detail > 0.0 && nearby > 0.0) {
		vec2 w = abs(world_nrm.xz) + 0.001;
		w /= w.x + w.y;
		vec3 p = world_pos / bark_metres;
		vec3 b = texture(bark_tex, vec2(p.z, -p.y)).rgb * w.x + texture(bark_tex, vec2(p.x, -p.y)).rgb * w.y;
		float mid = max(dot(textureLod(bark_tex, vec2(0.5), 12.0).rgb, vec3(0.333)), 0.005);  // its smallest mip: its average, in the same (linear) light
		float ratio = clamp(pow(dot(b, vec3(0.333)) / mid, 0.8), 0.3, 1.8);
		ALBEDO *= mix(1.0, ratio, bark_detail * nearby * (1.0 - abs(world_nrm.y)));
	}
	// Moss up the trunks of the wood, in patches by place (2026-11-05, the user: old and damp). Damp
	// moss is darker than the bark, not lighter: lifted it read as a yellow-green glow at the foot.
	float moss = 0.0;
	if (shade_below.x > 0.0) {
		float blot = sin(world_pos.x * 2.3 + 1.7 * sin(world_pos.z * 3.1 + world_pos.y * 1.4)) * sin(world_pos.y * 2.7 + 2.0 * sin(world_pos.x * 2.1) + world_pos.z * 2.6);
		float low = 1.0 - smoothstep(0.1, 2.0, world_pos.y);
		moss = smoothstep(-0.5, 0.6, blot + low * 0.6) * low;
		float bark = dot(ALBEDO, vec3(0.333));
		ALBEDO = mix(ALBEDO, (bark * 0.9 + 0.015) * vec3(0.92, 1.12, 0.6), moss * 0.6);
	}
	// The wood's dark (each copy's tone, the canopy's shade) is where the sky's light doesn't reach, not
	// a black bark: by night the lamp and the fire still show a tree's colours deep in the wood.
	float night = 1.0 - psx_haze_day;
	float tone = vertex_tint ? clamp(dot(COLOR.rgb, vec3(0.333)), 0.05, 1.0) : 1.0;
	ALBEDO *= mix(shade_lit, 1.0 / tone, night);
	// Pale textures lifted less: by the sky's light alone a pale fir stood out grey among the others.
	float pale = 1.0 / (1.0 + 5.0 * dot(ALBEDO, vec3(0.333)));
	AO = mix(1.0, shade * mix(tone, 1.0, 0.2) * night_fill * pale * 1.3, night);
	AO_LIGHT_AFFECT = 0.0;
#else
	ALBEDO *= shade;
#ifndef PSX_HAZE
	// Damp climbing the foot of whatever stands on the floor (2026-11-05, the user: everything looks
	// planted there): dark and a little moss, ragged by place, a hand or two up.
	float up = world_pos.y + 0.18 * sin(world_pos.x * 3.7 + 2.0 * sin(world_pos.z * 4.3));
	float foot = 1.0 - smoothstep(0.02, 0.55, up);
	ALBEDO = mix(ALBEDO, dot(ALBEDO, vec3(0.333)) * vec3(0.9, 1.1, 0.45), foot * 0.5) * mix(1.0, 0.5, foot);
#endif
#endif
	ROUGHNESS = 1.0;
	EMISSION = texture(emission_tex, uv).rgb * emission.rgb * emission_energy;
#ifdef PSX_SOFT
	// The sky's bounce on the trunk you stand by: strongest where the bark faces you, falling off to its
	// sides, so it stays round and its bark reads; the moss takes none, it only glowed (2026-11-05, the
	// user: "the trees break").
	if (near_fill > 0.0) {
		float facing = mix(0.35, 1.0, clamp(NORMAL.z, 0.0, 1.0));
		EMISSION += ALBEDO * near_fill * facing * (1.0 - moss * 0.4) * psx_haze_day * nearby;
	}
#endif
#ifdef PSX_HAZE
	// The far colour broken into big soft patches, by place, never by piece: they can't crawl.
	vec2 q = world_pos.xz * 0.11 + vec2(world_pos.y * 0.07);
	float patch = 0.5 + 0.25 * (sin(q.x + 1.7 * sin(q.y * 0.6)) + sin(q.y * 1.3 + 1.4 * sin(q.x * 0.7)));
	ALBEDO *= mix(1.0, mix(0.62, 1.15, patch), far);
	if (!FRONT_FACING) {
		ALBEDO *= 0.6;
	}
	float haze = smoothstep(psx_haze_range.x, psx_haze_range.y, length(VERTEX)) * psx_haze_max;
	ALBEDO *= 1.0 - haze;
	EMISSION = EMISSION * (1.0 - haze) + psx_haze_colour.rgb * haze;
#endif
}
