# Blender (5.x, background): a Sketchfab "original format" download (fbx/obj + textures/) turned into
# the glb tools/build_chests.py reads, its PBR textures wired to the materials by name.
# Run: blender -b --factory-startup -P tools/sketchfab_to_glb.py -- <model.fbx|obj> <textures dir> <out.glb>
import bpy, os, sys, glob
src, texdir, out = sys.argv[sys.argv.index("--") + 1:][:3]
bpy.ops.wm.read_factory_settings(use_empty=True)
if src.lower().endswith(".fbx"):
    bpy.ops.import_scene.fbx(filepath=src)
else:
    bpy.ops.wm.obj_import(filepath=src)
texs = glob.glob(os.path.join(texdir, "*"))
def pick(prefix, keys):
    for t in texs:
        n = os.path.basename(t).lower()
        if (not prefix or n.startswith(prefix)) and any(k in n for k in keys):
            return t
mats = {m for o in bpy.context.scene.objects if o.type == "MESH" for m in o.data.materials if m}
for m in mats:
    # textures named after the material if any match it, else the whole folder serves the one material
    base = m.name.lower().split(".")[0]
    prefix = next((p for p in (base, "foot_locker_" + base) if any(os.path.basename(t).lower().startswith(p) for t in texs)), "")
    m.use_nodes = True
    nt = m.node_tree
    bsdf = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
    def img(path, colour):
        n = nt.nodes.new("ShaderNodeTexImage"); n.image = bpy.data.images.load(path)
        if not colour: n.image.colorspace_settings.name = "Non-Color"
        return n
    for link in list(nt.links):
        if link.to_node == bsdf: nt.links.remove(link)
    b = pick(prefix, ["basecolor", "base_color", "diffuse", "albedo"]) or pick(prefix, ["image_0"])
    if b: nt.links.new(img(b, True).outputs["Color"], bsdf.inputs["Base Color"])
    for keys, inp in ((["metallic", "metalness"], "Metallic"), (["roughness"], "Roughness")):
        p = pick(prefix, keys)
        if p: nt.links.new(img(p, False).outputs["Color"], bsdf.inputs[inp])
    p = pick(prefix, ["normal"]) or pick(prefix, ["image_2"])
    if p:
        nm = nt.nodes.new("ShaderNodeNormalMap")
        nt.links.new(img(p, False).outputs["Color"], nm.inputs["Color"])
        nt.links.new(nm.outputs["Normal"], bsdf.inputs["Normal"])
    print("  mat", m.name, "prefix", prefix or "-", "base", b and os.path.basename(b))
bpy.ops.export_scene.gltf(filepath=out, export_format="GLB")
