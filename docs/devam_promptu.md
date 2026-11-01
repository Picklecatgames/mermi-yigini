# Devam promptu (2026-11-01)

Aşağıdakini yeni oturuma yapıştır:

---

Mermi Yığını'na devam ediyoruz (Godot 4.7, co-op FPS, zombi dalgaları). Önce `CLAUDE.md`, `docs/ayrintilar.md` → "Yeni yön: zombi dalgaları" bölümü (özellikle "Çit: bölmeler", "Yürüyüş", "Baygınlık") ve bu dosyayı oku.

**Main'de (2026-11-01):** dummyler gitti (B ve Teçhizat da); çit bölmeleri, delikten giren zombiler ve yeni yürüyüş; oyuncu baygınlığı, izleme, kaldırma (şimdilik tezgâhtan). Birleşik hâlde bütün `tools/*_check.gd` geçti. Ağ kontrolleri (fence, join, net, waves, down) ortak kilitle sırayla koşulur: `mkdir /c/Users/vedat/AppData/Local/Temp/godot_net.lock` başarılıysa koş, bitince `rmdir`.

**Açık oturum:** `claude/cit-atlayan-*`: çitin üstünden atlayan ve altından geçen zombi tipleri (kullanıcı kararı). Bitince main'e al, kontrolleri koş. Kullanıcının bilgisi: çit ileride görsel ve yapısal olarak, level sistemine göre çeşitlenecek.

**Zırhlı/maskeli isabet ipucu (yapılmadı):** zırhlıya metal kıvılcımı (projedeki Kenney kıvılcımları yeter), maskeliye cam çatlağı. Kullanıcı TextureCan "Broken Glass Texture with Cracks" (1K/2K, CC0) indirecek; tam yüzey kırık desen, merkezinden yuvarlak bir parça kesilip alfa ile decal yapılacak. 3DTexel'de daha uygun bir çatlak decal'ı bulursa o.

**Dikkat: `.claude/scripts/git-sync.sh` Stop hook'u** her tur sonunda upstream'e push'luyor, olmazsa `pull --rebase --autostash` deniyor. Bir worktree'de upstream origin/main ise kontrol edilmemiş birleşmeyi main'e itmeye kalkar. Bir keresinde de çalışma ağacını eski hâle döndürdü. Birleştirme dallarında upstream'i kaldır (`git branch --unset-upstream`) ya da kendi adıyla push'la.

**Reels işi (yarım):** kullanıcı oyunun gelişim sürecinden doğal bir Instagram Reels videosu istiyor. Lazer/katana efektli edit istemiyor; düz kesmeler, aynı açıdan "1. gün → bugün" geçişleri, müziğin vuruşuna oturan kesmeler olacak. Oturum `C:/rv/01`…`08`'e sekiz kilometre taşı commit'ini worktree olarak açtı ve import'a başladı, ama çekim yapmadan durduruldu. Kalan: `tools/*_shot.gd` yöntemiyle her sürümden aynı 2-3 açıdan fotoğraf ve Movie Maker ile 3-6 sn klip almak (pencere açmadan; olmuyorsa kullanıcıya sor). Çıktılar `reels/<sıra>_<tarih>_<ad>/` altına ve `reels/liste.md`'ye (`.gitignore`'da). İş bitince `C:/rv/*` worktree'lerini `git worktree remove` ile kaldır. Kurgu ffmpeg ile yapılacak (kurulu). Müziği kullanıcı seçecek, bugünden ham oynanışı da kendisi kaydedecek.

**Tasarım notları (kullanıcıyla konuşulan):** çitin kalması ama zombilerin bize de ulaşması kararlaştırıldı (bölmeler + baygınlık bunun ilk adımı). İleride: diriltme noktası, çitin üstünden atlayan tipler.

**Kullanıcıdan beklenenler:** ses kayıtları (silah, isabet, siren/kapı/şalter, çit pençe/yıkılma/onarım, kafa patlama, stil sırası; ayrıca baygınlık: `assets/sounds/player/` hurt, down, heartbeat, revive), ActionVFX lisans türü (Individual mı Startup mı), dalga dengesi ve baygınlık sayıları (hepsi oturumların önerisi).

Kurallar: Türkçe konuş; Godot penceresi açma (headless, ekran dışı çekim serbest); kullanıcı oyundayken Godot çalıştırma ve oturumlara da çalıştırtma; Godot'u isimle öldürme (PID ile); commit mesajı Türkçe birinci tekil şahıs, AI imzası yok; ham dosyalar git'e girmez; kullanıcı her görevi ayrı oturumda istiyor, bitenleri main'e sen birleştir; aynı anda birden çok oturum ağ kontrolü koşacaksa kilidi kullansınlar; kota %95'e gelince dur, commit'le, devam promptu ver; çoklu agent ya da uzun iş öncesi maliyeti söyle.
