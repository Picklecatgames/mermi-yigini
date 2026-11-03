// PS1 props far away, out of the fog (materials/psx_prop.gdshaderinc with PSX_HAZE): the scrap
// mountain's pieces (scripts/scrap_hills.gd). The scene's depth fog is solid by 75 m and turned the
// mountain into a flat beige cone by day and nothing at night (2026-11-03, the PS1 critic); these
// go into a haze of the fog's own colour only up to haze_max, so the mountain always reads as a
// dark, broken rust silhouette in the dust.
shader_type spatial;
render_mode vertex_lighting, specular_disabled, diffuse_lambert, fog_disabled;
#define PSX_HAZE
#include "res://materials/psx_prop.gdshaderinc"
