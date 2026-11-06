# Devam promptu (2026-11-02, açık alana geçiş)

Yan hesapta yeni bir oturum aç ve "Ana prompt" bölümünü olduğu gibi yapıştır. O oturum koordinatör olur: aşağıdaki oturumları açar, biten dalları main'e birleştirir.

---

## Ana prompt

Mermi Yığını'na devam ediyoruz (geçici proje adı; Godot 4.7, 4 kişilik co-op FPS). Oyunun yönü kökten değişti: **açık alanda gece-gündüz hayatta kalma**. Önce `git pull` yap. Sonra `CLAUDE.md`'yi, `docs/ayrintilar.md` → "Yeni yön: açık alan" bölümünü ve bu dosyanın tamamını oku.

**Senin işin koordinatörlük.** Kodu kendin yazmayacaksın; aşağıdaki oturumları açıp yöneteceksin.
1. Kullanıcıya "Açık sorular"ı (ayrintilar.md'de) tek mesajda, kısa sor. Cevap gelmeden de başla: cevabı gerektirmeyen oturumlar beklemesin.
2. "Oturumlar" bölümündeki 1, 2 ve 3 numaralı oturumları hemen, aynı anda aç. Her biri kendi worktree'sinde çalışsın, brief'i olduğu gibi kullan. 4 ve 5'i, "Ne zaman" satırlarında yazan koşul gerçekleşince aç.
3. Oturumlardan biri bitince: dalını oku, kontrollerini koş, main'e birleştir, push'la. Birleştirme worktree'sinde upstream main olmasın (Stop hook upstream'e push'luyor). Çakışmada iki tarafı da koru.
4. Her birleştirmeden sonra `docs/ayrintilar.md`'nin güncel olduğuna bak. Kullanıcının yeni kararlarını "Yeni yön: açık alan" bölümüne kural olarak yaz; kendi tercihlerini kural diye yazma.
5. Kota %95'e gelince dur, commit'le, bu dosyayı güncel durumla yeniden yaz.

**Durum (2026-11-02 sonu):**
- main `0246272`: oyunda hâlâ eski salon ve içinde 20 × 20 m, 50 m derin hurda çukuru var (kenarında korkuluk, sac zemin, merdiven). Bunların hepsi gidecek.
- `scripts/pile.gd` en değerli parça: yükseklik alanı, yüzde gerçek parçalar, altında gömülü parçalar, alınınca altının açılması, üstünün fizikle düşmesi, çökme, co-op senkronu. Dağ için yeniden kullanılacak.
- Ana klasörde (`C:\Users\vedat\projeler\mermi-yigini`) "Silah ve hurda toplama animasyonu" oturumunun commit'lenmemiş değişiklikleri olabilir. Önce `git status`'a bak. Dokunmadan önce o değişikliklerin main'e girip girmediğini kontrol et.
- `claude/hurda-pirinc-c70989` dalı yalnız bu bilgisayarda, push'lanmadı. İçinde 60 pirinç tesisat hurdası (`vana` türü, patina) var. Yarım: `hurda_check` koşulmadı, `.import` ve aset listesi eksik. 1 numaralı oturum bitirecek.
- `claude/cukur-aset-64123f` dalının commit'ine başka dosyalar da karışmış (hud, player, pile, game_state...). O daldan yalnız `assets/props/cukur/`, `tools/cukur/` ve `tools/cukur_check.gd` main'de; dalın geri kalanını birleştirme.

**Kurallar:** Türkçe konuş. Godot penceresi açma; kontroller headless, görsel kontrol için ekran dışı çekim serbest (`--position -10000,-10000`). Kullanıcı oyundayken Godot çalıştırma. Godot'u isimle öldürme, PID kullan. Godot: `C:/Users/vedat/projeler/Godot_v4.7.2-stable_win64.exe`. Yeni worktree'de kontrolden önce `--headless --import`. Ağ kontrollerini ortak kilitle koş: `mkdir /c/Users/vedat/AppData/Local/Temp/godot_net.lock` başarılıysa koş, bitince `rmdir`. Commit mesajları Türkçe, birinci tekil şahıs, samimi; AI imza satırı yok. Ham dosyalar (blend, zip, indirilen kaynak) git'e girmez. Kullanıcı her işi ayrı oturumda istiyor, bitenleri sen birleştirirsin. Çoklu agent ya da uzun iş öncesi maliyeti söyle. Hurda dağının kendi yüzeyi hiçbir zaman görünmez (kullanıcı bunu 20 kez söyledi).

---

## Oturumlar

Her oturum kendi worktree'sinde ve dalında çalışır, bitince dalını push'lar ve koordinatöre ne yaptığını yazar. Dosya sahipliği aşağıda; bir oturum başkasının dosyasına dokunacaksa küçük ve ayrı bir blokla dokunur, nedenini commit'te yazar. `scripts/game_state.gd`'yi birden çok oturum değiştirecek: herkes kendi sinyalini ve alanını ayrı bir blokta, kendi adıyla bir yorum altında eklesin.

| Oturum | Sahibi olduğu dosyalar |
|---|---|
| 1 aset-arastirma | `assets/` altında yeni klasörler, `docs/aset_adaylari_acik_alan.md`, `tools/assets_*` |
| 2 gece-gunduz | `scripts/day_night.gd` (yeni), gökyüzü ve ışık malzemeleri, `GameState`'te gün/evre bloğu, HUD'da saat |
| 3 mekan-dag | `tools/build_world.gd` (yeni) → `scenes/world.tscn`, `scenes/main.tscn`, `scripts/pile.gd`, `tools/build_scrap_face.gd`, `data/scrap_face.json` |
| 4 gece-dalgalari | `scripts/waves.gd`, zombi/yaratık betikleri, `tools/waves_check.gd` |
| 5 uretim | `scripts/crafting.gd`, `scripts/turret.gd` (yeni), masa ve üretim menüsü, tezgâh/geliştirme menüsü |

### 1. Aset araştırması (aset-arastirma) — hemen

> Mermi Yığını açık alana geçiyor. Önce `CLAUDE.md`'yi, `docs/ayrintilar.md` → "Yeni yön: açık alan" ve "Kullanılan asetler" bölümlerini oku. Görevin, yeni oyun için gereken asetleri **en ayrıntılı şekilde** araştırmak, aday listesini çıkarmak ve en iyileri indirip Godot'ya hazırlamak.
>
> Oyun: post-apokaliptik açık arazi. Oyuncuların üssünün arkasında ucu bucağı görünmeyen, sivri tepeli, dağ gibi bir çöplük var. Gündüz hurda toplanıp sökülüyor; otomasyon, taret ve silah üretiliyor. Gece zombiler, yaratıklar, canavarlar geliyor, her gece daha zor. Görünüm gerçekçi PBR; paslı, hafif karikatürize asetler de olur.
>
> Aranacak gruplar, her birinde birkaç seçenek:
> 1. **Arazi:** kuru toprak, çakıl, çatlak asfalt, çamur, kül zemin dokuları (CC0, tekrarı gizlenebilir); kayalar, ölü ağaçlar, kuru çalı, ufukta yıkık binalar ve direkler. Gökyüzü HDRI'ları: gündüz, gün batımı, gece.
> 2. **Çöp dağı:** dağın uzak ve büyük kısmı için büyük hurda (araba enkazı, beyaz eşya, varil, lastik yığını, konteyner, hurda sac yığını, kırık mobilya). Yakın kısım için el boyu hurda zaten var (`assets/props/hurda/`). Uzaktan bakınca dağ gibi okunacak yığın modelleri ya da dokuları.
> 3. **Üs:** çalışma masası, sökme tezgâhı, öğütücü/pres gibi makineler, jeneratör, projektör, kum torbası, barikat, hurdadan duvar ve kapı, depo kasaları.
> 4. **Otomasyon ve savunma:** konveyör bant parçaları, makine gövdeleri, kablolar, hurdadan taretler (sabit, dönen, alev, elektrik), tuzaklar (diken, tel).
> 5. **Düşmanlar:** zombi çeşitleri; yaratık ve canavarlar (büyük, sürünen, uçan, zırhlı). Rig'li ve animasyonlu olanlar öncelikli; animasyon lisansını ayrıca kontrol et.
> 6. **Silahlar:** post-apokaliptik, hurdadan yapılmış silahlar (mevcutlar: `docs/silah_adaylari.jpg`).
>
> Kurallar: CC0 tercih (Poly Haven, ambientCG, Kenney, Quaternius, Sketchfab CC0). CC-BY 4.0 olur, yazarı listeye yaz. NC, ND, "personal use only", Unreal/Lyra kaynaklı ve Mixamo gibi yeniden dağıtımı yasaklı olanlar alınmaz. Gerçek marka ve logo yok. Sketchfab sık sık 429 veriyor: istekleri yavaşlat, bekleyip tekrar dene. Kullanıcı indirme izni verdi, ayrıca sorma.
>
> Çıktılar:
> - Her aday için kaynak, yazar, lisans, üçgen sayısı, rig/animasyon var mı ve neden uygun olduğunu içeren bir galeri (Artifact) ve `docs/aset_adaylari_acik_alan.md`.
> - Her gruptan en iyi 3-5 aday indirilip `assets/<grup>/` altına işlenmiş olarak: metre ölçeği, orijin tabanda, basit çarpışma, ağır modeller sadeleştirilmiş. Setleri parça parça böl (kullanıcı kuralı).
> - `docs/ayrintilar.md` → "Kullanılan asetler"e her indirilen.
> - Ayrıca `claude/hurda-pirinc-c70989` dalındaki yarım işi bitir: 60 pirinç tesisat hurdası, `.import`'lar, `tools/hurda_check.gd`, aset listesi.
>
> Asetleri sahnelere yerleştirme; bunu başka oturumlar yapacak. Godot: `C:/Users/vedat/projeler/Godot_v4.7.2-stable_win64.exe`, yeni worktree'de önce `--headless --import`, pencere açma. Türkçe, birinci tekil şahıs, samimi commit mesajları; AI imzası yok. Dalını push'la.

### 2. Gece-gündüz döngüsü (gece-gunduz) — hemen

> Mermi Yığını açık alana geçiyor. Önce `CLAUDE.md`'yi, `docs/ayrintilar.md` → "Yeni yön: açık alan" bölümünü ve co-op kurallarını oku (`GameState`, `scripts/net.gd`, `tools/net_check.gd`). Görevin gece-gündüz döngüsü.
>
> Kullanıcının kararı: "Gece gündüz döngüsü olacak. Gündüz vakti materyalleri alıp söküp otomasyon, taret, silah craftlayacağız. Gece olunca zombiler, yaratıklar, canavarlar gelecek; her gece bir önceki geceden zor."
>
> Yapılacaklar:
> 1. `scripts/day_night.gd`: saat ve evreler (gündüz, akşam/uyarı, gece, şafak), gün sayacı. Host otoriter: saat host'ta ilerler, istemcilere `GameState` olayıyla gider (`_world`, `EVENTS`); geç katılan doğru saati alır. Süreler ayarlanabilir sabitler olsun. Kullanıcıya önerin: gündüz ~8 dk, gece ~4 dk; onaylanana kadar varsayılan bu.
> 2. Işık ve gökyüzü: güneş ve ay (DirectionalLight3D, açı ve renk saatle döner), gökyüzü (ProceduralSky ya da HDRI geçişi), ortam ışığı, sis, gece yıldızlar. Gece karanlık ama oynanabilir olmalı; üs ışıkları anlam kazanmalı. Performans: gölge ayarları, gece pahalı efekt yok.
> 3. Oyun bağlantısı: `GameState`'e `phase_changed(phase, day)` gibi bir dünya sinyali ekle. Dalgaları sen başlatma, sinyal yeter (4 numaralı oturum `waves.gd`'de dinleyecek). Bugün dalgayı başlatan şalter mantığını kaldırmak 4. oturumun işi.
> 4. HUD: köşede küçük saat/evre ve gün numarası; gece yaklaşınca uyarı. Kullanıcının UI kuralları: gereksiz yazı yok, tuş harfleri büyük, düz kutu yerine gerçek aset görünümü.
> 5. Test kısayolu: saati hızlandırma ya da atlama (debug, yalnız host).
> 6. `tools/day_night_check.gd`: evreler sırayla geçer, istemci host'un saatini izler, geç katılan doğru evreyi alır, sinyal her evrede bir kez çıkar. Ağ kontrolünü ortak kilitle koş.
>
> Sahne: açık alan sahnesini 3 numaralı oturum kuruyor (`scenes/world.tscn`). O sahneye dokunma; güneşi, ayı ve WorldEnvironment'ı `day_night.gd` kendisi kursun ya da bulduğunu yönetsin. Şimdilik eski `arena.tscn` üstünde dene; sahne gelince birleşir. Godot: `C:/Users/vedat/projeler/Godot_v4.7.2-stable_win64.exe`, yeni worktree'de önce `--headless --import`, pencere açma; görsel kontrol için ekran dışı çekim serbest. Türkçe, birinci tekil şahıs, samimi commit mesajları; AI imzası yok. Dalını push'la; sonunda evrelerin saatlerini, sinyalleri ve ekran görüntülerini (gündüz, akşam, gece) yaz.

