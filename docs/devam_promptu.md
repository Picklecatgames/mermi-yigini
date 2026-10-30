# Devam promptu (2026-10-30, ikinci hesap değişimi)

Aşağıdakini yeni cihazda/hesapta, projeyi klonlayıp açtığın oturuma yapıştır:

---

Mermi Yığını'na devam ediyoruz (Godot 4.7, co-op FPS, zombi dalgaları). Önce `CLAUDE.md`, `docs/ayrintilar.md` → "Yeni yön: zombi dalgaları" bölümü ve bu dosyayı oku. İş dört dalda, hepsi GitHub'da (`origin`), hiçbiri `main`'e birleşmedi. İlk iş: `git fetch` ve dalları sırayla `main`'e birleştir, çakışmaları çöz, kontrolleri koş, push'la.

**Dallar (önerilen birleştirme sırası):**
1. `claude/dalga-kodu-704193` — MAIN'E BİRLEŞTİ (2026-10-30, `waves_check` geçiyor; main'in zombi parçalanması ve ağıl çığlıkları `waves.gd`'ye taşındı): `scripts/waves.gd`, `tools/waves_check.gd`; holün kuzey duvarında şalter kolu + flip plakalı tabela (`tools/zombie_bay.gd`, arena yeniden üretildi), E ile kol → alarmlar, dönen lambalar, kapı açılır, zombiler korkuluğa yürür; host planlar, ortadan katılan dalgayı alır. Korkuluğun canı geçici (oyuncu ölümü yok). `zombie_killed` sinyali (öldüren, tür, kafa, yer, silah). Demo sahnesi silindi. Siren/kapı/kol ses yuvaları boş.
2. `claude/sketchfab-zombi-00090b` — BİTTİ: hazmat, flesh blob (`blob`), bloater, melty zombie, köpek (`dog`). Kullanıcı üçünü satın aldığını söyledi. `zombie_body.gd` `_roll` değişti (PCG): aynı tohum artık farklı model seçer. Tür/hız seçimleri "geçici" işaretli. Çekim aracı `tools/zombie_shots.gd`. Dalga koduna `dog`/`blob` türleri henüz bağlanmadı.
3. `claude/stil-sirasi-db59e8` — BİTTİ: solda D→SSS stil sıralaması (`zombie_killed`'e bağlı), Rubik Wet Paint yazı tipi, OpenGameArt CC0 grunge, Kenney parıltılar. Kalan: birleşince HUD kontrolünü yeniden koş; ses kayıtları `assets/sounds/style`'a gelecek. Kökteki `DURUM.md` birleşmeden önce silinebilir.
4. `claude/oyuncu-karakter-d964f1` — YARIM: uzak oyuncuda seçilen Mixamo bedeni (`remote_players.gd`) ve birinci şahısta karakterin kendi kolları (`tools/build_fp_arms.gd` → `fp_arms.scn`, `scripts/fp_arms.gd`) bitti, `remote_anim_check` beş karakterde geçiyor. Seçim ekranı (`scripts/character_pick.gd`) yazıldı ama denenmedi; `net_check` istemci tarafında takılıyor. Ayrıntı dalın kökündeki `DURUM.md`'de. Kullanıcı kararı: 5 karakter (The Boss, Ch16 maskeli, Ch32 turuncu tulumlu, Brute, Chupacabra), girişte her oyuncu seçer, FPS kolları karakterin kendi kolları (2026-10-30, önceki "aynı model, doku karaktere göre" kararının yerine). Ham dosyalar `Downloads\player_characters\` (eski cihazda; yeni cihazda yoksa kullanıcıdan iste). Animasyon paketleri (Pistol/Handgun, Rifle 8-Way, Male Locomotion) kullanıcıdan gelecek.

**Sonra:** dalga koduna yeni zombi türlerini bağla; sesler kullanıcıdan (zombi, canavar, siren, kapı, kol, stil); oyuncu ölümü gelince korkuluğun geçici canı ve başarısızlık kuralı yeniden düşünülecek.

**Yeni cihaz notu:** ham Mixamo/Sketchfab dosyaları git'te yok (`assets/characters/zombies/raw/` vb.); üretilmiş `.scn`/dokular git'te, oyun onlarla çalışır. Ham dosya gerekiyorsa kullanıcıdan iste. İlk açılışta `godot --headless --import`.

Kurallar: Türkçe konuş; Godot penceresi açma (headless; `-s` ile `--quit-after 600`), ekran dışı çekim serbest; Godot'u isimle öldürme; commit mesajı Türkçe birinci tekil şahıs, AI imzası yok; ham Mixamo dosyaları git'e girmez.
