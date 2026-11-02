# Devam promptu (2026-11-02, hesap değişimi)

Aşağıdakini yeni oturuma yapıştır:

---

Mermi Yığını'na devam ediyoruz (geçici proje adı; Godot 4.7, co-op FPS, zombi dalgaları, yeni yön hurdalık). Önce `CLAUDE.md`, `docs/ayrintilar.md` → "Yeni yön: hurdalık" ve "Hurda dağı" bölümleri ve bu dosyayı oku. `git fetch` yap.

**Durum (2026-11-02 sonu): her şey main'de.** `origin/birlesim` (main + `cit-atlayan` atlayan/alttan geçen zombiler ve içeri giren zombinin öldürülememe düzeltmesi + `hurda-liste` + `hurda-hazirla` 248 parça + `hurda-dagi` + `hurda-dagi-gorunum` + `net-check-2`) main'e alındı, ardından `b8909cf` belgeleri hurdalığa göre yeniden yazdı.
- **İlk iş: main'de bütün `tools/*_check.gd` kontrollerini koş.** Birleşmeden önce `birlesim`'de 4 kontrol düşüyordu, düzelip düzelmedikleri doğrulanmadı: `ambience_check` ("found the lit hall lamps"; hurda dağı salonun batısındaki lambaları silmiş olabilir), `electric_check` ("the crank sounds as the round closes on the spool"), `head_pop_check` ve `table_check` ("Initializing already initialized RID" / "material is null"; büyük ihtimalle `build_arena.gd` `_clear_for_heap()`'in x < 1,5'teki nesneleri silmesi). `zombie_sound_check` ("5 sounds started by one burst") eskiden de düşüyordu. Kırılanı düzelt, push'la.
- **Dışarıda kalan tek commit:** `origin/claude/hurda-dagi-gorunum-5c966f` 2b007aa ("Dağın kendi yüzeyi artık hiçbir yerde görünmüyor, yalnız hurda görünüyor…"). Kontrollerden sonra main'e al.
- `origin/claude/hurda-dagi-2-89247c` main'e girdi; o dalın `scripts/pile.gd`'yi karşılaştırma için kısmen eski hâline almış olabileceği not edilmişti. Kontroller kırılırsa önce `git log -p -- scripts/pile.gd` ile bak.

**Öğütücü (main'de, 07b967c):** `assets/props/ogutucu/ogutucu.glb`. Model benim, Blender'da koddan kuruldu, Cycles'ta dokuya pişirildi. Kaynak `assets/props/ogutucu/raw/ogutucu.blend` ve `raw/ogutucu_pisir.blend`; ham ve pişmiş dokular `doku/`, `doku_pisir/`. Bunlar git'te yok (`.gitignore`, `.gdignore`), yalnız bu bilgisayarda.
- Parçalar: `Pisir_Govde` sabit; `Pisir_RotorA` ve `Pisir_RotorB` ters yönde dönen kesici miller (orijin mil ekseninde, x ekseni etrafında); `Pisir_Toplama` çekilebilen toplama kutusu; `Ayri_IbreBasinc` basınç ibresi (orijin kadran merkezinde; dinlenme 135°, çalışma -30° civarı, çalışırken titreyecek); `Ayri_SayacRakam` LED sayaç (oyunda geri sayıma bağlanacak).
- **Yapılmadı:** salondaki yeri (kullanıcıya sorulacak; `tools/build_arena.gd` üzerinden eklenir), millerin dönmesi, ibrenin titremesi, sayacın çalışması, hurdanın öğütülüp barut/kovan malzemesine dönmesi.
- Kullanıcının öğütücü kararları: tıpa tıp kopya değil kendi tasarımımız; iki ters dönen keskin kesici mil; tabandaki delikten kanalla aşağıdaki toplama kutusuna akış; büyük, güçlü motor; az pas, kendi boyası görünsün, biraz "cozy" (hardal gövde, tuğla kırmızısı motor, krem kontrol kutusu); kontrol kutusunda sol üstte küçük LED sayaç, solda acil stop, sağda analog basınç göstergesi; merdiven, dikme, kaldırma halkası yok.

**Blender MCP:** eklenti `C:\Users\vedat\AppData\Roaming\Blender Foundation\Blender\5.2\scripts\addons\blender_mcp.py`; Blender'da Tercihler → Eklentiler → Diskten Yükle ile kuruldu, port 9876'da kendiliğinden bağlanıyor. AI üretimi (Hyper3D vb.) kapalı, anahtar yok. Arka plan pişirme betiği OPTIX ile saniyeler sürüyor.

**Kullanıcının yeni yön kararları (2026-11-01, kural):**
- Her şey hurdalıktan gelen malzemeden yapılır. Hurda öğütülür, çıkan malzeme istenirse barutta, istenirse kovanda kullanılır. Yeni kovanlar açılıp yeni mermi türleri açılır, daha fazla hurda gerekir.
- Oyuncunun arkasındaki alan tavana kadar hurdayla dolu, arkası görünmüyor, aralarda kutular; dişliler, yaylar, paslı metaller.
- Silahlar post-apokaliptik silahlara dönecek.
- Çit ileride level sistemine göre görsel ve yapısal olarak çeşitlenecek.
- Arkada kafa yormayan bir post-apo müziği çalacak (kullanıcı Suno ile üretecek).
- "Mermi Yığını" yalnız proje adı; tasarımı ada ya da yığına bağlama.

**Kullanıcıdan beklenenler:** öğütücünün salondaki yeri; ses kayıtları (silah, isabet, siren/kapı/şalter, çit, kafa patlama, baygınlık); ActionVFX lisans türü; dalga ve baygınlık sayılarının onayı; müzik.

Kurallar: Türkçe konuş; Godot penceresi açma (headless; ekran dışı çekim serbest: `--position -10000,-10000`); kullanıcı oyundayken Godot çalıştırma; Godot'u isimle öldürme (PID ile); Godot: `C:/Users/vedat/projeler/Godot_v4.7.2-stable_win64.exe`; yeni worktree'de kontrolden önce `--headless --import`; ağ kontrolleri ortak kilitle (`mkdir /c/Users/vedat/AppData/Local/Temp/godot_net.lock` başarılıysa koş, bitince `rmdir`); birleştirme worktree'sinde upstream main olmasın (Stop hook'u upstream'e push'luyor); commit mesajı Türkçe birinci tekil şahıs, AI imzası yok; ham dosyalar git'e girmez; kullanıcı her görevi ayrı oturumda istiyor, bitenleri main'e sen birleştir; kota %95'e gelince dur, commit'le, devam promptu ver; çoklu agent ya da uzun iş öncesi maliyeti söyle.
