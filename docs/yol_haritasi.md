# Yol haritası (2026-10-20, co-op demo)

**Hedef:** Steam'de, 4 kişilik co-op oynanabilen, yaklaşık 1 saatlik ücretsiz demo. Co-op demonun satış noktası: yayıncılar ve arkadaş davetleriyle yayılır.

Sıra kuralı: her adım bir sonrakinin sayılarını belirler. **Co-op en başta kurulur**, sonraki her sistem iki pencereyle denenerek yapılır. Steam, dışarıdan testten önce gelir: test edenler uzaktan bağlanabilmeli. Bir adım bitmeden sonrakine geçilmez; her adım sonunda commit. Ayrıntılı gerekçeler: `oyun_kritigi_2026-10-19.md`.

**Her sistemde sorulacak co-op soruları:**
- Durumu kim değiştirir? Yalnız host. Oyuncu `request_*` komutu yollar, host uygular, sonucu olay olarak herkese yayar.
- Rastgelelik nerede? Yalnız host'ta seçilir ve sonuç yayılır. İstemci kendi zarını atmaz.
- Kimin malı? Gold kişisel; dünya yapıları ortak kasadan; kasa özellikleri bütün takıma.
- Aynı anda iki oyuncu isterse? Host'a ilk gelen kazanır, öbürüne ret olayı gider.
- Oyun ortasında katılan oyuncu ne görür? Host o anki durumu bir kerede yollar.

**Kararlar (2026-10-20):** demo co-op olacak; kasa açılınca özellik bütün takıma açılır; dünya yapıları ortak kasadan alınır; oyuncu sayısına göre yığın ölçeği dünya oluşturma sayfasında seçilecek (Faz 6).

## Faz 0: Toparlanma (bitti)

1. ~~Her şeyi commit'le.~~
2. ~~Çift anahtar setini teke indir.~~ `key_NN.glb` kaldı, 12 anahtar.
3. ~~`viewmodel.gd` parse hatası.~~ Nişangâh işi bitince kendiliğinden çözüldü.

## Faz 1: Co-op iskeleti (~12 sa)

4. **Ağ katmanı:** Godot'nun ENet'i ile aynı bilgisayarda iki pencere (host + istemci). `request_*` komutları host'a gider, `GameState` olayları herkese yayılır. Bağlantı katmanı tek yerde durur; Faz 6'da Steam'e geçmek yalnız onu değiştirir.
5. **Diğer oyuncular:** 3. şahıs karakter (konum, nişan yönü, durum: yürüyor/ateş ediyor/reload); başkasının atışı dünyada alev, ses ve izle oynar. İsim etiketi.
6. **Mevcut sistemleri host'a bağla:**
   - Yığın kazıları zaten olay (`bullets_taken`); her makinede aynı sonucu verdiği doğrulanır.
   - Anahtar dizilimi (`key_cache.gd`) host'ta seçilir, tohumu yayılır.
   - Köstebek rafının sırası, popper'ın yatma süresi, Texas Star açısı host'tan olay olarak gelir.
   - Kovan, duman gibi süsler yerel kalır.
7. **Ortak kasa:** her isabetin payı (yer tutucu %20) kasaya akar, HUD'da görünür.
8. **Katılma ve ayrılma:** oyun ortasında katılan oyuncu durumu bir kerede alır; ayrılan istemcinin kişisel durumu saklanır, geri dönünce kaldığı yerden; host ayrılırsa oturum biter (host göçü yok).

## Faz 2: İlk 15 dakika (~15 sa)

9. **Dükkân:** Q menüsünde kişisel (kapasite, SMG) ve ortak (hedefler) bölümler. Ortak alımda kasadan düşülür, herkes görür.
10. **Yerleştirme modu:** satın alınan hedef böyle konur; ileride taret ve bant da aynı kodu kullanır. Konumu host doğrular; aynı yere iki kişi koyarsa ilk gelen kazanır. Başkalarının önizlemesi soluk görünür.
11. **Hile menüsü (x10 hız, para ekle) + ilk 15 dakikanın denge turu:** yalnız host açar, yalnız debug build'de. Denge 1 ve 2 oyuncuyla ölçülür.

## Faz 3: İkinci para ve kasalar (~15 sa)

12. **Kovan → fırın → külçe:** kovanı kim toplarsa onun; fırın dünya yapısı (ortak); külçe kişisel mi ortak mı bu adımda karar.
13. **Kasa duvarı + anahtar–kasa eşlemesi:** anahtarı yürüyen oyuncu alır (host'ta ilk gelen), kasa açılınca özellik herkese açılır, açılış töreni herkesin ekranında oynar.
14. **Mermi tipi altyapısı + tracer:** tip oyuncunun şarjöründe taşınır. Tracer: mor, hızlı; vurunca hedefin sağ arkasında ışık olarak belirip tekrar vurur; yankı vuruşlarını host zamanlar, herkes görür; yankı sayısı upgrade ağacı.

## Faz 4: Otomasyon ve orta oyun (~25 sa)

15. **İlk taret:** ortak kasadan alınır, külçeyle gelişir, zincire girmez. Hedef seçimi ve atış host'ta, istemciye yalnız atış olayları.
16. **Bantlar + robot taşıyıcı:** host simüle eder; bant kazısı `bullets_taken` olayıyla yayılır, anahtarlar bandın kazdığı yerden fırlar.
17. **Kalan mermi tipleri, birer birer:** seken, bölünme, delici, yanıcı, patlayıcı. Sekme hedefleri ve bölünme zarı host'ta.
18. **Orta oyun silahı (6. anahtar, Kum Adamı):** silah henüz seçilmedi. Saçma dağılımı host'ta hesaplanır.

## Faz 5: Final (~15 sa)

19. **Minigun (12. anahtar, Dişli):** herkese açılır; yüksek atış hızında ağ yükü için atışlar paketlenir (ör. 50 ms'de bir toplu olay).
20. **Kilometre taşları (99M/90M/50M/10M/1M) ve son mermi töreni:** son mermiyi alan oyuncu gonga atar, herkesin ekranında.
21. **Co-op iletişimi:** ping ve emote ikonları (CLAUDE.md kuralı: konuşma animasyonu yok).

## Faz 6: Steam ve demo hazırlığı (~20 sa)

22. **GodotSteam:** lobi, arkadaş daveti, "arkadaşına katıl". Bağlantı katmanı ENet'ten Steam'e geçer.
23. **Ana menü ve dünya oluşturma:** host et / katıl / ayarlar; oyuncu sayısına göre yığın büyüklüğü burada seçilir.
24. **Kayıt:** dünya host'ta kaydedilir; kişisel durum Steam ID'ye göre saklanır.
25. **60 dakikalık denge (1, 2 ve 4 oyuncuyla) + UI cilası.**
26. **Dışarıdan test:** 3–5 kişilik gruplar uzaktan, Steam üzerinden oynar.
27. **Steam sayfası ve demo uygulaması:** mağaza sayfası, ekran görüntüleri, fragman, ayrı demo app ID; hedef bir Next Fest'e yetiştirmek.
