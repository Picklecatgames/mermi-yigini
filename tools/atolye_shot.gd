extends SceneTree
## Açık alan ve atölye asetlerini yan yana dizip fotoğraflar, her birinin ölçüsünü ve çarpışmasını yazar:
##   Godot.exe --path . --position -10000,-10000 --resolution 1600x900 -s res://tools/atolye_shot.gd
## user://atolye_<klasör>.png her aset klasörü için, user://atolye_dokular.png zemin dokuları,
## user://atolye_gok_<hdri>.png gökyüzleri. "-- ad1 ad2" verilirse yalnız o asetleri yakından çeker (user://atolye_secim.png).

const DIRS := [
	"res://assets/env/acik_alan/kayalar", "res://assets/env/acik_alan/bitkiler", "res://assets/env/acik_alan/ufuk",
	"res://assets/env/acik_alan/yiginlar", "res://assets/env/acik_alan/kum_tepeleri",
	"res://assets/props/atolye/yapi", "res://assets/props/atolye/ic",
]
const TEX := "res://assets/env/acik_alan/dokular"
const SKIES := [
	"kloofendal_48d_partly_cloudy_puresky_4k", "mud_road_puresky_2k", "wasteland_clouds_puresky_4k",
	"kloppenheim_02_puresky_4k", "qwantani_moonrise_puresky_2k", "quarry_01_puresky_4k",
	"mpumalanga_veld_puresky_4k", "lonely_road_afternoon_puresky_4k", "qwantani_dusk_2_puresky_2k",
]

var _env: WorldEnvironment
var _cam: Camera3D
var _sun: DirectionalLight3D


func _initialize() -> void:
	var world := Node3D.new()
	root.add_child(world)
	_env = WorldEnvironment.new()
	_env.environment = Environment.new()
	_env.environment.background_mode = Environment.BG_SKY
	_env.environment.tonemap_mode = Environment.TONE_MAPPER_AGX
	world.add_child(_env)
	_sun = DirectionalLight3D.new()
	_sun.rotation_degrees = Vector3(-50, -35, 0)
	_sun.shadow_enabled = true
	world.add_child(_sun)
	_cam = Camera3D.new()
	_cam.fov = 40
	world.add_child(_cam)
	_set_sky(SKIES[0], 1.0)
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(400, 400)
	ground.mesh = pm
	ground.material_override = load(TEX + "/ground097/ground097.tres")
	world.add_child(ground)
	await process_frame

	var only := OS.get_cmdline_user_args()
	for d: String in (["secim"] if only else DIRS):
		var row := Node3D.new()
		world.add_child(row)
		var x := 0.0
		var hmax := 0.0
		var files: Array[String] = []
		if only:
			for dd: String in DIRS:
				for f in _gltfs(dd):
					if f.get_basename() in only:
						files.append(dd + "/" + f)
		else:
			for f in _gltfs(d):
				files.append(d + "/" + f)
		for path: String in files:
			var f := path.get_file()
			var inst: Node3D = load(path).instantiate()
			row.add_child(inst)
			var box := _aabb(inst)
			inst.position.x = x - box.position.x
			x += box.size.x + maxf(0.3, box.size.x * 0.25)
			hmax = maxf(hmax, box.size.y)
			var lab := Label3D.new()
			lab.text = f.get_basename()
			lab.pixel_size = maxf(0.0015, box.size.y * 0.004)
			lab.position = Vector3(box.get_center().x, -0.05, box.end.z + 0.1)
			lab.rotation_degrees.x = -90
			lab.modulate = Color.BLACK
			lab.outline_modulate = Color.WHITE
			inst.add_child(lab)
			print("%s | boyut %.2f x %.2f x %.2f m | taban %.2f | çarpışma %d" % [
				f, box.size.x, box.size.y, box.size.z, box.position.y, _shapes(inst)])
		await process_frame
		_frame(Vector3(x * 0.5, hmax * 0.45, 0), x, hmax)
		await _settle(12)
		_save("atolye_" + d.get_file())
		row.queue_free()
	if only:
		quit()
		return

	# zemin dokuları: 4 m'lik kareler
	var tiles := Node3D.new()
	world.add_child(tiles)
	var i := 0
	for t: String in DirAccess.get_directories_at(TEX):
		var m := MeshInstance3D.new()
		var p := PlaneMesh.new()
		p.size = Vector2(4, 4)
		m.mesh = p
		m.material_override = load("%s/%s/%s.tres" % [TEX, t, t])
		m.position = Vector3((i % 5) * 4.2, 0.01, (i / 5) * 4.2)
		var lab := Label3D.new()
		lab.text = t
		lab.pixel_size = 0.006
		lab.position = Vector3(0, 0.02, 2.25)
		lab.rotation_degrees.x = -90
		lab.modulate = Color.BLACK
		lab.outline_modulate = Color.WHITE
		m.add_child(lab)
		tiles.add_child(m)
		i += 1
	_cam.position = Vector3(8.4, 15.0, 13.0)
	_cam.look_at(Vector3(8.4, 0, 2.6))
	await _settle(12)
	_save("atolye_dokular")
	tiles.queue_free()

	for s: String in SKIES:
		_set_sky(s, 0.25 if s.contains("kloppenheim") or s.contains("moon") else 1.0)
		_cam.position = Vector3(0, 1.7, 0)
		_cam.rotation_degrees = Vector3(12, 0, 0)
		await _settle(12)
		_save("atolye_gok_" + s)
	quit()


func _gltfs(d: String) -> Array[String]:
	var out: Array[String] = []
	for f in DirAccess.get_files_at(d):
		if f.ends_with(".gltf") or f.ends_with(".glb"):
			out.append(f)
	return out


func _aabb(n: Node) -> AABB:
	var box := AABB()
	var first := true
	for m in n.find_children("*", "MeshInstance3D", true, false):
		var b: AABB = (m as MeshInstance3D).global_transform * (m as MeshInstance3D).get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box


func _shapes(n: Node) -> int:
	return n.find_children("*", "CollisionShape3D", true, false).size()


func _frame(center: Vector3, width: float, height: float) -> void:
	var t := tan(deg_to_rad(_cam.fov * 0.5))
	var dist := maxf(width * 0.55 / (t * 16.0 / 9.0), height * 0.7 / t) + 0.5
	_cam.position = center + Vector3(0, dist * 0.3, dist)
	_cam.look_at(center)


func _set_sky(name: String, energy: float) -> void:
	var mat := PanoramaSkyMaterial.new()
	mat.panorama = load("res://assets/env/hdri/%s.hdr" % name)
	mat.energy_multiplier = energy
	var sky := Sky.new()
	sky.sky_material = mat
	_env.environment.sky = sky
	_sun.light_energy = energy


func _settle(frames: int) -> void:
	for f in frames:
		await process_frame


func _save(name: String) -> void:
	root.get_viewport().get_texture().get_image().save_png("user://%s.png" % name)
	print("@@ ", name)
