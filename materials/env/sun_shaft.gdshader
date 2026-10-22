shader_type spatial;
render_mode blend_add, unshaded, cull_front, depth_draw_never, depth_test_disabled, shadows_disabled, fog_disabled;

// A shaft of sun through a roof hole, drawn without volumetric fog (that ignores the roof's shadow
// and lights the whole hall). The mesh is a unit box whose transform shears it along the
// sunlight: every horizontal slice is the hole. Each pixel marches its view ray through the box,
// stopped at the scene's depth, so the beam has real thickness and things in it cut it. Soft
// ragged edges, drifting dust streaks, bright under the roof and thinning toward the floor.

uniform vec3 color : source_color = vec3(0.85, 0.92, 1.0);
uniform float strength = 0.08;     // per metre of beam the ray crosses
uniform float floor_fade = 0.45;   // brightness left at the bottom
uniform sampler2D noise_tex : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform sampler2D depth_texture : hint_depth_texture, filter_linear_mipmap;

float density(vec3 p) {
	vec2 e = abs(p.xz) * 2.0;  // 0 centre, 1 the hole's edge
	float rag = texture(noise_tex, p.xz * 0.9 + 0.3).r;
	float edge = 1.0 - smoothstep(0.45 + 0.25 * rag, 1.0, max(e.x, e.y));
	float h = p.y + 0.5;  // 0 floor, 1 roof
	float streak = 0.65 + 0.7 * texture(noise_tex, vec2(p.x * 1.7 + p.z * 0.6, h * 0.25 - TIME * 0.006)).r;
	return edge * mix(floor_fade, 1.0, h) * streak;
}

void fragment() {
	mat4 inv_m = inverse(MODEL_MATRIX);
	vec3 cam = (inv_m * vec4(INV_VIEW_MATRIX[3].xyz, 1.0)).xyz;
	vec3 frag = (inv_m * INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 rd = normalize(frag - cam);
	vec3 t0 = (vec3(-0.5) - cam) / rd;
	vec3 t1 = (vec3(0.5) - cam) / rd;
	vec3 lo = min(t0, t1);
	vec3 hi = max(t0, t1);
	float t_in = max(max(max(lo.x, lo.y), lo.z), 0.0);
	float t_out = min(min(hi.x, hi.y), hi.z);
	// Stop at whatever the scene has in front.
	float z = texture(depth_texture, SCREEN_UV).r;
	vec4 sv = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, z, 1.0);
	vec3 scene = (inv_m * INV_VIEW_MATRIX * vec4(sv.xyz / sv.w, 1.0)).xyz;
	t_out = min(t_out, dot(scene - cam, rd));
	if (t_out <= t_in) {
		discard;
	}
	float metres = length((MODEL_MATRIX * vec4(rd, 0.0)).xyz);  // local units to m along the ray
	const int STEPS = 10;
	float dt = (t_out - t_in) / float(STEPS);
	float sum = 0.0;
	for (int i = 0; i < STEPS; i++) {
		sum += density(cam + rd * (t_in + (float(i) + 0.5) * dt));
	}
	ALBEDO = color;
	ALPHA = clamp(sum * dt * metres * strength, 0.0, 1.0);
}
