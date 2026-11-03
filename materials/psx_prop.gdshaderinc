// PS1 horror props (2026-11-02, the user: the whole game in the PSX horror look): materials/psx.gdshader
// for the world's things, with what props need on top of it. tools/psx_props.gd hands it out;
// psx_prop.gdshader culls back faces, psx_prop_2s.gdshader draws both (sheets, cards).
//   vertex_tint: COLOR multiplies the texture: the scrap's MultiMesh copies carry their tone there
//   triplanar: the texture by world position every tri_metres (boxes with no UVs worth having)

uniform sampler2D albedo_tex : source_color, filter_nearest, repeat_enable, hint_default_white;
uniform vec4 tint : source_color = vec4(1.0);
uniform vec3 uv_scale = vec3(1.0);
uniform vec3 uv_offset = vec3(0.0);
uniform float snap = 180.0;  // vertical grid the vertices snap to, in steps per screen height
uniform float alpha_cut = 0.0;  // above 0: a cutout
uniform bool vertex_tint = false;
uniform bool triplanar = false;
uniform float tri_metres = 2.0;

varying vec3 world_pos;
varying vec3 world_nrm;

void vertex() {
	UV = UV * uv_scale.xy + uv_offset.xy;
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_nrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vec4 clip = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	vec2 grid = vec2(snap * VIEWPORT_SIZE.x / VIEWPORT_SIZE.y, snap) * 0.5;
	clip.xy = round(clip.xy / clip.w * grid) / grid * clip.w;
	POSITION = clip;
}

void fragment() {
	vec4 c;
	if (triplanar) {
		vec3 w = abs(world_nrm);
		w /= w.x + w.y + w.z;
		vec3 p = world_pos / tri_metres;
		c = texture(albedo_tex, p.zy) * w.x + texture(albedo_tex, p.xz) * w.y + texture(albedo_tex, p.xy) * w.z;
	} else {
		c = texture(albedo_tex, UV);
	}
	c *= tint;
	if (vertex_tint) {
		c.rgb *= COLOR.rgb;
	}
	if (alpha_cut > 0.0 && c.a < alpha_cut) {
		discard;
	}
	ALBEDO = c.rgb;
	ROUGHNESS = 1.0;
}
