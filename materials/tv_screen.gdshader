// The old television's tube (scripts/tv.gd): its picture drawn coarse, under scan lines, grain, a slow
// roll bar and a line tear now and then. `noise` 0..1: how far the signal is gone; at 1 only grain.
// Its big texels are the PS1 look's: filtered nothing, the same 15-bit steps (materials/psx*).
shader_type spatial;
render_mode unshaded, cull_back, shadows_disabled, fog_disabled;

uniform sampler2D card : source_color, filter_nearest;
uniform float noise = 0.2;

const vec2 CELLS = vec2(160.0, 120.0);

float rand(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 uv = UV;
	float t = TIME;
	// The tube's bulge at the corners.
	vec2 c = uv - 0.5;
	uv = 0.5 + c * (1.0 + dot(c, c) * 0.16);
	float row = floor(uv.y * CELLS.y);
	// Lines slip sideways, a little always, a lot in the odd tear.
	float frame = floor(t * 18.0);
	float tear = step(0.985 - noise * 0.12, rand(vec2(frame, floor(row / 7.0))));
	uv.x += (rand(vec2(row, frame)) - 0.5) * (0.006 + noise * 0.02) + tear * (rand(vec2(frame, 3.0)) - 0.5) * 0.14;
	vec2 cell = floor(uv * CELLS);
	vec3 pic = texture(card, (cell + 0.5) / CELLS).rgb;
	float grain = rand(cell + frame * vec2(1.7, 2.3));
	vec3 col = mix(pic, vec3(grain * 0.75), clamp(noise, 0.0, 1.0));
	// A slow bar rolling up the picture.
	float bar = smoothstep(0.0, 0.12, abs(fract(uv.y + t * 0.07) - 0.5));
	col *= 0.86 + bar * 0.14;
	// Scan lines and the dark corners of the glass.
	col *= 0.78 + 0.22 * mod(row, 2.0);
	col *= smoothstep(0.78, 0.32, length(c * vec2(1.05, 1.15)));
	// 15-bit, as the rest of the screen.
	col = floor(col * 31.0 + 0.5) / 31.0;
	ALBEDO = col * 1.25;
}
