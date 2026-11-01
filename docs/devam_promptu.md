# Devam promptu (2026-11-01, kota dolmadan durdu)

Aşağıdakini yeni oturuma yapıştır:

---

Mermi Yığını'na devam ediyoruz (geçici proje adı; Godot 4.7, co-op FPS, zombi dalgaları). Önce `CLAUDE.md`, `docs/ayrintilar.md` → "Yeni yön: zombi dalgaları" ve bu dosyayı oku. `git fetch` yap.

**Main'de olanlar:** dummyler, B modu ve Teçhizat gitti; çit bölmeleri (yıkılan bölmeden zombi girer, yeni yürüyüş); oyuncu baygınlığı, izleme, kaldırma (şimdilik tezgâhtan). Birleşik hâlde bütün `tools/*_check.gd` geçiyordu.

**Main'e alınmayı bekleyen dallar** (kullanıcı oyundayken/editör açıkken birleştirme, dosyalar elinin altında değişir; önce sor ya da Godot süreçlerine bak):
1. `origin/claude/cit-atlayan-5990cc`: çitin üstünden atlayan ve altından geçen zombiler, çit ölçüleri tek yerde (`GameState.FENCE`). **Önemli:** main'deki "çitten içeri giren zombi öldürülemiyor" hatasının düzeltmesi de bu dalda. Oturum 38 kontrolün hepsinin geçtiğini söyledi.
2. `origin/claude/hurda-liste-4ee105`: `docs/ayrintilar.md` → "Yeni yön: hurdalık" bölümü. Hurda galerisi: https://claude.ai/artifact/AbZ1qisnc8UYjruHkhUXXJ (134 aday, lisanslar doğrulandı).
3. Hurdalık oturumunun kendi açtığı yan oturumlar: `hurda-dagi` (mermi yığınını fizikli hurda dağıyla değiştirme: yükseklik haritası + yüzeyde hurda + kum yığını gibi çökme), `hurda-hazirla` (`origin/claude/hurda-hazirla-320a3d`), `hurda-tasima` (hurdayı ele alma ve taşıma limiti). Durduruldular, "commit'le, kendi dalına push'la" dendi. Dallarını `git branch -r | grep hurda` ile bul, ne yaptıklarını kontrol et, kontrolleri koş, sonra main'e al.

Birleştirince bütün kontrolleri koş. Ağ kontrolleri (fence, join, net, waves, down) ortak kilitle sırayla: `mkdir /c/Users/vedat/AppData/Local/Temp/godot_net.lock` başarılıysa koş, bitince `rmdir`. Birleştirme worktree'sinde upstream main olmasın; `.claude/scripts/git-sync.sh` Stop hook'u upstream'e push'luyor ve bir keresinde çalışma ağacını eski hâle döndürdü.

**Kullanıcının yeni yön kararları (2026-11-01, kural):**
- Her şey hurdalıktan gelen malzemeden yapılır. Hurda öğütülür; çıkan malzeme istenirse barutta, istenirse kovanda kullanılır. Yeni kovanlar açılıp yeni mermi türleri açılır, daha fazla hurda gerekir.
- Oyuncunun arkasındaki alan tavana kadar hurdayla dolu, arkası görünmüyor, aralarda kutular; dişliler, yaylar, paslı metaller.
- Silahlar post-apokaliptik silahlara dönecek (şimdikiler çok cilalı).
- Çit ileride görsel ve yapısal olarak, level sistemine göre çeşitlenecek.
- Arkada kafa yormayan bir post-apo müziği çalacak (kullanıcı Suno ile üretecek; Instrumental, stil promptları konuşmada verildi; ticari kullanım için Pro/Premier dönemi gerek).
- "Mermi Yığını" yalnız proje adı, tasarımı ada ya da yığına bağlama.

**Fikir aşamasında (kural değil, kullanıcı "sadece fikir" dedi):** tur sonunda roguelike gibi nadirlikli 3 karttan 1 seçimi (sekme +1, ikinci silah yuvası, zırh, kafa hasarı, hız…); boss'ları kesince kalıcı açılımlar (ör. slot makinesi, yeni silah); üretim makineleri seviye atlar. Açık sorular: "koşu" ne zaman sıfırlanır (kartlar kalıcı mı), silah hangi kaynaktan açılır.

**Öğütücü modeli (yarım):** kullanıcı ücretsiz havuzdaki hiçbir adayı beğenmedi. Beğendiği tarz: paslı açık tekne, içinde helezon bıçaklı mil, yanında kayışla bağlı elektrik motoru, önünde kontrol kutusu, demir ayaklar. Kaynağı bulunamadı, o yüzden görsel girdi olarak verilmeyecek; Blender MCP `generate_3d` ile **tarifle** üretilecek (kullanıcı "yap" dedi). Blender açık ama MCP eklentisi bağlı değildi (port dinlemiyordu); kullanıcı nasıl bağlanacağını bilmiyor. Computer-use ile Blender'da N panelindeki MCP sekmesinden "Connect"e basılacak (izin isteği kota yüzünden yarıda kaldı). Her üretim kredi harcayabilir, birkaç denemeyle sınırlı tut.

**Zırhlı/maskeli isabet ipucu (yapılmadı):** zırhlıya metal kıvılcımı (projedeki Kenney kıvılcımları), maskeliye cam çatlağı (TextureCan "Broken Glass Texture with Cracks", 1K/2K, CC0; merkezinden yuvarlak parça kesilip alfa ile decal; ya da kullanıcının bulacağı bir 3DTexel çatlağı).

**Reels:** 8 sürümün yatay (1920x1080) fotoğraf ve klipleri `reels/` altında, liste `reels/liste.md` (git'e girmez). Kurgu ffmpeg ile; kullanıcıdan müzik ve bugünden ham oynanış kaydı bekleniyor. `C:/rv` (1,9 GB) ve `AppData/Roaming/MermiReels` geçici, silinebilir (güvenlik kontrolü silmeye izin vermedi; kullanıcı elle silebilir).

**Kullanıcıdan beklenenler:** ses kayıtları (silah, isabet, siren/kapı/şalter, çit pençe/yıkılma/onarım, kafa patlama, stil sırası, baygınlık: hurt/down/heartbeat/revive), ActionVFX lisans türü, dalga ve baygınlık sayılarının onayı, müzik.

Kurallar: Türkçe konuş; Godot penceresi açma (headless, ekran dışı çekim serbest); kullanıcı oyundayken Godot çalıştırma ve oturumlara da çalıştırtma; Godot'u isimle öldürme (PID ile); commit mesajı Türkçe birinci tekil şahıs, AI imzası yok; ham dosyalar git'e girmez; kullanıcı her görevi ayrı oturumda istiyor, bitenleri main'e sen birleştir; aynı anda birden çok oturum ağ kontrolü koşacaksa kilidi kullansınlar; kota %95'e gelince dur, commit'le, devam promptu ver; çoklu agent ya da uzun iş öncesi maliyeti söyle.
