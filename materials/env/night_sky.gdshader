shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;

// The sky at about 21:30 (build_arena.gd _sun), on a big dome round the hall, seen only through the
// glass lantern: a real night photograph, Poly Haven "Rogland Clear Night" (CC0), looked up by the
// view direction, so the stars keep their size wherever you stand. The photo is exposed bright;
// `black_point` takes its grey airglow back down to a night sky and `energy` sets the rest.
// Fog stays on: the hall's haze and the lamps' glow sit in front of it, as through real air.

uniform sampler2D panorama : source_color, filter_linear, repeat_enable;
uniform float energy = 0.2;
uniform float black_point = 0.13;  // photo brightness taken off before scaling: the empty sky goes near black
uniform float turn = 0.05;  // panorama's turn, in turns: the Milky Way's arc runs along the lantern's ridge (z)
uniform vec3 horizon : source_color = vec3(0.02, 0.014, 0.01);  // below the photo's horizon line: a warm dark glow

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 d = normalize(world_pos - CAMERA_POSITION_WORLD);
	vec2 uv = vec2(atan(d.x, -d.z) / TAU + 0.5 - turn, acos(clamp(d.y, -1.0, 1.0)) / PI);
	vec3 c = textureLod(panorama, uv, 0.0).rgb;
	float l = dot(c, vec3(0.3, 0.5, 0.2));
	c *= max(l - black_point, 0.0) / max(l, 1e-4);  // keeps the colour, drops the grey floor
	c = mix(vec3(dot(c, vec3(0.3, 0.5, 0.2))), c, 0.7) * vec3(0.85, 0.95, 1.15) * energy;  // the photo's green airglow calmed, a touch of night blue
	ALBEDO = mix(horizon, c, smoothstep(0.02, 0.12, d.y));  // the photo's hills never show
}
