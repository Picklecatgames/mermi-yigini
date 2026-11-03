// The PS1 screen's colour (scripts/psx_screen.gd): 5 bits a channel, 15-bit colour, with a 4x4
// ordered (Bayer) dither laid on the small screen's own pixels, so the dots are as big as they are.
// `px` is the pixel of the small screen (the 3D is drawn that small and blown up unfiltered).
// With psx_taps 2 the 3D is drawn twice as fine and each small pixel is the mean of its 2x2:
// thin bars, ridges and far leaves stop flickering in and out as the camera moves, the pixels
// stay as big (2026-11-03, the user: walls too zigzag, far things boil, "göz kanatıyor").

uniform vec2 psx_size = vec2(480.0, 270.0);  // the small screen, pixels
uniform float psx_dither = 0.5;  // 0..1, how strong the ordered dither is; half (2026-11-03): at full it was grain on bright, flat sky and sand
uniform float psx_taps = 1.0;  // 1 or 2: samples per small pixel each way

const float PSX_BAYER[16] = float[](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);

vec3 psx_colour(vec3 c, vec2 px) {
	ivec2 p = ivec2(mod(px, 4.0));
	float d = ((PSX_BAYER[p.y * 4 + p.x] + 0.5) / 16.0 - 0.5) * psx_dither;
	return clamp(floor(c * 31.0 + 0.5 + d) / 31.0, 0.0, 1.0);
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
