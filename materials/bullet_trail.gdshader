shader_type spatial;
// A round in flight: a short bright tracer racing from the muzzle to the hit (head, metres along),
// and behind it the disturbed air, a thin, faintly smoky streak that widens, wavers and fades.
// The air starts a little way out: the stretch by the muzzle is the one that slid sideways on
// screen when the player walked on, so lines seemed to come out of thin air beside the gun.
// Drawn on a unit quad whose x axis spans the shot; the quad is turned to face the camera around
// that axis here, so it reads as a line from any side.
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

uniform sampler2D noise_tex : repeat_enable, filter_linear_mipmap;
uniform float life = 0.0;       // 0 just fired → 1 gone
uniform float length_m = 10.0;  // metres from start to end, for noise scale along the streak
uniform float width = 0.018;    // m, half-width when fresh
uniform float opacity = 0.35;
uniform float head = 0.0;       // m from the start the round has got to
uniform float tracer_m = 2.5;   // m, length of the bright streak
uniform float clear_m = 1.5;    // m by the muzzle with no air streak

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
	float behind = step(along, head);  // the air is only stirred where the round has been
	float a = core * mix(0.45, 1.0, strands) * (1.0 - life) * (1.0 - life) * opacity * behind;
	a *= smoothstep(clear_m, clear_m + 2.0, along) * smoothstep(0.0, 0.04, 1.0 - UV.x);
	float t = clamp((along - (head - tracer_m)) / tracer_m, 0.0, 1.0) * behind;  // 0 tail → 1 head
	float tracer = t * t * exp(-across * across * 60.0) * step(head, length_m + tracer_m);
	ALBEDO = mix(vec3(0.86, 0.87, 0.9), vec3(1.0, 0.85, 0.55), clamp(tracer * 2.0, 0.0, 1.0));
	ALPHA = clamp(a + tracer * 0.9, 0.0, 1.0);
}
