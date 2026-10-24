# Blender (5.x, background): the crates on the chest stands, from Sketchfab and Poly Haven downloads (credits in
# docs/ayrintilar.md), made ready for a game: every part baked and joined into one mesh (no welding:
# the split normals stay), decimated only past a triangle budget, textures kept up to 4K in their own
# format, the long side along X and the front (lock side) toward glTF +Z, centred with its bottom
# on the origin and scaled to 1 m wide. The game sizes each one by its level
# (scripts/chests.gd), so the reward grows down the row. A preview of each, seen from the front, goes
# next to it (<name>_front.png) to check the turn.
# Run: blender -b --factory-startup -P tools/build_chests.py -- <downloads dir> <out_dir>
#   <downloads dir> holds chest<level>.glb as Sketchfab's "glb" download, or chest<level>/ with
#   Poly Haven's glTF (chest<level>.gltf, its .bin and textures/).
import bpy, math, os, sys
from mathutils import Euler, Vector, Matrix

SRC, OUT = sys.argv[sys.argv.index("--") + 1:][:2]
os.makedirs(OUT, exist_ok=True)

TEX = 4096     # largest texture side kept: the crates are the reward, seen up close
BUDGET = 40000  # triangles
# level: extra turn about the up axis (degrees) after the long side is laid along X, so the
# front faces +Z; read off the previews.
TURN = {1: 180}
# level: materials of what came with the model but is not the chest.
DROP = {}
# Sat tilted on its base: the chest's own turn is dropped, glTF's Y-up turn kept.
UPRIGHT = set()
# level: which parts to keep (by their centre) when the file holds more than one crate.
KEEP = {2: lambda c: c.x < 0.0}  # two crates, the one on the left has its lid on
# Modelled with the lid thrown open (its thumbnail too): the lid is swung shut about its hinge.
CLOSE = set()


def close_lid(o):
    # The lid is the mesh's highest island. Islands are found on a welded copy (the mesh itself
    # stays unwelded, its normals as made) and mapped back by position; the lid is split off, turned
    # about the hinge (its back bottom edge) till its flat underside faces down, set on the box's
    # rim and joined again.
    import bmesh
    from mathutils.kdtree import KDTree
    bm = bmesh.new()
    bm.from_mesh(o.data)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=max(o.dimensions) * 1e-4)
    bm.verts.index_update()
    bm.faces.index_update()
    island, n = {}, 0
    for f in bm.faces:
        if f.index in island:
            continue
        stack = [f]
        island[f.index] = n
        while stack:
            for e in stack.pop().edges:
                for g in e.link_faces:
                    if g.index not in island:
                        island[g.index] = n
                        stack.append(g)
        n += 1
    kd = KDTree(len(bm.verts))
    vert_island = {}
    for v in bm.verts:
        kd.insert(v.co, v.index)
        if v.link_faces:
            vert_island[v.index] = island[v.link_faces[0].index]
    kd.balance()
    top = {}
    for v in bm.verts:
        if v.index in vert_island:
            i = vert_island[v.index]
            top[i] = max(top.get(i, -1e9), v.co.z)
    lid = max(top, key=top.get)
    bm.free()
    me = o.data
    for v in me.vertices:  # the import leaves everything selected
        v.select = False
    for e in me.edges:
        e.select = False
    for p in me.polygons:
        _, idx, _ = kd.find(me.vertices[p.vertices[0]].co)
        p.select = vert_island.get(idx) == lid
        if p.select:
            for i in p.vertices:
                me.vertices[i].select = True
    bpy.ops.object.select_all(action="DESELECT")
    o.select_set(True)
    bpy.context.view_layer.objects.active = o
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_mode(use_extend=False, type="FACE")
    bpy.ops.mesh.separate(type="SELECTED")
    bpy.ops.object.mode_set(mode="OBJECT")
    cap = [p for p in bpy.context.selected_objects if p != o][0]
    lo, hi = bounds(o)
    # The hinge runs along the box's long side; the lid swings across the short one (s).
    axis, s = ("X", 1) if hi.x - lo.x > hi.y - lo.y else ("Y", 0)
    vs = [v.co.copy() for v in cap.data.vertices]
    low = min(v.z for v in vs)
    # Shut, the lid's flat underside faces straight down. Open, it faces down and to the front;
    # the hinge is at the bottom on the other side.
    # The underside is the biggest flat area facing down (the dome's back faces down too).
    flats = {}
    for p in cap.data.polygons:
        if p.normal.z < -0.5:
            k = tuple(round(c * 20) for c in p.normal)
            flats[k] = flats.get(k, 0.0) + p.area
    under = Vector(max(flats, key=flats.get))
    deg = math.degrees(math.atan2(under[s], -under.z))
    bottom = [v for v in vs if v.z < low + 0.05]
    hinge = (min if under[s] > 0 else max)(bottom, key=lambda v: v[s])
    # A right-hand turn about +Y lowers +X, about +X it lifts +Y.
    turn = -deg if axis == "X" else deg
    r = Matrix.Translation(hinge) @ Matrix.Rotation(math.radians(turn), 4, axis) @ Matrix.Translation(-hinge)
    print("  lid shut by %d degrees" % turn)
    cap.data.transform(r)
    # Its underside down on the box's rim (the hinge straps hang lower, at the back).
    cap.data.update()
    flat = [p.center.z for p in cap.data.polygons if p.normal.z < -0.98]
    cap.data.transform(Matrix.Translation((0, 0, hi.z - sum(flat) / len(flat))))
    bpy.ops.object.select_all(action="DESELECT")
    o.select_set(True)
    cap.select_set(True)
    bpy.context.view_layer.objects.active = o
    bpy.ops.object.join()
    return o


