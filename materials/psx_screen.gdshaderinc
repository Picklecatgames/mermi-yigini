// The PS1 screen's colour (scripts/psx_screen.gd): graded (psx_graded), 5 bits a channel, 15-bit colour, with a 4x4
// ordered (Bayer) dither laid on the small screen's own pixels, so the dots are as big as they are.
// `px` is the pixel of the small screen (the 3D is drawn that small and blown up unfiltered).
// With psx_taps 2 the 3D is drawn twice as fine and each small pixel is the mean of its 2x2:
// thin bars, ridges and far leaves stop flickering in and out as the camera moves, the pixels
// stay as big (2026-11-03, the user: walls too zigzag, far things boil, "göz kanatıyor").

uniform vec2 psx_size = vec2(480.0, 270.0);  // the small screen, pixels
uniform float psx_dither = 0.0;  // 0..1, how strong the ordered dither is; 2026-11-03: 0.5 was grain, 0.3 still crawled as the view moved, then off (the user: the game read as pixel art; the references show none)
uniform float psx_grade = 1.0;  // 0..1, how much of psx_graded()
uniform float psx_taps = 1.0;  // 1 or 2: samples per small pixel each way
uniform float psx_levels = 31.0;  // steps a channel; 31 is the PS1's 15-bit colour, which bands a soft fog (tools/ps1_demo.gd F)

const float PSX_BAYER[16] = float[](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);

// The palette (2026-11-03, the user: scarier, gloomier, not overdone; 2026-11-05: uncanny, old, damp,
// tools/psx_shots.gd): blood kept red and left out of the rest; deep shadows cold, highlights yellowed;
// black and white pulled in like an old photo. 2026-11-05, the user: "çok cansız gri ve renksiz",
// everything one grey: the colour was cut to 55 % everywhere and the middle pulled to one grey-green,
// so floor, bark, leaves, wood and sky read alike. Now the muted colours are pushed apart (a dull
// green from a dull brown), the loud ones a little held back, and the light warm against cold shade.
vec3 psx_graded(vec3 c, vec2 uv) {
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	float hi = max(max(c.r, c.g), c.b);
	float sat = (hi - min(min(c.r, c.g), c.b)) / max(hi, 1e-4);
	float over = c.r - max(c.g, c.b);
	float red = smoothstep(0.5, 0.85, over / max(c.r, 0.02)) * smoothstep(0.08, 0.28, over);  // blood; not old wood and brick, not their dark
	vec3 g = mix(vec3(l), c, mix(mix(1.3, 0.92, smoothstep(0.1, 0.6, sat)), 1.05, red));
	vec3 gain = mix(vec3(0.84, 0.92, 1.06), vec3(0.98, 1.0, 0.98), smoothstep(0.02, 0.24, l));
	gain = mix(gain, vec3(1.04, 1.0, 0.9), smoothstep(0.42, 0.9, l));
	g *= mix(gain, vec3(1.0), red);
	g = pow(max(g, 0.0), vec3(1.06));
	g = mix(vec3(0.012, 0.014, 0.02), vec3(0.96, 0.94, 0.85), g);
	g *= mix(1.0, 0.6, smoothstep(0.35, 0.85, length((uv - 0.5) * vec2(1.1, 1.0))));
	return mix(c, g, psx_grade);
}

vec3 psx_colour(vec3 c, vec2 px) {
	c = psx_graded(c, (px + 0.5) / psx_size);
	ivec2 p = ivec2(mod(px, 4.0));
	float d = ((PSX_BAYER[p.y * 4 + p.x] + 0.5) / 16.0 - 0.5) * psx_dither;
	// The steps closer together in the dark (2026-11-04, the user: the night and the black between
	// the trees looked blocky, glitched): even steps left a dark soft shade only two or three colours,
	// each a hard patch, and one channel dropping to 0 before the others tinted it.
	float n = psx_levels * 1.25;
	vec3 q = clamp(floor(sqrt(max(c, 0.0)) * n + 0.5 + d) / n, 0.0, 1.0);
	// Near-greys step as one (2026-11-05): channel by channel a grey sky or fog steps at three
	// different places, its bands went green and pink in turn. The hue stays, the steps stay.
	float m = max(max(c.r, c.g), c.b);
	float top = clamp(floor(sqrt(max(m, 0.0)) * n + 0.5 + d) / n, 0.0, 1.0);
	return mix(c * top * top / max(m, 1e-4), q * q, smoothstep(0.08, 0.25, (m - min(min(c.r, c.g), c.b)) / max(m, 1e-4)));
}

// The small pixel `px` of a texture drawn psx_taps times finer: the mean of its samples. Colour
// weighted by alpha, so a clear background doesn't darken the edges of what is on it (the gun).
vec4 psx_mean(sampler2D tex, vec2 px) {
	vec4 sum = vec4(0.0);
	for (float y = 0.0; y < psx_taps; y += 1.0) {
		for (float x = 0.0; x < psx_taps; x += 1.0) {
			vec4 c = texture(tex, (px + (vec2(x, y) + 0.5) / psx_taps) / psx_size);
			sum += vec4(c.rgb * c.a, c.a);
		}
	}
	return vec4(sum.rgb / max(sum.a, 1e-4), sum.a / (psx_taps * psx_taps));
}
