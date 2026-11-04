// PS1 props, both sides, the texture filtered (materials/psx_prop.gdshaderinc): the old wood's trees.
// A tree's cards spread few texels over metres; unfiltered, from under it they were hard blocks
// (2026-11-04, the user: "the leaves are bad"). Lit per pixel: a trunk's vertices are metres apart,
// and the head lamp's narrow beam fell between them, a lit tree stayed black.
shader_type spatial;
render_mode specular_disabled, diffuse_lambert, cull_disabled;
#define PSX_SOFT
#include "res://materials/psx_prop.gdshaderinc"
