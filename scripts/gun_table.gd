extends StaticBody3D
## The desk in front of the spawns (tools/build_arena.gd _spawns) with the pistol on it: E while
## looking at it takes the pistol (player.gd, GameState.request_take_pistol), drawn at once with an
## empty magazine; on this machine only, everyone takes their own. The desk stays: from then on E at
## it mends the railing (GameState.request_repair_fence, 2026-10-30, the user's call).
## No GameState in here: the builder runs without autoloads and wouldn't attach this script.

## The starting pistol, taped (scripts/viewmodel.gd PISTOL): its parts, all in one space.
const PISTOL := preload("res://assets/weapons/service_pistol/service_pistol.glb")
const PARTS := ["frame_tape", "trigger_tape", "slide", "hammer", "magazine"]
const GLOW := Color(0.55, 0.4, 0.15)

var _gun := Node3D.new()
var _fading := false


func _ready() -> void:
	add_to_group("gun_table")
	var parts := PISTOL.instantiate()
	var b := AABB()
	var meshes: Array[MeshInstance3D] = []
	for part: String in PARTS:
		var mi := MeshInstance3D.new()
		mi.mesh = (parts.find_child(part) as MeshInstance3D).mesh
		_gun.add_child(mi)
		meshes.append(mi)
		b = mi.mesh.get_aabb() if meshes.size() == 1 else b.merge(mi.mesh.get_aabb())
	parts.free()
	# Lying on its side across the top: the parts stand upright with the barrel along z.
	var box := find_children("*", "CollisionShape3D", false)[0] as CollisionShape3D  # the builder's box round the desk
	var top := box.position.y + (box.shape as BoxShape3D).size.y * 0.5
	var lay := Basis(Vector3.UP, 0.5) * Basis(Vector3.BACK, PI / 2.0)
	_gun.transform = Transform3D(lay, Vector3(0.0, top + b.size.x * 0.5, 0.0) - lay * b.get_center())
	add_child(_gun)
	# It breathes a warm glow: the first thing to take.
	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	glow.albedo_color = Color.BLACK
	for mi in meshes:
		mi.material_overlay = glow
	var tw := create_tween().set_loops().set_trans(Tween.TRANS_SINE)
	tw.tween_property(glow, "albedo_color", GLOW, 0.7)
	tw.tween_property(glow, "albedo_color", Color.BLACK, 0.7)


## The pistol is ours (player.gd calls it): the gun goes, the desk stays for the railing.
func fade() -> void:
	if _fading:
		return
	_fading = true
	_gun.queue_free()
