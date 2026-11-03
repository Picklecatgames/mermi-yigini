// The game's 3D as the PS1 drew it (scripts/psx_screen.gd): over the world, under the HUD. The
// world is already drawn small and blown up unfiltered (Viewport.SCALING_3D_MODE_NEAREST); this
// reads one colour per small pixel (the mean of 2x2 when drawn twice as fine) and brings it down to 15 bits with the dither.
shader_type canvas_item;
render_mode unshaded;

#include "res://materials/psx_screen.gdshaderinc"

uniform sampler2D screen : hint_screen_texture, filter_nearest;

void fragment() {
	vec2 px = floor(SCREEN_UV * psx_size);
	COLOR = vec4(psx_colour(psx_mean(screen, px).rgb, px), 1.0);
}
