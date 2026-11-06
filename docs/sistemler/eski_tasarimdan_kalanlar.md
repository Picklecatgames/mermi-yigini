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
