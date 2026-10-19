# Tasarım raporu: hedefler, ilk 60 dakika, yerleştirme (tasarim, 2026-10-19)

Okunanlar: `BRIEF.md`, `CLAUDE.md`, `docs/ajan_raporlari_2026-10-19.md`, `scripts/game_state.gd`, `dummy.gd`, `hanging_steel.gd`, `popper_target.gd`, `plate_rack.gd`, `texas_star.gd`, `rail_mover.gd`, `combo_meter.gd`, `upgrade_menu.gd`, `player.gd`, `viewmodel.gd` (bölüm süreleri), `scenes/main.tscn`, `steel_*.tscn`. Oyun dosyalarına yazılmadı. Sayıları elle kurduğum gelir modeliyle hesapladım (aşağıda "Sayılar"); x10 hile menüsüyle oyunda doğrulanmalı.

Öncelik: **Y** yüksek, **O** orta, **D** düşük. Süreler tek geliştirici içindir.

---

## Özet (5 madde)

1. **Karar: kombo zinciri yerine "çeşit çarpanı".** Çarpan = son 5 saniyede vurduğun **farklı hedef türü** sayısı. Tek dummy ×1 öder, dummy + gong ×2, altı tür ×6. Dummy'yi bırakmak gerekmiyor, yanında başka türleri de vurmak gerekiyor. Her yeni hedef satın alması çarpanın tavanını 1 artırıyor. "Neden diğer hedefler" ve "neden yeni hedef açayım" sorularının ikisine de aynı kural cevap veriyor.
2. **Şu anki kombo dummy'yi rakipsiz yapıyor** (`game_state.gd:248-250`). Tavansız zincir + ıskada sıfırlanma, oyuncuyu riskten kaçırıyor: kolay hedefte zinciri büyüt, zor hedefi şarjörün son mermisine sakla. Ayrıca şarjör başına ödeme mermi sayısının karesiyle büyüyor (AK'nin 30'luk şarjörü = taban ödemenin 465 katı). Otomatik silah gelmeden değişmeli.
3. **Hedef listesi 8'den 6 türe iniyor:** dummy, gong, popper çifti, çelik raf, köstebek rafı, Texas Star; sonra 7. tür olarak HP'li zırhlı dummy. **Raylı dummy** çıkarılsın: atış hitscan, yani önünü kestirme yok, yalnızca yavaş takip var. **Çelik silüet** de çıkarılsın: gongla aynı beceriyi soruyor. Gong kalıyor, çünkü "son mermi töreni"nin ve kilometre taşlarının çanı olacak.
4. **Yerleştirme:** Q'dan satın al, ardından elinde saydam bir önizleme belirir. Raycast ile yerleştiriyorsun; atış hattını geçmen gerekmiyor. Kurallar: 0,5 m grid, 15° döndürme, bölge x 18–26,5, çakışma yok, slot sınırı yok. Yakın/uzak bandı ×1/×1,5. Hedefleri kümelersen geçişler hızlanıyor (çarpan artıyor); uzağa koyarsan ödeme artıyor ama hedef küçülüyor. CLAUDE.md'nin istediği "yerleşim optimizasyonu" bu dengeden çıkıyor.
5. **Sistemlere bağlantılar:**
   - **Anahtarlar** yığında kalıyor, hedeflerden düşmüyor. Otomasyon gelince bandın ağzı nerede kazıyorsa anahtar orada fırlıyor.
   - **Kasa içerikleri** yerleşime bağlanıyor: seken mermi kümeyi, delici mermi derinlikte sıralı dizilimi ödüllendiriyor.
   - **Taretler** yalnızca sabit hedeflere ateş ediyor ve çeşit çarpanı almıyor. Oyuncunun çarpanı taretleri hızlandırıyor; orta ve son oyunda oyuncunun aktif işi bu.
   - **Son mermi** elle alınıp başlangıç tabancasıyla gonga atılıyor.

---

## "Neden yerinde duran dummy varken diğer hedeflere vurayım?"

### Bugünkü durum

- Ödeme `hit_gold × zayıf nokta(2) × zincir`.
- Zincir **herhangi bir** `target` isabetiyle 1 artıyor. CLAUDE.md "dummy isabeti" diyor, kod ise her hedefi sayıyor; belge ile kod uyuşmuyor.
- Iskada ya da ayağa/çerçeveye isabette zincir sıfırlanıyor.

Pistolün 7'lik şarjörüyle iki seçeneği karşılaştıralım:

- **Yalnız dummy (%95 isabet):** 1+2+…+7 ≈ **$28**.
- **Her atış Texas Star ($6, %50 isabet):** Iska zinciri sıfırladığı için beklenen zincir 1–2 civarında kalıyor, sonuç ≈ **$15–18**.
- **En iyi strateji:** 6 mermi dummy'ye, son mermi yıldıza: 21 + 0,5×6×7 = **$42**.

Yani akılcı oyuncu zor hedefi yalnızca şarjörün son mermisinde vuruyor. Bu ne sezgiyle bulunacak bir strateji ne de eğlenceli. Oyuncuların çoğu dummy'de kalır.

### Değerlendirilen seçenekler

| Seçenek | Ne yapar | Neden zayıf |
|---|---|---|
| A. Dummy yıpranması | Aynı hedefe art arda vurdukça ödeme düşer, zamanla toparlanır | Ceza dili kullanıyor (kayıptan kaçınma, "dummy bozuldu"). Oyuncu sayıyı göremeyince sebebini anlamıyor. Co-op'ta oyuncular aynı dummy'yi birbirine yıpratıyor. Dummy'nin "taban hedef" kimliği kayboluyor. Gizli bir verim düşüşü, oyuncuya yetkinlik hissi vermiyor (SDT). |
| B. Sipariş tahtası / hedefe özel görevler | "Popper'a 20 isabet" gibi görevler | Dışsal bir yapılacaklar listesi; anlık atış hissini değiştirmiyor. İçerik üretmek ve UI yazmak gerekiyor. Görev bitince oyuncu dummy'ye geri dönüyor. Kilometre taşları için iyi, çekirdek kural olarak değil. |
| C. Yalnız hedef değiştirince artan kombo | Aynı hedefe ikinci vuruş zinciri artırmaz | Tavansız kalıyor (n² sorunu sürüyor). Dummy ile gong arasında gidip gelmek sonsuza kadar yetiyor; 3. hedeften sonrası bir şey katmıyor. |
| D. Yalnız daha yüksek hedef ödemesi (bugünkü kural) | Zor hedef daha çok öder | Isabet oranını hesaba katınca kâr belirsiz. Ödül varyansı yüksek, ceza ise zincir sıfırlanması. Riskten kaçan oyuncu dummy'de kalıyor (yukarıdaki hesap). |
| **E. Çeşit çarpanı (seçilen)** | Çarpan = son 5 sn'de vurulan farklı tür sayısı | Aşağıda. |