def load(path, level):
    # No welding or splitting: the modellers' split normals (hard edges) stay as they made them.
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=path)
    for o in list(bpy.context.scene.objects):
        if o.type != "MESH":
            continue
        c = sum((o.matrix_world @ Vector(v) for v in o.bound_box), Vector()) / 8
        if any(m and m.name in DROP.get(level, ()) for m in o.data.materials) or (level in KEEP and not KEEP[level](c)):
            bpy.data.objects.remove(o)
    meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    for o in meshes:  # bake the Sketchfab node chain into the mesh, drop the empties
        o.data = o.data.copy()
        m = o.matrix_world
        if level in UPRIGHT:  # as the dune lies: glTF's Y-up turn only
            loc, _, scale = m.decompose()
            m = Matrix.LocRotScale(loc, Euler((math.radians(-90), 0.0, 0.0)), scale)
        o.data.transform(m)
        o.parent = None
        o.matrix_world = Matrix.Identity(4)
    for o in list(bpy.context.scene.objects):
        if o.type != "MESH":
            bpy.data.objects.remove(o)
    for a in list(bpy.data.actions):  # lid animations: not used
        bpy.data.actions.remove(a)
    bpy.ops.object.select_all(action="DESELECT")
    for o in meshes:
        o.select_set(True)
    bpy.context.view_layer.objects.active = meshes[0]
    if len(meshes) > 1:
        bpy.ops.object.join()
    return bpy.context.view_layer.objects.active


def bounds(o):
    vs = [v.co for v in o.data.vertices]
    return Vector([min(v[i] for v in vs) for i in range(3)]), Vector([max(v[i] for v in vs) for i in range(3)])


def preview(o, path):
    # Workbench, textured, orthographic, from a little above the front (glTF +Z is Blender -Y)
    # and from behind, so the lock side can be told from the hinges.
    s = bpy.context.scene
    s.render.engine = "BLENDER_WORKBENCH"
    s.display.shading.light = "STUDIO"
    s.display.shading.color_type = "TEXTURE"
    s.render.resolution_x = s.render.resolution_y = 384
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    s.collection.objects.link(cam)
    cam.data.type = "ORTHO"
    cam.data.ortho_scale = 1.4
    s.camera = cam
    for side, y, turn in (("front", -4.0, 0.0), ("back", 4.0, 180.0)):
        cam.location = (0.0, y, 1.3)
        cam.rotation_euler = (math.radians(80), 0.0, math.radians(turn))
        s.render.filepath = path % side
        bpy.ops.render.render(write_still=True)


# chest<level>.glb (Sketchfab), or chest<level>/chest<level>.gltf with its textures (Poly Haven).
for name in sorted(f for f in os.listdir(SRC) if f.startswith("chest")):
    level = int(os.path.splitext(name)[0][5:])
    path = os.path.join(SRC, name, name + ".gltf") if os.path.isdir(os.path.join(SRC, name)) else os.path.join(SRC, name)
    o = load(path, level)
    if level in CLOSE:
        o = close_lid(o)
    tris = sum(len(p.vertices) - 2 for p in o.data.polygons)
    if tris > BUDGET:
        m = o.modifiers.new("decimate", "DECIMATE")
        m.ratio = BUDGET / tris
        bpy.context.view_layer.objects.active = o
        bpy.ops.object.modifier_apply(modifier=m.name)
    lo, hi = bounds(o)
    d = hi - lo
    if d.y > d.x:  # long side along X
        o.data.transform(Matrix.Rotation(math.radians(90), 4, "Z"))
    o.data.transform(Matrix.Rotation(math.radians(TURN.get(level, 0)), 4, "Z"))
    lo, hi = bounds(o)
    o.data.transform(Matrix.Translation(-Vector(((lo.x + hi.x) / 2, (lo.y + hi.y) / 2, lo.z))))
    o.data.transform(Matrix.Scale(1.0 / (hi.x - lo.x), 4))
    for img in bpy.data.images:
        if img.size[0] > TEX or img.size[1] > TEX:
            k = TEX / max(img.size)
            img.scale(int(img.size[0] * k), int(img.size[1] * k))
    lo, hi = bounds(o)
    print("level %d: %d tris, %.2f x %.2f x %.2f (w x h x d)" % (level, sum(len(p.vertices) - 2 for p in o.data.polygons), hi.x - lo.x, hi.z - lo.z, hi.y - lo.y))
    # .gltf with its textures beside it: Godot extracts a .glb's textures into files anyway, so a
    # .glb would carry every 4K map twice.
    out = os.path.join(OUT, "chest_%02d.gltf" % level)
    bpy.ops.export_scene.gltf(filepath=out, export_format="GLTF_SEPARATE", export_texture_dir="chest_%02d" % level, export_animations=False, export_image_format="AUTO")
    preview(o, os.path.join(OUT, "chest_%02d_%%s.png" % level))
