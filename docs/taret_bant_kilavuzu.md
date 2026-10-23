# Taret ve bant hattı kılavuzu (2026-10-22)

> **2026-10-23:** Bant döşeme kalktı. Taret konunca yığına kendiliğinden bir hortum uzanır; aşağıdaki hat modeli (akış tek sayı, bir hat = bir taret) aynen geçerli, yalnız ızgara, L çekme ve modifiye karoları yok. Mermi özellikleri `ayrintilar.md` → "Mermi tarifi".

Yol haritası Faz 4'ün (15–16. adımlar) uygulama kılavuzu. Önce "Karar bekleyenler"i kapat, sonra adımları sırayla yap; her adımın sonunda kontrolü çalıştır ve commit'le.

## Ana fikir: bant mermi taşımaz, akış taşır

Mermi mantıkta zaten bir sayı (CLAUDE.md). Bu yüzden Factorio'nun en pahalı kısmı (bant üstündeki her eşyanın konumu, çarpışması, şeritler) bizde **hiç yok**. Bir hat, ağzı yığına dalan ve ucu bir taretin haznesinde biten bir **boru**:

```
akış (mermi/sn) = min(ağzın kazabildiği, bandın taşıyabildiği, haznenin alabildiği)
```

- Host her 0,25 sn'de bir (`TICK`) her hat için bu sayıyı hesaplar, yığından o kadar kazar, haznesine ekler.
- Bant üstünde kayan mermiler **yalnız süs**: hat "akıyor" mu durmuş mu, her makine bunu bilip MultiMesh'i yerelde kaydırır. Ağdan tek bir mermi konumu gitmez.
- Taret haznesinden kendi hızıyla harcar; her tick'te kaç atış yaptığını ve ne kazandırdığını tek bir olayla yayar.

Bu karar demoyu kurtarıyor: finalde saniyede ~50 bin mermi akarken bile sunucu tick başına hat sayısı kadar toplama yapar.

## Araştırmadan çıkanlar