### 3. Mekân ve çöp dağı (mekan-dag) — hemen

> Mermi Yığını açık alana geçiyor. Önce `CLAUDE.md`'yi, `docs/ayrintilar.md` → "Yeni yön: açık alan", "Hurda çukuru", "Gerçek yığın: alttan alınca üstü düşer" ve "Çamur hiç çizilmez" bölümlerini oku. Görevin oyunun yeni mekânı ve çöp dağı.
>
> Kullanıcının kararları: "Bugüne kadar kurduğumuz tüm yapılar gidecek. Oyun açık alanda geçecek. Bizim bir çöplüğümüz olacak. Çöplüğümüz dağ şeklinde olacak. Ucu bucağı olmayan bir çöp olacak. Oradan aldıklarımızı işleyeceğiz." Çizimi: geniş, oval açık bir arazi. Önde dikdörtgen bir üs alanı, sol üst köşesinde bir masa. Üssün hemen arkasında onu yarım halka gibi saran, sivri tepeli, çok büyük bir çöp dağı. Dağın iki yanından arazi geriye uzanıyor. Önceki kurallar: dağın kendi yüzeyi ("çamur") hiçbir zaman görünmez, yalnız hurda görünür; hurda gerçekçi yığılır, alttan alınca üstü hareketlenir.
>
> Yapılacaklar:
> 1. Eski yapıları kaldır: salon, duvarlar, çatı, korkuluk ve atış alanı, bölme, hurda çukuru ve kenarı (`tools/build_arena.gd` ve `scenes/arena.tscn`). Yerine yeni bir kurucu betik `tools/build_world.gd` → `scenes/world.tscn`. Bu sahne elle düzenlenmez. `scenes/main.tscn`'de Arena'nın yerine World gelsin. Eski kurucudan işe yarayanı (malzemeler, dekaller) al.
> 2. Açık arazi: büyük bir zemin (terrain ya da birkaç katman mesh), toprak/çakıl dokuları, tekrarı gizleyen karışım, ufka giden sis, ufukta siluetler. Oyuncunun sınırı doğal görünsün (dağ, enkaz, sis), görünmez duvar hissi olmasın. Navigasyon: düşmanlar araziden üsse yürüyebilmeli (`waves.gd`'nin navmesh kurulumu, `geometry_collision_mask`).
> 3. Üs alanı: çizimdeki dikdörtgen. Zemini, masa yeri (üretim masası 5 numaralı oturumun; sen yalnız yerini ve boş bir yer tutucuyu koy), oyuncu doğma noktaları (`SPAWNS`, co-op için 4 kişi).
> 4. Çöp dağı: `scripts/pile.gd`'yi çukurdan dağa çevir (`_build_heights`, `PIT_*` sabitleri, `top_point`, `pit_rect`). Yakın kısım bugünkü yöntemle: yüzde gerçek parçalar, altında gömülü parçalar, alınınca altı açılır, üstü fizikle düşer, çökme. "Ucu bucağı olmayan" uzak kısım için oynanmayan ama inandırıcı bir arka plan kur: büyük hurda modelleri, impostor ya da sadeleştirilmiş yığın mesh'leri, sis. Oyuncu dağın oynanabilir kısmından çıkamasın, uzak kısım da çıplak yüzey göstermesin. Dağ çok büyük olacağı için performansı baştan planla: bölgelere bölünmüş MultiMesh, uzakta sadeleştirilmiş kopya ya da hiç çizmeme, görünürlük mesafesi. Ölç (`tools/perf_probe.gd`) ve sonucu yaz.
> 5. `tools/build_scrap_face.gd` ile yüzü yeniden dök (`data/scrap_face.json`).
> 6. Bozulan kontrolleri yeni mekâna uyarla (`scrap_check`, `table_check`, `keys_check`, `ambience_check`, `fence_check` ve korkuluğa bağlı olanlar). Korkuluk ve bölmeye bağlı mantık (`fence.gd`, `FENCE_LAYER`, `FIRING_LINE_X`) gidiyor; kaldırırken 4 numaralı oturumla çakışmamak için yalnız sahne ve çarpışma tarafını kaldır, `waves.gd`'deki kullanımı 4. oturuma bırak ve koordinatöre yaz.
>
> Asetler: 1 numaralı oturum arıyor. Şimdilik eldekileri kullan (`assets/env/`, `assets/props/hurda/`, `assets/props/cukur/`), yerlerini sonra değiştirilebilir bırak. Godot: `C:/Users/vedat/projeler/Godot_v4.7.2-stable_win64.exe`, yeni worktree'de önce `--headless --import`, pencere açma; ekran dışı çekim serbest (`tools/shot.gd`'ye yeni açılar ekle). Türkçe, birinci tekil şahıs, samimi commit mesajları; AI imzası yok. Ara aşamalarda da commit'le ve push'la; sonunda çekimleri ve perf sayılarını yaz.

