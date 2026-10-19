shader_type spatial;
// The disturbed air a bullet leaves: a thin, faintly smoky streak along the shot that widens,
// wavers and fades. Drawn on a unit quad whose x axis spans the shot; the quad is turned to face
// the camera around that axis here, so it reads as a line from any side.
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

uniform sampler2D noise_tex : repeat_enable, filter_linear_mipmap;
uniform float life = 0.0;       // 0 just fired → 1 gone
uniform float length_m = 10.0;  // metres from start to end, for noise scale along the streak
uniform float width = 0.018;    // m, half-width when fresh
uniform float opacity = 0.55;

void vertex() {
	vec3 a = (MODEL_MATRIX * vec4(-0.5, 0.0, 0.0, 1.0)).xyz;
	vec3 b = (MODEL_MATRIX * vec4(0.5, 0.0, 0.0, 1.0)).xyz;
	vec3 p = mix(a, b, VERTEX.x + 0.5);
	vec3 axis = normalize(b - a);
	vec3 side = normalize(cross(axis, CAMERA_POSITION_WORLD - p));
	p += side * VERTEX.y * 2.0 * width * (1.0 + life * 5.0);
	p.y += life * life * 0.05;  // warm air drifts up a touch
	POSITION = PROJECTION_MATRIX * VIEW_MATRIX * vec4(p, 1.0);
}

void fragment() {
	float along = UV.x * length_m;
	float wobble = (texture(noise_tex, vec2(along * 0.06, life * 0.25)).r - 0.5) * life;
	float across = (UV.y - 0.5) - wobble;
	float core = exp(-across * across * 18.0);
	float strands = texture(noise_tex, vec2(along * 0.22 - life * 0.4, UV.y * 1.3)).r;
	float a = core * mix(0.45, 1.0, strands) * (1.0 - life) * (1.0 - life) * opacity;
	a *= smoothstep(0.0, 0.04, UV.x) * smoothstep(0.0, 0.04, 1.0 - UV.x);  // soft ends
	ALBEDO = vec3(0.86, 0.87, 0.9);
	ALPHA = clamp(a, 0.0, 1.0);
}
