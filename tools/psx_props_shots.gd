extends SceneTree
## The workshop, the bench up close and the scrap heap from main.tscn as PNGs, each with the frame's
## GPU time, triangles and draws: to set the PS1 props (tools/psx_props.gd) against what was there.
##   Godot.exe --path . --position -10000,-10000 --resolution 1600x900 -s res://tools/psx_props_shots.gd -- <tag>
## Shots land in user:// as props_<tag>_<view>.png.

const VIEWS := {
	"workshop": [Vector3(14.0, 2.2, 4.5), Vector3(5.0, 1.3, 0.0)],
	"bench": [Vector3(4.9, 1.65, 1.0), Vector3(2.6, 1.0, 1.2)],
	"lamp": [Vector3(6.0, 2.0, -1.0), Vector3(4.3, 2.5, -2.3)],
	"heap": [Vector3(0.5, 3.2, 6.0), Vector3(-12.0, 0.0, -1.0)],
	"heap_close": [Vector3(-3.0, 1.8, 2.0), Vector3(-7.0, 0.2, 0.5)],
}


func _initialize() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var tag: String = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "now"
	var main: Node = load("res://scenes/main.tscn").instantiate()
	main.get_node("Player").free()
	root.add_child(main)
	var cam := Camera3D.new()
	cam.fov = 70.0
	main.add_child(cam)
	cam.make_current()
	var vp := root.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(vp, true)
	for f in 240:  # shaders compile, the heap lays itself out
		await process_frame
	for n in main.get_node("World/Bench").find_children("*", "Node3D", true, false):
		n.visible = true  # the bench corner waits for its quest (scripts/reveal.gd)
	for v: String in VIEWS:
		cam.look_at_from_position(VIEWS[v][0], VIEWS[v][1])
		for f in 20:
			await process_frame
		var gpu := 0.0
		for f in 60:
			await process_frame
			gpu += RenderingServer.viewport_get_measured_render_time_gpu(vp)
		print("%s %-10s gpu %.2f ms  prims %dk  draws %d  vram %d MB" % [tag, v, gpu / 60.0,
				Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME) / 1000,
				Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
				Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576])
		var file := "user://props_%s_%s.png" % [tag, v]
		root.get_viewport().get_texture().get_image().save_png(file)
		print("shot ", ProjectSettings.globalize_path(file))
	quit()
