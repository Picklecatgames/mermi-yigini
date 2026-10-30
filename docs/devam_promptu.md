# Devam promptu (2026-10-30, üçüncü hesap değişimi)

Aşağıdakini yeni hesapta, projeyi açtığın oturuma yapıştır:

---

Mermi Yığını'na devam ediyoruz (Godot 4.7, co-op FPS, zombi dalgaları). Önce `CLAUDE.md`, `docs/ayrintilar.md` → "Yeni yön: zombi dalgaları" bölümü ve bu dosyayı oku. Önceki hesap kota yüzünden her şeyi aniden durdurdu: son commit (`main`, "Kota dolmadan önce...") içinde **üç yarım iş denenmeden commit'lendi**. İlk iş: `git pull`, `godot --headless --import`, sonra aşağıdaki kontrolleri koş, kırılanı düzelt, push'la.

**İlk koşulacak kontroller** (headless, `-s res://tools/X.gd`): `character_demo_check`, `remote_anim_check`, `specials_check`, `waves_check`, `hud_check`, `ambience_check`. Hepsi yarım işlerden önce geçiyordu. `net_check` zaten istemci tarafında takılıyor (eski sorun, sebebi bulunmadı).

**Yarım kalan üç iş (denenmeden commit'lendi):**
1. **Çömelme (Ctrl), co-op'ta görünen hâliyle:** `scripts/player.gd` (`crouched`, `CROUCH_*`, kapsül 1,3 m, göz `GameState.CROUCH_EYE` 1,1 m), `scripts/game_state.gd` (pozda `crouch`, ateş kaynağı kontrolü), `scripts/settings.gd`, `project.godot` (tuş), `scripts/special_demo.gd` / `scripts/character_demo.gd`, `tools/build_zombies.gd` (tüfek paketinin çömelik yürüme klipleri) → `assets/characters/players/player_anims.res`. Uzak bedende çömelme duruşunun `remote_players.gd`'ye bağlanıp bağlanmadığı belli değil; kontrol et ve `remote_anim_check`'e çömelme ekle.
2. **Kan, et dokusu, uzuv kopması:** `tools/build_blood.py` → `assets/vfx/blood/` (decal'lar, dokular), `materials/blood_mist.gdshader`, `materials/env/gore/flesh_*`. Ham ActionVFX/TextureCan dosyaları `assets/vfx/blood/raw/`'da, git'te yok (dağıtılamaz; yeni cihazda yoksa kullanıcıdan iste). Oyun koduna ne kadar bağlandığı belli değil; `docs/ayrintilar.md` "Kullanılan asetler"e kaynak ve lisansları yazılmalı.
3. **Gerçekçi gölgeler:** kullanıcı "gölge klonumun yerdeki siyah yansıması gibi, ışığa göre yönü değişmiyor, ayağa yapışık değil" dedi. Sebep: salonda gölgeyi yalnız ay atıyordu, tavan lambalarında gölge kapalıydı, ayın `shadow_normal_bias` 1,2 idi. `tools/build_arena.gd` içinde ay bias'ı düşürüldü, tavan spotlarına gölge ve mesafe solması eklendi, **ama arena yeniden üretilip görsel olarak denenmedi**. `tools/build_arena.gd`'yi çalıştırıp `scenes/arena.tscn`'yi yeniden üret, `tools/light_shot.gd` ile lamba altında / arasında / ay ışığında ayak dibi çekimlerine bak; performansı ölç (`tools/perf_probe.gd`); `scripts/settings.gd` düşük ayarda gölgeleri kapatıyor mu kontrol et.

**Bu hesapta biten (main'de):**
- Oyuncu karakterleri: 5 Mixamo bedeni (Patron, Maskeli, İşçi, Brute, Chupacabra), girişte "KİMSİN?" seçim ekranı. Uzak oyuncu seçtiği bedenle çiziliyor; gözleri tabanca duruşunda kameranın hizasına (1,6 m) ölçekleniyor. Silah bedenin el boyuna göre büyüyor. Kafa bakışı gövdeden önce gidiyor (fareyi hızlı sallamak co-op'ta kafayla evet/hayır).
- Birinci şahıs kolları karakterin kendi kolları: `tools/build_fp_arms.gd` → `assets/characters/players/<id>/fp_arms.scn`, `scripts/fp_arms.gd` eski rig'in eklemlerine oturtuyor (kullanıcı kararı).
- Oyuncunun kendi gölgesi: `remote_players.gd` `_own_shadow`, kamerada görünmeyen, yalnız gölge atan beden.
- Karakter denemesi (debug, tek oyunculu): **K** aynayı açar (karşıda seni co-op'taki gibi taklit eden beden), açıkken K sonraki karakter, **L** seçim ekranı, **Shift K** kapatır. `scripts/character_demo.gd`, kontrolü `tools/character_demo_check.gd`.
- Salon aydınlatması: ay artık bedenlerin katmanını da aydınlatıyor, ortam dolgusu ve SSAO yumuşadı.
- Dalga dalı (`claude/dalga-kodu-704193`) main'e birleşti: holün kuzey duvarında şalter, E ile dalga başlar. Kullanıcı şalteri oyunda henüz görmedi; oyunda dene.
- Ayna kapanırken ona bakılıyorsa çöken `player.gd` `_looking_at_table` düzeltildi.

**Hâlâ birleşmemiş dallar:** `claude/sketchfab-zombi-00090b` (hazmat, blob, bloater, melty, köpek; dalga koduna bağlanmadı) ve `claude/stil-sirasi-db59e8` (D→SSS stil sıralaması; birleşince `hud_check`, kökteki `DURUM.md` silinebilir). İkisini sırayla main'e birleştir.

**Sonra:** dalga koduna yeni zombi türlerini bağla; sesler kullanıcıdan (siren, kapı, kol, stil); oyuncu ölümü gelince korkuluğun geçici canı ve başarısızlık kuralı yeniden düşünülecek; `docs/ayrintilar.md`'deki 3. şahıs karakter bölümleri hâlâ eski operator'ü anlatıyor, güncelle; Mixamo jeneriğine The Boss, Ch16, Ch32, Brute, Ch43 eklenecek.

**Yeni cihaz notu:** ham Mixamo/Sketchfab/ActionVFX dosyaları git'te yok (`assets/characters/*/raw/`, `assets/vfx/blood/raw/`); üretilmiş `.scn`/dokular git'te, oyun onlarla çalışır. Ham dosya gerekiyorsa kullanıcıdan iste.

Kurallar: Türkçe konuş; Godot penceresi açma (headless; `-s` ile `--quit-after 600`), ekran dışı çekim serbest; Godot'u isimle öldürme (editör de kapanır, timeout + PID kullan); commit mesajı Türkçe birinci tekil şahıs, AI imzası yok; ham dosyalar git'e girmez; çoklu agent ya da uzun iş öncesi maliyeti söyle.
