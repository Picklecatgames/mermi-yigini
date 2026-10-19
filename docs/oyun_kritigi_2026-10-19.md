# Oyun kritiği (2026-10-19)

Dört ajan (ekonomi, tasarım, görsel, QA) oyunu iki tur inceledi: önce her biri kendi alanında rapor yazdı, sonra birbirlerinin raporlarını okuyup tartıştı ve fikir değiştirdi. Ayrıntılar, simülasyon tabloları ve ölçümler: `docs/ajan_kritik/` (`ekonomi.md`, `tasarim.md`, `gorsel.md`, `qa.md`, her birinin sonunda "2. tur: tartışma").

Ajanlar oyun dosyalarına dokunmadı. Bu belge yalnızca öneri; uygulanan bir şey yok.

## Kısaca

- **Çekirdek sağlam.** Zamanlı kombo zinciri, zayıf nokta, atış hattı ve hedeflerin tepkileri iyi bulundu. Mevcut iki test (`combo_check`, `steel_check`) temiz.
- **Ekonominin asıl sorunu kombo.** Tabancada reload (2,48 sn) 1,5 sn'lik pencereden uzun olduğu için zincir her şarjörde kırılıyor ve sorun görünmüyor. SMG ya da taret gelince gelir karesel patlıyor: AK'nin 30'luk şarjörü taban ödemenin 465 katını veriyor.
- **"Neden diğer hedeflere vurulsun" sorusunun cevabı kombonun içinde.** Zincir aynı kalıyor, ama ödenen çarpanın tavanını farklı hedef türleri açıyor.
- **Tempo çok hızlı.** İyi oyuncu kapasiteyi 1,4 dakikada bitiriyor, sonra parasını harcayacak bir şey kalmıyor. Hedef kilitleri dükkâna girmeli.
- **Sessiz hedefler, görünmeyen efektler.** Popper, köstebek rafı ve yıldızın sesi yok. Kıvılcımlar 10 m'den görünmüyor. Küçük plakalar ekranda 8–13 px.

## Ajanların uzlaştığı kararlar

### 1. Kombo: zincir kalır, tavanı çeşit açar (dört ajandan üçü, Y, ~2 sa)

- Zincir aynen kalıyor: 1,5 sn pencere, ıskada kırılma, büyüyen yazı (taramalıda x100).
- **Ödenen çarpan** = min(zincir, 1 + zincirdeki farklı hedef türü), en fazla ×7.
- Yalnız dummy vuran ×2'de takılır; her yeni hedef türü tavanı 1 açar. Gerçek ödeme "+$" yazısında görünür.
- Taret, bant ve robot isabetleri zinciri büyütmez.
- **Simülasyon sonucu:** tür değiştiren iyi oyuncu yalnız dummy'ye göre ×2,9, orta oyuncu ×2,0 kazanıyor; kötü oyuncu cezalandırılmıyor. SMG tabancanın ×5,2'si; yalnız çeşit kuralında ×8,5'ti.
- **Ret edilenler:**
  - Tavansız zincir: taret dakikada $1,8M kazanıyor.
  - ×4'lük sabit tavan: senin istediğin x100 hissini öldürüyor.
  - Zinciri tamamen kaldırıp yalnız çeşit çarpanı koymak: senin onayladığın zincirle çatışıyor.
  - Dummy yıpranması: ceza gibi hissettiriyor ve en çok kötü oyuncuyu vuruyor.

### 2. Hedef seti ve ödemeler (Y, ~30 dk)

