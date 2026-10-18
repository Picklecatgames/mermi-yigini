shader_type spatial;

// Heap surface from textures baked off the real bullet mesh (tools/bake_pile_texture.gd):
// albedo, world-space normal (y up) and height, mapped top-down on world xz.
// Parallax marches the height map so bullets stand out of the cone and hide each other.

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_tex : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D height_tex : filter_linear_mipmap, repeat_enable;
// Baked with bullets 3x real size: real 29 mm bullets read as grass on a 17 m heap.
// Only the look is scaled; the pile count stays real.
uniform float tile = 0.9;             // m, TILE in the bake script
uniform float depth = 0.09;           // m, MAX_H in the bake script
uniform vec3 tint : source_color = vec3(1.0);  // set from pile.gd


// Heap shape: height per cell, written by pile.gd as bullets are taken and slopes slide.
uniform sampler2D height_field : filter_nearest;
uniform int grid = 160;
uniform float cell_size = 0.125;
uniform float toe = 0.06;  // m; thinner than this the heap breaks up into single bullets

varying vec3 world_pos;
varying vec3 world_normal;
varying float heap_h;

float field(ivec2 c) {
	return texelFetch(height_field, clamp(c, ivec2(0), ivec2(grid - 1)), 0).r;
}

void vertex() {
	// The plane's vertices sit on cell centres.
	ivec2 c = ivec2(round(VERTEX.xz / cell_size + float(grid - 1) * 0.5));
	float h = field(c);
	heap_h = h;
	VERTEX.y = h > 0.0005 ? h : -0.05;  // empty cells tuck under the floor
	NORMAL = normalize(vec3(field(c - ivec2(1, 0)) - field(c + ivec2(1, 0)), 2.0 * cell_size,
			field(c - ivec2(0, 1)) - field(c + ivec2(0, 1))));
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 to_cam = CAMERA_POSITION_WORLD - world_pos;
	vec3 v = normalize(to_cam);
	vec2 uv = world_pos.xz / tile;
	vec2 dx = dFdx(uv);
	vec2 dy = dFdy(uv);

	// Parallax occlusion: walk down the view ray until it dips under the height map.
	float steps = mix(32.0, 6.0, clamp(length(to_cam) / 12.0, 0.0, 1.0));
	// Depth is measured along the cone normal, so slopes facing the camera don't smear.
	float v_n = max(dot(v, world_normal), 0.3);
	vec2 shift = -(v - world_normal * v_n).xz / v_n * depth / tile;  // uv shift over the full depth
	float ray = 0.0;
	float h = textureGrad(height_tex, uv, dx, dy).r;
	float prev_ray = 0.0;
	float prev_h = h;
	for (float i = 0.0; i < steps && 1.0 - ray > h; i += 1.0) {
		prev_ray = ray;
		prev_h = h;
		ray += 1.0 / steps;
		h = textureGrad(height_tex, uv + shift * ray, dx, dy).r;
	}
	float above = (1.0 - prev_ray) - prev_h;
	float below = h - (1.0 - ray);
	vec2 p = uv + shift * mix(prev_ray, ray, above / max(above + below, 1e-4));

	vec3 alb = textureGrad(albedo_tex, p, dx, dy).rgb;
	vec3 n = textureGrad(normal_tex, p, dx, dy).rgb * 2.0 - 1.0;
	float hh = textureGrad(height_tex, p, dx, dy).r;
	// Thin foot: only the tallest bullets of the texture remain, concrete shows between.
	if (hh < 1.0 - heap_h / toe) {
		discard;
	}
	float mask = smoothstep(0.0, 0.06, hh);  // 0 in the gaps between bullets
	// Bullets sunk below their neighbours get less light.
	float cavity = clamp(1.0 - (textureLod(height_tex, p, 6.0).r - hh) * 2.5, 0.15, 1.0);

	ALBEDO = alb * tint;
	METALLIC = mask;
	ROUGHNESS = mix(1.0, 0.3, mask);
	AO = cavity * mix(0.4, 1.0, hh);
	AO_LIGHT_AFFECT = 0.5;
	vec3 wn = normalize(world_normal * n.y + vec3(n.x, 0.0, n.z));
	NORMAL = normalize((VIEW_MATRIX * vec4(wn, 0.0)).xyz);
}
