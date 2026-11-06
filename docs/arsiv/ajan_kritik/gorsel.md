# Görsellik ve oyun hissi kritiği (ajan: gorsel, 2026-10-19)

Kanıt:
- Oyun açıktı (Beckett: `playing: true`, main.tscn). Kullanıcının oyununa dokunmadım, sadece iki ekran görüntüsü aldım. Beckett Lite girdi gönderemediği için kamerayı hedeflere çeviremedim. Kamera yığına bakıyordu.
  - `scratchpad/agents/gorsel/shot1.png`, `shot2.png` (1152×648, oyun içi)
- Hedefleri Blender 5.2 ile `main.tscn`'deki konumlarına koyup atış hattından (oyun x = 13,6, göz 1,6 m) oyunun kamerasıyla render ettim: dikey FOV 75° (Godot varsayılanı, `player.tscn`'de değiştirilmemiş), 1920×1080. Ortam, ışık ve gölge temsilî; boyut ve kadraj gerçek.
  - `scratchpad/agents/gorsel/view_center.png`: dummy, silüet, gong, popperlar, çelik raf
  - `scratchpad/agents/gorsel/view_star_racks.png`: yıldız, plaka rafı, çelik raf, popperlar (z = −16,5'te dururken)
  - `scratchpad/agents/gorsel/view_star_zoom.png`: yıldıza 20° FOV ile yakın bakış
- Hedef boyutlarını headless Godot ile modellerden ölçtüm (geçici `tools/agent_gorsel_sizes.gd`, iş bitince silindi).
- Karalama klasörü: `C:\Users\vedat\AppData\Local\Temp\claude\C--Users-vedat-projeler-mermi-yigini\1ac33e2e-342e-4fa3-b131-4175cf24154f\scratchpad\agents\gorsel\`

## Özet (5 madde)

1. **Üç hedef tamamen sessiz.** Popper, plaka rafı ve Texas Star'ın `hit_sound`, `rise_sound` ve `reset_sound` yuvaları boş; `.tscn` dosyalarında hiçbir ses atanmamış. Gerçek bir poligonda çelik vuruşunu asıl doğrulayan "ting" sesidir. Hazır `light.tres` ve `heavy.tres` bağlanırsa 10 dakikada biter. **(Y)**
2. **İsabet efektleri 10 m'den görünmüyor.** Kıvılcım 2 mm × 3 cm, toz zerresi 6 mm; atış hattından bakınca 1080p'de kıvılcım 0,14 × 2 px, toz 0,4 px tutuyor. Renk 1,0'da kaldığı için glow da tetiklenmiyor (eşik 1,3). Çelik vuruşunu şu an yalnızca plakanın hareketi ve 8 px'lik iz anlatıyor. **(Y)**
3. **Küçük hedefler 1152×648 pencerede 8 px.** Yıldız plakası, plaka rafı plakası ve popper kafası 0,2 m. 10,4 m'de 1080p'de 13,5 px, kullanıcının penceresinde 8 px ediyor. Nişangah 4×4 px beyaz nokta ve beyaz plakanın üstünde kayboluyor. **(Y)**
4. **İki hedef paketi iki ayrı dil konuşuyor.** "Shooting Target Set" (popper, raf, yıldız) beyaz boyalı. "Steel Targets Pack" (gong, silüet, çelik raf) siyah çelik. Siyah plakalar gri beton duvarın önünde zor okunuyor, kurşun izi de siyah üstünde kayboluyor. Çelik izinin ortasındaki siyah delik de yanlış: kurşun çelikte delik açmaz, gri bir sıçrama bırakır. **(O)**
5. **Yıldız 3 rad/s'de tam "rezonansta" dönüyor.** Plaka aralığı 72°, ateş aralığı 0,42 s; yıldız iki atış arasında tam olarak bir plaka dönüyor (3 × 0,42 = 1,26 rad ≈ 72,2°). Tek noktaya park edip tetiği basılı tutan oyuncu, sarsıntı bitene kadar her atışta bir plaka denk getiriyor. Ayrıca gerçek bir Texas Star dolu ve dengeliyken durur, plaka düştükçe dönmeye başlar. **(O)**

## İyi, kalsın

- **`hanging_steel.gd`:** Gerçek sarkaç fiziği var. Kaldıraç kolu, isabet noktasına göre dönme ve hafif plakanın baradan dönüp geçmesi doğru davranışlar. Ağır gong ile hafif raf plakasının farkı (6 kg / 1,2 kg) gözle seçiliyor.
- **`dummy.gd`:** Yay, sıkışma, ekleme (additive) parlama ve kumaş yüzeyine yeniden atılan ışın (`cloth_hit`) iyi çalışıyor. `MAX_TIP` seri atışta dummy'nin katlanmasını önlüyor. Kaide ile gövde ayrımı inandırıcı.
- **`popper_target.gd`:** Düşerken isabet almaması (`_shape.disabled` hemen kapanıyor) seri atışta doğru. Yere çarpıp `BOUNCE` ile sekmesi de doğru.
- **`payout_pop.gd`:** `fixed_size` sayesinde "+$" uzaktan da aynı boyda okunuyor. Zayıf noktada altın rengi ile normal isabette yeşil ayrımı net. Havuz kullanılıyor.
- **`combo_meter.gd`:** Logaritmik büyüme ve süre çubuğu yerinde. ×100 ekranı kaplamıyor.
- **`hit_marker.gd`:** Klasik dört çizgi, 0,22 s ve zayıf noktada altın renk. Endüstri standardı, dokunmayın.
- **`impacts.gd`:** Havuz, `decal_parent` ile izin sallanan plakada kalması ve dummy deliğinden çıkan tütme incelikli işler.
- **Mermi izi (`bullet_trail.gdshader`):** Kameraya dönük şerit ve 0,35 s ömür doğru. Tracer abartısına kaçmıyor.
- **Para sayacı zıplaması (`player.gd:278`):** Kısa ve yeterli.
- **Korkuluğun sarısı**, zemindeki sarı yürüyüş çizgileriyle aynı ailede (shot1.png'de solda). Tutarlı.

## Kötü, düzelsin

| # | Yer | Sorun | Öneri | Öncelik | Süre |
|---|---|---|---|---|---|
| K1 | `scenes/popper_target.tscn`, `plate_rack.tscn`, `texas_star.tscn` | `hit_sound`, `rise_sound`, `reset_sound` boş. Bu hedeflere isabet tamamen sessiz. Plaka rafında yeni kalkan plakayı haber veren ses de yok; 8 px'lik plakayı oyuncu ancak gözüyle tarayarak buluyor. | Popper hit: `heavy.tres`. Raf ve yıldız hit: `light.tres` (+3 dB). Kalkma ve geri gelme sesi için şimdilik `dry.wav` ya da `mag_seat.wav` kısılarak (pitch 0,7, −10 dB) kullanılabilir; gerçek bir "clack" kaydı gelene kadar yer tutar. | **Y** | 10 dk |
| K2 | `scenes/impact_fx.tscn` Sparks (`spark_mesh`: r = 0,001, h = 0,03) | 10 m'de çizgi 0,14 px genişliğe düşüyor ve görünmüyor. Renk 1,0 olduğu için glow da yok (`glow_hdr_threshold` 1,3). | Kıvılcım silindiri r = 0,003, h = 0,07. `spark_mat` için `albedo_color` 4,0 HDR çarpanı (ya da `emission`), amount 8 → 14. Gerçek mermide kıvılcım nadir çıkar ama oyunda isabeti 10 m'den haber veren tek görsel bu. | **Y** | 20 dk |
| K3 | `impacts.gd` çelik dalı (`["Sparks"]`) | Çelikte kıvılcımdan başka bir şey yok. Gerçekte kurşun çeliğe çarpınca plakanın yüzeyi boyunca diske benzer gri bir toz ve parça püskürmesi olur. Uzaktan görülen asıl şey budur. | Çelik için yeni bir `LeadSpray` emitter'ı: 24 parçacık, 0,25 s. Yön normale dik bir disk (`spread` 90°, `flatness` 1), hız 4–8 m/s, 0,02 m'lik gri billboard. Yanında 0,06 s'lik tek bir beyaz flaş quad'ı (0,15 m, additive), 10 m'den 10 px eder. | **Y** | 45 dk |
| K4 | `impact_fx.tscn` Dust (`mote_quad` 0,006 m) | Iskaya duvar ya da zemin tozu 10 m'den görünmüyor. Oyuncu ıskasının nereye gittiğini göremiyor ve düzeltemiyor. | Yumuşak bir puf billboard'u ekleyin: 0,25 m → 0,6 m büyüyen, 0,5 s, alfa 0,5. Mevcut zerreler yakın mesafe için kalsın. | **Y** | 30 dk |
| K5 | `materials/env/decals/bullet_mark_2_*.png` (çelik) | Ortadaki siyah nokta delik gibi okunuyor. Kurşun çeliği delmez; iz açık gri ya da gümüş bir leke ile ışınsal çizgilerden oluşur, boya kalkan merkez daha parlaktır. | `tools/draw_bullet_marks.gd` içinde tür 2 için merkezi siyah değil açık gri (0,75) yapın, halkayı koyu griye çekin. Boyutu 0,12 → 0,16 m: 10 m'de 8 → 11 px. | **O** | 20 dk |
| K6 | `scenes/player.tscn` Crosshair (4×4 beyaz `ColorRect`) | Beyaz plakanın, parlak gökyüzünün ve altın yığının üstünde kayboluyor (shot1.png'de yığının üstünde zar zor seçiliyor). | 1 px siyah kenarlı 4 px nokta. En ucuzu, `hit_marker.gd` gibi bir `_draw` ile `draw_circle` siyah r = 3,5, ardından beyaz r = 2. | **Y** | 10 dk |
| K7 | `scripts/texas_star.gd:13` `SPIN := 3.0` | (a) Rezonans: 3 × 0,42 s = 72,2° = plaka aralığı. Park et ve basılı tut stratejisi. (b) Plaka 126 px/s hızla geçiyor ve 1152p'de 8 px; tek atımlık tabancayla bunaltıcı. (c) Gerçekte dolu yıldız dengede durur, düşen plaka dengesizlik yaratıp döndürür. | Dengesizlik modeli: tork `Σ(düşen plakaların açısı)` üzerinden, sönümlü, taban hızı 0. Gerçek davranış ve gerçek beceri budur. Daha ucuzu: `SPIN` 1,8 rad/s (rezonanstan uzak, 3,5 s'de bir tur), `LURCH` 1,2 → 1,6. | **O** | 15 dk (ucuz) / 1,5 sa (dengesizlik) |
| K8 | `tools/build_arena.gd:365-379` `_firing_line` | Korkuluk keskin kenarlı `BoxMesh` kutulardan oluşuyor. Sundurmanın her parçası pahlı ve weighted normal'li (CLAUDE.md), bu yüzden korkuluk "geliştirici kutusu" gibi duruyor. Gerçek korkuluk 42–48 mm boru olur. | Ray ve dikmeleri `CylinderMesh` (r = 0,024, 12 segment) yapın, dikme altına mevcut taban plakası kalsın. Yerde x = 14'te 10 cm'lik sarı bir "atış hattı" boya çizgisi yok; mevcut `_decal` ve `line` dokusuyla tek satırda eklenir. Gerçek poligonlarda çizgi boyalı olur ve oyuncu "neden para vermedi"yi buradan anlar. | **O** | 30 dk |
| K9 | Steel Targets Pack (`gong`, `silhouette`, `plate_rack.glb`) siyah | Shooting Target Set beyaz. İki dil yan yana duruyor (view_center.png: siyah gong ve silüet, beyaz popperlar). Siyah plakalar gri beton duvarın önünde zayıf kalıyor ve izler siyahın üstünde kayboluyor. | Tüm çelik hedefler için tek bir boya: beyaz (0,85) ya da poligonlarda yaygın turuncu/sarı. `hanging_steel.gd` içinde `Plate*` mesh'lerine `albedo_color` çarpanı vermek yeterli; doku kalır, sadece tonlanır. Taban ve iskelet koyu kalsın: kontrast işi görür. | **O** | 20 dk |
| K10 | `texas_star.gd:157-165` `_put_back` | Plaka 0,01'den büyüyerek "biter". Gerçekçi PBR sahnede büyülü duruyor. | Plaka yerinde 0,15 s'de belirsin (alfa ya da `scale` 0,8 → 1). `reset_sound` ile birlikte daha az göze batar. Yerdeki düşmüş plaka 1,5 s'de aniden yok oluyor; aynı anda kaybolmalı. | **D** | 20 dk |
| K11 | `hanging_steel.gd:34` `SHIVER := 0.003` | 3 mm titreme 10 m'de 0,2 px; görünmüyor, işe yaramıyor. | Ya 0,01'e çıkarın ya da silin. Asıl titreşim hissini ses veriyor. | **D** | 2 dk |
| K12 | HUD `Counter` (`player.tscn:92`) | 20 px düz beyaz, kenar ve gölge yok. Gökyüzü ya da beton parlak olunca okunmuyor (shot1.png'de çatı arkasında ancak okunuyor). Para göstergesi ise kenarlı ve 40 px: iki farklı stil. | `Counter`'a `outline_size` 6, siyah %60 verin. "SINIRSIZ MERMİ (T)" test yazısı ayrı ve kırmızı olsun. | **O** | 10 dk |
| K13 | Eldiven dokusu (`arms_gloved_baseColor.png`) | Coyote/ten rengi eldiven ten rengine çok yakın. Oyunda çıplak el gibi görünüyor (shot1.png). | Eldiveni koyulaştırın (0,25–0,3 parlaklıkta zeytin ya da siyah) ya da 3. şahısta da aynı tonu kullanın. 3. şahısla tutarlılık kuralı için eldiven rengi orada da değişmeli. | **D** | 30 dk |

## Eklensin

| # | Ne | Neden | Öncelik | Süre |
|---|---|---|---|---|
| E1 | **Ses gecikmesi:** isabet sesini `mesafe / 343` s geciktirmek | 10 m'de 29 ms, 25 m'de 73 ms. Gerçek poligonda "bang … ting" aralığı uzak çeliğin imzasıdır. Çok ucuz: `KIT.play` içinde `await get_tree().create_timer(d/343)`. | O | 15 dk |
| E2 | **UI isabet tıkı:** hit marker'la birlikte kısa, sabit bir "tık" (2D, mesafeden bağımsız) | 3D ses 10 m ve reverb ile yumuşuyor. Çoğu FPS isabeti 2D tıkla doğrular; yalnızca para veren isabette çalsın. | O | 15 dk |
| E3 | **Uzaklıkla ölçeklenen efekt:** `impacts.gd` FX transform'una `max(1, d/4)` ölçek | K2–K4'ü tek satırda kısmen çözer: yakında doğal, uzakta okunur. Oyunlarda yaygın hiledir. | Y | 10 dk |
| E4 | **Plaka rafında kalkan plakaya ipucu:** kalkış anında 0,1 s beyaz parlama (dummy'deki `_flash` overlay yöntemi) | 8–13 px'lik plakayı göze çeker. Ses (K1) gelene kadar tek ipucu. | O | 20 dk |
| E5 | **Atış hattı tabelası ve zemin çizgisi** (K8'in devamı) | Ödeme kuralı görünür olur. Yazı yerine yere "→ 🎯 ←" ikon decal'ı (iletişim ikonla kuralına uygun). | D | 20 dk |
| E6 | **FOV ayarı:** varsayılan dikey FOV 75 → 70 | Yatayda 107° → 102°, hedefler %12 büyür. Bütün FOV ayarı ileride menüye. | D | 5 dk |

## Çıkarılsın

- `hanging_steel.gd` `SHIVER` (K11), büyütülmeyecekse.
- CLAUDE.md'deki "İsabet sesi henüz yok (`HitSound` boş)" notu eskimiş: `dummy.tscn:51`'de `hit.tres` atanmış, 18 kayıt var. Notu düzeltin; boş olanlar popper, raf ve yıldız.

## Sayılar

Hesap: dikey FOV 75°, odak f = (H/2) / tan 37,5°. 1080p'de f = 704 px, 648p'de (kullanıcının penceresi) f = 422 px. Atış hattındaki göz x ≈ 13,6, hedefler x = 22,5–24 → d ≈ 9–10,4 m. Piksel = boyut × f / d.

| Hedef | Ölçülen boyut (m) | d (m) | 1080p (px) | 648p (px) | Yorum |
|---|---|---|---|---|---|
| Texas Star plakası | 0,20 (yuvarlak) | 10,4 | 13,5 | 8 | Dönerken 126 px/s. Sınırda. |
| Plaka rafı plakası (whack) | 0,20 × 0,26 | 10,4 | 13,5 × 17,6 | 8 × 10,5 | 0,75 s'de, 0,36 m aralıkta (24 px). Ses yoksa zor. |
| Popper (tüm / kafa) | 0,20 × 0,70 / ≈0,2 | 9,9 | 14 × 50 / 14 | 8,5 × 30 / 8,5 | Gövde rahat, kafa zor. |
| Çelik raf plakası | 0,30 × 0,41 | 10,4 | 20 × 28 | 12 × 17 | İyi. |
| Gong | 0,46 × 0,53 | 10,4 | 31 × 36 | 19 × 21 | İyi. |
| Silüet | 0,51 × 0,82 | 9,9 | 36 × 58 | 22 × 35 | İyi. |
| Çelik izi (decal) | 0,12 | 10 | 8 | 5 | 0,16 m önerisi: 11 / 7 px |
| Kıvılcım | 0,002 × 0,03 | 10 | 0,14 × 2 | 0,08 × 1,3 | Görünmez. 0,006 × 0,07 → 0,4 × 5 px + glow |
| Toz zerresi | 0,006 | 10 | 0,4 | 0,25 | Görünmez. 0,25–0,6 m puf ekleyin. |

Önerilen değerler:
- **Yıldız `SPIN` 3,0 → 1,8 rad/s.** Rezonanstan kaçar (1,8 × 0,42 = 43°, plaka aralığının 0,6'sı) ve plaka 75 px/s hızla geçer. `LURCH` 1,2 → 1,6, böylece düşen plaka hissi kuvvetlenir.
- **Küçük plaka hedefleri (yıldız, raf):** ya ölçek ×1,3 (0,2 → 0,26 m, 1080p'de 17,6 px; oyunlarda yaygın abartı) ya da x = 24 → 21, yani d ≈ 7,4 m (19 px). Atış hattına yaklaştırmak gerçekçiliği bozmaz; gerçek poligonda da 7 m'de 8" plaka standarttır.
- **Plaka rafı `UP_MIN` 0,75 → 0,9 s.** 0,42 s ateş aralığı + ~0,25 s tepki + 24–120 px'lik nişan kaydırma, 0,75 s'yi tek atımlık tabancada neredeyse imkânsız yapıyor.
- **Kıvılcım:** amount 14, lifetime 0,35, r 0,003, h 0,07, renk ×4 HDR.
- **Çelik isabet sesi:** `KIT.sound` `unit_size` 8 iken `hanging_steel` 14 ve `max_db` 6 kullanıyor. Hepsi 14 / 6 olsun, ki çelik sesleri aynı yükseklikte duyulsun.

## Diğer ajanlara sorular

- **Ekonomi ajanı:** `game_state.gd:250` ödemesi `hit_gold × zayıf × combo` doğrusal. ×20 kombo yıldızda "+$120" yazdırıyor. Görsel olarak `payout_pop` bunu taşıyor ama tasarım bu büyüklüğü istiyor mu? "+$" yazısı tek isabet değeri mi, kombo dahil toplam mı göstermeli?
- **Tasarım ajanı:** Yıldız ve plaka rafı tek atımlık tabanca döneminde mi açılıyor? `LockedTargets` sırası belliyse küçük hedeflerin ölçeği ve hızı ona göre seçilmeli (K7 ve Sayılar).
- **Ses ajanı / kullanıcı:** Popper ve raf için kalkma "clack" sesi, yıldız için reset sesi kayıtları var mı? Yoksa Freesound'dan CC0 "metal target reset" araması öneririm.
- **QA:** Hiçbir ekran görüntüsünde hedefleri oyun içinden göremedim (Beckett Lite kamera çeviremiyor). Kullanıcı atış hattında dururken hedeflere bakan bir ekran görüntüsü alırsa K9 (siyah/beyaz kontrast) ve K2–K4 oyun ışığında doğrulanmalı.

---

## 2. tur: tartışma

Okunanlar: `ekonomi.md`, `tasarim.md`, `qa.md`. Kullanıcının koyduğu sınırları veri kabul ettim:
- Texas Star hızlı dönecek.
- Kombo zinciri ve xN göstergesi kalacak.
- Hedefler ilerledikçe açılacak ve yerleştirme moduyla konacak.

### 1. Texas Star: hızlı kalsın, rezonans kırılsın

İlk turdaki `SPIN 1,8` önerimi geri çekiyorum. Ekonominin 2,0 önerisi de kullanıcının "çok yavaş" geri bildirimiyle çatışıyor. Asıl sorun hız değil, **sabit** hız:
- 3,0 rad/s × 0,42 s = 72,2°, yani tam bir plaka aralığı (72°). Tek noktaya park edip tetiği basılı tutmak işe yarıyor.
- Rezonans hızları 2,99 ve 5,98 rad/s, ayrıca yarım katı olan 1,50 rad/s.

Öneri (üçü birlikte, `texas_star.gd`, ~1–1,5 sa):

1. **Değişken hız.** `ω(t) = 3,0 · (1 + 0,25 · sin(2π t / 3,7)) + lurch`.
   - Ortalama hız 3 rad/s'de kalıyor, kullanıcının istediği hız korunuyor.
   - Anlık hız 2,25 ile 3,75 rad/s arasında geziyor. Bir atıştaki dönüş 54° ile 90° arasında kayıyor, plaka aralığına (72°) yalnızca anlık olarak denk geliyor. Park et ve bekle stratejisi en fazla bir iki atış tutar.
   - 3,7 s'lik periyot ateş aralığıyla (0,42) ve kombo penceresiyle (1,5) ortak kat vermiyor.
   - **Okunabilirlik:** Değişken hız oyuncuya **okunacak bir ritim** veriyor. Yıldız her ~3,7 s'de bir "nefes alıyor", yavaşladığı yarım saniye nişan penceresi oluyor. Bu, rastgele hızdan çok daha adil. İyi oyuncu yavaşlamayı bekler, acelesi olan hızlıda dener. Beceri kararı ekrandan okunuyor.
2. **Dengesizlik salınımı (gerçek Texas Star davranışı).** Plaka düştükçe kalan plakaların ağırlık merkezi göbekten kayar. `τ = −m g · r_cm · sin(θ + φ_cm)` torku sürüşün üstüne eklenir.
   - 3 ve üstü plaka düştüğünde yıldız tekdüze dönmek yerine **sarkaç gibi hızlanıp yavaşlar**, ağır taraf aşağıda bir an asılı kalır. Gerçek poligonda yıldızın imzası budur.
   - Görsel olarak düşen plakanın sonucunu gösterir: "bir plaka gitti, yıldız topalladı".
   - Taban sürüş korunur, yani yön hiçbir zaman tamamen tersine dönmez. Yön değiştirmeyi önermiyorum: ani yön değişimi 13 px'lik hedefte okunmaz, oyuncuya haksızlık gibi gelir.
3. **Lurch'ü koruyun, 1,2 → 1,6 rad/s.** Plaka düşünce hızlanma artık "hızlı" hissini besleyen bir ödül. Ortalama hız arttığı için kullanıcının isteğiyle aynı yönde.

Hızlı dönen hedefi okunur tutan iki ek:
- **Interpolasyon kapalı (QA madde 5).** `_arm` `_process`'te taşınıyor ama `physics_interpolation` açık; 0,014–0,021 rad sapma ölçülmüş. Yavaş hedefte ihmal edilebilir, 3,75 rad/s'de yüksek Hz ekranda kolun titremesi olarak görünür. Hızlı yıldız için önceliği **D'den Y'ye** çekiyorum (2 dk).
- **İz hatası (QA madde 1).** Kurşun izi komşu plakaya yapışıyor. Dönen yıldızda "vurdum ama iz başka plakada" çok göze batar. Y, 10 dk.

Boyut tarafında: hız korunacaksa plakanın kendisi okunur olmalı. Yıldız plakaları **0,20 → 0,26 m** olmalı: 1080p'de 17,6 px, kullanıcının 1152×648 penceresinde 10,5 px. Ekonominin Texas Star ödemesi ($10 ya da 3 rad/s'de $15–16) bu büyütme hesaba katılarak simülasyonda yeniden ölçülmeli.

### 2. Kombo göstergesi: ekonominin ×4 tavanı ve tasarımın çeşit çarpanı

Değişmeyen kural şu: **ekranda büyük yazılan sayı, ödemeyi çarpan sayı olmalı.** "x37" yazıp "+$4" ödemek, oyuncunun ilk 10 saniyede "bozuk" diyeceği bir kopukluk. Gösterilen sayı ile ödenen çarpan ayrılırsa kafa karışır; ayrılmamalı.

Ama zincir sayısı ile çarpanın **birlikte** gösterilmesi bilinen ve iyi okunan bir kalıp. Referans Guitar Hero ve Rock Band: büyük "×4" çarpan, yanında 10'ar notada dolan dilimli halka ve ayrıca seri sayısı. Oyuncu ikisini ayırt ediyor, çünkü **tipografi ve konum farklı.**

Ekonominin kademeli tavanıyla (×1,1,2,2,3,3,4) kullanıcının tarifini koruyan şema, `combo_meter.gd` (~1 sa):

| Öğe | Ne gösterir | Kullanıcının tarifiyle ilişkisi |
|---|---|---|
| Büyük yazı `x2` | **Ödenen çarpan** (×1'de gizli) | "xN" biçimi aynen kalıyor |
| Yazı boyu ve rengi | **Zincir** uzunluğu, logaritmik: beyaz → altın → kırmızı, taramalıda zincir 100'de en büyük ve kırmızı | Logaritmik büyüme ve x100 hissi aynen kalıyor. Büyüyen şey sayı değil, yazının kendisi. |
| Solan cam bar | Kombo penceresi (1,5 s) | Aynen kalıyor |
| Barın altında küçük gri `37` | Zincir sayısı | Yeni; küçük ve gri, karışmıyor |
| Barın üstünde 2 pip | Sonraki kademeye kalan isabet | Ekonominin önerisi |

Böylece SMG ile 100'lük zincirde ekranda kocaman ve kırmızı bir **x4** ile altında küçük bir "100" görünür. Oyuncu hem "çok uzun zincir yaptım" hissini (yazı devleşti, kırmızı oldu) hem doğru ödemeyi okur. Kademe atlarken (x3 → x4) ekstra bir punch (`PUNCH` 0,35 → 0,7) ve bir "tık" sesi, kademeyi ses ve hareketle de ayırır.

**Tasarımın çeşit çarpanı:** Kullanıcı zinciri tuttuğu için çeşit çarpanı zincirin **yerine** geçemez. İkisinin **üst üste** ekranda durması da (zincir ×4 + tür ×5 + kafa ×2) bir nişan oyununda yönetilemeyecek kadar sayı demek. Görsel önerim:
- Çeşit çarpanı alınacaksa ikinci bir sayı olarak değil, **zincire beslenen bir kural** olarak gelsin. Örnek: farklı türe geçen isabet zinciri +2, aynı türe isabet +1 artırır. Yazı aynı kalır, hedef değiştirmek sadece zinciri daha hızlı büyütür.
- Görsel karşılığı: farklı türe geçilen isabette barın parlaması ve yazının hafif renk atlaması. Yeni ikon şeridine gerek yok.
- Tasarımın "gösterge hedeften hedefe zıplıyor" eleştirisi (combo_meter.gd:33) doğru. Çok hedefli süpürmede yazı her isabette 2–3 m sıçrıyor. Öneri: yazı hedef başına değil **nişangâhın sağ altında sabit** dursun (+48, +24 px). "+$" pop hedefin üstünde kalsın. Bu konum değişikliği kullanıcının tarifini bozmuyor; bar, yazı ve büyüme aynı.

### 3. Yerleştirme bölgesi x 18–26,5 ve "uzak ×1,5": piksel hesabı

Göz atış hattında x ≈ 13,6. Bölge x 18–26,5 → d = 4,4–12,9 m. f = 704 px (1080p) / 422 px (648p).

| Hedef özelliği | x 18 (d 4,4) | x 22 (d 8,4) | x 24 (d 10,4) | x 26,5 (d 12,9) |
|---|---|---|---|---|
| 0,20 m plaka (yıldız, köstebek, popper kafası), 1080p / 648p | 32 / 19 px | 17 / 10 px | 13,5 / 8 px | **10,9 / 6,5 px** |
| 0,26 m (büyütülmüş plaka önerisi) | 42 / 25 | 22 / 13 | 17,6 / 10,5 | 14 / 8,5 |
| 0,30 × 0,41 çelik raf | 48 × 66 | 25 × 34 | 20 × 28 | 16 × 22 |
| 0,46 gong | 74 | 39 | 31 | 25 |
| dummy kafası 0,30 | 48 | 25 | 20 | 16 |

Değerlendirme:
- Okunabilirlik eşiği olarak **en küçük vurulacak parça ≥ 10 px (1080p)** kabul ediyorum. 4 px'lik nişangah noktasının 2,5 katı; altında hedef, nişangahın kenar çizgisiyle (K6) aynı boya iner.
- **Büyük hedefler** (gong, dummy, çelik raf) için bölgenin tamamı ve ×1,5 sorunsuz: en uzakta bile 16–25 px.
- **0,20 m plakalar** x 26,5'te 1080p'de 10,9 px, kullanıcının penceresinde 6,5 px. ×1,5 ödeme bu küçülmeyi karşılamıyor. Mesafe 8,4'ten 12,9'a çıkınca açısal boyut ×0,65, açısal alan ×0,42 oluyor. Orta oyuncunun isabeti yaklaşık yarıya iner (ekonominin T1'inde köstebek 19,6 m'de %18).
- Öneri: **plakalar 0,26 m'ye büyüsün** (her durumda) **ve hareketli küçük hedefler (yıldız, köstebek) için bölgenin uzak sınırı x 24 olsun.** Sabit hedefler 26,5'e kadar gidebilir. ×1,5 bandı (x ≥ 22) kalsın.
- Bant ölçüsü hattan alınıyor, bu doğru. Zemine boyanan "YAKIN / UZAK" çizgisi, ilk turdaki atış hattı çizgisi önerimle (K8) aynı sarı boya dilinde olsun. Zeminde üç paralel sarı çizgi: x 14 (hat, kalın), x 18 (bölge başı, kesik), x 22 (uzak bant, kesik). Yazı yerine yere ikon: tek çentik ×1, çift çentik ×1,5.

**Açılış ve yerleştirme anının görsel sunumu** (yerleştirme modunun içinde, ~3–4 sa):

1. **Mağazada:** Kilitli hedef "?" silüeti (tasarımın önerisi). Para yetince Q ikonu yanıp söner.
2. **Önizleme:** Modelin kendisi, saydam beyaz Fresnel kenar ışıması ile (%35 alfa). Holografik mavi kullanılmasın; PBR sahnede bilim kurgu gibi durur.
   - Geçersiz yerde kırmızı, geçerlide beyaz.
   - Altında zemine sarı boya dilinde **taban izi dikdörtgeni** (decal). Yıldız ve köstebek için dönme çapı ve tarama genişliği de çizilsin.
   - Önizlemede **hedefin uzaklık bandı ikonu** ve 1080p'deki en küçük parça boyu belirsin. Yazı değil, renk yeterli: 10 px altıysa ikon turuncu.
3. **Yerleştirme anı:** Hedef 0,3 m yukarıdan 0,15 s'de **düşer**. Ağır metal "tok" sesi (çelik ayak betona; `mag_seat.wav` pitch 0,5 geçici olur). Ayakların çevresinde beton tozu halkası (K4'teki puf emitter'ı yeniden kullanılır).
4. **Kendini sınama (en önemli kısım):** Hedef konduğu anda bir kez kendi hareketini oynasın.
   - Popper yatıp `rise_sound` ile kalkar.
   - Köstebek tüm plakaları sırayla bir kez kaldırır.
   - Yıldız 0'dan 3 rad/s'ye 1,5 s'de **hızlanarak** döner. Kullanıcının istediği hızı ilk saniyede gösterir.
   - Gong bir kez kendi çalar.
   Oyuncu yeni hedefin neyi sorduğunu tek bakışta görür. Yazılı açıklamaya gerek kalmaz (iletişim ikon ve hareketle kuralına uygun).
5. **Işık:** Ek spot ışığı önermiyorum; 35 sarkıt lamba zaten var ve gölgesiz. Onun yerine yerleşimden sonra 1,5 s'lik beyaz kenar parlaması (dummy'nin `_flash` additive overlay yöntemi). Ucuz, gerçekçi ışığı bozmuyor.
6. **İlk isabet:** Yeni hedefe ilk isabette "+$" pop'u ×1,5 boyutta ve hit marker altın renkte. Hedefin "açıldı" töreni böylece kapanır.

### 4. Raylı dummy, silüet ve beyaz/siyah paket

- **Silüet:** Tasarım çıkarılmasını, ekonomi co-op şeridi olarak kalmasını istiyor. İkisi çelişmiyor: **tek oyunculu demodan çıksın, co-op'ta ikinci şerit olsun.** Görsel olarak tek koşul, siyah Steel Targets paketinden geldiği için **beyaz boyanması** (K9).
- **Gong:** Tasarım gongu "son mermi" ve kilometre taşı çanı yapıyor. O zaman gongun **diğerlerinden farklı renkte** olması tutarsızlık değil, bir anlam taşır. Gerçek Steel Challenge'da stop plakası çoğunlukla **kırmızı** boyanır. Öneri: bütün çelik beyaz, **gong kırmızı** (0,55, 0,08, 0,05). Oyuncu "kırmızı = özel" diye okur, kilometre taşında kendi kendine çalan da o olur.
- **Çelik raf:** Kalıyor ve siyahtan **beyaza** boyanıyor. Böylece K9'daki iki paket tutarsızlığı tek bir boya kuralıyla kapanıyor: hedef yüzeyi beyaz, ayak ve iskelet koyu çelik, çan kırmızı.
- **Raylı dummy:** Tasarımın hitscan gerekçesi (önünü kestirme yok) doğru. Görsel tarafta tek kaybı, sahnedeki tek hareketli "yumuşak" hedef olması. Yerleştirme bölgesinde raylar 6,2 m zemin kaplıyor ve taban izi büyük. Demodan çıkmasına katılıyorum. `rail_mover.gd` kalsın; zırhlı dummy ya da taret hedefi olarak raya geri dönebilir.

### 5. Diğer raporlardan görsel/his açısından katıldıklarım

- **QA madde 4 (hat ötesinden atış hedefi tüketiyor):** Görsel karşılığı şu olmalı: hedef **ses ve kıvılcım versin, düşmesin**. "+$" yerine soluk gri ve üstü çizili bir `$` ikonu belirsin. Yazı yerine ikon, oyuncu kuralı ilk denemede öğrenir. O, 20 dk.
- **QA madde 8 (sesler)** benim K1 bulgumla aynı. Ortak bulgu, Y.
- **Tasarımın "[Q] hazır" yanıp sönmesi:** K12'deki sayaç kenar çizgisiyle aynı iş paketi.

### Ortak öneri

Nihai liste, önem sırasıyla:

1. **Sessiz hedeflere ses + 2D isabet tıkı** (Y, 25 dk). Popper ve raf için `heavy.tres` / `light.tres`, kalkma ve geri gelme için geçici `mag_seat`/`dry`. Yalnız para veren isabette 2D "tık". İsteğe bağlı mesafe/343 s gecikme. QA ve gorsel ortak bulgusu.
2. **10 m'den okunur isabet efekti** (Y, 1–1,5 sa).
   - FX ölçeği `max(1, d/4)`.
   - HDR kıvılcım (r 0,003, h 0,07, ×4).
   - Çelikte yüzeye paralel kurşun püskürmesi + 0,06 s flaş.
   - Iskada 0,25–0,6 m toz pufu.
   - Çelik izi gri, ortası siyah değil, 0,16 m.
3. **Texas Star hızlı ama rezonanssız** (Y, 1,5 sa).
   - Ortalama 3 rad/s, ±%25 sinüs ile 3,7 s periyot.
   - 3+ plaka düşünce dengesizlik salınımı.
   - `LURCH` 1,6.
   - Plakalar 0,26 m.
   - Kol interpolasyonu kapalı.
   - İz plakaya doğru yapışsın (QA 1).
4. **Nişangah ve HUD okunurluğu** (Y, 20 dk). 1 px siyah kenarlı nokta; sayaç yazısına kenar çizgisi; test yazısı kırmızı.
5. **Kombo göstergesi ödenen çarpanı yazsın** (O, 1 sa). Büyük `xN` ödenen çarpanı gösterir (ekonominin ×4 kademesi). Yazının boyu ve rengi zincirle logaritmik büyür ve 100'de kırmızıya döner. Zincir sayısı barın altında küçük ve gri, solan cam bar aynen kalır. Kademe atlamada çift punch ve tık. Yazı nişangahın sağ altında sabit dursun. Çeşit çarpanı ayrı bir sayı olmasın; gelecekse zinciri hızlandıran bir kural olarak gelsin.
6. **Yerleştirme sunumu ve bölge sınırı** (O, yerleştirme modu içinde 3–4 sa).
   - Fresnel beyaz önizleme ve sarı taban izi.
   - Düşüş + "tok" sesi + toz halkası.
   - Hedef konunca **kendini sınama** animasyonu, yıldız 1,5 s'de hızlanır.
   - Hareketli küçük hedeflerde uzak sınır x 24; zeminde x 14 / 18 / 22 sarı çizgileri.
7. **Tek boya dili** (O, 30 dk). Bütün hedef yüzeyleri beyaz, iskeletler koyu çelik, gong kırmızı (stop plakası / tören çanı). Silüet ve raylı dummy tek oyunculu demodan çıksın; silüet beyaz boyanıp co-op şeridi olsun.
8. **Korkuluk boru + hat ötesi isabet ikonu** (D, 50 dk). Korkuluk 24 mm silindir olsun. Hat ötesinden vurulan hedef düşmesin, sadece ses ve kıvılcım versin, gri üstü çizili `$` ikonu belirsin (QA 4).
