// PS1 props, both sides, the texture filtered (materials/psx_prop.gdshaderinc): the old wood's trees.
// A tree's cards spread few texels over metres; unfiltered, from under it they were hard blocks
// (2026-11-04, the user: "the leaves are bad").
shader_type spatial;
render_mode vertex_lighting, specular_disabled, diffuse_lambert, cull_disabled;
#define PSX_SOFT
#include "res://materials/psx_prop.gdshaderinc"
