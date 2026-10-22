shader_type spatial;
render_mode cull_disabled;  // roof sheet is seen from below

// A PBR texture set (Poly Haven diff / nor_gl / arm) that stops reading as a repeat: every
// `cell_size` cell (a mat, a sheet) gets its own tone and, if `turn_cells`, a quarter turn; a
// second, larger and turned sample of the albedo breaks the texture's own repeat; big soft
// grime and worn patches sit on top; and for floors, a wear band where people stand.
// World-space projection (picked from the normal), or the mesh's own UVs when `mesh_uv`
// (corrugated sheet, whose ridges must keep the mesh's direction).

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D arm_tex : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D grime_tex : hint_default_white, filter_linear_mipmap, repeat_enable;  // seamless noise
uniform vec3 tint : source_color = vec3(1.0);
uniform float brightness = 1.0;
uniform bool mesh_uv = false;
uniform vec2 uv_scale = vec2(1.0);    // mesh_uv: UV multiplier
uniform float tex_size = 2.0;         // world: m covered by one texture repeat
uniform float cell_size = 2.0;        // m: one mat / sheet with its own tone
uniform bool turn_cells = false;
uniform float cell_tone = 0.08;       // +- brightness per cell
uniform float odd_cells = 0.06;       // share of cells swapped for a newer, darker one
uniform float antitile = 0.45;        // how much the big turned sample modulates the albedo
uniform vec3 grime_color : source_color = vec3(0.09, 0.08, 0.07);
uniform float grime = 0.35;           // big soft dirt
uniform float grime_scale = 0.06;     // 1/m
uniform vec3 rust_color : source_color = vec3(0.36, 0.17, 0.07);
uniform float rust = 0.0;             // metal: rust bloom in the grime's dark spots
uniform float wear_x = -1000.0;       // floor: x of a standing line (the railing); worn just behind it
uniform float wear_width = 3.0;

varying vec3 world_pos;
varying vec3 world_normal;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 n = abs(world_normal);
	vec2 p = n.y > 0.5 ? world_pos.xz : (n.x > n.z ? world_pos.zy : world_pos.xy);
	vec2 cell = floor(p / cell_size);
	float h = hash(cell);
	float h2 = hash(cell + 17.3);
	mat2 rot = mat2(1.0);
	vec2 uv;
	if (mesh_uv) {
		uv = UV * uv_scale;
	} else {
		float angle = turn_cells ? floor(h2 * 4.0) * PI * 0.5 : 0.0;
		rot = mat2(vec2(cos(angle), sin(angle)), vec2(-sin(angle), cos(angle)));
		uv = rot * (p / tex_size);
	}
	vec3 albedo = texture(albedo_tex, uv).rgb;
	// The texture's own repeat: a second sample 3.7x larger and turned, used for its brightness only.
	vec3 big = texture(albedo_tex, mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8)) * (p / (tex_size * 3.7))).rgb;
	float base_l = max(dot(textureLod(albedo_tex, vec2(0.5), 10.0).rgb, vec3(0.333)), 0.02);
	albedo *= mix(1.0, dot(big, vec3(0.333)) / base_l, antitile);
	// Per cell: tone, and now and then a replaced, newer piece.
	float tone = 1.0 + (h - 0.5) * 2.0 * cell_tone;
	if (h2 > 1.0 - odd_cells) {
		tone *= 0.82;
	}
	albedo *= tone;
	vec3 arm = texture(arm_tex, uv).rgb;
	float rough = arm.g;
	// Big soft grime: two noise scales.
	float g = texture(grime_tex, p * grime_scale).r * 0.65 + texture(grime_tex, p * grime_scale * 3.3 + 0.37).r * 0.35;
	float dirt = smoothstep(0.45, 0.8, g) * grime;
	// Standing line: dirtier and scuffed smooth just behind it.
	float wear = 0.0;
	if (wear_x > -999.0 && n.y > 0.5) {
		float d = wear_x - world_pos.x;
		wear = (1.0 - smoothstep(0.0, wear_width, abs(d - wear_width * 0.4))) * (0.55 + 0.45 * g);
	}
	albedo = mix(albedo, grime_color, clamp(dirt + wear * 0.45, 0.0, 0.85));
	rough = clamp(rough - wear * 0.25 + dirt * 0.1, 0.05, 1.0);
	float rust_mask = smoothstep(0.55, 0.15, g) * rust * (0.6 + 0.4 * h);
	albedo = mix(albedo, rust_color * (0.7 + 0.6 * texture(grime_tex, p * 0.9).r), clamp(rust_mask, 0.0, 1.0));
	float metal = arm.b * (1.0 - rust_mask);

	ALBEDO = albedo * tint * brightness;
	ROUGHNESS = mix(rough, 0.95, rust_mask);
	METALLIC = metal;
	AO = arm.r;
	vec3 nm = texture(normal_tex, uv).rgb;
	vec2 nxy = (nm.xy * 2.0 - 1.0) * rot;
	NORMAL_MAP = vec3(nxy * 0.5 + 0.5, nm.z);
}
