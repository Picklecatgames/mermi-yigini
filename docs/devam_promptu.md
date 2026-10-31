# Devam promptu (2026-10-31, kota %92'de durdu)

Aşağıdakini yeni oturuma yapıştır:

---

Mermi Yığını'na devam ediyoruz (Godot 4.7, co-op FPS, zombi dalgaları). Önce `CLAUDE.md`, `docs/ayrintilar.md` → "Yeni yön: zombi dalgaları" bölümü ve bu dosyayı oku. Önceki oturum 5 saatlik kota %92'deyken durdu.

**İlk iş:** `git pull`, `godot --headless --import` (Godot: `C:/Users/vedat/projeler/Godot_v4.7.2-stable_win64.exe`), sonra bütün kontrolleri koş (`-s res://tools/X.gd --quit-after 100000`): hitbox, hit_react, fence, waves, zombie_roles, zombie_body, blood, zombie_sound, hud, table, specials, ambience, character_demo, remote_anim, pistol, minigun, ads, hit_sound, shell_tink, feel, net (hepsi `_check`). Son birleşim (kafa patlaması dalı, `claude/kafasiz-sac-74b406`) main'e alındı ama birleşik hâlde kontroller **koşulmadı**; kırılan varsa düzelt, push'la.

**Yarım kalan iki dal (main'e birleşmedi):**
1. `claude/perf-ilk-acilis-*`: ilk açılış (boş shader önbelleği) takılmaları ve 40 zombide kalan ~6 ms CPU yükü. Son commit 606f95f: Q menüsündeki takılmalar giderildi, görünmeyen zombiler 3 karede bir canlanıyor (40 zombide 80 → 95 FPS); birleşik hâlde kontrol koşulmadı. Minigun'u ilk kullanma anında kararsız bir takılma var (çekme ile ateş üst üste gelince). Ölçüm aracı `tools/spike_probe.gd`, ilk açılış için `tools/first_probe.gd`. Makinede başka Godot çalışırken ölçme.
2. `claude/minigun-uzi-el-*`: kullanıcı "Minigun'daki parmak hatası ve UZI'deki kolun saçma duruşu" dedi, ayrıntı vermedi. Oturum yeni başlamıştı; dalda bir şey varsa oradan, yoksa baştan: birinci şahıs (`scripts/fp_arms.gd`, `viewmodel.gd` `SETS`) ve uzak beden (`scripts/remote_players.gd`) ekran dışı çekimle bul, düzelt.
Dalların adını `git branch -r | grep claude/` ile bul. Bitince main'e al, kontrolleri koş, push'la.

**Bu oturumda biten (main'de):** çömelme co-op'ta; tavan lambası gölgeleri; kan (mürekkep görüntüsü düzeldi); yeni zombi türleri ve stil sırası dalları; co-op'ta uzak oyuncunun nişan/rahat duruşu, tepmesi, kovanı; uzuv kopması ve sürünme; türe göre can, can barı, hepsi koşuyor, kayma yok, çığlıkçı/şişko/köpek rolleri; doğma alanı yarıya indi; çit canı, yıkılınca tur kaybı, **tamir atölyedeki tezgâh menüsünden** (kullanıcı kararı, ortadaki masa tabancadan sonra kaybolur); kemiklere oturan isabet kapsülleri ve vurulan yerden tepki; silah hissi (sarsıntı, tırmanma, isabet işaretleri); dalga takılmaları (40 zombide 11 → 54 FPS); net_check takılması (kontrol eskimişti); karakter dokümanı; kafa patlaması nadir (kullanıcı kararı: "sürekli patlarsa oyuncu iyi vuruş yaptığını düşünmez"), her seferinde farklı, daha sulu, kafasız boyunda saç/saçak kalmıyor.

**Kullanıcıdan beklenenler:** ses kayıtları (silah atış/yankı, şarjör/sürgü, Minigun motoru, boş tetik, kovan; et/kafa/beton/metal isabet, isabet işareti; siren, kapı, şalter; çite pençe/yıkılma/onarım; kafa patlama; stil sırası; listeler `docs/ayrintilar.md`'de ve oturum notlarında); ActionVFX lisans türü (Individual mı Startup mı; 2 kişilik ekip için Startup); dalga dengesi (tür karışımı, can, hız şimdilik oturumların önerisi).

**Kodda kalanlar:** yukarıdaki iki dal; dalga dengesinin kullanıcıyla ayarlanması.

Kurallar: Türkçe konuş; Godot penceresi açma (headless, ekran dışı çekim serbest); kullanıcı oyundayken Godot çalıştırma ve oturumlara da çalıştırtma; Godot'u isimle öldürme (PID ile); commit mesajı Türkçe birinci tekil şahıs, AI imzası yok; ham dosyalar git'e girmez; kullanıcı her görevi ayrı oturumda istiyor, bitenleri main'e sen birleştir; kota %95'e gelince dur, commit'le, devam promptu ver; çoklu agent ya da uzun iş öncesi maliyeti söyle.
