extends SceneTree
## Where the frame goes: a census of main.tscn (lights, shadows, decals, meshes, nodes) and the GPU
## time from a few fixed cameras, then the same view with each costly render feature off in turn.
##   Godot.exe --path . --position -10000,-10000 --resolution 1920x1080 -s res://tools/perf_probe.gd
## A window is needed (headless renders nothing); it opens off screen. To price a feature, run again
## with it off from the start (toggling mid-run left the GPU timer stuck):
##   ... -s res://tools/perf_probe.gd -- off=ssr,ssil,ssao,fog,glow,shadows,lamp_shadows,decals
## (lamp_shadows: only the hall lamps', the ones that fade with distance, as Settings' low does not)

const VIEWS := {
	"spawn": [Vector3(8.7, 1.7, 0.0), Vector3(-9.0, 2.5, 0.0)],
	"wood": [Vector3(11.0, 1.7, 1.0), Vector3(60.0, 9.0, 0.0)],
	"heap": [Vector3(4.0, 1.7, 12.0), Vector3(-9.0, 3.5, 0.0)],
	"range": [Vector3(9.0, 1.6, 7.0), Vector3(26.0, 1.2, -1.0)],
	"camp": [Vector3(-14.0, 1.7, -16.0), Vector3(-22.0, 1.0, -25.0)],
	"stands": [Vector3(-18.5, 1.8, -1.0), Vector3(-23.0, 1.0, 9.0)],
}


func _initialize() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var main: Node = load("res://scenes/main.tscn").instantiate()
	main.get_node("Player").free()
	root.add_child(main)
	var cam := Camera3D.new()
	main.add_child(cam)
	cam.make_current()
	_census(main)
	_switch_off(main)
	var vp := root.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(vp, true)
	for f in 300:  # shaders compile, the probes capture: the first seconds are not the game
		await process_frame
	for v: String in VIEWS:
		cam.look_at_from_position(VIEWS[v][0], VIEWS[v][1])
		print("%-8s %s" % [v, await _measure(vp)])
	quit()


func _switch_off(main: Node) -> void:
	var env: Environment = (main.find_children("*", "WorldEnvironment", true, false)[0] as WorldEnvironment).environment
	for a: String in OS.get_cmdline_user_args():
		if not a.begins_with("off="):
			continue
		for f in a.trim_prefix("off=").split(","):
			match f:
				"ssr", "ssil", "ssao", "glow":
					env.set(f + "_enabled", false)
				"fog":
					env.volumetric_fog_enabled = false
				"shadows":
					for l: Light3D in main.find_children("*", "Light3D", true, false):
						if not l is DirectionalLight3D:
							l.shadow_enabled = false
				"lamp_shadows":
					for l: SpotLight3D in main.find_children("*", "SpotLight3D", true, false):
						if l.distance_fade_enabled:
							l.shadow_enabled = false
				"decals":
					for d: Decal in main.find_children("*", "Decal", true, false):
						d.visible = false
			print("off: ", f)


func _census(main: Node) -> void:
	var count := {}
	var shadowed := {}
	var vol := 0
	var all := main.find_children("*", "", true, false)
	for n in all:
		var k := n.get_class()
		count[k] = count.get(k, 0) + 1
		if n is Light3D:
			if (n as Light3D).shadow_enabled:
				shadowed[k] = shadowed.get(k, 0) + 1
			if (n as Light3D).light_volumetric_fog_energy > 0.0:
				vol += 1
	print("nodes: %d" % all.size())
	for k in ["MeshInstance3D", "MultiMeshInstance3D", "Decal", "OmniLight3D", "SpotLight3D", "DirectionalLight3D",
			"GPUParticles3D", "CPUParticles3D", "ReflectionProbe", "Label3D", "AudioStreamPlayer3D", "StaticBody3D", "CollisionShape3D"]:
		print("  %-20s %5d  shadowed %d" % [k, count.get(k, 0), shadowed.get(k, 0)])
	print("  lights in volumetric fog: %d" % vol)


func _gpu(vp: RID) -> float:
	for f in 20:
		await process_frame
	var t := 0.0
	for f in 60:
		await process_frame
		t += RenderingServer.viewport_get_measured_render_time_gpu(vp)
	return t / 60.0


func _measure(vp: RID) -> String:
	var gpu := await _gpu(vp)
	return "gpu %.2f ms  draws %d  prims %dk  objects %d  vram %d MB  tex %d MB" % [gpu,
		Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME) / 1000,
		Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),
		Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576,
		Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) / 1048576]
