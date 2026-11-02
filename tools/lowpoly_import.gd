@tool
extends EditorScenePostImport
## Import script of the low poly glbs (assets/lowpoly, tools/lowpoly.py): their colour is in the
## vertices, and Godot's glTF import doesn't turn that on for a mesh that has a material.


func _post_import(scene: Node) -> Object:
	for mi: MeshInstance3D in scene.find_children("*", "MeshInstance3D", true, false):
		for s in mi.mesh.get_surface_count():
			var mat := mi.mesh.surface_get_material(s) as BaseMaterial3D
			if mat and mi.mesh.surface_get_format(s) & Mesh.ARRAY_FORMAT_COLOR:
				mat.vertex_color_use_as_albedo = true
				mat.vertex_color_is_srgb = false  # glTF's COLOR_0 is linear
	return scene
