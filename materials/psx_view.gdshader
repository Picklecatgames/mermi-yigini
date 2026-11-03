// The same 15-bit colour for a view drawn over the world by its own camera, the gun in the hand
// (player.tscn ViewmodelView): set on its SubViewportContainer by scripts/psx_screen.gd. Its clear
// background stays clear.
shader_type canvas_item;
render_mode unshaded;

#include "res://materials/psx_screen.gdshaderinc"

void fragment() {
	vec2 px = floor(UV * psx_size);
	vec4 c = texture(TEXTURE, (px + 0.5) / psx_size);
	COLOR = vec4(psx_colour(c.rgb, px), c.a);
}
