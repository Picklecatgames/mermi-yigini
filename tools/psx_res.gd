extends SceneTree
## A mesh saved as a .res (the ejected shell, assets/bullet/shell_45.res) in the PS1 horror look,
## next to it as <name>_psx.res (tools/psx_convert.gd: fewer triangles, small unfiltered colour map).
##   Godot.exe --headless --path . -s res://tools/psx_res.gd -- res://assets/bullet/shell_45.res [tris]

const Convert := preload("res://tools/psx_convert.gd")


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var path: String = args[0]
	var tris := int(args[1]) if args.size() > 1 else 300
	var src: ArrayMesh = load(path)
	var out := ArrayMesh.new()
	var before := 0
	var after := 0
	for s in src.get_surface_count():
		var arrays := src.surface_get_arrays(s)
		var format := src.surface_get_format(s)
		before += (arrays[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
		arrays[Mesh.ARRAY_INDEX] = Convert.fewer(arrays, format, tris)
		arrays[Mesh.ARRAY_TANGENT] = null
		after += (arrays[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		out.surface_set_material(s, Convert.material(src.surface_get_material(s) as BaseMaterial3D))
	var dest := path.get_basename() + "_psx.res"
	var err := ResourceSaver.save(out, dest, ResourceSaver.FLAG_COMPRESS)
	print("%s: %d -> %d tris, saved %s err=%d" % [path, before, after, dest, err])
	quit(0 if err == OK else 1)
