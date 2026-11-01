shader_type spatial;

// The scrap heap's surface under the drawn pieces (scripts/pile.gd): the dark jumble the pieces
// lie on. Small plates, each a Voronoi cell in world space with its own metal (ambientCG rust or
// bare steel under a tint: old paint, grime), its own turn and offset, black gaps between them;
// kept dark so it reads as depth under the lit pieces. Mapped triplanar: the face is near vertical.

uniform sampler2D rust_col : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rust_nrm : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rust_rgh : hint_roughness_r, filter_linear_mipmap, repeat_enable;
uniform sampler2D steel_col : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D steel_nrm : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D steel_rgh : hint_roughness_r, filter_linear_mipmap, repeat_enable;
uniform float piece = 0.16;      // m, how big the plates are
uniform float tex_size = 0.6;    // m one texture repeat covers
uniform float gap = 0.35;        // of a plate, dark between them
uniform float depth_dark = 0.45; // the whole surface: in the shade of what lies on it
// Old paint and grime over the steel, picked per plate.
uniform vec3 tint_a : source_color = vec3(0.30, 0.36, 0.42);
uniform vec3 tint_b : source_color = vec3(0.36, 0.40, 0.30);
uniform vec3 tint_c : source_color = vec3(0.52, 0.46, 0.38);

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

vec3 hash3(vec3 p) {
	p = vec3(dot(p, vec3(127.1, 311.7, 74.7)), dot(p, vec3(269.5, 183.3, 246.1)), dot(p, vec3(113.5, 271.9, 124.6)));
	return fract(sin(p) * 43758.5453123);
}

// Nearest and second nearest feature: which plate, and how far into its gap.
void voronoi(vec3 p, out vec3 id, out float edge) {
	vec3 b = floor(p);
	float d1 = 8.0;
	float d2 = 8.0;
	for (int z = -1; z <= 1; z++)
	for (int y = -1; y <= 1; y++)
	for (int x = -1; x <= 1; x++) {
		vec3 g = b + vec3(float(x), float(y), float(z));
		vec3 f = g + hash3(g);
		float d = length(p - f);
		if (d < d1) {
			d2 = d1;
			d1 = d;
			id = g;
		} else if (d < d2) {
			d2 = d;
		}
	}
	edge = d2 - d1;
}

void fragment() {
	vec3 id;
	float edge;
	voronoi(world_pos / piece, id, edge);
	vec3 r = hash3(id + 17.0);
	vec3 w = pow(abs(world_normal), vec3(4.0));
	w /= w.x + w.y + w.z;
	// Each plate turned and shifted on its own.
	float a = r.x * 6.2832;
	mat2 turn = mat2(vec2(cos(a), sin(a)), vec2(-sin(a), cos(a)));
	vec2 ux = turn * world_pos.zy / tex_size + r.yz * 7.0;
	vec2 uy = turn * world_pos.xz / tex_size + r.yz * 7.0;
	vec2 uz = turn * world_pos.xy / tex_size + r.yz * 7.0;
	vec3 col;
	vec3 nrm;
	float rgh;
	// Which metal: mostly rust, the rest bare or painted steel.
	float m = hash3(id + 3.0).x;
	if (m < 0.6) {
		col = texture(rust_col, ux).rgb * w.x + texture(rust_col, uy).rgb * w.y + texture(rust_col, uz).rgb * w.z;
		nrm = texture(rust_nrm, ux).rgb * w.x + texture(rust_nrm, uy).rgb * w.y + texture(rust_nrm, uz).rgb * w.z;
		rgh = texture(rust_rgh, ux).r * w.x + texture(rust_rgh, uy).r * w.y + texture(rust_rgh, uz).r * w.z;
	} else {
		col = texture(steel_col, ux).rgb * w.x + texture(steel_col, uy).rgb * w.y + texture(steel_col, uz).rgb * w.z;
		nrm = texture(steel_nrm, ux).rgb * w.x + texture(steel_nrm, uy).rgb * w.y + texture(steel_nrm, uz).rgb * w.z;
		rgh = texture(steel_rgh, ux).r * w.x + texture(steel_rgh, uy).r * w.y + texture(steel_rgh, uz).r * w.z;
		float k = hash3(id + 9.0).x;
		col *= k < 0.33 ? tint_a : (k < 0.66 ? tint_b : tint_c);
	}
	float lit = smoothstep(0.0, gap, edge);  // 0 down in the gaps between plates
	col *= mix(0.5, 1.1, r.z) * depth_dark;
	ALBEDO = col * mix(0.03, 1.0, lit);
	METALLIC = m < 0.6 ? 0.3 : 0.7;
	ROUGHNESS = mix(1.0, rgh, lit);
	AO = mix(0.2, 1.0, lit);
	NORMAL_MAP = nrm;
	NORMAL_MAP_DEPTH = 1.2;
}
