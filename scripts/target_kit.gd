extends RefCounted
## Shared bits for the model-based range targets (assets/props/targets, split out of the
## Shooting Target Set by tools/build_targets.py): collision for moving parts and stands, the
## hit sound player, and the swing of a part about its pivot.


## A hit shape for a moving part, on `body`; keep it on the part with `follow()` every frame.
static func part_shape(body: CollisionObject3D, part: MeshInstance3D) -> CollisionShape3D:
	var c := CollisionShape3D.new()
	c.shape = part.mesh.create_convex_shape()
	body.add_child(c)
	follow(c, part)
	return c


static func follow(c: CollisionShape3D, part: Node3D) -> void:
	c.global_transform = part.global_transform


## The frame a part stands on blocks shots (sparks, and the combo breaks) but pays nothing.
static func stand_body(parent: Node3D, part: MeshInstance3D) -> StaticBody3D:
	var b := StaticBody3D.new()
	b.add_to_group("steel")
	var c := CollisionShape3D.new()
	c.shape = part.mesh.create_trimesh_shape()
	b.add_child(c)
	parent.add_child(b)
	b.global_transform = part.global_transform
	return b


static func sound(parent: Node3D, stream: AudioStream) -> AudioStreamPlayer3D:
	var p := AudioStreamPlayer3D.new()
	p.stream = stream
	p.bus = &"Dunya"
	p.unit_size = 8.0
	p.max_polyphony = 3
	parent.add_child(p)
	return p


static func play(p: AudioStreamPlayer3D, at: Vector3) -> void:
	if p.stream:
		p.global_position = at
		p.play()


## A part turned by `angle` about the model's X axis through its own pivot: hinged plates tip
## back (negative) away from a shooter on +Z.
static func tipped(rest: Transform3D, angle: float) -> Transform3D:
	return Transform3D(Basis(Vector3.RIGHT, angle) * rest.basis, rest.origin)
