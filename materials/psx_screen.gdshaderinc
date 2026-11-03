// The PS1 screen's colour (scripts/psx_screen.gd): 5 bits a channel, 15-bit colour, with a 4x4
// ordered (Bayer) dither laid on the small screen's own pixels, so the dots are as big as they are.
// `px` is the pixel of the small screen (the 3D is drawn that small and blown up unfiltered).

uniform vec2 psx_size = vec2(400.0, 225.0);  // the small screen, pixels
uniform float psx_dither = 1.0;  // 0..1, how strong the ordered dither is

const float PSX_BAYER[16] = float[](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);

vec3 psx_colour(vec3 c, vec2 px) {
	ivec2 p = ivec2(mod(px, 4.0));
	float d = ((PSX_BAYER[p.y * 4 + p.x] + 0.5) / 16.0 - 0.5) * psx_dither;
	return clamp(floor(c * 31.0 + 0.5 + d) / 31.0, 0.0, 1.0);
}
