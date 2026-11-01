shader_type spatial;

// The scrap heap's surface under the drawn pieces (scripts/pile.gd): more of the same scrap, packed
// deep. A tile baked from the real pieces (tools/build_scrap_carpet.gd: colour darkened in the
// cracks, height in alpha, normal map), mapped triplanar since the face is near vertical. Two
// takes on it, turned and scaled apart, are mixed by height (the higher piece wins) under a slow
// noise, so the repeat doesn't show; kept a little dark, in the shade of what lies on it.

uniform sampler2D carpet_col : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D carpet_nrm : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float tile = 2.0;        // m one repeat covers (build_scrap_carpet.gd TILE)
uniform float depth_dark = 0.55; // the whole surface: under the pieces drawn over it

// Heap shape: height per cell, written by pile.gd as scrap is taken and slopes slide.
uniform sampler2D height_field : filter_nearest;
// Heights one physics tick earlier; slides are drawn between the two.
uniform sampler2D height_prev : filter_nearest;
uniform float blend = 1.0;  // Engine.get_physics_interpolation_fraction(), set every frame
uniform ivec2 grid = ivec2(128, 224);
uniform float cell_size = 0.25;

varying vec3 world_pos;
varying vec3 world_normal;

float field(ivec2 c) {
	ivec2 t = clamp(c, ivec2(0), grid - 1);
	return mix(texelFetch(height_prev, t, 0).r, texelFetch(height_field, t, 0).r, blend);
}

void vertex() {
	// The plane's vertices sit on cell centres.
	ivec2 c = ivec2(round(VERTEX.xz / cell_size + vec2(grid - 1) * 0.5));
	float h = field(c);
	VERTEX.y = h > 0.004 ? h : -0.05;  // empty cells tuck under the floor
	NORMAL = normalize(vec3(field(c - ivec2(1, 0)) - field(c + ivec2(1, 0)), 2.0 * cell_size,
			field(c - ivec2(0, 1)) - field(c + ivec2(0, 1))));
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

float hash(vec3 p) {
	return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453123);
}

// Smooth value noise: which take shows where.
float noise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = smoothstep(0.0, 1.0, fract(p));
	return mix(mix(mix(hash(i), hash(i + vec3(1, 0, 0)), f.x), mix(hash(i + vec3(0, 1, 0)), hash(i + vec3(1, 1, 0)), f.x), f.y),
			mix(mix(hash(i + vec3(0, 0, 1)), hash(i + vec3(1, 0, 1)), f.x), mix(hash(i + vec3(0, 1, 1)), hash(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

// One take of the tile over the three planes: colour with height in alpha, and the normal.
void take(vec3 p, vec3 w, mat2 turn, float scale, out vec4 col, out vec3 nrm) {
	vec2 ux = turn * p.zy / (tile * scale);
	vec2 uy = turn * p.xz / (tile * scale);
	vec2 uz = turn * p.xy / (tile * scale);
	col = texture(carpet_col, ux) * w.x + texture(carpet_col, uy) * w.y + texture(carpet_col, uz) * w.z;
	nrm = texture(carpet_nrm, ux).rgb * w.x + texture(carpet_nrm, uy).rgb * w.y + texture(carpet_nrm, uz).rgb * w.z;
}

void fragment() {
	vec3 w = pow(abs(world_normal), vec3(4.0));
	w /= w.x + w.y + w.z;
	vec4 col_a;
	vec3 nrm_a;
	vec4 col_b;
	vec3 nrm_b;
	take(world_pos, w, mat2(vec2(1.0, 0.0), vec2(0.0, 1.0)), 1.0, col_a, nrm_a);
	take(world_pos + vec3(0.37, 0.0, 0.81), w, mat2(vec2(0.267, 0.964), vec2(-0.964, 0.267)), 0.83, col_b, nrm_b);
	// Where the noise leans to b, b's pieces come up over a's; the higher one wins at the edge.
	float lean = noise(world_pos * 0.9) * 0.6 - 0.3;
	float pick = smoothstep(-0.04, 0.04, col_b.a - col_a.a + lean);
	vec4 col = mix(col_a, col_b, pick);
	ALBEDO = col.rgb * depth_dark;
	METALLIC = 0.35;
	ROUGHNESS = 0.85;
	AO = mix(0.4, 1.0, col.a);
	NORMAL_MAP = mix(nrm_a, nrm_b, pick);
	NORMAL_MAP_DEPTH = 1.0;
}
