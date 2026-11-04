// The evening and night sky over the day's photo (scripts/day_night.gd): a dome round the eye, only
// for the eye. Tonight's sky from zenith down to a paler horizon and a glow round the moon, so the
// crowns stand black against it; at dusk and dawn a low warm band on the sun's side. The sky can't be
// tinted through the fog: at night the fog is the wood's darkness, darker than this.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, fog_disabled, shadows_disabled;

uniform vec3 zenith : source_color = vec3(0.0);
uniform vec3 horizon : source_color = vec3(0.0);
uniform vec3 glow : source_color = vec3(0.0);
uniform vec3 moon_dir = vec3(0.0, 1.0, 0.0);
uniform float amount = 0.0;  // how much of the night over the photo: its clouds stay under what's left
uniform vec3 band : source_color = vec3(0.0);
uniform vec3 sun_dir = vec3(1.0, 0.0, 0.0);
uniform float band_amount = 0.0;

varying vec3 world_dir;

void vertex() {
	world_dir = (MODEL_MATRIX * vec4(VERTEX, 0.0)).xyz;
}

void fragment() {
	vec3 d = normalize(world_dir);
	float up = clamp(d.y, 0.0, 1.0);
	vec3 c = mix(horizon, zenith, pow(up, 0.55));
	// Torn cloud: the moon's glow in perfect rings stepped into circles in 15-bit colour.
	vec2 q = d.xz / (up + 0.25) * 1.7;
	float cloud = 0.5 + 0.2 * (sin(q.x * 1.3 + 2.1 * sin(q.y * 0.9)) + sin(q.y * 2.1 + 1.7 * sin(q.x * 1.1)) + 0.5 * sin((q.x + q.y) * 3.7 + 2.0 * sin(q.x * 2.3 - q.y)));
	c *= mix(0.72, 1.12, cloud);
	float m = clamp(dot(d, moon_dir) + (cloud - 0.5) * 0.09, 0.0, 1.0);  // the cloud bends its contours out of round
	c += glow * pow(m, 14.0) * 0.55;
	// Slow big bands only: thin ones step into stripes in 15-bit colour.
	float low = pow(1.0 - up, 5.0);
	float side = 0.25 + 0.75 * smoothstep(-0.2, 0.9, dot(normalize(d.xz + vec2(1e-4)), normalize(sun_dir.xz + vec2(1e-4))));
	float b = low * side * band_amount;
	ALBEDO = mix(c, band, b / max(b + amount * (1.0 - b), 1e-4));
	ALPHA = max(b, amount);
}
