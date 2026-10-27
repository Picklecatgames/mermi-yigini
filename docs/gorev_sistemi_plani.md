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
| m02 | Ana | Avuç avuç | yığından mermi taşı | 60 | – | bucket | – |
| m03 | Ana | Kova dolusu | mermi ateşle | 400 | – | uzi | – |
| m04 | Ana | Seri atış | isabet (uzi) | 600 | – | blueprints | – |
| m05 | Ana | İlk tarif | isabet (clone) | 300 | – | hand_press | – |
| m06 | Ana | Pres başında | tarife mermi işle | 2.000 | – | shovel | – |
| m07 | Ana | Kürek kürek | yığından mermi taşı | 6.000 | – | melter | – |
| m08 | Ana | İlk erime | mermi erit | 3.000 | – | slot_machine | – |
| m09 | Ana | Kumarbaz | $ kazan | 8.000 | – | scorpion | – |
| m10 | Ana | Kompakt | isabet (scorpion) | 3.000 | – | electric_press | – |
| m11 | Ana | Seri üretim | tarife mermi işle | 30.000 | – | wheelbarrow | – |
| m12 | Ana | El arabası | yığından mermi taşı | 60.000 | – | melter_speed | – |
| m13 | Ana | Harlı pota | mermi erit | 50.000 | – | melter_yield | – |
| m14 | Ana | Pirinç nehri | mermi erit | 150.000 | – | sweeper | – |
| m15 | Ana | Yarım plan | mermi ateşle | 100.000 | – | drone_teaser | – |
| e01 | Kolay | Kafadan | kafa isabeti | 10 | – | – | $20 |
| e02 | Kolay | Seri | kombo zinciri | 5 | – | – | $30 |
| e03 | Kolay | Hamal | yığından mermi taşı | 200 | – | – | $40 |
| e04 | Kolay | Tabancacı | isabet (deagle) | 150 | – | – | $50 |
| e05 | Kolay | Tetik | mermi ateşle | 1.000 | uzi | – | $120 |
| e06 | Kolay | Uzun seri | kombo zinciri | 10 | workbench | – | $150 |
| e07 | Kolay | Nişancı | kafa isabeti | 200 | uzi | – | $300 |
| e08 | Kolay | Isınma | mermi erit | 2.000 | melter | – | $600 |
| e09 | Kolay | Taşıyıcı | yığından mermi taşı | 20.000 | shovel | – | $1000 |
| e10 | Kolay | Kombo ustası | kombo zinciri | 20 | workbench | – | $2000 |
| o01 | Orta | Sabırlı | mermi ateşle | 300 | – | – | parça: dual_pistol |
| o02 | Orta | Kova kova | yığından mermi taşı | 500 | – | – | parça: dual_pistol |
| o03 | Orta | Mikro | isabet (uzi) | 800 | uzi | – | parça: obur |
| o04 | Orta | Çırak | tarife mermi işle | 1.000 | blueprints | – | parça: dual_pistol |
| o05 | Orta | Kafa avcısı | kafa isabeti | 500 | uzi | – | parça: obur |
| o06 | Orta | Pota bekçisi | mermi erit | 5.000 | melter | – | parça: sekme |
| o07 | Orta | Klon yağmuru | isabet (clone) | 3.000 | hand_press | – | parça: sekme |
| o08 | Orta | Akrep | isabet (scorpion) | 4.000 | scorpion | – | parça: yanki |
| o09 | Orta | Usta | tarife mermi işle | 20.000 | electric_press | – | parça: yanki |
| o10 | Orta | Erime noktası | mermi erit | 40.000 | melter_speed | – | parça: yanki |
| z01 | Zor | Kazıcı | anahtar bul | 1 | – | – | perk: clone_spread |
| z02 | Zor | Ritim | kombo zinciri | 15 | workbench | – | perk: clone_count |
| z03 | Zor | Klon ordusu | isabet (clone) | 10.000 | hand_press | – | perk: clone_count_2 |
| z04 | Zor | Doymaz | mermi erit | 30.000 | melter | – | perk: obur_more |
| z05 | Zor | Anahtarcı | anahtar bul | 3 | – | – | perk: sekme_more |
| z06 | Zor | Servet | $ kazan | 200.000 | scorpion | – | perk: yanki_more |
<!-- /havuz tablosu -->

## Kullanıcıdan beklenenler

- Slot makinesi modeli (adım 10).
- Demo/tam sürüm tablosunun onayı.
- Anahtarlar ve kasa sırasının kaderi.
- Eritmenin ana zincirdeki yeri (~9. mi ~15. mi).
- Görev havuzu taslağının onayı (yukarıdaki tablo).
- Tezgâh animasyonları ve slot makinesi için ses kayıtları.
