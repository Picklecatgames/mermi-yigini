// The day's sky (tools/build_world.gd _sky; 2026-11-05, the user: uncanny, old, damp): the overcast
// photo's clouds kept, its colour dropped for a damp yellow-grey low down and a colder grey-green
// overhead. Only what the eye sees is dimmed, not the light the sky gives (AT_CUBEMAP_PASS).
// 2026-11-05, the user: everything the same grey: the sky was the floor's and the fog's grey-green;
// now sallow low down and a cold blue-grey overhead, so it reads apart from the trees under it.
shader_type sky;

uniform sampler2D panorama : filter_nearest, repeat_enable;
uniform vec3 low_tint = vec3(1.0, 0.96, 0.84);
uniform vec3 high_tint = vec3(0.8, 0.89, 1.05);
uniform float seen = 0.6;

void sky() {
	float l = dot(texture(panorama, SKY_COORDS).rgb, vec3(0.2126, 0.7152, 0.0722));
	COLOR = l * mix(low_tint, high_tint, smoothstep(0.0, 0.5, EYEDIR.y)) * (AT_CUBEMAP_PASS ? 1.0 : seen);
}
