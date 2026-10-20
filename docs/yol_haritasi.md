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

4. ~~**Ağ katmanı:**~~ (bitti 2026-10-20) Godot'nun ENet'i ile aynı bilgisayarda iki pencere (host + istemci). `request_*` komutları host'a gider, `GameState` olayları herkese yayılır. Bağlantı katmanı tek yerde durur; Faz 6'da Steam'e geçmek yalnız onu değiştirir.
   - Bağlantı: `scripts/net.gd` (`Net` autoload). Başlatma `-- --host` / `-- --join[=IP]`, debug build'de F7 host, F8 katıl (127.0.0.1). Port 24680. Durum sol üstte ve pencere başlığında.
   - İstemcinin isteği kendi tarafında **tahmin** olarak çalışır (silah, el ve HUD hemen tepki verir) ve host'a gider. Host gerçekten uygular, oyuncunun durumunu geri yollar. İstemci bu cevabı yalnız bütün istekleri cevaplanınca uygular, yoldaki tahmini geri almaz. Dünya (yığın, dökülen mermi, anahtar, atış izi ve ödeme) yalnız host'ta değişir ve olay olarak gelir.
   - Kontrol: `tools/net_check.gd` (iki süreç; istemci, host'un önceden aldığı mermiye uzanınca geri alınır; yığından alır, doldurur, dummy'ye atar; host'un isabeti istemcinin kendi ışınıyla aynı, $1 iki tarafta).
   - Sonraki adımlara kalanlar: katılınca yalnız yığın *sayısı* gelir (şekli, dökülenler, anahtarlar 8. adım); host istemcinin `from` konumuna güvenir (5. adımda senkron konumla doğrulanır); kovanlar atış katmanında (1) ve yalnız atanın makinesinde var, host'un kovanı istemcinin atışını kesebilir (kovanları ayrı katmana almak gerek); her istemci aynı doğma noktasında başlar (5. adım).
5. ~~**Diğer oyuncular:**~~ (bitti 2026-10-20) 3. şahıs karakter (konum, nişan yönü, durum: yürüyor/ateş ediyor/reload); başkasının atışı dünyada alev ve izle oynar. İsim etiketi. (Sesler bu adımda yok, 25. adımda.)
   - Konum: her oyuncu ayağını, yaw/pitch'ini, durumunu (`GameState.Act`) ve havada olup olmadığını saniyede 20 kez yollar (`GameState.send_pose`, unreliable, ayrı kanal); host saklar ve öbürlerine dağıtır. Alan taraf 100 ms geride iki örnek arasında yumuşatır (`scripts/remote_players.gd`).
   - Karakter: bumstrum operatörü, Quaternius UAL animasyonlarıyla (`assets/characters/animations/operator_anims.res`). Bacaklar hıza göre idle/walk/jog/sprint, havadayken zıplar, yerinde inerse çömelir; omurgadan yukarısı tabanca duruşu, reload ve atış klipleri onun üstünde. Pitch omurga ve göğsü klibin üstüne eğer, kalçanın koşudaki sallanması üst gövdeden çıkarılır: silah hep bakılan yöne. Silah sağ bilekte (FP modelinin `Talon` parçası). Kontrol: `tools/remote_anim_check.gd`. Başının üstünde "Oyuncu <id>" (duvar arkasından da görünür). Ayrılınca kaybolur.
   - Başkasının atışı: alev (FP silahın `Flash`'ının kopyası) ve barut taneleri karakterin namlusunda, mermi izi ve mevcut atış sesi oradan çıkar.
   - Doğma: host ilk boş noktayı verir (`_spawn`), host 0'da.
   - Host, istemcinin atışındaki `from`'u o oyuncunun son konumuyla karşılaştırır (göz ±1,5 m, `FIRE_FROM_SLACK`), uzaksa atış hiç olmamış sayılır. Oyuncu gövdeleri artık atışı durdurmaz (host'un gövdesi misafirlerin mermisini yiyordu). Kovanlar zaten hiçbir katmanda değil (`collision_layer = 0`), atışı kesemez; 4. adımdaki not yanlıştı.
   - Kontrol: `tools/net_check.gd` genişledi (ayrı doğma noktası, host'un karakteri istemcide, istemcinin konumu host'ta, atış sesi karakterin namlusunda, sahte `from` reddedilir, ayrılınca karakter gider).
   - Kalanlar: yana ve geri yürürken de ileri yürüme klibi oynar (strafe klipleri UAL'de var, BlendSpace2D ile); oyuncular birbirinin içinden geçer; başkasının kovanı yok (süs, yerel kalır).
6. ~~**Mevcut sistemleri host'a bağla:**~~ (bitti 2026-10-20)
   - Yığın: kazılar zaten olaydı (`bullets_taken`). Host istemci içerideyken 10.000 mermi kazıyor, istemci 1 mermi alıyor; yığın oturunca iki taraftaki 160×160 yükseklik alanı **bit bit aynı** (hash eşit, en büyük fark 0). Kayma adımları sırayla aynı işlediği için kare zamanlaması fark yaratmıyor. Ortada katılan için yükseklik alanını yollamak 8. adımda.
   - Anahtarlar: tohumu host atar (`GameState.key_seed`, `key_layout` olayı, katılana bağlanınca gider). İstemcinin kendi zarı yalnız tek başınayken geçerli; tohum gelince anahtarları kendi yığınına yeniden gömer (host'un başlangıç yığınıyla aynı, konumlar aynı çıkıyor). Açığa çıkma kararı zaten yalnız host'ta.
   - Hareketli hedefler: yeni dünya olayı `target_cue(target, cue)`; hedef kendi kararını host'ta `GameState.cue_target` ile verir, istemci zamanlayıcı ya da zar kullanmaz, bekler. Köstebek rafı: `[plaka]` kalkar, `[-1]` kaçtı. Popper: yatma süresini host seçer, kalkma anı `[]` ile gelir. Texas Star: düşen plaka `[&"off", i, yön]`, geri gelen `[&"on", i]`; açı her 0,5 sn'de `[&"turn", açı, hız]` (istemci ENet gidiş-dönüş süresinin yarısı kadar ileri sarar, `Net.latency()`).
   - Süsler yerel: kovan, duman, kıvılcım, toz, "+$", dökülen merminin tekmelenmesi, fırlatılan merminin saçılımı, düşen yıldız plakasının yuvarlanışı. Rastgelelikleri her makinede ayrı.
   - Kontrol: `tools/net_check.gd` genişledi (yığın hash'i, anahtar konumları, rafın kaldırdığı plakalar, popper'ın düşüp kalkma anı, yıldız açısı; iki süreç aynı duvar saatini okuyarak karşılaştırır). 3 kez üst üste geçti: raf ±0,3 sn içinde aynı plakalar, yıldız farkı 0,02–0,03 rad.
   - **Oyuncular arası (kullanıcı isteği, 2026-10-20):** gövdeler birbirinden geçmez (uzak karakterde kapsül `AnimatableBody3D`, oyuncununkiyle aynı boyda). Birine yürüyen onu iter: çarpışmada yürüme hızının %90'ı `request_push` ile host üzerinden itilenin makinesine gider, itilen kendi gövdesini hareket ettirir (yarım saniyede söner; host mesafeyi ve hızı sınırlar). Dost ateşi öldürmez, para ve kombo vermez (zincir kırılır); vurulanın nişanı yukarı ve yana kayar, görüş sarsılır (`player_shot` olayı). Atan kendi gövdesinden muaf, öbür oyuncular atışı durdurur. Katılan oyuncu host'tan doğma noktası gelene kadar konum yollamaz (yoksa host'un noktasında çarpışıp onu itiyordu). İsim etiketi büyüdü (32 px), oyuncu renginde bir kutunun içinde; renk şimdilik doğma noktasına göre (turuncu, mavi, yeşil, mor; `player_slots` olayı), kendi seçtiği renk 25. adımda. Uzak karakter 3. görsel katmanda: zemin boyası botlarına basılmıyor. Kontrol: `net_check` (istemci host'u vurur, nişanı kayar; üstüne yürür, 0,70 m'de durur, host ~2,2 m itilir; etiket renkleri).
   - Kalanlar: ortada katılan anahtar durumlarını ve hedeflerin o anki halini almıyor (8. adım); istemci yıldızı gecikme kadar geride görmüyor ama vuruşu host'un yıldızında değerlendiriliyor, uzak bağlantıda nişan farkı hissedilebilir (Steam testinde bakılır).
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
25. **60 dakikalık denge (1, 2 ve 4 oyuncuyla) + UI cilası + ses geçişi:** bütün sesler (reload, ayak, boş tetik, kovan) co-op'ta karakterin konumunda 3D. Yerleri hazır: ayak ve reload `remote_players.gd` karakter düğümünde, atış `muzzle_position()`'da.
   - **Karakter ayrıştırma (karar 2026-10-20, en sona):** önce oyuncu sırasına göre otomatik kıyafet rengi (maske + shader, operator dokusunda tişört/pantolon/yelek bölgeleri, ağdan veri gitmez); sonra ana menüde renk seçimi (birkaç sayı, `request_*` ile host'a, `PlayerState`'te). Aksesuar ve farklı karakter demo sonrası.
26. **Dışarıdan test:** 3–5 kişilik gruplar uzaktan, Steam üzerinden oynar.
27. **Steam sayfası ve demo uygulaması:** mağaza sayfası, ekran görüntüleri, fragman, ayrı demo app ID; hedef bir Next Fest'e yetiştirmek.
