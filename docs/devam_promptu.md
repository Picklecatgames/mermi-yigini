# Devam promptu (2026-10-30, hesap değişimi)

Aşağıdakini yeni hesapta, bu projede (`C:\Users\vedat\projeler\mermi-yigini`) açılan oturuma yapıştır:

---

Mermi Yığını'na devam ediyoruz (Godot 4.7, co-op FPS, zombi dalgaları). Önce `CLAUDE.md`, `docs/ayrintilar.md` → "Yeni yön: zombi dalgaları" bölümü ve `git log -5` oku. Son commit'te her şey kayıtlı. Durum:

**Bitti (commit'te):**
- Atış alanı zombi kıyım yeri olarak baştan üretildi (`tools/zombie_bay.gd`, `tools/build_arena.gd`): arka duvarda ortadan iki yana kayan çift kanatlı kapı (`MainGateN/S`), yan duvarlarda kalkan kepenkler; kanatlar `wave_gate` grubunda, meta `slide_dir`/`slide_dist`/`mouth`; ağıllarda 24 `wave_spawn`; 12 sönük `wave_alarm` (yakmak: Light3D'leri görünür yap, `lit_material` metasını tak, beacon'ın `Spin`'ini döndür). Talim alanı izleri (metre çizgileri, kontrplak, kauçuk zemin, perdeler) kaldırıldı, kanlı beton, kemik, et, çöp, yanan lastikler. Ayrıntı: `docs/ayrintilar.md` → "Zombi girişi".
- Mixamo zombileri: `tools/build_zombies.gd` (ham dosyalar `assets/characters/zombies/raw/`, git'te yok, `C:\Users\vedat\Downloads\mixamo_zombie\` altında da duruyor), `scripts/zombie_body.gd` (tohumla giydirip oynatır), `scenes/zombie_demo.tscn` (alarmlar + kapı + yürüyen zombiler demosu), `tools/zombie_body_check.gd`. 13 model, ~44 klip.
- Yeni tabanca (silah oturumu): `viewmodel.gd` SETS "pistol", `add_pistol`/`pistol_grip`, `remote_players.gd`'de çağrısı.

**Yarım / sıradaki:**
1. **Dalga kodu yok:** zombileri doğurup yürüten, şalter kolu + siren + kapı sekansını oynatan kod ("şalter iner, siren ve kırmızı ışıklarla beraber ikili kapı ortadan yanlara doğru slide ile açılır"). `zombie_demo.gd` örnek; `GameState`'te host otoriter, yeni istemci komutu `REQUESTS`'e, yeni dünya sinyali `EVENTS`'e.
2. **Oyuncu karakterleri (kullanıcı kararı):** 5 karakter, oyuna girerken her oyuncu SEÇER: The Boss, Ch16 (maskeli), Ch32 (turuncu tulumlu), Brute, Chupacabra (Ch43). Dosyalar `C:\Users\vedat\Downloads\player_characters\`. Diğer oyuncular seçilen Mixamo bedenini görür (`remote_players.gd`, şimdi operator + `tools/retarget_ual.gd`). FPS kolları: mevcut kol modeli/rig (`tools/build_arms.py`, `tools/paint_arms.py`) aynı kalır, her karakter için deri/kıyafet/eldiven dokusu o karakterden türetilir. Animasyon paketleri (kullanıcı indiriyor, Downloads'a düşer): Pistol/Handgun Locomotion Pack, Rifle 8-Way Locomotion Pack, Male Locomotion Pack. `build_zombies.gd` düzenini kullan.
3. Sketchfab zombileri (`Downloads\mixamo_zombie\sketchfab\`: hazmat, bloater, zombie dog, flesh blob, animation-zombie x2) eklenmedi: farklı iskelet; köpek ve blob kendi animasyonlarıyla. animation-zombie zip'lerinin kaynak/lisansı kullanıcıdan sorulacak.
4. Sesler kullanıcıdan gelecek: zombi inleme/saldırı/ölüm, canavar kükremesi, siren, kapı kayma, kepenk.
5. Görsel kontrol yapılmadı: ekran dışı çekim (`tools/shot.gd -- bay range`) için kullanıcıdan izin al.

Kurallar: Türkçe konuş; Godot penceresi açma (headless; `-s` ile çalıştırırken `--quit-after 600` ekle); Godot'u isimle öldürme; commit mesajı Türkçe birinci tekil şahıs, AI imzası yok; aset kuralları CLAUDE.md'de (Mixamo kullanıcı kararıyla alındı: Adobe şartları, ham dosya dağıtılmaz).
