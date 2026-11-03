shader_type spatial;
// One puff of filmed blood mist (tools/build_blood.py: an 8x8 flipbook of a real shot, blood blown
// left to right). The quad turns to the camera but keeps the film's left-to-right along `dir`, the way
// the round went, and sits on the hit at `emit`, the point in the square the puff came out of.
// blood_fx.gd steps `frame`; two frames are blended so the footage plays smooth. Lit like any
// surface it went near-black in the hall's dark between lamps, so it also glows a little of its own red.
render_mode blend_mix, depth_draw_never, cull_disabled, skip_vertex_transform, specular_disabled, diffuse_lambert_wrap;

uniform sampler2D atlas : source_color, filter_nearest, repeat_disable;  // PS1 horror: unfiltered, 64 px a frame (the import)
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;
instance uniform float frame = 0.0;
instance uniform float size = 0.5;  // m, the square's side
instance uniform vec3 dir = vec3(1.0, 0.0, 0.0);
instance uniform vec2 emit = vec2(0.2, 0.3);
instance uniform float flip = 1.0;  // mirrors the film across its flight, for variety
instance uniform float fade = 1.0;

const float GRID = 8.0;
const float SOFT = 0.06;  // m: fades out where it meets a wall or the floor instead of cutting

varying vec2 cell_a;
varying vec2 cell_b;

void vertex() {
	vec3 origin = MODEL_MATRIX[3].xyz;
	vec3 view = normalize(origin - INV_VIEW_MATRIX[3].xyz);
	vec3 right = dir - view * dot(dir, view);
	if (length(right) < 0.08) {  // coming straight at the camera: any way across will do
		right = INV_VIEW_MATRIX[0].xyz;
	}
	right = normalize(right);
	vec3 up = normalize(cross(view, right)) * flip;
	vec2 q = vec2(UV.x - emit.x, emit.y - UV.y);
	vec3 world = origin + (right * q.x + up * q.y) * size;
	VERTEX = (VIEW_MATRIX * vec4(world, 1.0)).xyz;
	NORMAL = normalize((VIEW_MATRIX * vec4(-view, 0.0)).xyz);
	float f = floor(frame);
	cell_a = vec2(mod(f, GRID), floor(f / GRID));
	float g = min(f + 1.0, GRID * GRID - 1.0);
	cell_b = vec2(mod(g, GRID), floor(g / GRID));
}

void fragment() {
	vec4 a = texture(atlas, (UV + cell_a) / GRID);
	vec4 b = texture(atlas, (UV + cell_b) / GRID);
	vec4 c = mix(a, b, fract(frame));
	float depth = texture(depth_tex, SCREEN_UV).r;
	vec4 behind = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, depth, 1.0);
	float gap = VERTEX.z - behind.z / behind.w;
	ALBEDO = c.rgb;
	EMISSION = c.rgb * 0.35;
	ALPHA = c.a * fade * clamp(gap / SOFT, 0.0, 1.0);
	ROUGHNESS = 1.0;
	BACKLIGHT = c.rgb * 0.8;  // thin blood glows red with a light behind it
}
