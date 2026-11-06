# Devam promptu (2026-11-06, kısa)

Eski uzun hâli (2026-11-02 oturum brief'leri): `docs/arsiv/devam_promptu_2026-11-02.md`. Yeni oturuma yalnız bu dosyayı ve `CLAUDE.md`'yi ver; sisteme dokunurken `docs/sistemler/README.md` → ilgili dosya.

## Çalışma kuralları (hepsi kullanıcıdan geldi)
- Türkçe yaz. Commit mesajları Türkçe, birinci tekil şahıs, samimi; AI imza satırı yok.
- Godot: `C:/Users/vedat/projeler/Godot_v4.7.2-stable_win64.exe`. Pencere açma; kontroller headless, görsel kontrol için ekran dışı çekim serbest (`--position -10000,-10000`). Kullanıcı oyundayken Godot çalıştırma. Godot'u isimle öldürme, yalnız kendi PID'ini (kullanıcının editörü aynı exe).
- Kontrolleri `powershell -File tools/run_checks.ps1 <ad> ...` ile koş: tek satır özet, tam günlük `%TEMP%\mermi_checks\`; `--import`'u kendisi yapar (yeni worktree'de ilk koşu uzun sürer), ağ kontrollerinde ortak kilidi alır. Çekim: `-Shot shot -ShotScale 0.5`.
- Ham dosyalar (blend, zip, indirilen kaynak) git'e girmez. Çoklu agent ya da uzun iş öncesi maliyeti söyle.
- Hurda dağının kendi yüzeyi hiçbir zaman görünmez (kullanıcı bunu 20 kez söyledi).
- Kota %95'e gelince dur, commit'le, bu dosyayı güncelle.

## Durum (2026-11-06)
Açık alan sahnesi (`scenes/world.tscn`, kurucu `tools/build_world.gd`), gece-gündüz, ev ve TV, ormandan gelen zombiler (görüş/koşma, nav), ormana izlenme olayları, kafa lambası titremesi, hurdadan alınan parçalar, PS1 ses düzeni, eller/tabanca kavrayışı main'de. Tek tek ayrıntı: `git log --oneline -30`.

## Sıradaki işler
Sıra için `docs/yol_haritasi.md`. Açık uçlar: öğütücü, malzeme → barut/kovan, yeni mermi türleri ve post-apo silahlar, dalga/denge turu, otomasyon (`docs/otomasyon_hazirlik.md`), müzik (kullanıcı Suno ile üretecek), bitiş hedefi, Steam.
