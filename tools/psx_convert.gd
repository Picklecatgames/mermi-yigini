extends RefCounted
## The PS1 horror conversion shared by tools/psx_import.gd (the guns and arms, at import) and
## tools/psx_res.gd (meshes saved as .res): fewer triangles, the colour map small and unfiltered on
## materials/psx.gdshader.

const PSX := preload("res://materials/psx.gdshader")
const TEX := 256


## The PS1 material for what was `std`: its colour map at TEX px, its colour as the tint.
static func material(std: BaseMaterial3D) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = PSX
	if std == null:
		return mat
	if std.albedo_texture:
		var img: Image = std.albedo_texture.get_image().duplicate()
		img.decompress()
		img.clear_mipmaps()
		if maxi(img.get_width(), img.get_height()) > TEX:
			img.resize(TEX, TEX, Image.INTERPOLATE_LANCZOS)
		mat.set_shader_parameter("albedo_tex", ImageTexture.create_from_image(img))
	mat.set_shader_parameter("tint", std.albedo_color)
	if std.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
		mat.set_shader_parameter("alpha_cut", 0.5)
	mat.resource_name = std.resource_name
	return mat


## The LOD nearest `tris` triangles, its indices into the surface's own vertices.
static func fewer(arrays: Array, format: int, tris: int) -> PackedInt32Array:
	var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	if idx.size() / 3 <= tris:
		return idx
	var im := ImporterMesh.new()
	im.add_surface(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, null, "", format)
	im.generate_lods(25.0, 60.0, [])
	var best := idx
	for l in im.get_surface_lod_count(0):
		var lod := im.get_surface_lod_indices(0, l)
		if absi(lod.size() / 3 - tris) < absi(best.size() / 3 - tris):
			best = lod
	return best
