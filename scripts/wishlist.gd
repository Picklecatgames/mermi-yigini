class_name Wishlist
## The wishlist reward: a gold Deagle for whoever adds the game to their Steam wishlist. Steam
## tells no game who wishlisted it (no Steamworks call, no inventory promo rule for it), so the
## button opens the store page and trusts the click. The skin is this machine's, kept in user://.
# ponytail: honour system and local only; others in co-op still see a plain Deagle (send it with
# request_hello if that matters).

## Steam's own client first (the player is signed in there), the web page if Steam isn't installed.
# ponytail: app id 0 until the store page exists (Faz 6, step 27); set it then.
const APP_ID := 0
const STORE := "https://store.steampowered.com/app/%d/"
const SAVE := "user://rewards.cfg"
const GOLD := Color(1.0, 0.78, 0.34)  # gold's own reflectance (F0)
const SHEEN := preload("res://materials/gold_sheen.gdshader")


static func golden() -> bool:
	var cfg := ConfigFile.new()
	return cfg.load(SAVE) == OK and cfg.get_value("wishlist", "golden_deagle", false)


## Opens the store page and hands the skin over; every first-person gun puts it on at once.
static func claim(tree: SceneTree) -> void:
	var url := STORE % APP_ID
	if OS.shell_open("steam://openurl/" + url) != OK:
		OS.shell_open(url)
	var cfg := ConfigFile.new()
	cfg.load(SAVE)
	cfg.set_value("wishlist", "golden_deagle", true)
	cfg.save(SAVE)
	tree.call_group("first_person_gun", "gild")


## Turns every surface of `mi` to polished gold, the kind CS cases sell: full metal, near mirror,
## so it is the reflections that draw it (the hall sky's lamp streaks sliding over warm dark gold),
## not a flat yellow. The roughness map stays at a fraction, so the parts still read; a glint
## sweeps across now and then.
static func gild(mi: MeshInstance3D) -> void:
	var sheen := ShaderMaterial.new()
	sheen.shader = SHEEN
	for i in mi.mesh.get_surface_count():
		var gold := mi.get_active_material(i).duplicate() as StandardMaterial3D
		gold.albedo_texture = null
		gold.albedo_color = GOLD
		gold.metallic = 1.0
		gold.metallic_texture = null
		gold.roughness = 0.35  # scales the map: polished, but not one smooth blob
		gold.rim_enabled = false
		gold.next_pass = sheen
		mi.set_surface_override_material(i, gold)
