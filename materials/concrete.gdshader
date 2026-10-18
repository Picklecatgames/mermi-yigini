shader_type spatial;

// World-space UVs: floor can be any size, texel density stays constant.
uniform sampler2D grain_tex : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D stain_tex : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec3 base_color : source_color = vec3(0.62, 0.60, 0.57);
uniform float grain_scale = 0.5;   // repeats per meter
uniform float stain_scale = 0.04;  // large, non-repeating-looking dirt
uniform float normal_scale = 0.5;
uniform float normal_strength = 0.8;
uniform float slab_size = 4.0;     // expansion joint spacing (m)
uniform float seam_width = 0.012;  // m

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = world_pos.xz;
	float grain = texture(grain_tex, p * grain_scale).r;
	float stain = texture(stain_tex, p * stain_scale).r;

	vec2 to_seam = abs(fract(p / slab_size + 0.5) - 0.5) * slab_size;
	float d = min(to_seam.x, to_seam.y);
	// fwidth keeps the joint anti-aliased and fades it out at a distance instead of dotting.
	float aa = fwidth(d);
	float seam = (1.0 - smoothstep(seam_width * 0.5, seam_width * 0.5 + aa, d)) * clamp(seam_width / max(aa, 1e-4), 0.0, 1.0);

	// Each pour cures slightly differently: per-slab brightness jitter.
	vec2 slab = floor(p / slab_size + 0.5);
	float slab_tint = mix(0.92, 1.06, fract(sin(dot(slab, vec2(12.9898, 78.233))) * 43758.5453));

	ALBEDO = base_color * slab_tint * mix(0.75, 1.15, grain) * mix(0.6, 1.05, stain) * (1.0 - seam * 0.6);
	ROUGHNESS = clamp(mix(0.8, 0.95, grain) - (1.0 - stain) * 0.15, 0.0, 1.0);
	AO = 1.0 - seam * 0.5;
	NORMAL_MAP = texture(normal_tex, p * normal_scale).rgb;
	NORMAL_MAP_DEPTH = normal_strength;
}
