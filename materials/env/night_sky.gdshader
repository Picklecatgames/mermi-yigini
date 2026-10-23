shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, fog_disabled;

// The sky at about 21:30 (build_arena.gd _sun), on a big dome round the hall, seen only through the
// glass lantern. Everything is worked out from the view direction, so it has no size or distance:
// stars stay 1-2 pixels wherever you stand. A dark country sky: dense stars, the Milky Way with its
// dust lanes across it, a few dark clouds drifting, and a warm brown glow low down.

uniform vec3 zenith : source_color = vec3(0.006, 0.0075, 0.012);  // just off black, so the glazing bars stand against it
uniform vec3 horizon : source_color = vec3(0.03, 0.021, 0.014);  // distant town lights, warm and low
uniform float star_energy = 3.0;  // the brightest few go over the glow threshold and bloom a touch
uniform float milky_way_energy = 4.0;
uniform float cloud_cover = 0.32;  // 0 clear, 1 overcast
uniform vec3 milky_way = vec3(0.95, 0.1, 0.3);  // the band's pole: it runs overhead along the lantern's ridge

varying vec3 world_pos;

float hash13(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.zyx + 31.32);
	return fract((p.x + p.y) * p.z);
}

vec3 hash33(vec3 p) {
	p = fract(p * vec3(0.1031, 0.103, 0.0973));
	p += dot(p, p.yxz + 33.33);
	return fract((p.xxy + p.yxx) * p.zyx);
}

float noise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash13(i), hash13(i + vec3(1, 0, 0)), f.x), mix(hash13(i + vec3(0, 1, 0)), hash13(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(hash13(i + vec3(0, 0, 1)), hash13(i + vec3(1, 0, 1)), f.x), mix(hash13(i + vec3(0, 1, 1)), hash13(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

float fbm(vec3 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 5; i++) {
		v += a * noise(p);
		p = p * 2.03 + 17.1;
		a *= 0.5;
	}
	return v;
}

// One layer of stars: a hashed star in some of the cells of a grid round the sky, `scale` cells per
// radian. Drawn as a gaussian one pixel (`pix`, in radians) wide, so it never grows with distance.
vec3 stars(vec3 d, float pix, float scale, float density) {
	vec3 c = floor(d * scale);
	if (hash13(c) > density) {
		return vec3(0.0);
	}
	vec3 sd = normalize(c + 0.2 + 0.6 * hash33(c));
	if (floor(sd * scale) != c) {  // its direction falls in a neighbour's cell: skipped, not cut in half
		return vec3(0.0);
	}
	float r = length(d - sd) / pix;
	float m = hash13(c + 7.7);
	// Orders of magnitude apart, since the tone mapper lifts faint ones: thousands at the edge of
	// seeing, hundreds plain, a handful bright.
	float mag = 0.0015 + 0.02 * pow(m, 3.0) + 0.25 * pow(m, 12.0) + 1.6 * pow(m, 40.0);
	float twinkle = 1.0 + 0.06 * sin(TIME * (2.0 + 3.0 * m) + m * 60.0);  // barely: the air is still
	vec3 tint = mix(vec3(0.72, 0.82, 1.0), vec3(1.0, 0.85, 0.66), hash13(c + 3.3));
	return tint * mag * twinkle * exp(-r * r * 1.4);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 d = normalize(world_pos - CAMERA_POSITION_WORLD);
	float pix = max(length(dFdx(d)), length(dFdy(d)));
	float up = max(d.y, 0.0);
	vec3 sky = mix(horizon, zenith, pow(up, 0.35));

	// Milky Way: a broad soft glow, a brighter mottled core, dark dust lanes down its middle, and
	// many more faint stars in it.
	float b = dot(d, normalize(milky_way));
	float wide = exp(-b * b / 0.05);
	float core = exp(-b * b / 0.008);
	float mottle = smoothstep(0.3, 0.8, fbm(d * 7.0));
	float dust = smoothstep(0.42, 0.62, fbm(d * 9.0 + vec3(3.0, 0.0, 1.0) + b * 6.0)) * exp(-b * b / 0.004);
	float band = (wide * (0.35 + 0.65 * mottle) + core * mottle) * (1.0 - 0.85 * dust);
	sky += mix(vec3(0.016, 0.017, 0.022), vec3(0.03, 0.026, 0.022), core) * band * milky_way_energy;

	vec3 s = stars(d, pix, 140.0, 0.35 + 0.5 * band) + stars(d.zxy, pix, 60.0, 0.3) + stars(d.yzx, pix, 23.0, 0.3)
		+ stars(d.yxz, pix, 330.0, 0.15 + 0.6 * band) * 0.4;  // the dense dust of stars too faint to pick out one by one
	s *= smoothstep(0.0, 0.2, up) * (1.0 - 0.7 * dust);  // the haze low down and the dust lanes dim them

	// A few dark clouds drifting slowly on a plane above, catching a little of the town's glow.
	vec2 q = d.xz / max(d.y, 0.08) * 0.3 + vec2(TIME * 0.002, TIME * 0.0008);
	float cl = smoothstep(1.0 - cloud_cover, 1.2 - cloud_cover * 0.6, fbm(vec3(q, 0.0)) + 0.2 * fbm(vec3(q * 3.5, 5.0)) - 0.1);
	vec3 cloud_col = mix(horizon * 0.9, vec3(0.003, 0.0028, 0.0032), pow(up, 0.5));
	sky = mix(sky + s * star_energy, cloud_col, cl * 0.92);

	if (d.y < 0.0) {
		sky = mix(sky, vec3(0.004), smoothstep(0.0, -0.02, d.y));  // below the horizon: dark ground
	}
	ALBEDO = sky;
}
