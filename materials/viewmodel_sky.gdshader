shader_type sky;
// What the first-person guns reflect (scripts/player.gd, never drawn as a background): the hall
// they stand in, rows of bright LED battens on a dark roof, dim walls, warm lit concrete. Steel
// catches the battens as sharp streaks that slide over it as the player turns.

uniform vec3 roof_color : source_color = vec3(0.035, 0.034, 0.032);
uniform vec3 wall_color : source_color = vec3(0.16, 0.15, 0.14);
uniform vec3 floor_color : source_color = vec3(0.3, 0.27, 0.23);
uniform vec3 lamp_color : source_color = vec3(1.0, 0.95, 0.87);
uniform float lamp_energy = 7.0;
uniform float lamp_spacing = 1.5;  // between batten rows, in roof heights
uniform float lamp_width = 0.06;   // share of the spacing a batten covers
uniform float lamp_length = 0.7;   // share of the spacing a batten runs along before a gap

void sky() {
	vec3 d = EYEDIR;
	float up = d.y;
	vec3 col = mix(wall_color, floor_color, smoothstep(0.0, -0.35, up));
	if (up > 0.0) {
		col = mix(wall_color, roof_color, smoothstep(0.0, 0.25, up));
		vec2 p = d.xz / max(up, 0.02);  // where the ray meets a roof one unit up
		vec2 cell = fract(p / lamp_spacing) - 0.5;
		float across = 1.0 - smoothstep(lamp_width * 0.5, lamp_width * 0.5 + 0.01, abs(cell.x));
		float along = 1.0 - smoothstep(lamp_length * 0.5, lamp_length * 0.5 + 0.02, abs(cell.y));
		float far = smoothstep(0.03, 0.2, up);  // far rows crowd into the horizon: fade them
		col += lamp_color * lamp_energy * across * along * far;
	}
	COLOR = col;
}
