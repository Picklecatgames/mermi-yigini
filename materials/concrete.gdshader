shader_type spatial;

// Scanned concrete (Poly Haven "Concrete Floor Worn 001", CC0) on world-space UVs, so any
// surface size keeps the same texel density. Projection picked from the world normal, so the
// same material works on floors and walls. Every 4 m slab gets its own random shift and
// quarter turn of the texture; the joints hide where one slab's texture ends.

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rough_tex : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D ao_tex : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform sampler2D stain_tex : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform vec3 tint : source_color = vec3(1.0);
uniform float brightness = 1.35;   // the scan is an indoor floor; outdoors it reads lighter
uniform float tex_size = 2.0;      // m covered by one texture repeat
uniform float stain_scale = 0.04;  // large, non-repeating dirt
uniform float normal_strength = 1.0;
uniform float slab_size = 4.0;     // joint spacing (m): floor slabs / precast wall panels
uniform float seam_width = 0.012;  // m

varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 n = abs(world_normal);
	vec2 p = n.y > 0.5 ? world_pos.xz : (n.x > n.z ? world_pos.zy : world_pos.xy);

	vec2 slab = floor(p / slab_size + 0.5);
	vec3 rnd = fract(sin(vec3(dot(slab, vec2(12.9898, 78.233)), dot(slab, vec2(39.346, 11.135)),
			dot(slab, vec2(73.156, 52.235)))) * 43758.5453);
	float angle = floor(rnd.z * 4.0) * PI * 0.5;
	mat2 rot = mat2(vec2(cos(angle), sin(angle)), vec2(-sin(angle), cos(angle)));
	vec2 uv = rot * (p / tex_size) + rnd.xy;

	float stain = texture(stain_tex, p * stain_scale).r;
	vec2 to_seam = abs(fract(p / slab_size + 0.5) - 0.5) * slab_size;
	float d = min(to_seam.x, to_seam.y);
	// fwidth keeps the joint anti-aliased and fades it out at a distance instead of dotting.
	float aa = fwidth(d);
	float seam = (1.0 - smoothstep(seam_width * 0.5, seam_width * 0.5 + aa, d)) * clamp(seam_width / max(aa, 1e-4), 0.0, 1.0);
	// Each pour cures slightly differently: per-slab brightness jitter.
	float slab_tint = mix(0.95, 1.04, rnd.x);

	// The scan's own 2 m repeat still shows across a 56 m floor: a 3.7x larger, turned sample
	// modulates the brightness, at a scale the slabs never line up with.
	float big = dot(texture(albedo_tex, mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8)) * (p / (tex_size * 3.7))).rgb, vec3(0.333));
	float mean = max(dot(textureLod(albedo_tex, vec2(0.5), 10.0).rgb, vec3(0.333)), 0.02);
	ALBEDO = texture(albedo_tex, uv).rgb * mix(1.0, big / mean, 0.4) * tint * brightness * slab_tint * mix(0.85, 1.0, stain) * (1.0 - seam * 0.6);
	ROUGHNESS = mix(0.75, 1.0, texture(rough_tex, uv).r);  // weathered, not polished
	AO = texture(ao_tex, uv).r * (1.0 - seam * 0.5);
	// Undo the slab's quarter turn on the normal's tangent-space xy.
	vec3 nm = texture(normal_tex, uv).rgb;
	vec2 nxy = (nm.xy * 2.0 - 1.0) * rot;
	NORMAL_MAP = vec3(nxy * 0.5 + 0.5, nm.z);
	NORMAL_MAP_DEPTH = normal_strength;
}
