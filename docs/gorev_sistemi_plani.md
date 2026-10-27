# Görev sistemi: uygulama planı (2026-10-27)

Tasarım: `docs/ayrintilar.md` → "Görev ağacı ve görev tahtası". Bu belge yeni bir oturumda sırayla yapılacak işlerin listesi. Sayılar yer tutucu; bot testi (adım 4) bulur.

## Demo / tam sürüm ayrımı (öneri, kullanıcı onayı bekliyor)

Demo ~1 saat, tam oyun 4-5 saat. Demoya hızlanma eğrisinin ilk yarısı girer, tam sürüme yeni fiiller kalır.

| | Demo (~60 dk) | Tam sürüme kalan |
|---|---|---|
| Taşıma | El → kova → kürek → el arabası | Maden vagonu, forklift, tavan vinci, emme pompası |
| Üretim | Tezgâh geliştirmeleri (animasyonlu), el presi → elektrikli pres | Döner tabla, şerit doldurucu, tam otomatik hat |
| Eritme | Eritme hunisi (hız ve verim ayarı) | Kovan ayıklayıcı, döküm kalıbı, külçe ekonomisi |
| Mermiler | Klon, Obur, Sekme, Yankı (+ ustalık perkleri) | Delici, Parça tesirli, Yakıcı, Yıldırım, Yer çekimi, Dondurucu, Bağ, oyuklu uç, demet, gecikmeli tapa… |
| Silahlar | Deagle, UZI, Scorpion, çift tabanca (parçalı blueprint) | Altıpatlar, kaldıraçlı, keskin nişancı, ağır makineli, mermi havanı, minigun |
| Otomasyon | Süpürge robotu (demonun son açılışı, tadımlık) | Dronlar, robot kol, örümcek kazıcı, dedektör robotu, çırak robot, otomatik tezgâh |
| Diğer | Slot makinesi, görev tahtası | Yeni alanlar (kapılar), yük asansörü, kozmetikler |