### 4. Gece dalgaları ve zorluk (gece-dalgalari) — 2 numaralı oturum `phase_changed` sinyalini main'e koyunca

> Mermi Yığını açık alana geçti. Önce `CLAUDE.md`'yi, `docs/ayrintilar.md` → "Yeni yön: açık alan" ve "Yeni yön: zombi dalgaları" bölümlerini, ardından `scripts/waves.gd` ile zombi rollerini oku. Görevin dalgaları gece döngüsüne bağlamak ve her geceyi bir öncekinden zor yapmak.
>
> Kullanıcının kararı: "Gece olunca zombiler, yaratıklar, canavarlar gelecek. Her gecede bir önceki geceden zor."
>
> Yapılacaklar:
> 1. Dalgayı şalter değil gece başlatsın (`GameState.phase_changed`). Gün doğunca kalanlar ne olur, öner ve uygula (dağılır, kaçar ya da ölür). Şalter mantığını ve korkuluk/bölme bağımlılıklarını (`FIRING_LINE_X`, `fence_bays`, `cross_of`) temizle.
> 2. Açık alanda doğma: düşmanlar arazinin kenarlarından ve dağın arkasından gelsin (3 numaralı oturumun haritasındaki işaretleri kullan; harita yoksa geçici noktalar). Hedefleri: oyuncular, üsteki yapılar ve taretler (5. oturum taretleri getirdiğinde onlara da saldırsınlar; bir "hedef alınabilir yapı" grubu ya da arayüzü tanımla).
> 3. Zorluk eğrisi: gece numarasına göre sayı, çeşit, can, hız, aynı anda kaç düşman, özel düşman oranı. Veriyle sürülsün (tek tablo ya da fonksiyon); ilk 5 gecenin sayılarını kullanıcıya özet olarak öner.
> 4. Yeni düşman rolleri: "yaratıklar, canavarlar". Mevcut zombi rolleriyle başla, 1. oturumun bulduğu modeller geldikçe büyük/zırhlı/hızlı/uzaktan saldıran roller ekle. Her rolün açıkça farklı bir davranışı olsun.
> 5. Kaybetme koşulu: kullanıcıya soruldu. Cevap gelene kadar bugünkü "herkes baygın" kuralı kalsın.
> 6. `tools/waves_check.gd` ve zombi kontrollerini güncelle; ağ kontrollerini ortak kilitle koş.
>
> Godot: `C:/Users/vedat/projeler/Godot_v4.7.2-stable_win64.exe`, yeni worktree'de önce `--headless --import`, pencere açma. Türkçe, birinci tekil şahıs, samimi commit mesajları; AI imzası yok. Dalını push'la.

