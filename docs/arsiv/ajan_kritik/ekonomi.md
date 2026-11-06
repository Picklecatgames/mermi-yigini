# Ekonomi ve denge raporu (ajan: ekonomi, 2026-10-19)

Bu rapor yalnızca okuma ve simülasyonla hazırlandı; oyun dosyalarında değişiklik yok. Hedef boyutlarını ölçmek için geçici bir `tools/agent_ekonomi_sizes.gd` betiği headless çalıştırıldı ve sonra silindi.

**Simülasyon betikleri** (karalama klasörü: `C:\Users\vedat\AppData\Local\Temp\claude\C--Users-vedat-projeler-mermi-yigini\1ac33e2e-342e-4fa3-b131-4175cf24154f\scratchpad\agents\ekonomi\`):
- `sim.py`: ana model, T1–T6 tabloları (`python sim.py`, yaklaşık 20 sn)
- `unit_e.py`: $1 hit_gold ile hedef başına $/dk; altın önerisi bu tablodan çıktı
- `tempo.py`: ilk 15 dakika, şimdiki ekonomi ile önerilen dükkân sırasının karşılaştırması
- `exploit.py`: T (sınırsız mermi) suistimali
- Çıktılar: `out.md`, `tempo_out.md`, `exploit_out.md`

## Özet (5 madde)

1. **Kombo tabancada şimdilik zararsız.** Bunu sağlayan bir tesadüf var: reload kombo penceresinden uzun. Son atıştan sonraki `fire_last` (0,467 s), `reload_empty` (1,23 s) ve `slingshot` (0,783 s) toplam 2,48 s tutuyor; pencere ise 1,5 s. Bu yüzden zincir her şarjörde kırılıyor ve 7'lik şarjörde en yüksek çarpan ×7 oluyor. **Taret gelince ekonomi patlıyor:** %100 isabetli, beslemeli tek bir taret dummy'de **dakikada $1,8 milyon** kazanıyor. Aynı taret kademeli ×4 tavanla dakikada $2.400 kazanıyor. T tuşu da (sınırsız mermi) bugün iyi oyuncuya ×5 gelir veriyor ve yığından hiç mermi harcatmıyor.
2. **Önerim kademeli tavan:** çarpan sırasıyla ×1, ×1, ×2, ×2, ×3, ×3, ×4 (formül `mini(1 + (zincir-1)/2, 4)`). Çarpanlar tam sayı kalıyor ve HUD'da okunuyor. ×4'e tam 7. isabette, yani dolu bir ağır tabanca şarjörüyle ulaşılıyor. SMG'nin tabancaya göre geliri ×4,8'den ×3,2'ye iniyor; taret ise sınırsız büyümek yerine dakikada $2.400'de kalıyor. Kombo yalnızca **elle atışta** işlemeli; taret, bant ve robot zinciri asla büyütmemeli.
3. **Hedef ödemeleri merdiven gibi değil.** Hepsi açıkken orta oyuncunun gelirinin **%61'i popper'dan** geliyor (kafa ×2 ile $6, hatta %80 isabet). En zor hedef Texas Star ise gelirin yalnızca **%1'ini** sağlıyor: $6 veriyor ama dakikada dummy'den az kazandırıyor. Silüet ve gong her oyuncu için dummy ile aynı $/dk'yı veriyor, yani gereksizler. Önerilen değerler: **popper $3→$2, köstebek $5→$8, Texas $6→$10 (dönüş 3→2 rad/s)**; dummy $1, raylı $2, raf $3, silüet/gong $2 kalıyor. Böylece iyi oyuncu Texas'ta ×2,6, orta oyuncu ×1,7 kazanıyor. Kötü oyuncu zor hedefte kazanmıyor ve dummy'de kalıyor (beceriye göre ayrışma).
4. **Tempo çok hızlı ve sonra harcayacak bir şey kalmıyor.** Hedefler fiilen kilitsiz olduğundan kapasite 7'ye iyi oyuncu 1,4 dk'da, orta oyuncu 3 dk'da ulaşıyor (koddaki yorum "~10 min" diyor). 15. dakikada iyi oyuncunun elinde $10.680, orta oyuncunun elinde $3.436 harcanmamış para birikiyor. Öneri: kapasite ve hedef kilitlerini tek bir dükkânda karışık sıralamak (11 kalem, toplam $1.285). Bu düzende iyi oyuncu dükkânı ~6 dk'da, orta oyuncu ~12 dk'da bitiriyor; ardından ~$1.000'lık bir sonraki silah geliyor. Dummy yıpranmasını önermiyorum: kötü oyuncunun en iyi hedefi dummy, yıpranma en çok onu cezalandırır.
5. **Suistimal açıkları:** (a) T tuşu sevkiyatta da açık, para ödüyor ve zinciri sonsuz yapıyor. (b) `request_fire` namlunun konumunu (`from`) istemciden alıyor; co-op'ta hile yapan bir istemci atış hattı kuralını kolayca aşar. (c) Yerleştirme modu gelince hedefi korkuluğun dibine koymak %100 kafa vuruşu demek; bir yerleştirme bölgesi şart. (d) Atış hattı ile yığın arasındaki 4 m'lik yürüyüş reload'un içinde kayboluyor. Bu suistimal değil ama taşıyıcı robotun tabanca döneminde kazandıracağı bir şey kalmıyor.

## İyi, kalsın

- **"Kapasite = kombo tavanı" ilişkisi** (`game_state.gd:41`, `:51`, `viewmodel.gd` CLIPS). Reload pencereden uzun olduğu için kapasite upgrade'i ikinci dereceden değer kazanıyor. 7 mermilik bir şarjör şimdi 1+2+…+7 = 28 birim, önerdiğim kademelerle 16 birim ödüyor. Kapasite 1→7 arasında iyi oyuncunun geliri dakikada $39'dan $469'a çıkıyor (×12). Böylece tek upgrade'in bile hissedilir bir değeri var.
- **Iska ve ayağa isabet zinciri kırıyor** (`game_state.gd:239`, `:255`; `target_kit.gd stand_body`). Kombo gerçek bir nişan ödülü oluyor.
- **Atış hattı kontrolü host'ta yapılıyor** (`game_state.gd:245`). Fikir doğru; yalnızca kullanılan veri istemciden geliyor (aşağıya bakın).
- **Kombonun hedefler arasında taşınması.** Oyuncu ilk mermileri kolay hedefe sıkıp zinciri kuruyor, son mermiyi zor ve pahalı hedefe atıyor; son mermide ıskanın bir bedeli yok. Simülasyondaki açgözlü oyuncu da bunu kendiliğinden buldu. Bu iyi bir beceri katmanı, kalsın.
- **Dummy kafası ×2.** İyi oyuncu 9–13 m'de kafayı %90 vuruyor, dummy onun için fiilen $2. Orta oyuncu için kafa ile gövde neredeyse başa baş, kötü oyuncu için gövde daha iyi. Yani zayıf nokta becerinin göstergesi olarak çalışıyor.

## Kötü, düzelsin

| # | Yer | Sorun | Öneri | Öncelik / süre |
|---|---|---|---|---|
| 1 | `game_state.gd:48-51`, `:250` | Kombo tavansız. Taret, minigun ya da reload'u kısaltan bir upgrade geldiğinde gelir zincir uzunluğunun karesiyle büyüyor (T4: %100 isabetli taret dakikada $1,8M). | `const COMBO_MAX := 4`, `func combo_mult(n): return mini(1 + (n - 1) / 2, COMBO_MAX)` ve `gold = hit_gold * weak * combo_mult(p.combo)`. Taret atışları ayrı bir istekle gelmeli ve `PlayerState.combo`'ya dokunmamalı. | Y, 1 sa (+ combo_meter ve combo_check güncellemesi) |
| 2 | `combo_meter.gd:9`, `:54`, `:59` | Zinciri "x%d" olarak gösteriyor, logaritmik büyüme ×100'e göre ayarlı. Tavan gelince yazının çarpanı göstermesi gerekir. | Yazı `x{çarpan}` olsun (×1'de gizli). Barın altında zincirden sonraki kademeye kalan isabet için 2 küçük pip gösterilsin. `MAX_COMBO` 4 olsun. | O, 1 sa |
| 3 | `tools/combo_check.gd:23-24` | Kademeli kombo gelince eski beklentiler bozulur. | Yeni beklentiler: 2. isabet kafada 1×2×1 = 2, 3. isabet ×2 = 2. Ayrıca bir assert: 9. isabet ×4. | Y (1 ile birlikte), 15 dk |
| 4 | `popper_target.gd:19` | $3 ve kafa ×2, %77–87 isabetle isabet başına $6 ediyor. Karışık oyunda iyi ve orta oyuncunun gelirinin %51–61'i buradan geliyor. | **$2** (kafada $4). Yatık kaldığı 2–3,5 sn yüzünden tek başına zayıf; karışık oyunda dolgu hedefi olarak kalsın. | Y, 2 dk |
| 5 | `texas_star.gd:10`, `:18` | 3 rad/s'de iyi oyuncunun bile isabeti %64, orta oyuncununki %30. $6 ile dakikada dummy'nin altında kalıyor ve gelirin %1'ini sağlıyor. | `SPIN` 3,0 → **2,0** (bir tur ~3 sn), `hit_gold` 6 → **10**. Hız aynı kalırsa ancak $15–16 yeterli olur. | Y, 5 dk |
| 6 | `plate_rack.gd:27` | $5 ile orta oyuncu için dummy'nin 0,95 katı, yani açtığına değmiyor. | **$8**. Tepki penceresi (1,6 → 0,75 s) iyi oyuncuyu ödüllendiriyor: ×2,2. | Y, 2 dk |
| 7 | `game_state.gd:39-42` | Yorum "son seviye ~10 dk" diyor; gerçekte iyi oyuncuda 1,4 dk, orta oyuncuda 3 dk (hedefler açıkken). Sonrasında harcanacak bir şey yok. | Kapasite fiyatları **$5/15/35/70/120/200**, hedef kilitleri de aynı dükkânda (Sayılar bölümünde). | Y, 3–4 sa (dükkân satırları + kilit) |
| 8 | `main.tscn:29` `LockedTargets` | Adı "kilitli" ama hiçbir kod kilitlemiyor; ekonomi bütün hedefler baştan açıkmış gibi işliyor. | Satın alınana kadar `visible = false` + `process_mode = 4` (CLAUDE.md'deki yöntem). Satın alma `request_buy_upgrade` ile aynı yoldan yapılsın. | Y (7 ile birlikte) |
| 9 | `player.gd:135-136`, `game_state.gd:217-222`, `:232` | T (sınırsız mermi) her derlemede çalışıyor; para ve kombo veriyor, yığından mermi harcatmıyor. İyi oyuncuya ×5 gelir (exploit tablosu). | T açıkken `gold = 0` olsun (efekt denemesi için kalır) ya da tuş yalnız `OS.is_debug_build()` içinde çalışsın. İlki tek satır. | Y, 10 dk |
| 10 | `game_state.gd:227`, `:245` | Atış hattı kontrolü istemcinin gönderdiği `from` ile yapılıyor. Co-op'ta hileli istemci `from.x = 13,9` gönderip hedefin dibinden ateş edebilir. | Host, oyuncunun **kendi bildiği** gövde konumunu kullansın: `from`, host'taki kafa konumundan 0,5 m'den fazla saparsa atışı reddetsin ya da para vermesin. | O (co-op başlarken), 1 sa |
| 11 | `dummy.tscn` Base/Pole şekilleri | Kaideye ve direğe isabet de $1 ödüyor ve zinciri sürdürüyor. Simülasyonda etkisi küçük (göğse nişanlı ıskaların ~%1'i). | Kaide `target` dışındaki ayrı bir gövdeye taşınsın (diğer hedeflerin `stand_body`'si gibi): para vermesin, zinciri kırsın. | D, 30 dk |

## Eklensin

- **Tek dükkân listesi** (Q menüsü): kapasite seviyeleri ve hedef kilitleri tek bir ilerleme listesinde. `UPGRADES` yapısı bunu zaten taşıyor; örneğin `"rayli": {"values": [0, 1], "costs": [30]}`. Hedef de `upgraded` sinyalini dinleyip açılır. Y, 3 sa.
- **"Kombo yalnız elle atış" kuralı** CLAUDE.md'ye yazılsın. Bu, "manuel ateş bonusu" fikrinin ta kendisi: orta oyunda oyuncunun aktif işi taretten ×4'e kadar fazla kazanmak. Y, 5 dk.
- **Sonraki silah eşiği** yaklaşık **$1.000**. Bu eşikle iyi oyuncu SMG'ye ~8. dk'da, orta oyuncu ~15–16. dk'da ulaşıyor. Önceki tempo tablosunda "Uzi 10–15. dk" vardı; $1.500 orta oyuncuyu ~19. dakikaya itiyor. O.
- **Yerleştirme bölgesi** (inşa modu gelince): hedefler yalnız x ≥ 20'ye konabilsin (korkuluktan en az 6 m). Ya da ödeme mesafeyle ölçeklensin: `hit_gold * clamp((d - 5) / 8, 0.25, 1.25)`. O, 1 sa.
- **Erken kilometre taşı:** tabanca döneminde yığın gözle küçülmüyor (aşağıya bakın). "İlk 1.000 mermi" ve "ilk 10.000 mermi" gibi küçük törenler bu dönemde ilerleme hissi verir. D.

## Çıkarılsın

- **Silüet ve gong, ilerleme basamağı olarak.** Simülasyonda $1 başına $/dk dummy'nin tam 0,50 katı çıkıyor; $2 ile her becerideki oyuncu için dummy'ye eşitler. Yeni bir beceri istemiyorlar. Bunları satın alınacak basamak olmaktan çıkarıp **co-op şeritleri** yapın: oyuncu sayısı arttıkça ücretsiz açılsınlar, çünkü 4 kişinin tek dummy'yi paylaşması zor. Tek oyunculu dükkânda yer almasınlar. Silüete ileride rehine çeliği gibi ceza bölgesi eklenirse yeniden değerlendirilir.
- **Dummy yıpranması** (CLAUDE.md'deki öneri). Kötü oyuncu için en iyi hedef dummy; diğer bütün hedefler onda dummy'nin 0,69–1,12 katı veriyor. Yıpranma en zayıf oyuncuyu ilerlemenin dışına iter. Hedef değiştirmeyi zaten yeni ödeme merdiveni sağlıyor. Yıpranma yalnız görsel kalsın (delikler, saman). "HP'li zırhlı dummy" taret dönemindeki karşılığı olarak kalsın.
- **Koddaki `MAX_COMBO := 100` varsayımı** (`combo_meter.gd:9`). Tavan gelince gereksiz.

## Sayılar

### Model ve varsayımlar

- **Oyuncu becerisi:** Dummy göğsüne nişanla 13,5 m'de iyi oyuncu %90, orta oyuncu %70, kötü oyuncu %45 isabet ediyor. Model iki parçalı: Gauss nişan saçılması (iyi 3,5, orta 6, kötü 10 mrad) ve kaba ıska oranı (iyi %10, orta %29, kötü %50; kalibrasyonla bulundu). Hareketli hedefte, hareket yönünde ek hata = hız × zamanlama hatası (iyi 0,06, orta 0,10, kötü 0,15 s).
- **Atış ritmi:** Atış aralığı en az 0,42 s; nişan süresi iyi 0,35, orta 0,45, kötü 0,6 s. Hedef değiştirmek iyi oyuncuya +0,2 s, orta oyuncuya +0,3 s, kötü oyuncuya +0,45 s ekliyor.
- **Reload:** Son atıştan sonra 2,48 s, ardından yeniden nişan (iyi 0,25, orta 0,5, kötü 0,8 s).
- **Mermi alma:** Uzanma mesafesi 2,5 m, alma süresi 0,02 s/mermi; reload başında el boşalıyor. İyi oyuncu reload sırasında yığına dönüp mermi alabiliyor; orta oyuncuya +0,6 s, kötü oyuncuya +1,5 s eklendi.
- **Durma noktası:** İki seçenek denendi: yığın kenarı (r = 9,5 m) ya da atış hattı (x = 13,7, her şarjörde 8 m/s koşarak yığına gidip gelme). Simülasyon her durum için daha iyisini seçiyor. Atış hattındaki yürüyüş neredeyse her zaman reload'un içinde kayboluyor (dummy önünde 4,2 m: gidiş-dönüş 1,05 s, reload 2,48 s).
- **Hedef boyutları** headless AABB ölçümünden alındı: dummy gövdesi 0,42×0,97 m, kafası 0,30×0,44 m; silüet 0,51×0,82; gong Ø0,46; raf plakası Ø0,25; popper 0,20×0,70 (kafa Ø0,20); köstebek plakası Ø0,20; Texas plakası Ø0,28. Hedefin zamanlamaları kendi script'lerinden.

### T1: İsabet olasılığı (yığın kenarından; hat 9–10 m'de daha yüksek)

| hedef | mesafe | iyi | orta | kötü |
|---|---|---|---|---|
| dummy | 13,5 | gövde %90; kafa %90 (zayıf %90) | gövde %70; kafa %66 | gövde %45; kafa %37 (zayıf %33) |
| raylı | 19,0 | gövde %84; kafa %74 | gövde %54; kafa %42 | gövde %30 |
| silüet | 14,5 | %90 | %70 | %45 |
| gong | 16,5 | %90 | %65 | %30 |
| raf | 17,1 | %79 | %35 | %11 |
| popper | 14,8 | kafa %77 (zayıf %76) | kafa %37 | %13 |
| köstebek | 19,6 | %53 | %18 | %5 |
| texas (3 rad/s) | 22,7 | %38 | %13 | %4 |

### T2: Şimdiki durum, tek hedef, kapasite 7, kombo şimdiki (tavansız): $/dk (isabet %, durulan yer)

| hedef | $/isabet | iyi | orta | kötü |
|---|---|---|---|---|
| dummy | 1 | 469 (%90, hat) | 221 (%70) | 70 (%44) |
| raylı | 2 | 633 (%85) | 231 (%56) | 64 (%32) |
| silüet | 2 | 469 (%90) | 225 (%70) | **79** (%48) |
| gong | 2 | 465 (%89) | 219 (%70) | 62 (%45) |
| raf | 3 | **655** (%89) | **253** (%63) | 44 (%26) |
| popper | 3 | 291 (%88) | 192 (%56) | 65 (%22) |
| köstebek | 5 | 631 (%87) | 190 (%51) | 33 (%19) |
| texas | 6 | 462 (%64) | 120 (%30) | 27 (%12) |

Kapasite 1'de durum farklı: popper en kârlı hedef (iyi oyuncu 115 $/dk, dummy 39). Tek mermiyle zincir olmadığı için popper kafasının $6'sı doğrudan cebe giriyor.

Hepsi açık **karışık** oyunda gelirin kaynağı (`tempo.py`):
- **Şimdi:** iyi oyuncuda popper %51, raf %30, köstebek %18, Texas %1. Orta oyuncuda popper %61, raf %39. Kötü oyuncuda silüet %100.
- **Öneriyle:** iyi oyuncuda Texas %80–82. Orta oyuncuda raf %63–82, dummy %12–33. Kötü oyuncuda dummy %100. Beceri katmanları kendi hedefine ayrılıyor.

### T3: Kombo varyantları, tabanca kapasite 7, $/dk (tek hedef dummy / hepsi karışık)

| çarpan | iyi | orta | kötü |
|---|---|---|---|
| A şimdiki: zincir, tavansız | 469 / 779 | 221 / 292 | 70 / 82 |
| B en çok ×5 | 434 / 705 | 213 / 288 | 70 / 82 |
| C 1+log2(n) | 347 / 591 | 183 / 262 | 66 / 76 |
| D 1+0,5(n−1), en çok ×4 | 306 / 528 | 157 / 228 | 57 / 65 |
| **E öneri: ×1,1,2,2,3,3,4 (tavan)** | 276 / 475 | 140 / 202 | 51 / 58 |

Tabancada E, A'ya göre geliri %35–40 kısıyor; fiyatlar buna göre önerildi. İyi/kötü oyuncu gelir oranı A'da 6,7, E'de 5,4: beceri farkı biraz daralıyor. D ile E neredeyse eşit; E'yi tam sayı olduğu ve HUD'da okunduğu için seçtim. D'de $1'lık hedeften ×1,5 gelince yuvarlama sorunu çıkıyor.

### T4: Hızlı silahta kombo, dummy $1, 10 dk ortalaması, $/dk

| silah | A şimdiki | B ×5 | C log | D | **E** |
|---|---|---|---|---|---|
| tabanca 7'li, iyi oyuncu | 465 | 431 | 345 | 304 | 274 |
| SMG 12/s, 30'luk, 2,5 s reload, %90 | 2.214 | 1.252 | 1.064 | 933 | 887 |
| AK 10/s, 30'luk, %90 | 2.009 | 1.140 | 968 | 850 | 808 |
| taret 10/s beslemeli, %95 | 10.677 | 2.590 | 2.621 | 2.014 | 1.978 |
| taret 10/s beslemeli, %100 | **1.799.100** | 2.998 | 7.263 | 2.398 | 2.398 |

Taramalı ya da taretli silahta 1,5 s'lik pencere pratikte sonsuz: SMG'de atış aralığı 0,083 s, reload'a kadar zincir kırılmıyor. Taret ıskalamıyorsa zincir hiç kırılmıyor ve gelir zamanın karesiyle büyüyor. Log çarpanı bile sınırsız büyüdüğü için yetmiyor (7.263). Tavan şart.

### T (sınırsız mermi) suistimali, dummy, $/dk: normal → T açık

| çarpan | iyi | orta | kötü |
|---|---|---|---|
| A şimdiki | 468 → 2.345 (×5,0) | 227 → 636 (×2,8) | 68 → 157 (×2,3) |
| E öneri | 276 → 753 (×2,7) | 143 → 351 (×2,4) | 49 → 109 (×2,2) |

### Önerilen hit_gold (kombo E, kapasite 7, Texas 2 rad/s), dummy'ye göre $/dk oranı

$1 başına birim oranlar `unit_e.py`'den. Önerilen değer = birim oran × altın.

| hedef | şimdi | **öneri** | iyi | orta | kötü | gerekçe |
|---|---|---|---|---|---|---|
| dummy | 1 | **1** | 1,00 | 1,00 | 1,00 | Başlangıç; kafa ×2 beceriyi öğretiyor. |
| raylı | 2 | **2** | 1,36 | 1,12 | 0,96 | 1,6 m/s hareket; ilk basamak. $3 olursa rafı ezer (orta oyuncuda 1,68). |
| silüet | 2 | **2** (co-op şeridi) | 1,00 | 1,02 | 1,12 | Dummy ile aynı; basamak değil, şerit. |
| gong | 2 | **2** (co-op şeridi) | 0,99 | 0,99 | 0,88 | Aynı. |
| popper | 3 | **2** | 0,51 tek / karışıkta dolgu | 0,72 | 0,73 | Yatma süresi zinciri kırıyor; kafa $4. Şimdiki $6 karışık oyunda baskın. |
| raf | 3 | **3** | 1,39 | 1,17 | 0,69 | Ø25 cm, durağan; orta oyuncunun en iyi yeri. |
| köstebek | 5 | **8** | 2,17 | 1,53 | 0,92 | Ø20 cm, 0,75–1,6 s pencere; tepki ödülü. |
| texas | 6 | **10** (+ SPIN 2,0) | 2,61 | 1,70 | 0,96 | En zoru. 3 rad/s'de kalırsa $15–16 gerekir. |

İlke şu: her yeni hedef, açabilen orta oyuncuya %10–50 artış, iyi oyuncuya ×1,4–2,6 versin; kötü oyuncuya kazandırmasın (≤1,1). **Sabit dummy'den neden geçilir?** Çünkü bir sonraki hedef, onu vurabilen oyuncuya dakikada daha çok para veriyor. Bir de karışık oyunda dummy zincir kurmak için, zor hedef son mermi için kullanılıyor.

### Tempo: ilk 15 dakika (`tempo.py`, birikimli kazanç $)

| senaryo | oyuncu | 1 dk | 2 dk | 3 dk | 5 dk | 8 dk | 10 dk | 15 dk | harcanan | 15. dk elde kalan |
|---|---|---|---|---|---|---|---|---|---|---|
| şimdi (hepsi açık, A) | iyi | 345 | 1.134 | 1.914 | 3.427 | 5.615 | 7.249 | 11.241 | 603 | **10.680** |
| şimdi | orta | 96 | 331 | 568 | 1.129 | 1.964 | 2.642 | 4.008 | 603 | **3.436** |
| şimdi | kötü | 17 | 45 | 89 | 200 | 387 | 563 | 968 | 603 | 370 |
| öneri (dükkân, E, yeni altın) | iyi | 43* | 111 | 221 | 682 | 2.675 | 4.082 | 7.542 | 1.285 | 6.344 |
| öneri | orta | 27 | 80 | 142 | 333 | 713 | 992 | 1.767 | 1.285 | 502 |
| öneri | kötü | 12 | 32 | 55 | 119 | 220 | 312 | 522 | 435 | 91 |

\* İyi oyuncu simülasyonda baştan güneydeki hedeflerin önünde duruyor (sabit nokta seçimi). Bu yüzden ilk dakikası düşük; gerçekte dummy önünde başlar ve ~$70 kazanır (`sim.py` T5 "dummy, E").

**Alım anları** (önerilen sıra, seed 0, dakika):
- **iyi:** kap2 0,24 · kap3 0,6 · raylı 1,2 · kap4 1,6 · popper 2,3 · kap5 2,8 · raf 3,5 · kap6 4,1 · köstebek 5,0 · kap7 5,4 · texas 6,1
- **orta:** kap2 0,31 · kap3 0,68 · raylı 1,5 · kap4 2,2 · popper 3,0 · kap5 3,7 · raf 4,4 · kap6 5,5 · köstebek 7,3 · kap7 8,8 · texas 12,0
- **kötü:** kap2 0,5 · kap3 1,9 · raylı 3,3 · kap4 4,6 · popper 6,2 · kap5 8,1 · raf 10,1 · kap6 12,7. Bu oyuncu önce kapasite alırsa kap7'ye 13,5 dk'da ulaşıyor.

**Önerilen dükkân sırası ve fiyatları** (yanlarında yaklaşık orta oyuncu alım dakikası):
kapasite 2 **$5** (0,3) → kapasite 3 **$15** (0,7) → raylı **$30** (1,5) → kapasite 4 **$35** (2,2) → popper **$60** (3,0) → kapasite 5 **$70** (3,7) → raf **$100** (4,4) → kapasite 6 **$120** (5,5) → köstebek **$250** (7,3) → kapasite 7 **$200** (8,8) → Texas **$400** (12). Toplam $1.285. Ardından sonraki silah ~$1.000.

Sıra ilk 1–2 dakikayı hızlı tutuyor (ilk alım ~20 sn, koddaki niyetle uyumlu). Kapasite 7 ve son hedefler orta oyuncuda ~9–12. dakikaya yayılıyor. İlk $5 kötü oyuncunun ilk alımını 77 s'den 30 s'ye çekiyor.

### 60 dakika ve 100M hedefi

- **Tabanca döneminde yığın küçülmüyor.** İyi bir oyuncu kapasite 7'de dakikada ~80 mermi atıyor: her 5,25 s'de 7 mermi. İlk 15 dakikada en fazla ~1.500 mermi gidiyor, yani yığının %0,0015'i.
- **Yarıçap hacmin küp köküyle değişiyor** (r ∝ N^(1/3)). Yarıçapın %10 küçülmesi için 27M mermi harcanmalı. Önceki tempo tablosuyla bu ~45. dakikaya denk geliyor; yığın "görünür" şekilde ancak son ~15 dakikada küçülüyor. CLAUDE.md'deki "son saatte" ifadesi 1 saatlik demoda fiilen "son çeyrek" demek. Bu yüzden tabanca döneminde ilerlemeyi para ve hedef açılımları taşımalı (öneri: erken kilometre taşları).
- **Otomasyon dönemi kuralı:** 95 bin mermi/s'de mermi başına $1 bile dakikada $5,7M eder. Taret ve bant isabetleri komboya girmemeli. Taret başına ödeme mermi başına ≤ $1 olmalı, sonraki kademeler fiyatta ×1,6–2 artmalı (ayrı bir denge geçişi gerekir).

## Diğer ajanlara sorular

1. **Tasarım/co-op:** Hedef kilidi dünya için ortak, para ise kişisel. Kilidi kim açar: ortak kasa mı, yoksa ilk satın alan herkes için mi açar? Popper, köstebek ve Texas plakaları ortak; 4 kişide hızlı oyuncu hepsini kapar. Hedef başına "son vuran" kuralı mı, yoksa oyuncu sayısına göre kopya hedef mi?
2. **His/animasyon:** Reload'u kısaltan bir upgrade (ya da hızlı reload animasyonu) düşünülüyor mu? Reload 1,5 s'nin altına inerse zincir şarjörler arasında korunur. E tavanıyla sorun olmaz ama tavansız kombo kalırsa tabancada da patlar.
3. **UI:** Kombo yazısı zinciri mi göstersin, çarpanı mı? Benim önerim büyük yazıda çarpan (×2), küçük pip'lerde sonraki kademeye kalan isabet.
4. **Seviye/ortam:** Atış hattı ile yığın arası ~4 m, reload'un içinde koşarak gidilip geliniyor; yürüme şu an bedava. Taşıyıcı robotun tabanca döneminde değeri olsun isteniyorsa hat x = 16–17'ye çekilebilir (her şarjörde ~1 s'lik yürüyüş maliyeti). İsteniyor mu?
5. **QA:** `tools/combo_check.gd` kademeli komboya göre güncellenince "taret atışı zinciri büyütmez" assert'i de eklensin mi?

## 2. tur: tartışma

Okunanlar: `tasarim.md`, `gorsel.md`, `qa.md` ve koordinatörün aktardığı 2. tur notları (tasarım: birleşik kural, görsel: büyük yazı ve sinüslü yıldız).

Yeni betikler (karalama klasöründe):
- `sim2.py`: kural karşılaştırması ve rezonans; çıktısı `sim2_out.md`
- `reson2.py`: rezonans ayrıntısı
- `final_gold.py`: birleşik kuralda altın setleri; çıktısı `final_gold_out.md`

Texas Star'ın oyunda gerçekten rezonansa girip girmediğine bakmak için geçici `tools/agent_ekonomi_texas.gd` betiğini headless çalıştırdım ve sildim.

### Kullanıcının sınırlarıyla çatışmam

- **Kombo ve x100 göstergesi.** 1. turdaki ×4 tavanım "zincir büyür, x100 görülür" isteğiyle çatışıyordu. Çözüm, **gösterilen zinciri ödenen çarpandan ayırmak**: zincir 1,5 sn'lik penceresiyle olduğu gibi kalır ve sınırsız sayar, ekranda x100'e kadar büyür. Ödenen çarpan ise sınırlı bir fonksiyon. Ödenen değeri ayrıca yazmaya gerek yok: "+$" yazısı (`payout_pop`) zaten gerçek ödemeyi gösteriyor.
- **Görsel ajanla ayrıldığım nokta.** Görsel ajan "büyük yazı ödenen çarpanı, zincir küçük ve gri" diyor. Bunu kullanıcının açık isteğine aykırı buluyorum. Önerim: **büyük yazı zincir (xN)**, ödeme "+$" yazısında. Ödeme kademesi yalnızca barın rengiyle/pip'leriyle sezdirilir.
- **Texas Star hızı.** Hız 3 rad/s'de kalabilir; aşağıda gösterildiği gibi rezonans sorunu oyunda yok. 1. turdaki "2 rad/s" önerimi geri çekiyorum.
- **Yerleştirme.** Hedefler sırayla açılıyor ve oyuncu kendi yerleştiriyor. 1. turdaki x ≥ 20 bölgesi tasarımın x 18–26,5 önerisiyle uyumlu; tasarımınkini kabul ediyorum.

### Zincir mi, çeşit mi, ikisi birden mi? (`sim2.py`)

Koşullar: kapasite 7, tasarımın 6 türü, tasarımın altını (1/2/3/4/6/10), 10 dk. Her hücrede: karışık oyunda $/dk / yalnız dummy $/dk (karışık ile dummy oranı).

| kural | iyi | orta | kötü | SMG / tabanca |
|---|---|---|---|---|
| A şimdiki ×n | 995 / 477 (×2,1) | 314 / 223 (×1,4) | 67 / 67 (×1,0) | ×5,6 |
| E ×4 tavan (1. tur önerim) | 573 / 280 (×2,0) | 210 / 141 (×1,5) | 50 / 49 | ×4,9 |
| √n | 528 / 250 (×2,1) | 214 / 137 (×1,6) | 52 / 52 | ×4,9 |
| V tasarımın 1. turu: ×tür, 5 sn, ıska kırmaz | 979 / 144 (**×6,8**) | 320 / 94 (×3,4) | 66 / 43 (×1,5) | **×8,5** |
| **H birleşik: min(zincir, 1 + zincirdeki tür)** | 754 / 256 (**×2,9**) | 295 / 150 (**×2,0**) | 60 / 60 | ×5,2 |

- **V (yalnız çeşit) aşırı.**
  - Yalnız dummy'ye ateş eden iyi oyuncu altıda birine düşüyor. Bu yeni oyuncuyu ilk dakikalarda cezalandırır.
  - Iska bedava olduğu için SMG püskürtmesi en çok kazanan kural oluyor (×8,5).
  - Zincir (kullanıcının istediği) tamamen kayboluyor.
- **E ve √n sınırlı ama tür değiştirmeyi ödüllendirmiyor.** Karışık oyun dummy'ye göre yalnız ×2 getiriyor.
- **H (tasarımın 2. tur önerisi) en dengelisi.** Bunu kabul ediyorum.
  - Zincir korunuyor: ıska ve pencere onu kırıyor, x100'e kadar büyüyor.
  - Ödeme en fazla ×7 (6 tür + 1). Taret dahil hiçbir silah karesel büyüyemiyor.
  - Tek hedefte ödeme ×2'de duruyor. Tür değiştirmek iyi oyuncuya ×2,9, ortaya ×2,0 getiriyor; kötü oyuncuyu cezalandırmıyor (dummy'de aynı parayı alıyor).
  - Her yeni tür tavanı 1 artırıyor. Hedef açmak ölçülebilir bir güç artışı oluyor.
- **Kural yine de şart:** taret ve bant isabetleri zinciri büyütmez. Büyütse bile ×7'de kalır ama "elle ateş bonusu" anlamı kaybolur.

### Altın değerleri: tasarım ile benim önerim (H kuralı altında, `final_gold.py`)

Her hücrede: karışık $/dk / yalnız dummy $/dk, ardından gelirin hedeflere dağılımı.

| altın (dummy/gong/popper/raf/köstebek/texas) | iyi | orta | kötü |
|---|---|---|---|
| tasarım 1/2/3/4/6/10 | 754 / 256; popper %37, raf %32, köstebek %20, texas %11 | 295; raf %53, popper %47 | 60; dummy %100 |
| benim 1. tur 1/2/2/3/8/15 | 900; **texas %75**, köstebek %25 | 246; **texas %89** | 60 |
| **ortak 1/2/3/4/7/12** | **835**; popper %30, köstebek %27, raf %25, texas %18 | 290; raf %52, popper %46 | 60; dummy %100 |

- **Benim 1. tur değerlerim H altında yanlış.** Texas $15 her şeyi yutuyor.
  - **Popper:** $3'ü düşürmeyi geri çekiyorum. H'de popper ucuz bir "tür" basamağı ve karışımın parçası oluyor; tek başına baskın olma sorunu zincir tavanıyla kendiliğinden kalkıyor.
  - **Köstebek ve Texas:** Tasarımın $6/$10'u ile benim $8/$15'imin arası olan **$7/$12**, iyi oyuncuda 4 hedefe dengeli dağılan tek set oluyor.
- **Raylı dummy ve silüet:** Tasarıma katılıyorum, demodan çıksınlar.
  - Silüet benim modelimde de her becerideki oyuncu için dummy'ye eşitti.
  - Raylı dummy H'de ayrı tür sayılırsa tavanı kolayca 1 artırır, beceri sorusu ise zayıf.
  - Altı türle ×7 tavanı anlamlı kalıyor.
- **Fiyatlar.** Tasarımın hedef fiyatları ($30/300/700/3.000/9.000) çeşit modelindeki ~$82/sn gelire göre kurulmuş. H'de iyi oyuncu ~$14/sn, orta oyuncu ~$5/sn kazanıyor. Bu fiyatlarla orta oyuncu Texas'a ~50. dakikada ulaşır.
  - Önerim, tasarımın açılış sırası ile benim ölçeğimin birleşimi: kap2 $5, kap3 $15, **gong $30**, kap4 $35, **popper $60**, kap5 $70, **raf $120**, kap6 $120, **köstebek $300**, kap7 $200, **Texas $500**, SMG ~$1.200.
  - Tahminim: orta oyuncu ~10–12. dakikada, iyi oyuncu ~5–6. dakikada bitirir. Bu tahmin E temposundan H gelirine (×1,4) ölçeklenerek yapıldı; x10 hile menüsüyle doğrulanmalı.

### Texas Star: rezonans gerçekte yok, sinüs ekonomiyi bozar

Görsel ajanın hesabı doğru: 3 × 0,42 = 72,2°, plaka aralığına çok yakın. Ama vurulan her plaka `LURCH` (+1,2 rad/s) ile dönüşü hızlandırıyor ve bu senkronu bozuyor. Ölçümler:

| ölçüm | park edip basılı tutunca isabet |
|---|---|
| **Oyunda headless test**: 12 park noktası × 7 atış, sabit 3 rad/s | **3/84 = %3,6** |
| Model, sabit 3,0 + LURCH 1,2 (şimdi) | %8; 5 ve üstü isabet %0 |
| Model, sabit 3,0, LURCH yok | %37; 7/7 olasılığı %36 (rezonans buydu) |
| Model, 3,0 ± %25 sinüs, 3,7 sn (görsel öneri) | **%28**; 5 ve üstü isabet %0 |

- **Sinüs "basılı tutunca sıra sıra düşme"yi gidermiyor**, çünkü o zaten olmuyor. Bunun yerine **beceri istemeyen bir strateji açıyor:** bir noktaya nişan alıp tetiği basılı tutmak %28 isabet veriyor.
- Kötü oyuncu nişan alarak Texas'ta %4–12 isabet ediyor. Park ederse %28'e çıkar ve $12'lık plakada atış başına ~$3,4 kazanır; dummy'de ~$0,5. Texas kötü oyuncunun en iyi hedefi olur ve zorluk ve ödül ilkesi çöker.
- **Öneri:** `SPIN` 3,0 sabit ve `LURCH` 1,2 kalsın. Hız kullanıcının istediği gibi hızlı, rezonans ise lurch sayesinde fiilen yok.
- Görsel çeşitlilik istenirse sinüs genliği ≤ %10 tutulsun ve aynı park testi (≤ %10 isabet şartıyla) `combo_check`'e eklensin.
- `LURCH` düşürülür ya da sönümü hızlandırılırsa rezonans geri gelir (LURCH 0'da 7/7 %36). Bu iki değer birlikte değişmeli.

### QA bulgularının ekonomi etkisi

- **Hattın ötesinden atış hedefi tüketiyor (QA #4).**
  - Tek oyunculu oyunda para kaybı yok; oyuncu yalnızca kendi köstebek temposunu ve popper'ını harcıyor.
  - Co-op'ta yerleştirme yapan oyuncu, hattaki arkadaşının popper'ını yatırıyor ve köstebek temposunu bozuyor (`_up_time` kısalıyor ya da plaka iniyor). H'de bu, arkadaşın tür sayısını ve zincirini de kırabiliyor; hedef 2–3,5 sn yok kalıyor.
  - Kullanıcının kararıyla yerleştirme modu kalıcı bir özellik olacak, yani bu açık oyunda sürekli bulunacak.
  - Düzeltme: QA'nın iki önerisi birlikte uygulansın. Yerleştirme modunda silah ateş etmesin (`request_fire` başında `if p.placing: return false`), hat ötesi atış hedefi tüketmesin.
- **T tuşu bedava mermi (QA #6) ve sınırsız mermi.**
  - Her aç/kapa yığından düşmeden kapasite kadar mermi veriyor.
  - Açık kaldığında gelir iyi oyuncuda ×5, H'de ~×2–3; zincir yalnız ıskada kırılıyor.
  - "Yığın hem hedef hem yakıt" kuralını deliyor.
  - Düzeltme: T açıkken atış $0 ödesin ve zincir kurmasın; kapatınca şarjör eski değerine dönsün. Hile menüsü gelince T oraya taşınsın.
- **Zamanlayıcılar kısılmış delta ile sayılıyor (QA #3).** x10 hızda popper 3,4 kat uzun yatıyor. x10 ile yapılacak denge ölçümü hedef ödemelerini **olduğundan düşük** gösterir ve fiyatlar yanlış ayarlanır. Denge testinden önce düzeltilmeli.
- **`from` istemciden geliyor (QA #9, benim #10).** Aynı bulgu; co-op başlarken düzeltilmeli.

### Ortak öneri

1. **Kombo:** zincir 1,5 sn penceresiyle ve ıskada kırılmayla aynen kalsın. Ekranda büyük yazı **zincir xN** olsun (kullanıcının isteği, x100'e kadar). **Ödenen çarpan = min(zincir, 1 + zincirdeki farklı tür sayısı)**, en fazla ×7 (tasarımın 2. tur kuralı); gerçek ödeme "+$" yazısında görünür. Taret, bant ve robot isabetleri zinciri büyütmez. `combo_check.gd` beklentileri buna göre güncellensin. **Y, 2 sa.**
2. **Hedef seti:** dummy, gong, popper çifti (tek tür), çelik raf, köstebek, Texas Star. Raylı dummy ve silüet demodan çıksın (dosyalar kalsın). Silüet ileride co-op şeridi olarak dönebilir. **Y, 30 dk.**
3. **Altın:** dummy $1 (kafa ×2), gong $2, popper $3 (kafa ×2), raf **$4**, köstebek **$7**, Texas **$12**. H altında iyi oyuncunun geliri 4 hedefe %18–30 dağılıyor, orta oyuncu raf ve popper'da, kötü oyuncu dummy'de; kötü oyuncu cezalandırılmıyor. **Y, 5 dk.**
4. **Açılış sırası ve fiyatlar:** kap2 $5, kap3 $15, gong $30, kap4 $35, popper $60, kap5 $70, raf $120, kap6 $120, köstebek $300, kap7 $200, Texas $500, SMG ~$1.200. Hedefler Q menüsünden alınır ve yerleştirme modunda x 18–26,5 bölgesine konur (tasarımın kuralları). Fiyatlar x10 ile doğrulanacak; QA #3 önce düzeltilmeli. **Y, 4–6 sa (dükkân + kilit).**
5. **Texas Star:** `SPIN` 3,0 sabit ve `LURCH` 1,2 kalsın. Oyunda park edip basılı tutmak %3,6 isabet veriyor, rezonans yok. Görselin ±%25 sinüsü park stratejisini %28'e çıkarıp Texas'ı kötü oyuncunun en iyi hedefi yapar. Sinüs istenirse genliği ≤ %10 olsun ve park testi `combo_check`'e eklensin. **O, 30 dk (test).**
6. **Suistimal kapatma:**
   - Yerleştirme modunda silah ateş etmesin ve hat ötesi atış hedefi tüketmesin (QA #4).
   - T açıkken ödeme ve zincir olmasın, kapatınca şarjör geri alınsın (QA #6).
   - Co-op'ta `from` host'taki gövde konumuyla doğrulansın (QA #9).
   - **Y, 1 sa; `from` doğrulaması co-op ile.**
7. **Denge testinden önce:** hedef zamanlayıcıları ham delta ile saysın (QA #3). Aksi hâlde x10 ölçümleri hedef gelirini düşük gösterir. **Y, 20 dk.**