Demonun son 10 dakikası tam sürümden bir şeyi gösterir ama vermez (ör. drone blueprint'inin ilk parçası panoda yarım asılı).

## Adımlar

Her adım ayrı commit. Sonunda ilgili `tools/*_check.gd` çalışır.

1. **Görev verisi ve durumu** (~2-3 sa)
   - `GameState`'e `QUESTS` tablosu: `id`, `tier` (ana/kolay/orta/zor), `kind` (gold_earned, bullets_melted, bullets_carried, hits_with, key_found, crafted, …), `target`, `reward`, `unlock`.
   - Takım durumu: tahtadaki 5 slot, her görevin ilerlemesi, açılmış mekanikler. Host sayar, istemci `_state` ile aynalar; görev bitişi `EVENTS`'e yeni dünya olayı (`quest_done`).
   - Havuzdan çekme host'ta (rastgelelik yalnız host'ta).
   - Kontrol: `tools/quest_check.gd` (ilerleme, slot dolumu, co-op'ta aynalanma) + `net_check.gd`'ye olay.
2. **İlerleme kancaları** (~1-2 sa): var olan yerlerden sayaç beslemesi: `request_fire` (isabet, silah, mermi türü), `request_pick_up` (taşınan), gold ödemesi, anahtar alma. Eritme ve üretim gelince onlar da.
3. **Görev havuzu** (~2 sa, tasarım): demo için ~35-45 görev; ana zincir ~15, kolay/orta/zor havuzları. Her görev "aç → kullandır → ödüllendir" kalıbına uyar; çoğu hedef mermi cinsinden. Tablo bu belgeye eklenir, kullanıcı onaylar.
4. **Bot testi: görev süreleri** (~3-4 sa)
   - `tools/quest_sim.gd` (headless): 1, 2, 3, 4 oyuncu × 3 beceri profili (kötü/orta/iyi: isabet oranı, kafa oranı, taşıma temposu, geliştirme seçimi).
   - Çıktı: her görevin bitiş dakikası, açılışların dakikası, saniyede eritilen mermi eğrisi, ilk 60 dakikada yığından giden toplam.
   - Hedefler: demonun ana zinciri tek kişi orta beceride ~55-65 dk; 4 kişi en az ~35 dk; açılışların arası hiçbir yerde 6-7 dk'yı geçmesin.
   - Sonuçtan oyuncu sayısı ölçeği bulunur (ör. hedef × (1 + k·(n−1))).
5. **Görev tahtası arayüzü** (~3-4 sa): soruşturma panosunda 5 görev kartı (yakına gelince okunur), biten kartın üstü çizilir ve yenisi iğnelenir; HUD'da odaklanılan görevin tek satırı ve ilerlemesi; bitişte bildirim. Parçalı blueprint panoda yarım görünür.
6. **Tezgâh = geliştirme ağacı** (~4-6 sa): 1. görev tezgâhı açar; kişisel geliştirmeler Q'dan tezgâha taşınır; Q yalnız takım teçhizatı. Animasyonlar: silah masaya kayar, şarjör/dipçik/nişangâh takılır (sesler kullanıcıdan).
7. **Blueprint parçaları ve ustalık perkleri** (~2-3 sa): parça sayacı, tamamlanınca açılış; perkler mermi ustalık görevlerinden.
8. **Taşıma aletleri** (~4-6 sa): kova, kürek, el arabası (görsel taşıma, kapasite kademeleri). Modeller asetten.
9. **Eritme hunisi mekaniği** (~4-6 sa): huniye boşaltılan mermi saniyede N erir; hız ve verim tezgâhtan geliştirilir. "Eritilen" sayacı HUD'a (yığında kalan yerine ya da yanına).
10. **Slot makinesi** (~3-4 sa, model kullanıcıdan): parayla, artan fiyat, sınırlı havuz, merhamet sayacı; zar host'ta.
11. **Süpürge robotu** (~3 sa): demonun son açılışı.
12. **Kasaların kaldırılması**: anahtarların yeni rolü ve kasa sırasının yeri kullanıcı kararına bağlı (bkz. ayrintilar.md "Anahtarlar ve kasa sırası"). `GUNS`'taki `"crate"` alanları görev/blueprint kilidine döner.
13. **Denge turu**: bot testini tekrar çalıştır, F9 paneliyle elle dene, `yol_haritasi.md`'yi güncelle.

Toplam kaba tahmin: ~40-55 saatlik iş; 1-4 temel (oynanabilir iskelet, ~10 sa), 5-10 içerik, 11-13 cila.

## Görev havuzu taslağı (adım 3, kullanıcı onayı bekliyor)

Kodda `GameState.QUESTS`; bu tablo ondan üretildi, sıra aynı. 41 görev: 15 ana, 10 kolay, 10 orta, 6 zor. Hedefler 1 kişilik; takımda `quest_target` büyütür (oran adım 4'te). Kolay ödül para, orta ödül blueprint parçası, zor ödül ustalık perki. Ana zincir sırayla gelir; öteki slotlar kendi havuzunun en kolay iki görevinden birini rastgele çeker, `Gerekir` açılmadan o görev çekilmez.

Açılışların anlamı (taslak, mekaniklerin çoğu henüz yok):

- `workbench` tezgâh, kişisel geliştirmeler buraya taşınır (adım 6). `blueprints` tarif panosu, ilk tarif klon. `hand_press` ve `electric_press` daha pahalı tarifleri açar.
- Taşıma: `bucket` 50, `shovel` 200, `wheelbarrow` 1.000 mermi.
- Silahlar: `uzi` ve `scorpion` ana zincirden; çift tabanca 3 orta görevin parçasından.
- Eritme: `melter` açar, `melter_speed` hızlandırır, `melter_yield` mermi başına parayı artırır. Taslakta 7. görevde (8. açılış); yeri hâlâ açık soru.
- Parçalı tarifler: Obur 2, Sekme 2, Yankı 3 parça. Perkler (`clone_count` vb.) tarif ustalıkları.
- `slot_machine`; `sweeper` demonun son mekaniği; `drone_teaser` son görev, tam sürümün dron blueprint'i panoda yarım asılı.
- Anahtar görevleri (z01, z05) yalnız öneri; anahtarların rolü kullanıcı kararını bekliyor.

`crafted` ve `bullets_melted` türlerinin kancası tezgâh ve huni yapılınca eklenecek; o zamana kadar bu görevler oyunda ilerlemez, yalnız bot testinde ilerler.

<!-- havuz tablosu: QUESTS'ten üretilir -->
| id | Kademe | Ad | Hedef türü | Hedef (1 kişi) | Gerekir | Açar | Ödül |
|---|---|---|---|---|---|---|---|
| m01 | Ana | İlk kazanç | $ kazan | 6 | – | workbench | – |
| m02 | Ana | Avuç avuç | yığından mermi taşı | 19 | – | bucket | – |
| m03 | Ana | Kova dolusu | mermi ateşle | 130 | – | uzi | – |
| m04 | Ana | Seri atış | mermi ateşle (uzi) | 420 | – | blueprints | – |
| m05 | Ana | İlk tarif | mermi ateşle (clone) | 520 | – | hand_press | – |
| m06 | Ana | Pres başında | tarife mermi işle | 650 | – | shovel | – |
| m07 | Ana | Kürek kürek | yığından mermi taşı | 1.500 | – | melter | – |
| m08 | Ana | İlk erime | mermi erit | 730 | – | slot_machine | – |
| m09 | Ana | Kumarbaz | $ kazan | 20.000 | – | scorpion | – |
| m10 | Ana | Kompakt | mermi ateşle (scorpion) | 1.000 | – | electric_press | – |
| m11 | Ana | Seri üretim | tarife mermi işle | 750 | – | wheelbarrow | – |
| m12 | Ana | El arabası | yığından mermi taşı | 8.600 | – | melter_speed | – |
| m13 | Ana | Harlı pota | mermi erit | 9.200 | – | melter_yield | – |
| m14 | Ana | Pirinç nehri | mermi erit | 9.600 | – | sweeper | – |
| m15 | Ana | Yarım plan | mermi ateşle | 1.600 | – | drone_teaser | – |
| e01 | Kolay | Kafadan | kafa isabeti | 4 | – | – | $20 |
| e02 | Kolay | Seri | kombo zinciri | 5 | – | – | $30 |
| e03 | Kolay | Hamal | yığından mermi taşı | 420 | – | – | $40 |
| e04 | Kolay | İsabetçi | isabet | 250 | – | – | $50 |
| e05 | Kolay | Tetik | mermi ateşle | 640 | uzi | – | $120 |
| e06 | Kolay | Uzun seri | kombo zinciri | 8 | workbench | – | $150 |
| e07 | Kolay | Nişancı | kafa isabeti | 24 | uzi | – | $300 |
| e08 | Kolay | Isınma | mermi erit | 650 | melter | – | $600 |
| e09 | Kolay | Taşıyıcı | yığından mermi taşı | 1.500 | shovel | – | $1000 |
| e10 | Kolay | Kombo ustası | kombo zinciri | 10 | workbench | – | $2000 |
| o01 | Orta | Sabırlı | mermi ateşle | 140 | – | – | parça: dual_pistol |
| o02 | Orta | Kova kova | yığından mermi taşı | 180 | – | – | parça: dual_pistol |
| o03 | Orta | Mikro | mermi ateşle (uzi) | 970 | uzi | – | parça: obur |
| o04 | Orta | Çırak | tarife mermi işle | 1.500 | blueprints | – | parça: dual_pistol |
| o05 | Orta | Kafa avcısı | kafa isabeti | 61 | uzi | – | parça: obur |
| o06 | Orta | Pota bekçisi | mermi erit | 1.200 | melter | – | parça: sekme |
| o07 | Orta | Klon yağmuru | mermi ateşle (clone) | 1.600 | hand_press | – | parça: sekme |
| o08 | Orta | Akrep | mermi ateşle (scorpion) | 1.700 | scorpion | – | parça: yanki |
| o09 | Orta | Usta | tarife mermi işle | 1.200 | electric_press | – | parça: yanki |
| o10 | Orta | Erime noktası | mermi erit | 12.000 | melter_speed | – | parça: yanki |
| z01 | Zor | Kazıcı | anahtar bul | 1 | – | – | perk: clone_spread |
| z02 | Zor | Ritim | kombo zinciri | 12 | workbench | – | perk: clone_count |
| z03 | Zor | Klon ordusu | mermi ateşle (clone) | 2.800 | hand_press | – | perk: clone_count_2 |
| z04 | Zor | Doymaz | mermi erit | 20.000 | melter | – | perk: obur_more |
| z05 | Zor | Anahtarcı | anahtar bul | 3 | – | – | perk: sekme_more |
| z06 | Zor | Servet | $ kazan | 43.000 | scorpion | – | perk: yanki_more |
<!-- /havuz tablosu -->

## Bot testi sonuçları (adım 4, 2026-10-27)

`tools/quest_sim.gd` (headless, ~20 sn): 1-4 bot × 3 beceri, her biri 3 tohumla, gerçek `GameState` üstünde (görevler, geliştirmeler, teçhizat, `hit_pay`, `quest_add`/`quest_hit`). Fizik yok: atış botun isabet oranıyla tutar, yığına gidiş bir süre. Oyunda henüz olmayanlar simin kendi tahmini (dosyanın başındaki tablolar): kova 50 / kürek 200 / el arabası 1.000, tarif maliyeti ve ödemesi (klon 2 → Yankı 50), huni 20 → 60 mermi/sn, eritilen mermi başına $0,2 → 0,5, anahtar bulma yığından giden mermiye bağlı. Beceri profilleri: isabet %45/65/85, kafa %5/15/30, yığına gidiş-dönüş 15/11/8 sn, boşa giden zaman %35/15/5, kötü oyuncu geliştirmeyi kötü sırayla alır. Botlar tahtadaki görevin istediği silaha ve tarife geçer, kombo görevi varken her üç yükten birini düz mermiyle atar.

Hedefler 1 kişi orta beceride ana zincir takvimine (`1,5 / 4 / 7 / 10,5 / 14 / 18 / 22 / 26 / 30 / 34 / 38,5 / 43 / 48 / 54 / 60` dk) göre sim tekrar tekrar koşturularak oturtuldu; yan görevler çekildikten sonra kolay ~4, orta ~7, zor ~12 dk sürecek şekilde. Yeniden koşmak: `Godot --headless --path . -s res://tools/quest_sim.gd` (`-- --sweep` ölçek taraması, `-- --fit` tek kişinin görev süreleri).

**Oyuncu sayısı ölçeği:** `quest_target = hedef × (1 + k·(n−1))`, **k = 0,5** (`GameState.quest_scale`). Tarama (orta beceri, ana zincir dk): k 0,2 → 4 kişi 26 dk; 0,3 → 30; 0,4 → 33; **0,5 → 36**; 0,6 → 39; 0,8 → 46. Kombo, anahtar ve eritme hedefleri büyümez (eritme hunisi takımda tek, el çoğalınca hızlanmıyor).

| Oyuncu | Beceri | Ana zincir (dk) | En uzun bekleme (dk) | 60 dk'da yığından giden | 60. dk'da mermi/sn |
|---|---|---|---|---|---|
| 1 | kötü | 108.0 (104.5-109.8) | 14.9 (12.1-17.7) | 7.385 | 4.4 (3.3-5.1) |
| 1 | orta | 61.2 (59.7-62.3) | 6.3 (6.1-6.5) | 47.112 | 31.2 (28.8-32.4) |
| 1 | iyi | 46.1 (45.2-47.0) | 5.9 (5.5-6.2) | 87.326 | 44.3 (41.8-45.8) |
| 2 | kötü | 71.5 (70.4-72.8) | 8.2 (7.6-8.8) | 29.605 | 52.2 (28.1-68.3) |
| 2 | orta | 42.4 (40.8-44.0) | 4.6 (4.4-4.8) | 125.941 | 59.5 (56.5-65.4) |
| 2 | iyi | 34.8 (33.0-35.9) | 4.3 (4.0-4.7) | 214.671 | 70.2 (69.6-70.5) |
| 3 | kötü | 59.6 (58.5-61.7) | 6.0 (5.7-6.2) | 72.623 | 73.6 (72.0-74.5) |
| 3 | orta | 38.1 (37.1-38.7) | 4.3 (4.3-4.3) | 203.324 | 71.9 (71.2-73.2) |
| 3 | iyi | 30.1 (30.0-30.2) | 4.0 (3.6-4.6) | 355.252 | 74.1 (73.0-75.3) |
| 4 | kötü | 53.3 (53.2-53.5) | 4.7 (4.6-4.9) | 122.506 | 77.7 (75.8-78.8) |
| 4 | orta | 36.3 (34.9-37.0) | 3.9 (3.7-4.1) | 288.153 | 76.1 (72.2-78.7) |
| 4 | iyi | 28.1 (27.9-28.2) | 3.5 (3.4-3.5) | 491.998 | 79.3 (78.5-80.5) |

Ortalama (en az–en çok), 3 tohum. Hedefler orta beceride tutuyor: tek kişi 61,2 dk (55-65), 4 kişi 36,3 dk (≥ 35), en uzun bekleme 6,5 dk (≤ 7).

1 kişi, orta (tohum 1):
- görev bitişleri (dk): m01 1.5  m02 3.9  m03 7.0  m04 10.3  m05 13.8  m06 17.8  m07 21.9  m08 25.8  m09 30.4  m10 34.8  m11 39.9  m12 44.5  m13 49.6  m14 55.7  m15 61.8  e01 7.8  e02 7.4  e03 11.0  e04 29.3  e05 15.1  e06 18.8  e07 20.7  e08 38.9  e09 33.3  e10 56.1  o01 6.8  o02 7.1  o03 14.1  o04 21.2  o05 15.0  o06 28.4  o07 20.9  o08 37.5  o09 42.1  o10 51.3  z01 8.8  z02 56.1  z03 –  z04 –  z05 26.3  z06 –
- açılışlar (dk): 0.0 başlangıç  1.5 workbench  3.9 bucket  7.0 uzi  10.3 blueprints  13.8 hand_press  15.0 bp:obur  17.8 shovel  21.2 bp:dual_pistol  21.9 melter  25.8 slot_machine  28.4 bp:sekme  30.4 scorpion  34.8 electric_press  39.9 wheelbarrow  44.5 melter_speed  49.6 melter_yield  51.3 bp:yanki  55.7 sweeper  61.8 drone_teaser
- mermi/sn (atılan + eritilen): 5. dk 0.6  10. dk 2.5  15. dk 2.7  20. dk 4.7  25. dk 6.7  30. dk 6.0  35. dk 6.2  40. dk 5.6  45. dk 43.3  50. dk 26.9  55. dk 28.1  60. dk 32.3
- ana zincir 61.8 dk, en uzun bekleme 6.1 dk, 60 dk'da yığından giden 46976

4 kişi, orta (tohum 1):
- görev bitişleri (dk): m01 1.2  m02 3.1  m03 5.5  m04 7.7  m05 9.9  m06 12.5  m07 15.4  m08 16.5  m09 18.6  m10 21.3  m11 23.1  m12 25.9  m13 28.5  m14 31.2  m15 34.9  e01 6.2  e02 5.9  e03 10.3  e04 8.6  e05 12.9  e06 10.4  e07 14.0  e08 17.8  e09 16.6  e10 16.9  o01 5.3  o02 5.1  o03 9.9  o04 14.2  o05 9.7  o06 17.2  o07 14.5  o08 23.1  o09 24.3  o10 29.3  z01 5.0  z02 16.9  z03 24.7  z04 –  z05 –  z06 –
- açılışlar (dk): 0.0 başlangıç  1.2 workbench  3.1 bucket  5.5 uzi  7.7 blueprints  9.9 bp:obur  9.9 hand_press  12.5 shovel  14.2 bp:dual_pistol  15.4 melter  16.5 slot_machine  17.2 bp:sekme  18.6 scorpion  21.3 electric_press  23.1 wheelbarrow  25.9 melter_speed  28.5 melter_yield  29.3 bp:yanki  31.2 sweeper  34.9 drone_teaser
- mermi/sn (atılan + eritilen): 5. dk 2.4  10. dk 10.4  15. dk 21.4  20. dk 25.4  25. dk 38.5  30. dk 78.3  35. dk 77.4  40. dk 78.3  45. dk 78.3  50. dk 78.7  55. dk 78.5  60. dk 77.4
- ana zincir 34.9 dk, en uzun bekleme 3.7 dk, 60 dk'da yığından giden 307469

**Bulgular (karar değil, sonraki denge turu için):**

- Tek kişi kötü beceride ana zincir ~108 dk, açılışlar arası 15 dk'ya kadar bekleme var. Demo için kötü oyuncuya yardım gerekebilir (ör. erken görevlerin hedefi beceriyle değil zamanla da ilerlesin) ya da kabul edilir.
- İlk 20 dakika mermi/sn çok düşük (0,6 → 4,7); "kurtulma" sıçraması el arabası ve hızlı huniyle 40-45. dakikada geliyor (tek kişi ~5 → ~30-40 mermi/sn). 4 kişide 30. dakikada ~78 mermi/sn'de tavan yapıyor: huni tek ve 60/sn'de doluyor, sonrası atışla sınırlı.
- Pahalı tarifler komboyu öldürüyor: maliyet şarjöre yaklaşınca şarjör başına bir atış kalıyor, şarjör değişimi zinciri koparıyor. Kombo görevleri geç oyunda ancak düz mermiyle biter.
- Demonun 60 dakikasında yığından giden 7 bin (tek, kötü) ile 490 bin (4, iyi) arası; 100M'nin en çok %0,5'i.
- `crafted` ve `bullets_melted` görevlerinin oyunda kancası yok; tezgâh ve huni gelene kadar bu görevler (m06, m08, m11, m13, m14 ve yan görevler) oyunda takılı kalır.

## Kullanıcıdan beklenenler

- Slot makinesi modeli (adım 10).
- Demo/tam sürüm tablosunun onayı.
- Anahtarlar ve kasa sırasının kaderi.
- Eritmenin ana zincirdeki yeri (~9. mi ~15. mi).
- Görev havuzu taslağının onayı (yukarıdaki tablo).
- Tezgâh animasyonları ve slot makinesi için ses kayıtları.