### 5. Sökme, üretim, otomasyon ve taretler (uretim) — 3 numaralı oturum üs alanını main'e koyunca (tasarım kısmına hemen başlanabilir)

> Mermi Yığını açık alana geçti. Önce `CLAUDE.md`'yi, `docs/ayrintilar.md` → "Yeni yön: açık alan", "Yeni yön: hurdalık" (hurda → materyal eşlemesi), "Tezgâhta silah geliştirme" ve "Atölye" bölümlerini oku. Görevin gündüzün oynanışı: hurdayı söküp işlemek ve onunla üretmek.
>
> Kullanıcının kararları: "Oradan aldıklarımızı işleyeceğiz. Gündüz vakti materyalleri alıp söküp otomasyon, taret, silah vesaire craftlayacağız." Çizimde üs alanının köşesinde bir masa var. Her şey hurdadan gelir; hurdanın materyali `hurda.json`'daki `materyal` alanında (çelik, pirinç, bakır, alüminyum...).
>
> Yapılacaklar:
> 1. Önce kısa bir tasarım yaz (`docs/ayrintilar.md`'ye yeni bölüm): sökme (hurda → materyaller), üretim tarifleri, otomasyonun kapsamı (bant, öğütücü, pres, jeneratör/enerji), taret türleri, silah üretimi ve geliştirme. Kullanıcıya en fazla 3 soru sor; cevap beklerken cevaptan bağımsız kısımlara başla. Kendi seçimlerini kural diye yazma.
> 2. Çekirdek döngüyü uçtan uca yap: hurda topla → masada sök → materyal deposu → tarifle üret → yerleştir. Co-op kuralları: her eylem `request_*`, host otoriter, durum `GameState`'te.
> 3. İlk taret: hurdadan yapılır, yerleştirilir, gece düşmanlara ateş eder, mermisi ya da enerjisi biter, onarılır. Düşman hedefleme 4. oturumla ortak: "hedef alınabilir yapı" arayüzünü onunla aynı tutun.
> 4. İlk otomasyon: örneğin öğütücüye hurda taşıyan bant ya da kendi kendine çalışan sökme makinesi (`assets/props/ogutucu/` hazır; milleri, ibresi ve sayacı daha çalışmıyor).
> 5. Yerleştirme: ızgaraya oturan, önizlemeli, döndürülebilir, üs alanı sınırında; çarpışma ve navigasyonu güncelleyen.
> 6. Her parça için headless kontrol (`tools/crafting_check.gd`, `tools/turret_check.gd`), ağ kontrolleri ortak kilitle.
>
> Asetler: 1 numaralı oturumun bulduklarını kullan; yoksa basit yer tutucu. Kullanıcının UI kuralları: gereksiz yazı yok, tuş harfleri büyük, düz kutu yerine plakalar ve render simgeler. Godot: `C:/Users/vedat/projeler/Godot_v4.7.2-stable_win64.exe`, yeni worktree'de önce `--headless --import`, pencere açma. Türkçe, birinci tekil şahıs, samimi commit mesajları; AI imzası yok. Dalını push'la.

---

## Sonra (koordinatörün takip listesi)

- Müzik: kafa yormayan post-apo; kullanıcı Suno ile üretecek, gelince gece ve gündüz için ayrı.
- Ses kayıtları kullanıcıdan: silah, isabet, gece başlangıcı, taret, makine, düşman.
- ActionVFX lisans türü (kan efektleri; "Startup" gerekebilir) kullanıcıya hatırlatılacak.
- Merdivene tırmanma ve dağa tırmanma (mekân netleşince).
- Demo hedefi: ~1 saat. Kaç gecenin bir demoya sığacağı zorluk eğrisiyle birlikte kararlaştırılacak.