### Neden E

- **Gerçek dünyada karşılığı var.** Steel Challenge'da bir dizide her plaka en az bir kez vurulmadan stop plakası vurulamaz; oyuncunun becerisi hedefler arası geçiş hızıdır. Popper'ın düşmesi, köstebek plakasının sırayla kalkması ve yıldız plakasının kopması zaten "bir sonrakine geç" diyen mekanikler. Bu kural onları ödüllendiriyor, onlarla çelişmiyor.
- **Sınırlı.** En fazla ×6–7, otomatik silahta bile doğrusal kalıyor. Kombo göstergesindeki `MAX_COMBO 100` gibi yamalar gerekmiyor.
- **İlerlemeyle bağlantılı.** Her hedef türü tavanı 1 artırıyor. Hedef açmak, sadece "yeni oyuncak" değil, ölçülebilir bir güç artışı.
- **Dummy cezalandırılmıyor.** Dummy setin bir parçası olarak kalıyor ve taretlerin ana hedefi oluyor (aşağıda).
- **Iskada ceza yok.** Bedeli boşa giden mermi ve zamanla sönen tür. Zor hedefi denemek artık riskli değil (Autonomy ve Competence).
- **Co-op'ta sorun çıkmıyor.** Her oyuncunun kendi tür sayacı var, hedefler ortak. Kimse kimsenin hedefini "tüketmiyor".

### Kural (uygulanabilir tanım)

- Her hedefin bir `kind` değeri var: `dummy`, `gong`, `popper`, `steel_rack`, `plate_rack`, `texas_star`, `armored`. Bir raftaki 5 plaka, 2 popper ve ek dummy'ler **tek tür** sayılır.
- Oyuncu başına `last_hit[kind]` (oyun zamanı) tutulur.
- İsabette (atış hattının içinden, `target` grubu):
  1. `last_hit[kind] = şimdi`
  2. `V = { k : şimdi − last_hit[k] ≤ VARIETY_WINDOW }` kümesinin boyutu
  3. `gold = hit_gold × (2 zayıf noktaysa) × V × band`
- Iska ve ayak/çerçeve isabeti hiçbir şeyi sıfırlamaz (ayar düğmesi: `MISS_CLEARS = false`).
- `shot_landed` olayındaki `combo` alanı, V'yi taşır.

---

## İlk 60 dakikanın oyuncu yolculuğu

Varsayımlar:
- Boş şarjör reload'u + avuçlama ≈ 2,3 sn.
- Ateş aralığı 0,42 sn.
- Ortalama isabet: dummy %95, gong %95, popper %80, çelik raf %75, köstebek %65, yıldız %50.
- İsabetlerin %15'i zayıf noktaya.
- Oyuncu teorik çarpanın %80'ini tutturuyor.

Bu varsayımlarla dakikalar aşağıda.