1. **Factorio "yapacak işi azalt" diyor.** 0.12'den beri her eşya yalnız önündekine bakıyor; 0.15'te düz bant dizileri tek parça sayılıp yalnız aralar (gap) güncelleniyor, sıkışık bant hiç dokunulmadan kalıyor ([FFF #148](https://factorio.com/blog/post/fff-148), [FFF #176 tartışması](https://forums.factorio.com/viewtopic.php?p=241640)). Bizde bu en uç noktasına gidiyor: hat başına tek sayı.
2. **shapez.io da aynı yolu seçti:** bant yolları birim olarak tutuluyor, yalnız yolun ucundaki çıkış güncelleniyor ([commit kaydı](https://code.garrettmills.dev/Archives/tobspr_shapez.io/src/commit/c844dd4798c06ca21268b0ca337d65913f8f5795)).
3. **Co-op'ta eşya kopyalamak pahalı.** Satisfactory 2000+ bandı her oyuncuya yayınlamakla uğraştı, bant kaynaklı çökme düzeltmeleri peş peşe geldi; Unreal'ın veri sınırına takılınca bantlar takılıyor ([Satisfactory ağ optimizasyonları](https://www.gamedeveloper.com/programming/satisfactory-network-optimizations), [bant kalitesi notu](https://help.freakhosting.com/games/satisfactory/changing-server-quality-settings-for-belts-satisfactory)). Ders: ağdan eşya değil durum gitsin.
4. **Godot'ta darboğaz çizim değil, `_process` döngüsü.** MultiMesh tek çizim çağrısı ama bütün örnekler birlikte kesilir (culling), o yüzden parçalara bölmek gerekir. 40 bin elemanı her karede gezmek yavaş; sabit hızdaki bantta her kareyi simüle etmek yerine olay planlamak öneriliyor ([Godot MultiMesh belgesi](https://docs.godotengine.org/zh-cn/4.4/tutorials/performance/using_multimesh.html), [forum: bin nesne](https://forum.godotengine.org/t/thousend-objects-performance-problems/12882), [forum: bant bileşeni](https://forum.godotengine.org/t/best-component-to-make-conveyor-belt/132596)). Örnek proje: Factory Core Lite (MIT; 60 tick, headless, aralık modelli bant) ([asset](https://godotengine.org/asset-library/asset/edit/24611)).
5. **Taret besleme dersleri (Factorio forumları):** seri beslemede öndeki taretler sondakileri aç bırakır, geliştirilen taret mermiyi hızla bitirir, döngü bant ortada mermi biriktirir; hattı son tarette bitirmek öneriliyor ([taret tartışması](https://forums.factorio.com/viewtopic.php?p=39579), [mermi bandı](https://forums.factorio.com/viewtopic.php?p=272624)). Bizde: **bir hat = bir taret**, dallanma yok.
6. **İncremental matematik:** fiyat üstel (`taban × büyüme^sahip`), üretim doğrusal × çarpan; çarpanlar üretimi bir süre fiyatın önüne geçirir ([The Math of Idle Games I](https://www.gamedeveloper.com/design/the-math-of-idle-games-part-i), [II](https://www.gamedeveloper.com/game-platforms/the-math-of-idle-games-part-ii)). Taret ve bant kademeleri buna göre: her kademe fiyatta ×1,6–2 (ekonomi ajanının önerisiyle aynı, `ajan_kritik/ekonomi.md`).

## Sistemin parçaları

| Parça | Ne yapar | Nerede |
|---|---|---|
| **Ağız** | Yığının kenarına konur, `DIG_RATE` mermi/sn kazar (`bullets_taken(at, n)` mevcut olay). Yüzey ağzın altında biterse akış 0'a düşer; oyuncu ağzı taşır. 45° kayma yamacı kendiliğinden ağza doldurur (çığ hissi bedava). | Yığın kenarı, r ≈ 7–9 m |
| **Bant** | 1 m ızgara hücreleri, tek yönlü, düz + 90° dönüş. Yerleştirmede başlangıç hücresinden sürükleyerek L şeklinde çekilir. Kapasitesi kademeye bağlı. | Atıcı tarafı, x < 14 |
| **Taret** | Haznesi var. Yalnız sabit hedeflere (kukla, gong, çelik raf) ateş eder. Kombo yok, kafa yok. Hazne elle de doldurulabilir (E). | Korkuluğa yakın, x ≈ 10–13,5 |
| **Komuta** (sonra) | Oyuncunun kombo tavanı taretlerin hızını artırır: `× (1 + 0,15·V)`; co-op'ta en büyük V. Orta oyunda oyuncunun aktif işi. | `ajan_kritik/tasarim.md` |

**Yerleşim (2026-10-22, kullanıcı isteği):** yığın x = 0'dayken boyalı halkası (yarıçap 10,6 m) x = 10,6'da bitiyordu, korkulukla (x = 14) arasında yalnız 3,4 m kalıyordu. Bant için gereken derinlik, korkuluktan geriye doğru:

| Şerit | Derinlik |
|---|---|
| Oyuncu koridoru (korkuluk dibinde atış yeri) | 3 m |
| Taret sırası (2×2 m gövde + hazne) | 2,5 m |
| Bant alanı (2–3 dönüş, 3–4 modifiye karosu, hatlar arası 1 m yürüme) | ~6 m |
| Ağız payı (yığın halkasından içeri uzanır) | ~1 m |
| **Toplam** | **~12,5 m** |

Bu yüzden yığın 9 m batıya taşındı (x = −9, `main.tscn` `Pile` ve `build_arena.gd` `HEAP`). Halka artık x = 1,6'da bitiyor; korkuluğa kadar **12,4 m** var. Korkuluk yerinde kaldı (hedef alanı ve atış alanı süslemesi ona bağlı). Kasa sırası x = −20'den −23'e kaydı (yığının batı halkası −19,6'da). Doğma noktaları, yığın spotları ve lamba boşluğu yığınla birlikte kaydı. Bu ölçüm yığının doğusundaki şerit için; kuzey ve güney yanları (z = ±10,6 … ±27) daha da geniş, uzun hatlar oradan dolaşabilir.

**Durum (`GameState`):**
- `turrets`: her taret için `[konum, yön, seviye, hazne]`
- `lines`: her hat için `[ağız hücresi, hücre listesi, taret no, seviye]`
- Hat oluşturma, silme ve seviye artırma `request_*` komutlarıyla.
- Yeni dünya olayları `EVENTS`'e girer (`_world` ile):
  - `turret_placed` / `line_built` / `line_removed`
  - `line_flow(n, akıyor)`: yalnız değişince gider
  - `turret_burst(n, hedef, atış, altın)`: tick başına bir tane, bütün taretler tek pakette
- Katılana hepsi `_join` snapshot'ında gider.

**Ödeme:** `hit_gold × (1 + altın bonusu) × komuta`, kombo ve kafa yok (ekonomi kuralı: otomasyonda mermi başına ≤ $1). Raycast her atışta değil: taret hedef seçerken bir kez görüş hattına bakar, sonra isabet yüzdesi sabit (ör. %90). Iska süs olarak yere/duvara iz bırakır.

**Ölçek (yer tutucu, denge turunda değişir):** 100M'nin ~60 dakikada bitmesi için son 20 dakikada ortalama ~50 bin mermi/sn gerekiyor.

| Kademe | Bant (mermi/sn) | Taret atış/sn | Not |
|---|---|---|---|
| 1 | 20 | 5 | ilk taret, ~15. dk |
| 2 | 100 | 25 | |
| 3 | 500 | 120 | |
| 4 | 2.500 | 600 | |
| 5 | 12.000 | 3.000 | minigun taret, final |

Yüksek kademede taretin "bir atışı" görsel olarak birden çok mermi demektir. İz/alev saniyede en çok ~15 kez çizilir (`TRACER_CAP`), sayı yine tam akar.

**Görsel ve ses:**
- Bant: gövde mesh'i + hat başına bir MultiMesh (mermiler sabit aralıklı; `offset = (zaman × hız) mod aralık`, durunca donar). Uzun hatlar 16 m'lik parçalara bölünür (culling).
- Görünen mermi sayısı gerçek akıştan bağımsız, sabit yoğunlukta.
- Taret kovanları mevcut kovan havuzundan, saniyede sınırlı.
- Ses: tekil atışlardan taret sayısı arttıkça "fabrika uğultusuna" geçiş (`ayrintilar.md` Ses maddesi). Kayıtlar kullanıcıdan gelir.

**Aset:** gerçekçi PBR, CC0 tercih, < 50 bin üçgen, marka yok. Taret için Sketchfab/Poly Haven'da "sentry turret / mounted gun" (CC0/CC-BY). Bant, ambientCG (CC0) kauçuk ve çelik dokularıyla Blender'da kutulardan yapılabilir. Hazır "conveyor kit"lerin çoğu low-poly; reddedilen tarz.

## Adım listesi

Toplam ~32 saat. Her adım kendi başına oynanabilir bir şey bırakır.

0. **Önkoşul: hile menüsü (yol haritası 11. adım, henüz yok).** Taret dengesi x10 hız ve para eklemeden ölçülemez. ~3 sa.
1. **Karar turu:** aşağıdaki "Karar bekleyenler"i kapat, `ayrintilar.md`'ye yaz. ~15 dk.
2. **Atıcı tarafı yerleştirme alanı:**
   - `PLACE_ZONES`'a korkuluğun berisi eklenir: yığın ayak izi (r > 9 m) ve doğma noktaları hariç.
   - Parça türüne göre hangi alanın geçerli olduğu `GEAR`'da tutulur (hedef = öte taraf, taret/bant = beri taraf).
   - `placement.gd`'ye 1 m ızgara ve sürükleyerek hat çekme eklenir; kuş bakışı kamera aynen kullanılır.
   - Kontrol: `tools/place_shot.gd`. ~3 sa.
3. **Taret (elle hazne):**
   - `GEAR`'a taret eklenir, ortak kasadan alınır.
   - Hazneye E ile eldeki mermi boşaltılır (`request_feed_turret`).
   - Host tick'i yeni dosya `scripts/factory.gd`'de: hedef seçimi, haznenin harcanması, `turret_burst` olayı. Ödeme oyunculara gider (bkz. karar 1). `PlayerState.combo`'ya dokunulmaz.
   - Kontrol: yeni `tools/factory_check.gd`. Taret zinciri büyütmez, hazne bitince durur, ödeme formülü doğru, Texas Star/köstebek/popper'a ateş etmez. ~6 sa.
4. **Bant + ağız:**
   - Hat verisi ve akış formülü yazılır. Kazı mevcut `bullets_taken` olayıyla yapılır; tick başına tek olay, ağzın noktasında.
   - Yüzey biterse akış 0 olur. Anahtarlar ağzın kazdığı yerden mevcut açığa çıkma yoluyla fırlar.
   - Son 1 mermide bant ve taret durur (son mermi töreni).
   - Kontrol: `factory_check`'e eklenir (akış = min(...), yığın tam o kadar azalır, yüzey bitince durur); yığın hash'i `net_check`'teki gibi. ~8 sa.
5. **Görünüm:** bant mesh'i ve kayan mermiler (MultiMesh), taret modeli, namlu dönüşü, iz sınırı, ağzın yığına dalan kepçesi. Görsel kontrol: `place_shot.gd` benzeri bir kare. ~6 sa.
6. **Co-op:**
   - Katılma snapshot'ı (taretler, hatlar, hazneler) eklenir.
   - `join_check` ve `net_check` genişler: istemci hat kurar, host'ta akar, ikisinde de yığın aynı, `turret_burst` altını iki tarafta aynı.
   - ~3 sa.
7. **Kademeler + denge:**
   - Bant ve taret seviyeleri atölyenin Teçhizat sekmesine eklenir; fiyatlar kademe başına ×1,6–2.
   - Hile menüsüyle 1 ve 2 oyuncuda 15–35. dakikalar ölçülür, `ayrintilar.md`'ye yazılır.
   - ~3 sa.
8. **Sonra (Faz 4'ün kalanı, ayrı adımlar):**
   - Komuta çarpanı.
   - Taret geliştirmenin külçeye geçmesi (12. adım bitince).
   - Robot taşıyıcı (yığından şarjöre, oyuncunun yerine yürür).
   - ~~Bant modifiye karoları~~ (2026-10-23: yerine mermi tarifi, `ayrintilar.md` → "Mermi tarifi"; taret takımın tarifiyle kendisi işler).

## Gerekmeyenler

Bunlar fabrika oyunlarında var ama bizde **yazılmayacak**:

- **Bant üstünde tek tek mermi simülasyonu:** konum, çarpışma, aralık, sıkışma. Akış bir sayı.
- **İki şeritli bant, yan yükleme, splitter, birleştirici, öncelik, filtre:** CLAUDE.md kuralı zaten bu. Bir hat = bir ağız + bir taret.
- **Inserter / kol, ara depo kutuları:** bant doğrudan hazneye girer.
- **Elektrik, kablo, güç şebekesi:** kablolama "Yok" listesinde. İleride gerekirse jeneratör yarıçapı yeter.
- **Bantta birden çok eşya türü, tarif zinciri:** bantta yalnız mermi var. Mermi tipi taretin özelliği olur.
- **Yer altı bandı, köprü, rampa, eğimli bant:** düz zemin, 1 m ızgara.
- **Oran hesaplayıcı, akış grafiği, fabrika istatistik ekranı:** taretin üstünde "hazne N / akış N/sn" yazısı yeter.
- **Lojistik robot ağı, yol bulma:** robot taşıyıcı sabit iki nokta arasında gider.
- **Deterministik lockstep, eşya replikasyonu:** host otoriter, yalnız olaylar.
- **Blueprint / kopyala-yapıştır, toplu yıkım:** X basılı tut zaten var. Demo süresinde ~10–20 hat kurulur, gerek yok.
- **Taret dönüşü için fizik, mermi başına raycast:** hedef başına bir görüş kontrolü.

## Karar bekleyenler

1. ~~**Taret geliri kime?**~~ **Karar (kullanıcı, 2026-10-22):** taret, bant ve robot geliri takımın ortak havuzu: bağlı oyunculara eşit bölünür, elle atıştaki gibi isabetin %20'si (`VAULT_SHARE`) üstüne ortak kasaya gider. Oranlar denge testinde değişecek.
2. **Külçe yokken taret neyle gelişir?** Öneri: şimdilik ortak kasa ($); 12. adım (kovan → fırın → külçe) gelince fiyatın para birimi değişir.
3. **Faz sırası:** yol haritasında Faz 3 (kovan, kasalar, mermi tipi) Faz 4'ten önce. Taretlere şimdi geçmek 12–14. adımları sona itiyor. Öneri: tamam, ama 0. adım (hile menüsü) önce.
4. **Ağız nasıl konur?** Öneri: bandın ilk hücresi yığın ayak izine değerse orası ağız olur, ayrı parça yok.
5. **Taret menzili ve hedef seçimi:** öneri en yakın sabit hedef, oyuncu değiştiremez. Alternatif: yerleştirmede hedef seçtirmek (oyuncuya iş, ama UI işi).
