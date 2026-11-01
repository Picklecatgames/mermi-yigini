# Devam promptu (2026-11-01)

Aşağıdakini yeni oturuma yapıştır:

---

Mermi Yığını'na devam ediyoruz (Godot 4.7, co-op FPS, zombi dalgaları). Önce `CLAUDE.md`, `docs/ayrintilar.md` → "Yeni yön: zombi dalgaları" bölümü (özellikle "Çit: bölmeler", "Yürüyüş", "Baygınlık") ve bu dosyayı oku.

**İlk iş: `ana-kontrol` dalını bitirip main'e almak.** Dal `origin/claude/ana-kontrol`'da (worktree: `.claude/worktrees/ana-kontrol`). İçinde main'e henüz girmemiş üç iş birleşik duruyor:
1. **Dummyler gitti** (kullanıcı: "dummyleri kaldır oyundan", B ve Teçhizat için "hepsi gitsin"): 12 hedef, B yerleştirme modu, tezgâhtaki TEÇHİZAT, N deneme alanı. Isınma zinciri artık tabanca → yığından mermi → doldur → pano.
2. **Çit bölmeleri ve yürüyüş** (kullanıcı: "zombiler çite çok saçma yürüyor", "hasar gören çitin bölmesinden zombiler içeri girebilsin, tek can barı saçma"): 20 bölmenin her birinin canı var, yıkılan bölme delik açar, zombiler en yakın deliğe yönelip içeri girer ve en yakın ayaktaki oyuncuya saldırır. Tek can barı kalktı.
3. **Baygınlık** (kullanıcı: "oyuncu baygın düşsün, ekran giderek kırmızılaşsın, bir süre sonra kararıp diğer oyuncuyu izlemeye geçsin; turu bitiren oyuncu ileride ekleyeceğimiz diriltme noktasından yüksek maliyetle kaldırabilsin"): oyuncu canı, baygın düşme, kırmızılaşma, izleme, herkes düşünce tur kaybı, kaldırma şimdilik tezgâh menüsünden (geçici, diriltme noktası sonra).

Birleştirmede çakışmalar elle çözüldü. Dummy dalının sildiği silah indirme (`viewmodel.gd` `LOW_*`, `_low_lin`) baygınlık için geri getirildi. İki daldan gelen yinelenen `hurt_player` / `is_down` silindi; oyun yine açılıyor (blood_check geçti). **Birleşik hâlde bütün kontroller henüz koşulmadı.** Yapılacaklar:
- worktree'de `--headless --import`, sonra bütün `tools/*_check.gd` (`--quit-after 100000`). Ağ kontrolleri (fence, join, net, waves, down) ortak kilitle sırayla koşulmalı: `mkdir /c/Users/vedat/AppData/Local/Temp/godot_net.lock` başarılıysa koş, bitince `rmdir`. pause_check'e 120 sn timeout ver.
- Oturumların bildirdiği kırık kontroller: `pause_check` (takılıyor), `electric_check`. Bunların main'de de kırık olduğu söylendi, birleşik hâlde doğrula, düzelt.
- Geçince `ana-kontrol`'ü main'e al (`git merge`), push'la.

**Dikkat: `.claude/scripts/git-sync.sh` Stop hook'u** her tur sonunda upstream'e push'luyor, olmazsa `pull --rebase --autostash` deniyor. Bir worktree'de upstream origin/main ise kontrol edilmemiş birleşmeyi main'e itmeye kalkar. Bir keresinde de çalışma ağacını eski hâle döndürdü. Birleştirme dallarında upstream'i kaldır (`git branch --unset-upstream`) ya da kendi adıyla push'la.

**Reels işi (yarım):** kullanıcı oyunun gelişim sürecinden doğal bir Instagram Reels videosu istiyor. Lazer/katana efektli edit istemiyor; düz kesmeler, aynı açıdan "1. gün → bugün" geçişleri, müziğin vuruşuna oturan kesmeler olacak. Oturum `C:/rv/01`…`08`'e sekiz kilometre taşı commit'ini worktree olarak açtı ve import'a başladı, ama çekim yapmadan durduruldu. Kalan: `tools/*_shot.gd` yöntemiyle her sürümden aynı 2-3 açıdan fotoğraf ve Movie Maker ile 3-6 sn klip almak (pencere açmadan; olmuyorsa kullanıcıya sor). Çıktılar `reels/<sıra>_<tarih>_<ad>/` altına ve `reels/liste.md`'ye (`.gitignore`'da). İş bitince `C:/rv/*` worktree'lerini `git worktree remove` ile kaldır. Kurgu ffmpeg ile yapılacak (kurulu). Müziği kullanıcı seçecek, bugünden ham oynanışı da kendisi kaydedecek.

**Tasarım notları (kullanıcıyla konuşulan):** çitin kalması ama zombilerin bize de ulaşması kararlaştırıldı (bölmeler + baygınlık bunun ilk adımı). İleride: diriltme noktası, çitin üstünden atlayan tipler.

**Kullanıcıdan beklenenler:** ses kayıtları (silah, isabet, siren/kapı/şalter, çit pençe/yıkılma/onarım, kafa patlama, stil sırası; ayrıca baygınlık: `assets/sounds/player/` hurt, down, heartbeat, revive), ActionVFX lisans türü (Individual mı Startup mı), dalga dengesi ve baygınlık sayıları (hepsi oturumların önerisi).

Kurallar: Türkçe konuş; Godot penceresi açma (headless, ekran dışı çekim serbest); kullanıcı oyundayken Godot çalıştırma ve oturumlara da çalıştırtma; Godot'u isimle öldürme (PID ile); commit mesajı Türkçe birinci tekil şahıs, AI imzası yok; ham dosyalar git'e girmez; kullanıcı her görevi ayrı oturumda istiyor, bitenleri main'e sen birleştir; aynı anda birden çok oturum ağ kontrolü koşacaksa kilidi kullansınlar; kota %95'e gelince dur, commit'le, devam promptu ver; çoklu agent ya da uzun iş öncesi maliyeti söyle.
