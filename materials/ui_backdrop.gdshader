shader_type canvas_item;
// Behind a menu (UiStyle.backdrop): the game blurred and darkened, darker still towards the
// edges, so the menu stands in the world rather than on a window of its own.

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform float blur = 3.5;  // mip level
uniform float dark = 0.42;  // brightness left in the middle
uniform float vignette = 0.75;  // how much darker the corners go

void fragment() {
	vec2 px = SCREEN_PIXEL_SIZE * exp2(blur);
	vec3 c = textureLod(screen_texture, SCREEN_UV, blur).rgb * 0.4;
	c += textureLod(screen_texture, SCREEN_UV + vec2(px.x, px.y), blur).rgb * 0.15;
	c += textureLod(screen_texture, SCREEN_UV + vec2(-px.x, px.y), blur).rgb * 0.15;
	c += textureLod(screen_texture, SCREEN_UV + vec2(px.x, -px.y), blur).rgb * 0.15;
	c += textureLod(screen_texture, SCREEN_UV + vec2(-px.x, -px.y), blur).rgb * 0.15;
	float edge = smoothstep(0.25, 0.95, length((SCREEN_UV - 0.5) * vec2(1.4, 1.0)));
	COLOR = vec4(c * dark * (1.0 - vignette * edge), 1.0);
}