| Hedef | Şimdi | Öneri | Not |
|---|---|---|---|
| Dummy | $1 | $1 (kafa ×2) | |
| Gong | $2 | $2 | Kilometre taşlarının ve son mermi töreninin çanı |
| Popper (çift, tek tür) | $3 | $3 (kafa ×2) | |
| Çelik raf | $3 | $4 | |
| Köstebek rafı | $5 | $7 | `UP_MIN` 0,75 → 0,9 sn |
| Texas Star | $6 | $12 | $15 bütün geliri Texas'a topluyordu (%75–89) |
| Raylı dummy | $2 | demodan çıkar | Atış anlık olduğu için önünü kestirmek gerekmiyor, pratikte dummy ile aynı |
| Çelik silüet | $2 | demodan çıkar | Gongla aynı beceriyi soruyor; co-op şeridi olabilir |

### 3. Texas Star: hız 3,0 rad/s kalır (QA ve ekonomi ölçtü)

- Görsel ajan "tetiği basılı tutan oyuncu plakaları sırayla düşürür" demişti. Ölçüm bunu çürüttü: park edip ateş eden oyuncu 47 atışta 4 (60 FPS) ve 84 atışta 3 isabet aldı. Her isabetteki ani hızlanma senkronu bozuyor.
- Görselin ±%25 sinüs önerisi park stratejisini %28 isabete çıkarıyor. Bu durumda Texas, kötü oyuncunun en iyi hedefi olur; öneri reddedildi. Sinüs istenirse genlik en fazla %10.

### 4. Dükkân ve açılış sırası (Y, 4–6 sa)

Tek liste; hedefler Q menüsünden satın alınır ve yerleştirme moduyla konur:

kap2 $5 → kap3 $15 → **gong $30** → kap4 $35 → **popper $60** → kap5 $70 → **çelik raf $120** → kap6 $120 → **köstebek $300** → kap7 $200 → **Texas $500** → SMG ~$1.200

Hedefe göre orta oyuncu bu listeyi ~12. dakikada, iyi oyuncu ~6. dakikada bitiriyor. Fiyatlar x10 hile menüsüyle doğrulanmalı, ama önce QA'nın 5. maddesi (zamanlayıcılar) düzelmeli.

### 5. Yerleştirme modu (Y, 6–8 sa)

- Akış: Q'dan satın al → saydam önizleme (beyaz Fresnel kenar, yerde sarı taban izi) → raycast ile koy.
- Yerleşim kuralları: 0,5 m grid, 15° döndürme, çakışma yasak, taşımak bedava.
- Bölge: x 19–25. Küçük plakalı hedefler (yıldız, köstebek) en fazla x 24'e konabilir; daha uzakta ekranda 6 px'e düşüyorlar. Zemine x 14/18/22'de sarı çizgiler boyanır.
- Hedef konunca yere "tok" diye oturur, toz halkası çıkar, bir kez kendini sınar (popper kalkar, gong çalar).
- Yerleştirme modunda silah iner, ateş edilemez. B ile hattı geçme kaldırılır.

### 6. Önce düzeltilecek hatalar (QA sırası, Y, toplam ~2 sa)

1. **Efekt havuzu silinen hedefe dayanıklı olsun** (`impacts.gd`). Hedef silinince ona taşınmış delik ve duman da siliniyor, sonraki isabetlerde script hatası çıkıyor. Yerleştirme modundan önce şart.
2. **Texas Star'da iz yanlış plakaya yapışıyor.** `decal_parent` içindeki `_on` filtresi kalkmalı.
3. **`request_fire` sağlamlaştırılsın.** `hit_gold` olmayan hedef `int(null)` ile atışı kesiyor. Hedefin konumu da kontrol edilsin. Co-op'ta `from` host'taki gövde konumuyla doğrulansın.
4. **Sayılmayan isabet hedefi tüketmesin.** Hattın ötesinden vurulan popper şu an deviriliyor, köstebek de hızlanıyor.
5. **Hedef zamanlayıcıları ham `delta` ile saysın.** x10 hızda popper 3,5 sn yerine 11,8 sn yerde kalıyor; denge ölçümleri 3,4 kat yanlış çıkar.
6. **T (sınırsız mermi) yalnız debug build'de olsun**, para ve zincir vermesin, kapatınca bedava mermi bırakmasın. T şu an iyi oyuncunun gelirini ×5'e çıkarıyor ve yığından mermi harcatmıyor.

