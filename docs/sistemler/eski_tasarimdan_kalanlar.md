# Eski tasarımdan kodda kalanlar

> **Özet (2026-11-06):**
> 2026-11-02'de mermi yığını bırakıldı; aşağıdaki kod hâlâ duruyor ve hurdalık sistemleri geldikçe kalkacak ya da değişecek.
> Örnekler: `GameState.pile` sayacı, yığından mermi alma, SPECIALS özel mermileri, huni-erit ve pres-basma.
> Silmeden önce ilgili `tools/*_check.gd`'yi çalıştır.
> Tam eski belge: `docs/arsiv/ayrintilar_tam_2026-11-06.md`. Dizin: `docs/sistemler/README.md`.

### Eski tasarımdan kodda kalanlar (2026-11-02)

Mermi yığını bırakıldı ama şunlar kodda duruyor; hurdalık sistemleri geldikçe kalkacak ya da değişecek:
- `GameState.pile` sayacı (100M), HUD'daki yığın sayacı ve ilerleme çubuğu, denge panelindeki yığın satırı.
- Yığından "mermi" alıp şarjöre koyma (`request_pick_up_loose`, el kapasitesi); dağdan alınan parça hâlâ mermi sayılıyor.
- Yığından zarla çıkan özel mermiler: `GameState.SPECIALS` (Yumruk, Balon, Çığlık), `ammo_wheel.gd`'deki cep, `player.gd` `_hit_by_special`, `assets/bullet/tips/`, `tools/specials_check.gd`.
- Huninin mermiyi pirince eritmesi (`request_melt`, `melt_bin`, `MELT_RATES`, `melter_menu.gd`, `hopper.gd`) ve presin pirinçten klon/elektrikli basması (`PRESS_ROUNDS`, `press_menu.gd`).
- Kasalar (`scripts/chests.gd`, yuvasız) ve minigun'un `GUNS`'taki `"crate": 12` kilidi.
- Isınma görevleri t00 (yığın metni) ve t01 "Yığından mermi al", mermi cinsinden görev hedefleri.
- Elektrikli mermi gösterisi (`electric_fx.gd`, oyuna bağlı değil).

Salon, korkuluk, atış alanı ve çukurdan kalanlar (temizlik, 2026-11-06):
- **Silindi:** eski salonun kurucusu `tools/build_arena.gd` ve `scenes/arena.tscn`, onun süsleyicileri `tools/hall_dressing.gd`, `tools/range_dressing.gd`, `tools/zombie_bay.gd` (ağıllar, kapılar, kol), salon iskeleti meshlerini çıkaran `tools/build_shed_meshes.py`; `build_world.gd`'de hiç çağrılmayan `_cukur`. `build_world.gd`'nin kullandığı yardımcılar (`add`, `worn`, `pbr_box`, `_prop`, `block`, `collide`, `_lighten`) `tools/world_kit.gd`'ye taşındı; aynı `world.tscn` çıkıyor. Bu dosyaların andığı, başka yerde geçmeyen asetler silinmedi (shed meshleri, salon dekalleri, kemikler, `assets/props/cukur/`, Poly Haven eşyalarının bir kısmı, `materials/env/` altındaki salon malzemeleri); liste kullanıcıda.
- **Düzeltildi:** `tools/press_check.gd` arenayı değil `world.tscn`'i yüklüyor. `tools/specials_check.gd` yumruk testini evin dışında, açık havada yapıyor (oyuncu artık evde doğuyor; ev tavanı uçuşu 1,1 m'de kesiyordu, salonun çatısı 9 m'deydi).
- **Duruyor, `waves.gd`'nin temizliğini bekliyor:** korkuluk ve bölmeleri (`scripts/fence.gd`, `GameState.FENCE*`, `fence_bays`, `FIRING_LINE_X`, `FENCE_LAYER`, `request_repair_fence`), dalga kolu (`LEVER_POS`, `request_pull_lever`, `player.gd`'deki kol ipucu; kol olmadığı için görünmüyor), `OVERHEAD_LAYER`. Bunlara bağlı çekimler: `tools/fence_shot.gd`, `wave_shot.gd`, `walk_shot.gd`, `cross_shot.gd`, `first_probe.gd`, `spike_probe.gd`, `minigun_probe.gd` (korkuluğu onarıyor).
- **Duruyor:** `scripts/flicker_lamp.gd` (yalnız eski salon kullanıyordu; lamba titremesi işinde yeniden kullanılabilir).
