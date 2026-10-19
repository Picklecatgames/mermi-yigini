shader_type spatial;
// Cigarette-style smoke on particle trail ribbons: a soft gaussian across each ribbon, broken up
// along its length by drifting noise so it thins into wisps instead of reading as a hard line.
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, particle_trails;

uniform sampler2D noise_tex : repeat_enable, filter_linear_mipmap;
uniform vec4 tint : source_color = vec4(0.9, 0.91, 0.94, 1.0);
uniform float opacity = 0.35;
uniform float softness = 2.5;  // higher = narrower core

void fragment() {
	float across = abs(UV.x - 0.5) * 2.0;
	float soft = exp(-across * across * softness);
	float n = texture(noise_tex, vec2(UV.x * 0.5 + UV.y * 0.15, UV.y * 1.5 - TIME * 0.08)).r;
	float breakup = mix(0.35, 1.0, smoothstep(0.3, 0.7, n));
	ALBEDO = tint.rgb * COLOR.rgb;
	float ends = sin(clamp(UV.y, 0.0, 1.0) * PI);  // each ribbon fades in and out along its length, so overlaps don't show seams
	ALPHA = clamp(soft * breakup * ends * COLOR.a * opacity, 0.0, 1.0);
}