### 7. His ve görünürlük (Y/O, ~3 sa)

- **Sessiz hedeflere ses** (25 dk): `light.tres`/`heavy.tres` bağlanır. Ayrıca yalnız para veren isabette mesafeden bağımsız 2D bir "tık" çalar.
- **10 m'den okunur isabet** (1–1,5 sa):
  - Efekt ölçeği `max(1, d/4)`.
  - Glow'u tetikleyen HDR kıvılcım.
  - Çelikte plakaya paralel kurşun püskürmesi ve 0,06 sn'lik flaş.
  - Iskada 0,25–0,6 m toz bulutu.
  - Çelik izinin ortasındaki siyah delik kalkar; kurşun çeliği delmez.
- **Nişangah ve HUD** (20 dk): nişangaha siyah kenarlı nokta, sayaç yazısına kenar çizgisi.
- **Tek boya dili** (30 dk): hedef yüzeyleri beyaz, iskeletler koyu çelik, gong kırmızı (gerçek poligonda stop plakası kırmızıdır).
- **Korkuluk** 24 mm'lik borulardan yapılsın; kutular pahlı sundurma parçalarının yanında sırıtıyor.
- `_process`'te taşınan hedef parçalarında fizik interpolasyonu kapansın.

### 8. Co-op'tan önce (Y, 2–3 sa)

Yıldızın açısı, köstebeğin sıradaki plakası ve popper'ın yatma süresi her makinede ayrı hesaplanıyor. Host bunları seçip olay olarak yaymalı, yoksa istemcinin gördüğü ile host'un isabet hesabı tutmaz.

### 9. Sistem bağlantıları (O)

- **Anahtarlar:** yığında kalır; otomasyon gelince bandın kazdığı noktadan fırlar, tarayıcı bandın yerini seçtirir.
- **Kovanlar:** atıcının yanına düşer.
- **Taretler:** yalnız sabit hedeflere ateş eder, zincire girmez.
- **Kilometre taşları:** 99M kilometre taşı eklenir, çünkü yığın ilk 30 dakikada pratikte küçülmüyor.
- **Son mermi:** elle alınıp gonga atılır.

## Senin karar vermen gerekenler

1. **Büyük kombo yazısı neyi göstersin?**
   - Ekonomi, tasarım ve QA: **zincir xN**. x100'e büyür; gerçek ödeme "+$" yazısında görünür.
   - Görsel: **ödenen çarpan**. Zincir barın altında küçük ve gri durur; gerekçe, oyuncunun iki farklı sayıyı "bozuk" sanması.
2. **Raylı dummy ve silüet** demodan çıkarılsın mı? Dosyalar kalır, sadece sahneden kalkar.
3. **Hedefler** ortak kasadan mı, kişisel parayla mı alınsın? Tasarımın önerisi ortak kasa, çünkü hedefler dünyaya ait.
4. **Kasalar:** tasarım ajanı hareket hızı ve stamina kasalarının çıkarılmasını, kasaların yalnız mermi tipi vermesini öneriyor. Bu senin listendeki örneklerle çatışıyor.
5. **Dummy yıpranması:** dört ajan da karşı. Vazgeçilsin mi?

## Önerilen uygulama sırası

1. QA hataları (6. bölüm) ve sessiz hedeflere ses: ~2,5 sa
2. Kombo kuralı, hedef seti ve ödemeler (1–2. bölümler) + `combo_check` güncellemesi: ~2,5 sa
3. Dükkân kilitleri ve fiyatlar (4. bölüm): ~5 sa
4. Yerleştirme modu (5. bölüm): ~7 sa
5. His ve görünürlük (7. bölüm): ~3 sa
6. x10 hile menüsüyle denge turu
