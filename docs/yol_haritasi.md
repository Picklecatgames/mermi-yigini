# Yol haritası (2026-10-20)

Sıra kuralı: her adım bir sonrakinin sayılarını belirler. Önce gelir (ekonomi), sonra o geliri harcayan şeyler (dükkân, kasa, taret), en son denge ve co-op. Bir adım bitmeden sonrakine geçilmez; her adım sonunda commit. Ayrıntılı gerekçeler: `oyun_kritigi_2026-10-19.md`.

## Faz 0: Toparlanma (~1 sa)

1. ~~**Her şeyi commit'le.**~~ (yapıldı) Repoda yalnız 2 commit var, haftalık iş commit'lenmemiş ve paralel oturumlar aynı dosyalara dokunuyor.
2. ~~**Çift anahtar setini teke indir.**~~ (yapıldı: `key_NN.glb` kaldı) `assets/props/keys/` içinde iki set var: `key_NN.glb` (yaygından nadire, `key_cache.gd` bunu kullanıyor) ve `key_NN_<isim>.glb` (iyiden kötüye). Biri silinir, jenerik ona göre düzeltilir.
3. **`viewmodel.gd` parse hatası** (`REAR_SIGHT`, `FRONT_SIGHT`): silah yüklenmiyorsa ilk iş bu.

## Faz 1: İlk 15 dakika (~15 sa)

4. **Açık ekonomi kararları** (kritikte "Senin karar vermen gerekenler"): hedefler ortak kasa mı kişisel mi, kasalar yalnız mermi tipi mi. Bunlar dükkân ve kasa listesini değiştirir.
5. **Dükkân ve açılış sırası:** Q menüsünde kapasite + hedefler + SMG tek liste.
6. **Yerleştirme modu:** satın alınan hedef böyle konur; ileride taret ve bant da aynı kodu kullanır.
7. **Hile menüsü (x10 hız, para ekle) + ilk 15 dakikanın denge turu.** Denge ancak bu menüyle ölçülür.

## Faz 2: İkinci para ve kasalar (~15 sa)

8. **Kovan → fırın → külçe:** taretlerden önce gelmeli, taret geliştirme külçeyle.
9. **Kasa duvarı + anahtar–kasa eşlemesi:** hangi anahtar ne açar (tarayıcı, kolaylıklar, mermi tipleri, iki benzersiz silah). Anahtarların yığına gömülmesi `key_cache.gd` ile kısmen hazır.
10. **Mermi tipi altyapısı + tracer:** tip şarjörde taşınır (CLAUDE.md kuralı). İlk tip tracer: mor, hızlı; vurunca hedefin sağ arkasında ışık olarak belirip tekrar vurur; yankı sayısı upgrade ağacı.

## Faz 3: Otomasyon ve orta oyun (~25 sa)

11. **İlk taret:** dolarla açılır, külçeyle gelişir, zincire girmez. Yığın burada küçülmeye başlar.
12. **Bantlar + robot taşıyıcı:** anahtarlar artık bandın kazdığı yerden fırlar.
13. **Kalan mermi tipleri, birer birer:** seken, bölünme, delici, yanıcı, patlayıcı.
14. **Orta oyun silahı (~6. anahtar):** henüz seçilmedi (öneri: çift namlu av tüfeği). Mermi tiplerinden sonra, çünkü saçmalar onlarla etkileşir.

## Faz 4: Final ve cila (~20 sa)

15. **Minigun (son anahtar):** "delire delire sıkma" finali.
16. **Kilometre taşları (99M/90M/50M/10M/1M) ve son mermi töreni.**
17. **60 dakikalık denge, kayıt sistemi, UI.**
18. **Dışarıdan 3–5 kişiye oynatma.**

## Faz 5: Co-op ve Steam

19. **Host'un seçip yaydığı hedef olayları** (yıldız açısı, köstebek sırası, popper süresi): co-op'tan önce şart.
20. **GodotSteam ile 4 kişilik co-op.**