| Dakika | Oyuncu ne yapar | Açılan | Neden sıradakine geçer | Sıkılma riski |
|---|---|---|---|---|
| 0:00–0:20 | Doğar, yığını görür. "[E] Mermi al" ile 1 mermi avuçlar, R ile doldurur, atış hattının ötesindeki dummy'ye ateş eder: "+$1", toz, delik. | — | $8 birikince HUD'da "[Q] Geliştirme hazır" yanıp söner (eklensin). | Yok; her şey yeni. |
| 0:20 | Kapasite 2 | $8 | Sonraki kapasite ucuz. | — |
| 0:50 | Kapasite 3 | $20 | Q'da "Hedefler" sekmesinde gong görünür. | — |
| ~1:30 | **Gong** satın alır, önizlemeyi yerleştirir. Dummy, sonra gong: "x2" ve iki ikon yanar. **Asıl "aha" anı.** | $30 | Ekranda dummy ve gong ikonlarının yanında boş bir yuva: "?". | — |
| 1:50–2:30 | Kapasite 4–5. Dummy↔gong geçişi, kafa vuruşları. | $45, $90 | Popper fiyatı görünür ve yaklaşır. | Düşük. |
| ~4:00 | **Popper çifti**: vurulan yatar, diğerine geçmen gerekir; kafa ×2. Çarpan ×3. | $300 | — | — |
| 4:30–5:30 | Kapasite 6, 7 (MAKS). | $160, $280 | — | — |
| ~7:00 | **Çelik raf** (5 küçük plaka, art arda vurursan takla atar). Çarpan ×4. | $700 | SMG gösterilir. | **Risk 1 (7–10 dk):** tabanca maksimumda, aynı döngü. **Çözüm:** ilk 2 anahtar yığının doğu yüzünde, oyuncunun avuçladığı yerde 10 cm derinlikte. ~8. dakikada kendiliğinden fırlar → kasa 1 → **seken mermi %10**. Seken mermi 4 m içindeki başka türe sıçrar: oyuncu hedefleri yeniden kümelemeye döner. |
| ~10:00 | **SMG** (30'luk, ~0,08 sn). Güç sıçraması: tarayarak çarpanı tek şarjörde ×4'e çıkarmak. Kapasitesi 12→30. | $1.750 | — | — |
| ~12:30 | **Köstebek rafı**: tepki ve dikkat bölme. Çarpan ×5. | $3.000 | Taret görünür. | — |
| ~14:40 | **İlk taret**. Yalnız sabit türlere ateş eder (dummy, gong, çelik raf); çeşit çarpanı almaz. Elle doldurulan 200'lük hazne. Ek dummy ($150) taret için anlam kazanır. | $5.000 | Haznenin elle doldurulması kasıtlı bir acı: bandı istetiyor. | — |
| ~17:00 | **Texas Star**: zamanlama ve önden kestirme. Taretin vuramadığı, yalnız insanın vurabildiği hedef. Çarpan ×6. | $9.000 | — | **Risk 2 (17–20 dk):** haznelere elle mermi taşımak. **Çözüm:** bant hemen arkadan gelir. |
| ~19–20 | **Bant**: yığından taret haznesine. Bant ağzı yığını kazıyor; otomasyonun açtığı ilk çukur gözle görülür. | — | Anahtarlar artık bant ağzından fırlıyor. Tarayıcı, bandın nereden kazacağını seçtiriyor. | — |
| 20–25 | Daha çok taret; robot kol atış hattında şarjör istasyonu. Oyuncu artık yığına yürümüyor, ateş etmeye odaklanıyor. Kovan süpürgesi → fırın → külçe → taret geliştirme. | — | — | — |
| ~25 | **AK** + **zırhlı dummy** (7. tür, HP 20; kırılınca "kasa" ödemesi, 3 sn'de yenilenir). Sürekli ateş kontrolü sorusu. | — | — | — |
| ~28–30 | **99M kilometre taşı (eklensin):** ilk milyon. Gong kendi kendine çalar, büyük yazı. Mermi tüketimi ~3k/sn. | — | Kasa 3–5: **delici** (arka arkaya dizilmiş türleri deler; dizilimi derinliğe göre yeniden kur), **patlayıcı** (küme). | — |
| 30–40 | **Komuta:** oyuncunun çarpanı tüm taretlerin ateş hızını artırır (×(1 + 0,15·V), V=7'de ×2,05). Aktif işin ta kendisi: süpürme yaparsan yığın iki kat hızlı erir. ~37. dakikada 90M. | — | — | — |
| 40–50 | Minigun taret, ölçek büyür, yığın gözle küçülür. ~50. dakikada 50M. | — | Son kasalar. | **Risk 3 (40–50 dk):** "sadece sayılar büyüyor". **Çözüm:** çığ (bant ağzı dibi oyunca yamaç kayar, saçılan mermi yerden toplanır), son kasalar, yığının fiziksel küçülmesi. |
| 50–60 | 10M ~57. dakikada, 1M ~59,5. dakikada. **Son mermi töreni:** 1 mermi kalınca bantlar durur. Son mermi elle alınır, **başlangıç tabancasına** konur ve **gonga** atılır. Co-op'ta herkes izler. | — | Oyun başladığı gibi bitiyor: elde 1 mermi. | — |

Mermi tüketimi ilk 25 dakikada pratikte sıfır (toplam < 200 bin). Yığın ilk 30 dakikada küçülmüyor. O dönemi hedef açılışları, anahtarlar ve 99M taşı taşıyor. Bu yüzden 99M taşı şart.

---

## Hedefler: hangi beceri, ne zaman, kalsın mı

| Hedef | Sorduğu beceri | Ödeme (öneri) | Açılış | Karar |
|---|---|---|---|---|
| Dummy | Temel nişan, kafa = hassasiyet mi hız mı | $1, kafa ×2 | Başlangıç | **Kalsın.** Taretin ana yemi, ek kopyaları satılır. |
| Gong | İlk hedef geçişi; büyük, net "ding" geri bildirimi | $2 | ~1:30, $30 | **Kalsın.** Tören ve kilometre taşı çanı. |
| Çelik silüet | Gongla aynı (ağır asılı çelik, sabit) | — | — | **Çıkarılsın** (demoda). Kafanın ters savrulması hoş ama soru aynı. |
| Raylı dummy | Yavaş takip. Hitscan yüzünden önünü kestirme yok, 1,6 m/sn'de pratikte dummy. | — | — | **Çıkarılsın.** `rail_mover.gd` kalsın; ileride bir taret hedefi ya da "ray modülü" olabilir. |
| Popper çifti | Hassasiyet (kafa ×2) + zorunlu geçiş (düşer) | $3, kafa ×2 | ~4:00, $300 | **Kalsın**, çift tek tür sayılır. |
| Çelik raf (5 plaka) | Küçük hedefte hassasiyet; ritim (takla atma) | **$3 → $4** | ~7:00, $700 | **Kalsın.** $3'te mermi başı beklenen ödemesi popper'dan düşük (2,25'e karşı 2,4). |
| Köstebek rafı | Tepki süresi, dikkat bölme, hızlanan tempo | **$5 → $6** | ~12:30, $3.000 | **Kalsın.** |
| Texas Star | Zamanlama ve dönen hedefte önden kestirme | **$6 → $10** | ~17:00, $9.000 | **Kalsın.** $6'da mermi başı beklenen ödemesi köstebekten düşük (3,0'a karşı 3,25). |
| Zırhlı dummy (HP) | Sürekli ateş, DPS kontrolü (AK için) | Plaka başı $2, kırılınca $50 | ~25 | **Eklensin.** |

Kural: **mermi başı beklenen ödeme (ödeme × isabet oranı), açılış sırasıyla artmalı:** 0,95 → 1,9 → 2,4 → 3,0 → 3,9 → 5,0. "Yeni hedef daha iyi" sezgisi, isabet oranı hesaba katılınca da doğru kalıyor.

---

## Yerleştirme modu

**Seçim: serbest yerleştirme, 0,5 m grid, raycast ile, slot sınırı yok.**

Alternatifler:
- **Sabit slot (ör. 8 kaide):** Okuması kolay ama yerleşim kararı yok. "Yerleşim optimizasyonu" ölüyor, seken/delici mermilerin anlamı kalmıyor.
- **Tamamen serbest (grid yok):** Co-op'ta ağdan konum göndermek ve çakışma kontrolü zorlaşıyor, görsel düzensizlik artıyor.

Kurallar:

1. **Giriş:** Q → Hedefler → Satın al. Para düşer, hedef "elde" saydam önizleme olur (CLAUDE.md'deki inşa modu dili). B ile aynı moda girilip var olan hedef seçilir: E al, sol tık koy. **Taşımak bedava**, deneme teşvik edilsin. Satış yok (demo).
2. **Yerleştirme ışını** oyuncunun bulunduğu yerden 25 m'ye kadar. Atış hattını geçmek gerekmiyor (geçiş B ile açık kalabilir, zararsız).
3. **Bölge:** x ∈ [18, 26,5], z ∈ [−26, 26]. Hattın 4 m önü yasak: hem dibine dayanmayı engeller hem "+$" yazıları okunur kalır. Bölge dışında önizleme kırmızı.
4. **Grid** 0,5 m. Yön varsayılan −X (hatta bakar), Q/E veya tekerlek ile 15° adım, sınır ±45°.
5. **Çakışma:** Her türün dikdörtgen taban izi var. Örtüşme yasak, aralarında en az 0,3 m boşluk. Görüş hattı kontrolü **yok**: öndeki hedef arkadakini kapatıyorsa bu oyuncunun tercihi; delici mermiyle avantaja da dönüşüyor.
6. **Mesafe bandı:** Zemine sarı boya ve "YAKIN / UZAK" yazısı.
   - x 18–22: ×1
   - x 22–26,5: ×1,5
   - Ölçü hattan alınır, oyuncunun durduğu yerden değil; geri çekilip ateş etmek ödemeyi artırmaz.
7. **Hareketli hedef izleri:** Texas Star dönme çapı 1,6 m, köstebek rafı 3 m genişlik. Taban izine dahil.
8. **Co-op:** `request_place_target(kind, pos, yaw)` ve `request_move_target(id, pos, yaw)`. Host taban izini ve bölgeyi doğrular, `target_placed` olayını yayar. **Açık soru:** hedefi kim öder? Önerim: ortak kasa. Hedefler dünyaya ait ve herkes kullanıyor; kişisel parayla alınınca bedavacılık tartışması çıkar.

Ortaya çıkan karar dengesi:
- Kümelersen geçiş kısa, çarpan yüksek.
- Uzağa koyarsan ödeme ×1,5 ama hedef küçük, geçiş açısı büyük.
- Seken mermi kümeyi, delici derinlik sırasını, patlayıcı kümeyi ister; taretler sabit türlerin görüş hattını ister.

Tek "doğru" dizilim yok. Bu, sağlıklı ustalık alanı (Sirlin).

---

## Sistemlere bağlantı ve sıralı yol haritası

**Anahtarlar hedeflerden mi düşmeli?** Hayır, yığında kalsın.
- Find the Needle kancası "yığını kaz, bul". Anahtar hedeften düşerse yığın yeniden yalnızca yakıta döner.
- Bağ şöyle kuruluyor: ilk 2 anahtar elle kazılan doğu yüzeyinde, sonrakiler bant ağzında fırlıyor. Tarayıcı, bandın nereye kurulacağını belirleyen bir alet oluyor.

**Kovanlar hedef başına mı birikmeli?** Hayır. Kovan atıcının yanına düşer (fiziksel olarak doğru): oyuncunun ayağına, taretin dibine. Süpürge ve fırın atış hattı tarafında yaşar. Hedeflerin külçeyle bağı demoda yok; ileride "hedef seviyesi" olabilir (D).

**Taret:**
- Yalnız sabit türlere ateş eder.
- Çeşit çarpanı almaz: ödemesi `hit_gold × 1 × band`.
- Oyuncunun V'si taretlerin ateş hızını artırır (komuta).
- Co-op'ta komuta çarpanı için önerim, oyuncuların V'lerinin en büyüğü.

**Kilometre taşları:** 99M (yeni), 90M, 50M, 10M, 1M. Her birinde gong kendi çalar.

**Son mermi:** 1 mermi kalınca bant ve taret kesilir. Son mermi elle alınır, tabancayla gonga atılır.

**Sıra (her adım bir öncekinin üstüne):**

1. Çeşit çarpanı + `kind` alanı + HUD (Y, 5–7 sa)
2. Q menüsünde Hedefler sekmesi + kilitli hedefler (Y, 3 sa)
3. Yerleştirme modu: önizleme, grid, bölge, taşıma (Y, 6–8 sa)
4. Ödeme ve fiyat güncellemesi, hile menüsüyle 0–17. dakika doğrulaması (Y, 2 sa)
5. Anahtar + tarayıcı + kasa 1 (seken mermi) (O, 8–10 sa)
6. SMG (O, 6 sa)
7. Taret (sabit hedef) + elle hazne (O, 6 sa)
8. Bant + anahtarın bant ağzından fırlaması (O, 8 sa)
9. Robot kol şarjör istasyonu, kovan süpürgesi → fırın → külçe (O, 10 sa)
10. AK + zırhlı dummy (O, 6 sa)
11. Komuta çarpanı + kilometre taşları + 99M (O, 3 sa)
12. Delici ve patlayıcı kasaları (D, 5 sa)
13. Son mermi töreni (O, 3 sa)
14. Stop plakası (D)

---

## İyi, kalsın

- **Atış hattı ve hattın ötesinden atışa para yok** (`game_state.gd:57`, `:245`). Dibine dayanma suistimalini temiz kapatıyor. Önerilen yerleşim bölgesi (x ≥ 18) bunu destekliyor.
- **Zayıf nokta ×2** (`game_state.gd:47`). Çeşit çarpanıyla çarpılır, rekabet etmez; hız mı hassasiyet mi kararını taşır.
- **Sabit ateş aralığı 0,42 sn ve tek upgrade olarak Kapasite.** Tabanca dönemini sade tutuyor. Fiyatlar ($8–280) önerilen akışta 5–6 dakikaya oturuyor.
- **Popper'ın düşüş süresi (2–3,5 sn), yıldız plakasının 1,5 sn'de geri gelmesi, köstebeğin hızlanan temposu.** 5 sn'lik çeşit penceresiyle tam uyumlu: hedef seni bir sonrakine itiyor, pencere seni geri getiriyor.
- **Gold kişisel, `shot_landed` olayıyla host otoritesi.** Çeşit sayacı oyuncu başına tutulur ve aynı yapıya oturur.
- **"Küçük, hareketli ve zamanlı hedef daha çok öder" kuralı.** Doğru; yalnız sayıların isabet oranına göre düzeltilmesi gerekiyor (aşağıda).

## Kötü, düzelsin

| Yer | Sorun | Öneri | Öncelik / süre |
|---|---|---|---|
| `game_state.gd:248-250` | Tavansız doğrusal zincir: şarjör başına ödeme n(n+1)/2. AK'de ×465, SMG 7 sn'de ×100. Iska sıfırlıyor, risk alan cezalandırılıyor. Zor hedef yalnızca son mermide akılcı. | Çeşit çarpanı (yukarıdaki kural). | Y, 3–4 sa |
| `game_state.gd:255` | Ayak/çerçeve isabeti zinciri sıfırlıyor. Hareketli hedeflerde ayağa değmek kolay, ceza orantısız. | Çeşit modelinde sıfırlama yok, yalnızca mermi boşa gider. | Y (1. ile birlikte) |
| `CLAUDE.md:31` | "Her dummy isabeti" yazıyor; kod her `target` isabetini sayıyor. | Çeşit kuralına geçince belge güncellenmeli. | D, 5 dk |
| `combo_meter.gd:33`, `:50` | Gösterge vurulan hedefin başında. Çok hedefli süpürmede yazı hedeften hedefe zıplıyor ve okunmuyor. | Nişangâhın altında sabit şerit: büyük "x4" ve her tür için bir ikon. İkonun etrafındaki halka 5 sn'de boşalır. Yeni tür eklenince ikon parlar. Son 1 sn'de halka kırmızı yanıp söner ("dummy'ye dön"). | Y, 2–3 sa |
| `steel_rack.tscn:9` | Çelik raf $3: mermi başı beklenen ödeme 2,25, popper'dan (2,4) düşük ama daha geç açılıyor. | $4 | Y, 1 dk |
| `plate_rack.gd:27` | Köstebek $5 → 3,25; yıldız $6 → 3,0. Sıra ters. | Köstebek $6, yıldız $10 (`texas_star.gd:18`). | Y, 1 dk |
| `main.tscn:29-66` | Bütün hedefler açık; iki popper ayrı istasyon. | Kilit + satın alma. Popper'lar tek `kind`, çift olarak satılsın. | Y (2. adımda) |
| `upgrade_menu.gd:5-7` | Tek satır, sekme yok; paranın yettiği anlaşılmıyor. | Geliştirmeler / Hedefler sekmeleri. Para ilk kez yetince HUD'da "[Q]" yanıp söner. | Y, 3 sa |
| `rail_mover.gd` | Hitscan'de önünü kestirme yok; dummy'den farkı yalnız yavaş takip. | Demodan çıkar, kod kalsın. | D |
| `steel_silhouette.tscn` | Gongla aynı soru. | Demodan çıkar. | D |

## Eklensin

| Ne | Neden | Öncelik / süre |
|---|---|---|
| Çeşit çarpanı (`kind`, `last_hit`, V, `VARIETY_WINDOW`) | Çekirdek karar | Y, 3–4 sa |
| Çeşit HUD şeridi | Kuralın okunması; 0,5 sn içinde geri bildirim | Y, 2–3 sa |
| Hedefler sekmesi, sıralı kilit (yalnız sıradaki gösterilir, ondan sonraki "?" siluet) | "Yavaş yavaş açılsın" isteği; merak | Y, 3 sa |
| Yerleştirme modu (önizleme, grid, bölge, çakışma, taşıma, `request_place_target`) | Yerleşim optimizasyonu, co-op'a hazır komut | Y, 6–8 sa |
| "Geliştirme hazır" uyarısı | Q'nun keşfedilmesi; ilk 20 sn'nin kaybolmaması | O, 30 dk |
| Mesafe bandı ×1,5 + zemin boyası | Yerleşim kararı için karşı ağırlık | O, 1–2 sa |
| İlk 2 anahtar doğu yüzeyinde, sığ | 7–10. dakikadaki sıkılma çukuru | O, anahtar sistemiyle |
| Taret yalnız sabit tür + komuta çarpanı | Orta oyunda aktif iş (CLAUDE.md kuralı) | O, taretle |
| Zırhlı dummy (HP 20) | AK'ye tür sorusu; 7. tür | O, 3 sa |
| 99M kilometre taşı | İlk 30 dakikada yığında görünür bir zafer | O, 15 dk (taş sistemi varsa) |
| Son mermi töreni (gong, başlangıç tabancası) | Döngüyü kapatan bitiş | O, 3 sa |
| Stop plakası (gong vurulunca süpürme biter, "tam tur" bonusu) | Steel Challenge'ın kendisi, risk ve ödül | D, 2 sa |

## Çıkarılsın

- **Tavansız kombo zinciri ve ıskada sıfırlanma.** Yerine çeşit çarpanı.
- **Raylı dummy ve çelik silüet** (demodan; dosyalar kalsın).
- **Revolver** silah sırasından. Tabancadan sonra 6'lık bir silah, kapasitede geri adım; demoda rolü yok. Sıra: tabanca → SMG → AK → (taret minigun).
- **"Hareket hızı, stamina" gibi kasa içerikleri.** Hedeflere ya da yerleşime dokunmayan ödüller kasayı sıradan bir mağaza satırına çeviriyor. Yerine seken, delici ve patlayıcı mermi, SMG reload hızı, tarayıcı menzili.

---

## Sayılar

| Değer | Öneri | Gerekçe |
|---|---|---|
| `VARIETY_WINDOW` | **5,0 sn** (aralık 4–6) | Boş reload + avuçlama ≈ 2,3 sn. Reload'dan önce vurulan tür, reload sonrası ilk atışta yaşıyor olmalı. 3 sn reload'u cezalandırır, 7 sn kampa izin verir. |
| V tavanı | Sahip olunan tür sayısı (demoda en fazla 7) | Doğal sınır |
| Ödemeler | dummy 1, gong 2, popper 3, çelik raf **4**, köstebek **6**, yıldız **10**, zırhlı plaka başı 2 + kırılınca 50 | Mermi başı beklenen ödeme sırasıyla artıyor: 0,95 / 1,9 / 2,4 / 3,0 / 3,9 / 5,0 |
| Hedef fiyatları | gong $30, popper çifti $300, çelik raf $700, köstebek $3.000, Texas Star $9.000, ek dummy $150 | Tabloda hesaplanan ~1:30 / 4:00 / 7:00 / 12:30 / 17:00 açılışlar |
| Silah ve diğer fiyatlar | SMG $1.750 (kapasite 12→18→24→30: $600 / $1.200 / $2.000), ilk taret $5.000 | ~10:00 SMG, ~14:40 taret |
| Kapasite | $8 / 20 / 45 / 90 / 160 / 280, aynı kalsın | Çeşit çarpanıyla 5:15'te biter. 7. dakikadaki çelik raf ve sığ anahtarlar boşluğu dolduruyor. |
| Gelir eğrisi (model) | ~1:30'da $0,9/sn → 4:00'te $5/sn → 7:00'de $11/sn → 12:30'da $36/sn → 17:00'de $82/sn | Her açılış gelirde ~1,5–3× sıçrama: testere dişi akış. |
| Yerleşim bölgesi | x 18–26,5, z −26…26, grid 0,5 m, döndürme 15° (±45°), boşluk 0,3 m | Hat 14'te, duvar ~28'de |
| Mesafe bandı | x < 22 ×1, x ≥ 22 ×1,5 | Uzak yerleşimin bedeli: hedef küçülür, geçiş açısı büyür |
| Komuta | taret ateş hızı × (1 + 0,15·V) | V=7'de ×2,05; oyuncu süpürmezse yığın yarı hızda erir |
| Zırhlı dummy | HP 20, kırılınca $50, 3 sn'de yenilenir | AK ile ~2 sn sürekli ateş |
| Kilometre taşı dakikaları (eski tempo tablosuyla) | 99M ~29, 90M ~37, 50M ~50, 10M ~57, 1M ~59,5 | Eski tablonun bölüm bölüm toplanmasıyla |

---

## Diğer ajanlara sorular

- **Programcı/Godot:**
  - `hanging_steel.gd`'deki `Plate` gövdeleri ayrı `StaticBody3D`. `kind` değerini hedef kökünden okumak (`_target.kind`) yeterli mi? Ayrıca `request_fire`'ın `target.get("kind")` okuması host'ta başka bir maliyet çıkarır mı?
  - Yerleştirilen hedefler `main.tscn` dışında, çalışma anında örneklenecek. Kayıt sistemi bunları `kind, pos, yaw` listesi olarak tutabilir mi?
- **Ekonomi:**
  - Modeldeki %80 çeşit tutturma ve isabet oranları tahmin. Hile menüsüyle 0–17. dakika, iki farklı yetenekte oyuncuyla ölçülmeli. Gelir 17. dakikada $82/sn'nin çok üstündeyse önce hedef fiyatları ×1,5'e çekilmeli.
  - Taretten itibaren eski tempo tablosu (80 → 100k mermi/sn) bu modelle hesaplanmadı.
- **QA:**
  - Popper'lar ve çelik raf plakaları tek tür sayılınca çarpan şişmiyor mu? Ek dummy'ler V'yi artırıyor mu? (Artırmamalı.)
  - 5 sn'lik pencere `Engine.time_scale` ile (x10) doğru sayılıyor mu?
- **UX:** Çeşit şeridi nişangâhın altında mı olmalı, ekranın alt ortasında mı? Hedef ikonları için silüet çizimleri gerekiyor.
- **Kullanıcıya açık kararlar:**
  - Hedefleri kim öder: ortak kasa mı, kişisel para mı?
  - Iska hiç ceza vermesin mi (önerim), yoksa en eski türü mü düşürsün?
  - Stop plakası demoya girsin mi?

---

## 2. tur: tartışma

Okunanlar: `ekonomi.md` (gerçek Python simülasyonu, ölçülmüş hedef boyutları), `gorsel.md` (Blender'da oyun kamerasıyla render ve piksel hesapları), `qa.md` (headless ile doğrulanmış hatalar). Kullanıcının üç sınırı esas alındı:
- kombo, 1,5 sn'lik ve görsel olarak büyüyen bir zincir olarak kalacak;
- Texas Star hızlı dönecek;
- hedefler sırayla açılacak ve yerleştirme moduyla konacak.

### 1. Kendi raporumdaki düzeltme: çeşit çarpanı zincirin yerine geçemez

1. turdaki "zinciri kaldır, yerine 5 sn'lik çeşit çarpanı koy" önerim kullanıcının onayladığı zincirle (1,5 sn pencere, solan cam bar, büyüyen yazı) doğrudan çatışıyor. **Geri çekiyorum.** Çeşit fikrini zincirin **tavanı** olarak yeniden kuruyorum:

> **Ödenen çarpan = min(zincir, 1 + bu zincirde vurulan farklı tür sayısı)**

- Zincir bugünkü gibi çalışıyor: 1,5 sn pencere, her isabet +1, ıska ya da ayağa isabet kırıyor. Görsel aynı kalıyor.
- Tek dummy'de çarpan 1, 2, 2, 2… olur, yani **×2'de tıkanır**. Dummy + raylı ×3'e, üç türde ×4'e kadar çıkar. Altı türle tavan ×7.
- "Neden başka hedef?" sorusunun cevabı artık şu: zinciri büyütmeye devam etmek istiyorsan tavanı açman lazım, tavanı da yalnızca yeni tür açar. Dummy cezalandırılmıyor, zinciri başlatan hedef oluyor.
- Ekonominin istediği tavan da kendiliğinden geliyor. Tabancanın 7'lik şarjöründe üç türle ödeme 1+2+3+4+4+4+4 = 22 birim. Ekonominin önerdiği kademeli tavan 16, şimdiki tavansız zincir 28 veriyor; benimki ikisinin arasında. SMG'de ve AK'de tavan en fazla ×7'de kalıyor, taret zincire hiç girmiyor. Ekonominin 1,8 milyon $/dk'lık patlaması bu kuralla oluşmuyor.
- Ekonominin ×1, 1, 2, 2, 3, 3, 4 kademesine göre farkı: kademe yalnızca "zincir uzunluğu" sorusunu soruyor, hedef değiştirmeye bir sebep vermiyor. Ekonomi ajanı "hedef değiştirmeyi ödeme merdiveni sağlıyor" diyor. Kendi tablosu ise kötü oyuncunun %100 dummy'de kaldığını gösteriyor; bunu ben de iyi buluyorum (beceriye göre ayrışma). Ama orta oyuncunun dummy'den çıkma sebebi yalnızca para farkı olursa yine görünmez bir hesap olarak kalıyor. Tavan ise **HUD'da görülen** bir sebep.

**Açık çatışma (kullanıcı karar versin):** Kullanıcı "taramalıyla x100" büyümesini tarif etti. Tavanlı herhangi bir kural (benimki de, ekonominin ×4'ü de) bu sayıyı paraya çeviremez. Önerim şu:
- Büyük yazı **zincir sayısını** göstermeye devam etsin (x37, x100; büyüme ve cam bar aynı).
- Altında küçük tür ikonları ve "tavan ×4" yazsın.
- Gerçek para zaten "+$" pop'unda görünüyor.

Kullanıcı büyük yazının ödenen çarpanı göstermesini isterse, x100 görseli tavanla birlikte kaybolur.

### 2. Texas Star: hızı düşürmeden rezonansı kırmak

Görsel ajanın bulgusu doğru: 3,0 × 0,42 sn = 72,2°, yani tam bir plaka aralığı. Ekonominin önerdiği 2,0 rad/s ve görselin önerdiği 1,8 rad/s kullanıcının "çok yavaş" itirazıyla çatışıyor. Bu ikisini öneri olarak almıyorum. Benim önerim:
- **`SPIN` 3,0 → 3,6 rad/s.** Daha hızlı. Atış başına 86,6° dönüyor, plaka aralığının 1,2 katı; yani her atışta faz kayıyor.
- **±%20 hız dalgası** (sinüs, 2,7 sn periyot). Hız 2,9–4,3 rad/s arasında sürekli değişiyor ve hiçbir sabit tetik ritmi plakaya kilitlenmiyor.
- Rezonans noktaları 2,99 ve 5,98 rad/s; dalga bunların hiçbirinde 0,4 sn'den uzun kalmıyor.
- `LURCH` korunuyor.
- Gerçekçi dengesizlik modeli (dolu yıldız durur) kullanıcının hız isteğiyle çeliştiği için demoda yok.

Bedeli: ekonominin hesabına göre 3 rad/s'de bile $15–16 gerekiyordu. **Texas Star $15** olsun, plakalar ×1,3 büyüsün (görselin önerisi: 0,2 → 0,26 m, 1080p'de ~17 px). Böylece hız korunurken iyi oyuncu da kazanıyor.

### 3. Ödemelerde ekonomiyle ayrıldığımız yerler

| Konu | Benim 1. tur | Ekonomi | Karar | Neden |
|---|---|---|---|---|
| Popper | $3 | $2 (kafa $4) | **Ekonomi** | Benim isabet oranlarım tahmindi. Onlarınki ölçülmüş boyutla kalibre: popper karışık oyunda gelirin %51–61'ini alıyor. |
| Çelik raf | $4 | $3 | **Ekonomi** | Orta oyuncu için zaten en iyi yer (1,17×). |
| Köstebek | $6 | $8 | **Ekonomi**, ayrıca görselin `UP_MIN` 0,75 → 0,9 önerisi | 0,75 sn tek atımlık tabancayla neredeyse imkânsız. |
| Texas Star | $10 | $10 (2 rad/s'de) | **$15, 3,6 rad/s** | Kullanıcı sınırı (yukarıda). |
| Raylı dummy | çıkarılsın | $2, ilk basamak | **Ekonomi** | Simülasyon hareketin isabeti gerçekten düşürdüğünü gösteriyor (orta oyuncu %70 → %54). Ucuz ve okunaklı ilk "ikinci tür". Hitscan itirazım geçerli ama yanlış hedefe yönelmiş. |
| Gong / silüet | gong 2. basamak, silüet çıksın | ikisi de co-op şeridi | **Birleşik:** ikisi tek tür ("asılı çelik") sayılır, tek oyunculu dükkânda yok. Gong ayrıca kilometre taşı ve son mermi çanı. | Ekonominin dummy'ye eşitlik bulgusu doğru. Tören rolü ise ödemeden bağımsız. |
| Dükkân fiyatları | gong $30 … Texas $9.000, SMG $1.750 | karışık liste toplam $1.285, SMG ~$1.000 | **Ekonomi** | Benim gelir modelim çeşit ×5'i tam isabetle çarpıyordu ve geliri 3–5 kat abartıyordu. Fiyatlar 1. maddedeki kuralla yeniden simüle edilmeli. Benim kuralım ×4 kademesinden %15–35 fazla ödüyor, fiyatlar o oranda yukarı çekilmeli. |
| Dummy yıpranması | reddedildi | reddedildi | **Ortak** | Kötü oyuncunun en iyi hedefi dummy. |
| Taret ve kombo | taret çeşit almaz, oyuncunun V'si taretleri hızlandırır | "kombo yalnız elle" | **Ortak.** Komuta katmanını (taret hızı × (1 + 0,15 · tavan)) ekonominin taret simülasyonuna bırakıyorum. | — |

### 4. Görselin "8 px" bulgusu ve yerleştirme bölgem

- 1. turda önerdiğim bölge x 18–26,5 ve x ≥ 22'de ×1,5'ti. Bu, küçük plakaları en uzağa (atış hattından ~12,5 m) koymayı ödüllendiriyordu. Kullanıcının 1152×648 penceresinde orada 0,2 m'lik plaka **~7 px** ediyor. Görselin ölçümüyle bu çatışıyor; **düzeltiyorum:**
  - **Bölge x 19–25** (hattan 5–11 m). Bu, ekonominin "x ≥ 20" ve görselin "x = 21" önerilerinin ortası.
  - **Varsayılan önizleme konumu x = 21.**
  - **Uzak bant ×1,5 → ×1,25.** Büyük hedefler (dummy, asılı çelik) uzağa konabilir. Küçük plakalar (yıldız, köstebek) uzakta yalnızca %25 fazla ödediği için yakın konum çoğu oyuncuya daha iyi geliyor; kararı oyuncu veriyor.
- Ekonominin sürekli formülü (`clamp((d−5)/8, 0.25, 1.25)`) yerine iki boyalı bant kalsın. Yerdeki sarı çizgi ödemeyi görünür kılıyor (görselin E5 önerisiyle aynı dil).
- Görselin FOV 75 → 70 önerisi ucuz ve bu hesabı iyileştiriyor; destekliyorum.

### 5. QA bulgularının tasarıma etkisi

- **Hedef silinince Impacts havuzu bozuluyor (QA #2).** Benim "taşımak bedava" kuralım, düğüm silinip yeniden yaratılırsa bu hatayı her taşımada tetikler. Taşıma, **düğümün dönüşümünü değiştirerek** yapılmalı; silme yalnızca satışta olur (demoda satış yok). Havuz düzeltmesi yine de yerleştirmeden önce yapılmalı.
- **Hat ötesi atış hedefi tüketiyor (QA #4).** QA'nın sorusuna cevabım: yerleştirme modunda **silah iner**. Ayrıca sayılmayan isabet hedefi tüketmez (sadece ses ve kıvılcım). İkisi birlikte.
- **x10'da hedef zamanlayıcıları kısılıyor (QA #3)** ve **T para veriyor (ekonomi #9, QA #6).** İkisi de denge testinin ön koşulu. Bu düzeltmeler olmadan dükkân fiyatları x10 hile menüsüyle doğrulanamaz. Öncelik Y.

### Ortak öneri

1. **Zincir kalsın, tavanı çeşit açsın (Y, 2 sa):**
   - Kural: `ödenen çarpan = min(zincir, 1 + zincirdeki farklı tür sayısı)`.
   - 1,5 sn pencere, ıskada kırılma ve büyüyen yazı aynen kalır.
   - Tek dummy ×2'de tıkanır, her yeni tür tavanı +1 açar (en fazla ×7).
   - Taret, bant ve robot zincire girmez.
   - Büyük yazı zincir sayısını göstermeye devam eder (x100 görseli korunur); tavan altta tür ikonlarıyla görünür. Büyük yazının ne göstereceği kullanıcının kararı.
2. **Texas Star hızlansın, rezonans kırılsın (Y, 30 dk):** `SPIN` 3,6 rad/s + ±%20 hız dalgası (2,7 sn periyot), plakalar ×1,3, ödeme $15.
3. **Ödemeler ekonomi simülasyonuna göre (Y, 10 dk):** dummy 1, raylı 2, popper 2 (kafa 4), çelik raf 3, köstebek 8 (`UP_MIN` 0,9), Texas 15. Gong ve silüet tek tür ("asılı çelik") sayılır ve co-op şeridi olur; gong ayrıca kilometre taşı ve son mermi çanı. Dummy yıpranması yok.
4. **Dükkân ekonominin karışık listesi olsun (Y, 3–4 sa):**
   - Sıra: kapasite ve hedef kilitleri bir arada, sonra SMG ~$1.000.
   - Benim fiyatlarımı geri çekiyorum; benim gelir modelim abartıyordu.
   - Önce 1. maddedeki kuralla yeniden simüle edilmeli: bu kural ×4 kademesinden %15–35 fazla ödüyor.
5. **Yerleştirme modu (Y, 6–8 sa):**
   - Q'dan satın al, önizleme belirir, raycast ile yerleştir; 0,5 m grid, 15° döndürme.
   - Bölge x 19–25, varsayılan konum x = 21.
   - Boyalı yakın/uzak bant: ×1 / ×1,25.
   - Taşıma düğüm silmeden yapılır.
   - Yerleştirme modunda silah iner; hat ötesi isabet hedefi tüketmez.
6. **Denge testinden önce ön koşullar (Y, 40 dk):**
   - Hedef zamanlayıcıları ham `delta` ile saysın (QA #3).
   - T para vermesin ve kapatınca mermi bırakmasın.
   - Impacts havuzu silinen hedefe dayanıklı olsun (QA #2).
7. **Sistem bağlantıları 1. turdaki gibi (O):**
   - Anahtarlar yığında, otomasyon gelince bant ağzında.
   - Kasalar seken, delici ve patlayıcı mermi verir; bunlar yerleşimi ödüllendirir.
   - Taret yalnız sabit türlere ateş eder ve zincirsizdir.
   - Komuta katmanı ekonominin taret simülasyonu ile onaylanırsa eklenir.
   - 99M kilometre taşı, son mermi gonga.
8. **Küçük hedeflerin okunurluğu (Y, 1 sa):** görselin K1 (popper, köstebek ve yıldıza çelik sesi), K2/E3 (uzaklıkla ölçeklenen kıvılcım) ve K6 (kenarlı nişangâh) önerileri. 8 px'lik bir hedef ancak sesle ve kenarlı nişangâhla oynanabilir.

Kaynaklar: [Steel Challenge (Wikipedia)](https://en.wikipedia.org/wiki/Steel_Challenge), [USPSA Steel Challenge kuralları 9.3](https://rules.uspsa.org/scsa/section/9.3), [Find The Needle tanıtımı (MEmu)](https://www.memuplay.com/blog/?p=57464).
