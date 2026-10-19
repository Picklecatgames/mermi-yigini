# Ajan brifingi (2026-10-19)

Bu klasördeki raporları yazan ajanlar için ortak kurallar. Raporlar Türkçe.

## Proje

- Godot 4.7 projesi: `C:\Users\vedat\projeler\mermi-yigini`. Önce `CLAUDE.md`'yi baştan sona oku: oyun fikri, tasarım kuralları, kararlar ve yapılanlar orada.
- Önceki ajan turu: `docs/ajan_raporlari_2026-10-19.md` (bir kısmı düzeltildi; tekrarlama, üstüne koy).
- Oyun: 3D FPS incremental. Ortada 100M mermilik yığın; mermi alınır, tabancaya konur, hedeflere sıkılır, isabet para verir. Kombo zinciri (1,5 sn pencere, zincir = çarpan), zayıf nokta ×2, atış hattı (x = 14, ötesinden atış para vermez), hedefler arka duvarda.
- Hedefler ve ödemeleri: `main.tscn` içindeki `LockedTargets` ve `scripts/*` (dummy, `hanging_steel.gd`, `popper_target.gd`, `plate_rack.gd`, `texas_star.gd`, `rail_mover.gd`). Ekonomi: `scripts/game_state.gd` (`UPGRADES`, `request_fire`, `COMBO_WINDOW`).
- Hedef: yaklaşık 1 saatlik oynanabilir demo, 4 kişilik co-op sonra.

## Kurallar (kesin)

1. **Oyun dosyalarına dokunma.** `.gd`, `.tscn`, `.tres`, `project.godot`, `assets/`, `materials/` salt okunur. Yazabileceğin tek yer kendi rapor dosyan ve kendi karalama klasörün: `C:\Users\vedat\AppData\Local\Temp\claude\C--Users-vedat-projeler-mermi-yigini\1ac33e2e-342e-4fa3-b131-4175cf24154f\scratchpad\agents\<adın>\`.
2. **Godot yalnızca headless:** `"C:/Users/vedat/projeler/Godot_v4.7.2-stable_win64.exe" --headless --path . ...`. Ekranda pencere açma. Godot'u isimle öldürme (`taskkill /IM` yok); `timeout` kullan.
3. Kendi test/simülasyon betiklerini karalama klasörüne yaz. Godot'un `-s` ile çalıştıracağı bir `.gd` betiği proje içinde olmak zorundaysa `tools/agent_<adın>_*.gd` adını kullan ve iş bitince sil.
4. Mevcut kontroller: `tools/combo_check.gd` (`-s` ile), `tools/steel_check.tscn` (sahne olarak). Çalıştırmak serbest.
5. Rapor yapısı: **Özet (5 madde)** → **İyi, kalsın** → **Kötü, düzelsin** (dosya:satır, neden, öneri) → **Eklensin** → **Çıkarılsın** → **Sayılar** (somut değer önerileri ve gerekçesi) → **Diğer ajanlara sorular**. Her öneriye öncelik (Y/O/D) ve tahmini süre yaz.
6. Somut ol: "daha iyi olur" değil, "popper $3 → $4, çünkü ...".
