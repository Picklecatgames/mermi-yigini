extends StaticBody3D
## The desk in front of the spawns (tools/build_arena.gd _spawns) with the pistol on it: E while
## looking at it takes the pistol (player.gd, GameState.request_take_pistol), drawn at once with an
## empty magazine. Its job done, the desk fades away; on this machine only, everyone takes their own.
## No GameState in here: the builder runs without autoloads and wouldn't attach this script.

const ARMS := preload("res://assets/weapons/arms/arms.gltf")  # the first-person Deagle's own mesh
const FADE := 1.5  # s
const FADE_DELAY := 0.6  # s: the draw starts first
const GLOW := Color(0.55, 0.4, 0.15)

var _gun := MeshInstance3D.new()
var _fading := false


func _ready() -> void:
	add_to_group("gun_table")
	var arms := ARMS.instantiate()
	_gun.mesh = (arms.find_child("Deagle") as MeshInstance3D).mesh  # skinned: drawn in its bind pose
	arms.free()
	# Lying on its side across the top: the mesh stands upright with its barrel along z.
	var box := find_children("*", "CollisionShape3D", false)[0] as CollisionShape3D  # the builder's box round the desk
	var top := box.position.y + (box.shape as BoxShape3D).size.y * 0.5
	var b := _gun.mesh.get_aabb()
	var lay := Basis(Vector3.UP, 0.5) * Basis(Vector3.BACK, PI / 2.0)
	_gun.transform = Transform3D(lay, Vector3(0.0, top + b.size.x * 0.5, 0.0) - lay * b.get_center())
	add_child(_gun)
	# It breathes a warm glow: the first thing to take.
	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	glow.albedo_color = Color.BLACK
	_gun.material_overlay = glow
	var tw := create_tween().set_loops().set_trans(Tween.TRANS_SINE)
	tw.tween_property(glow, "albedo_color", GLOW, 0.7)
	tw.tween_property(glow, "albedo_color", Color.BLACK, 0.7)


## The pistol is ours (player.gd calls it): the gun goes, the desk fades out and is gone.
func fade() -> void:
	if _fading:
		return
	_fading = true
	_gun.visible = false
	collision_layer = 0
	var tw := create_tween().set_parallel()
	for g: GeometryInstance3D in find_children("*", "GeometryInstance3D", true, false):
		tw.tween_property(g, "transparency", 1.0, FADE).set_delay(FADE_DELAY)
	tw.chain().tween_callback(queue_free)
