shader_type spatial;

// Ground outside the shed, on world-space UVs: a gravel yard inside the fence, dry veld past it.
// Tiling is broken up by blending each texture with a shifted copy of itself under a large noise.

uniform sampler2D yard_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D yard_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D yard_arm : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform sampler2D field_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D field_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D field_arm : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform sampler2D noise_tex : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform float yard_size = 3.0;    // m per texture repeat
uniform float field_size = 6.0;
uniform float yard_half = 44.0;   // m, fence line
uniform vec3 tint : source_color = vec3(1.0);

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

// Two shifted samples blended by noise: no texture repeat lines up with the next one.
// A macro, not a function: one sampler argument can't take textures with different hints.
#define detile(t, uv, k) mix(texture(t, uv), texture(t, (uv) * 0.87 + vec2(0.37, 0.61)), k)

void fragment() {
	vec2 p = world_pos.xz;
	float n = texture(noise_tex, p * 0.013).r;
	float k = smoothstep(0.35, 0.65, texture(noise_tex, p * 0.031 + 0.5).r);
	// Square yard with a ragged edge where the gravel thins into the field.
	float edge = max(abs(p.x), abs(p.y)) - yard_half + (n - 0.5) * 6.0;
	float field = smoothstep(-1.0, 3.0, edge);

	vec2 yu = p / yard_size;
	vec2 fu = p / field_size;
	vec3 alb = mix(detile(yard_albedo, yu, k).rgb, detile(field_albedo, fu, k).rgb, field);
	vec3 arm = mix(detile(yard_arm, yu, k).rgb, detile(field_arm, fu, k).rgb, field);
	vec3 nm = mix(detile(yard_normal, yu, k).rgb, detile(field_normal, fu, k).rgb, field);

	// Texture detail averages out at grazing angles far away; large patches of scrub and bare
	// earth keep the veld from reading as one flat colour up to the horizon.
	float patch = smoothstep(0.3, 0.7, texture(noise_tex, p * 0.0021 + 0.13).r);
	float scrub = smoothstep(0.45, 0.75, texture(noise_tex, p * 0.0067 + 0.71).r) * field;
	alb = mix(alb, alb * vec3(0.62, 0.6, 0.45), patch * field);
	alb = mix(alb, vec3(0.16, 0.17, 0.1), scrub * 0.7);
	ALBEDO = alb * tint * mix(0.85, 1.1, n);
	AO = arm.r;
	ROUGHNESS = mix(0.8, 1.0, arm.g);
	METALLIC = 0.0;
	NORMAL_MAP = nm;
}
