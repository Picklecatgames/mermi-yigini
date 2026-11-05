# Otomasyon makineleri ve yardımcılar: fikirler ve model adayları (2026-11-05)

Kullanıcının sözü: "Bir oturumda videodaki gibi, oyunu bozmayacak, oyuna uygun dilde otomasyon makineleri ve yardımcılar için fikirler bulup model araştırması yap."

**Bu dosya araştırma. Kural yok, kod değişmedi, sahneye bir şey konmadı.** Kullanıcı kararları yalnız aşağıdaki kısa listede. Geri kalan her fikir, sıra ve seçim benim önerim; her sayı tahmin.

Önizlemeli aday galerisi: https://claude.ai/artifact/BXbxg8NKfZfEVY7Y1JUqpQ

## Kullanıcı kararı: işin düğümleri (2026-11-05)

Kullanıcının sözü (yazımı düzelttim): "Şimdi bize şu düğümler lazım: taşıma, taşıma kapasitesi artıran kova, el arabası vs., bir yerden sonra teleferik; bu taşıma sistemi. Bir de demiri öğütme, öğütülmüş demiri eritme, eritilmiş demiri işleme. Bunlar düğümlerimiz, işlerimiz olacak; gündüz vaktinde, isterse gece de yapabilir."

Karar olan yalnız şu: **taşıma merdiveni** (kova, el arabası vs., sonra teleferik), **demir zinciri** (öğütme → eritme → işleme), ve bunlar gündüzün işi, oyuncu isterse gece de yapar. Aşağıdaki tablolarda düğümlerin dışındaki her şey benim önerim, sayılar tahmin. Bu karar, aşağıdaki 8 fikirden çuval ve el arabası ile teleferiği doğruluyor; öbür fikirler öneri olarak kalıyor.

### Taşıma

| Düğüm | Durum | Bir seferde (tahmin) | Bedeli (benim önerim) | Model |
|---|---|---|---|---|
| Elle | Karar | 1 parça | Yok | Gerekmez |
| Kova | Karar | 10 parça | Bir eli doldurur | [Wooden Bucket 01](https://polyhaven.com/a/wooden_bucket_01), CC0; metal kova aranmadı |
| Çuval | Önerim ("vs." içinde) | 25 parça | Doldurması zaman alır, yavaşlatır | Galeride, taranmış çuval |
| El arabası | Karar | 6 çuval | İki eli doldurur, silah elde değil | Galeride, paslı el arabası |
| Teleferik | Karar, "bir yerden sonra" | Sürekli akış | Tek hat, dolum ve boşaltma insan ister | Galeride, makara ve halat üretilir |

Mevcut kodda taşınan tek şey elle alınan parça (`request_pick_up`).

### Demir zinciri

| Düğüm | Girer | Çıkar | Makine | Bugün elimizde |
|---|---|---|---|---|
| Öğütme | Demir hurda | Öğütülmüş demir | Öğütücü | `assets/props/ogutucu/`, model benim. Üretim temelindeki `ezici` buna yakın |
| Eritme | Öğütülmüş demir, yakıt (önerim) | Erimiş demir | Fırın ve pota | `scripts/hopper.gd`, `request_melt`: eski mermi-kovan zinciri için, yeniden bağlanır. Model `assets/props/workbench/hopper.glb` |
| İşleme | Erimiş demir | İşlenmiş demir: üretimin girdisi (önerim) | Pres, kalıp | `assets/props/press/`, `scripts/press.gd`, `request_press`: aynı şekilde eski zincirden |

Üç makinenin üçünün de modeli ve eski bir kod yolu var, ama eski yollar başka bir zincir için yazılmış. Üretim temelinin tarifleri (`claude/angry-yonath-6994c0`, `data/recipes.json`) bugün `sokme` ve `ezme`; hurda doğrudan malzemeye dönüyor, ara ürün yok. Bu zincir için üç yeni ürün ve üç tarif gerekir. Kod değiştirmedim.

**Açık kalanlar:**
1. Zincir yalnız demir için mi? Çelik, bakır, teneke de aynı yoldan mı geçiyor? Sökücü olmadığı için hurdadaki kauçuk, ahşap gibi demir dışı malzemelerin ne olacağı da buna bağlı.
2. Her düğümde kol mu, motor mu? Önce elle, sonra motorla (benim önerim).

**Kullanıcı kararı, sökücü yok (2026-11-05):** "Sökücü gerek yok, yoksa oyuncu tüm gün kafası yorulur, geceye kafa kalmaz." Hurda doğrudan öğütücüye girer. Üretim temelindeki `sokucu` satırı ve `sokme` tarifi (`claude/angry-yonath-6994c0`) bu karara göre kalkar; o dala dokunmadım. Aşağıdaki 2. fikir bu yüzden kollu öğütücü oldu.

## Kullanıcı kararı: yabancı (2026-11-05)

Kullanıcının sözleri (yazımı düzelttim): "Tüm bunlar için zombi uzvu kullanmak sığ kalabilir, bir ya da ikisinde kullanmalıyız. Şöyle bir şey yapalım: oyunun bir noktasından sonra bir yabancı gelsin, NPC, bu mesela teleferiği kullanacak ama bir maliyeti olmalı." Maliyet sorusuna, önerdiğim mermiye: "Mermi iyi bir fikir, o yabancı da kendi grubuna avlanan biriymiş gibi olur."

Karar olan: zombi yalnız bir iki makinede; oyunun bir noktasından sonra bir yabancı NPC gelir ve teleferiği kullanır; bedeli mermi; yabancı kendi grubu için avlanan biri gibidir.

**Benim önerim (kural değil, sayılar tahmin):**
- **Geliş:** Teleferik kurulduktan sonra bir sabah alt istasyonda oturuyor olur. Tam oyunda 9. gece civarı, demoda yok.
- **Ödeme:** Her sabah bir kutu mermi bırakılır, istediği miktar geceler geçtikçe artar. Ortak kasadan çıktığı için dört kişi birlikte karar verir. Tek karar, yeni iş değil.
- **Ödenmezse:** Hat o gün durur, dolum ve boşaltma elle yapılır. Üst üste ödenmezse gider.
- **Grubu:** Mermi nereye gidiyor sorusunun cevabı bu. Grup hiç görünmeyebilir: yalnız uzaktan silah sesi, ormanda av izleri, kulübede başkasına ait eşyalar. Mermiyle yaptığı avın zombi mi başka bir şey mi olduğu açık kalabilir.
- **Gece:** Kulübede kalır, üssü savunmaz. Ölürse hat durur.
- **Havayı korumak için:** Tek kişi, kulübeden çıkmaz, az konuşur, görev ekranı yok. Yol bulma yapay zekâsı gerekmez. Aşağıdaki "NPC işçi ve kolonist" maddesi kalabalık ve görev düzeni için geçerli, bu yabancı için değil.
- **Zombi:** Zincirli ölü yalnız öğütücü kolunda kalır.

**Kullanıcı kararı, grup sonda gelir (2026-11-05):** "Sonda gelsinler." Yabancının grubu oyunun sonuna kadar görünmez, sonda gelir.

**Sonla ilgili önerim (kural değil):**
- **Son gece:** Grup 14. gecede gelir. Oyun boyunca yalnız uzak silah sesi, av izleri, kulübedeki eşyalar ve tek cümleler duyulur.
- **Verdiğin mermi geri döner:** Yabancıya toplam ne kadar mermi verildiyse grup o kadar güçlü gelir (sayı ya da ateş süresi). Sabahları verilen küçük karar sonda ödenir. Az verenin teleferiği daha çok durmuştur, dağı daha geride kalmıştır; bu iki bedel birbirini dengeler.
- **Yabancının sonu:** Yaşıyorsa onlarla gelir; öldüyse grup ölüsünü bulup yine gelir, ama daha az mermiyle.
- **Demo:** Grup ve yabancı demoda yok.

**Yapım bedeli:** Bugünkü dalga düşmanları yakın dövüş için kurulu; ateş eden insan düşman, siper ve oyuncuya ateş yeni iş (yüksek, tahmin). Ağda host otoriter olmalı. Model aranmadı, Mixamo aday listesi dışı.

**Açık:** Grup gelince zombi dalgası da sürüyor mu; grupla konuşma ya da pazarlık var mı. Yabancının ve grubun modeli de aranacak.

## Oyuncu karakterleri ve yabancı: model adayları (2026-11-05)

Kullanıcının sözü: "Karakter tiplerimiz oyuna çok kötü duruyor, sen bulsana." Bunu oyuncu bedenleri (`GameState.CHARACTERS`: Patron, Maskeli, İşçi, Brute, Chupacabra) diye okudum; zombileri kapsamıyor. Seçim kullanıcının, ★ benim önerim. Hepsi galeride, "Oyuncu karakterleri ve yabancı" grubunda.

| Aday | Yazar | Lisans | Üçgen | Animasyon | Neden uyar | PS1 |
|---|---|---|---|---|---|---|
| [Farmer](https://sketchfab.com/3d-models/farmer-ae5182ccddfd47acb59400f739581743) ★ | LxNazarov | CC-BY 4.0 | 8.606 | 4 animasyon | Kürk şapka, yamalı ceket, ağır kürek. Hurdada çalışan biri gibi okunuyor; oyuna en doğru tip. | **dikkat.** Sayfa doku sayısını 0 gösteriyor ama görselde boyalı; indirince bakılmalı. 4 animasyon kendi iskeletinde, kürek ayrı mı bilinmiyor. |
| [Butcher](https://sketchfab.com/3d-models/butcher-8d76c3ade3bf46218c782f983b0b0596) ★ | Artise1 | CC-BY 4.0 | 5.248 | 1 animasyon | Kanlı önlük, satır, kaba yüz. Gore ve tekinsizlik doğrudan üstünde. | **uygun.** 5.248 üçgen, 1024 px doku (yazarına göre). Satır ayrı sayılmış, ayrılması kolay olabilir. |
| [Prisoner Hostage Low Poly Character](https://sketchfab.com/3d-models/prisoner-hostage-low-poly-character-dae7e2ff73cd4ece8d7655d1f4fcbb1b) ★ | 00amza | CC-BY 4.0 | 2.283 | 1 animasyon | Turuncu tulum, sıradan yüz: kaçmış bir mahkûm. Yazarı Mixamo iskeleti diyor, bugünkü kliplerle çalışması en olası aday. | **uygun.** 2.283 üçgen, tek doku. Turuncu kirletilir. |
| [Biohazard Survivor](https://sketchfab.com/3d-models/biohazard-survivor-2d8f986cfea5409d80ff60a79ce0d571) ★ | Jim Wing | CC-BY 4.0 | 1.110 | animasyon yok | Yıpranmış koruyucu giysi ve gaz maskesi, yüz yok. Gerçek PS1 ölçüsü. | **uygun.** 1.110 üçgen, tek doku, çeviriye gerek az. T-poz; rig indirmeden belli değil. |
| [PS2 / PSX Lowpoly Character](https://sketchfab.com/3d-models/ps2-psx-lowpoly-character-d737592243fc433e842d745f8e7f296f) ★ | Loco | CC-BY 4.0 | 7.136 | 1 animasyon | Kamuflaj ceketli sıradan adam, PS2/PSX tarzında yapılmış. | **uygun.** 7.136 üçgen, rigged etiketi, 1 animasyon. Yüz ve eller parlak, kirletilir. |
| [old man psx](https://sketchfab.com/3d-models/old-man-psx-dc42fa861cd645f489be5c9b3d2076fb) | petya-petyavich | CC-BY 4.0 | 1.591 | 1 animasyon | Yırtık kot, ekose gömlek, yaşlı adam. Yedek; gerçek PS1 dokusu. | **uygun.** 1.591 üçgen, tek doku, 1 animasyon. |
| [Alan Survivor(rigged)](https://sketchfab.com/3d-models/alan-survivorrigged-cca25ef7b9794d49b909022ed8e81f15) | RRB STUDIOS | CC-BY 4.0 | 14.353 | animasyon yok | Kaba kıyafetli hayatta kalan, yedek. Biraz temiz ve oyunsu. | **dikkat.** 14 bin üçgen, 8 malzeme, 16 doku; sadeleşmeli. |
| [antiradiation suit - ozk](https://sketchfab.com/3d-models/antiradiation-suit-ozk-2e815542505d48d8be91e9f7dbebfd0a) ★ | sanyaork | CC-BY 4.0 | 20.813 | animasyon yok | Yabancı için: gaz maskeli, kamuflaj, üstü başı eşya dolu. Yüzü hiç görünmez, kulübede oturunca çok tekinsiz durur. | **dikkat.** 20.813 üçgen, 6 malzeme, 30 doku; yazarı parçaların söküldüğünü ve rig olduğunu söylüyor. Çeviride düşmeli. |

- **Yapım:** Bedenler `tools/build_zombies.gd players` ile kuruluyor, ölçek gözden hesaplanıyor (`remote_players.gd`), PS1 çevirisi zombilerle aynı hat. Klipler `mixamorig_` kemik adlarını bekliyor. Yalnız Prisoner için yazarı Mixamo iskeleti diyor; öbürleri indirilip iskeletine bakılmalı, gerekirse yeniden hedeflenir ya da yeniden rig'lenir.
- **Mixamo:** Bedenler değişse de `player_anims.res` Mixamo paketlerinden geliyor; o soru durur.
- **Doğrulanmayan:** Hiçbiri indirilmedi, rig ve kemik adları görülmedi. Oyundaki bugünkü bedenlere de bakmadım, kötü durduklarını kullanıcıdan biliyorum.
- **Elenenler:** A.B.C. Soldier (Nazi etiketleri, tanınan silah), Hunter from Left 4 Dead, Aya Brea, Genome Soldier (başka oyunlardan), Old man in coat (Fuse ile yapılmış, lisansı bana net değil), Old fat man ve Redneck (komik), Marie Survivor (28 animasyonu var ama açık giysili, oyunun tonuna uymuyor).

## Kısa özet

- En iyi 8 fikir, sırayla: **çuval ve el arabası, kollu öğütücü, dizel motor ve kayış, elle beslenen mazgal, zincirli ölü, teleferik, pençeli vinç, kişisel takım.**
- Her biri için 2-4 model aday buldum, galeride 50 model var. En sağlam eşleşmeler: [taranmış kütük ayırıcı](https://sketchfab.com/3d-models/old-wood-splitter-7d416be344604eeb9143af39c21e007b) (kollu öğütücü), [terk edilmiş jeneratör](https://sketchfab.com/3d-models/abandoned-soviet-generator-game-ready-ue5-prop-0f11d8e9b59b431295e42ddf579c38ce) (motor), [elde yapılmış taret](https://sketchfab.com/3d-models/post-apocalyptic-turret-d561bde953754ceca06e38737ffea40d) (mazgal), [ırgat](https://sketchfab.com/3d-models/capstan-anchor-winches-e8537c1d32d4401b91d0332107a4560d) (zincirli ölü), [liman vinci](https://sketchfab.com/3d-models/port-crane-sokol-4964eaa7634e47c9bac4c2a74fa91c20) (vinç).
- **Üretilmesi gerekenler:** hurda pençesi, teleferik makarası ve halatı, kayış ve kasnak, sırt çerçevesi, mıknatıs ucu. Rig'li, sıska, gerçekçi bir köpek bulamadım.
- En çok kullanıcı kararı isteyen şey **zincirli ölü**: bence en özgün fikir, ama tonu oyunun kimliğini etkiler.

## Dayanak

- **Kullanıcı kararları:** bant, taret, hurda dönüştürme, kasaya alma; kasa yüzde yüz ortak; kişisel geliştirmelerde otomatikleştirme; tek dağ; tam oyun 5-6 saat, demo ~1 saat; "Oyuna Factorio ekleyip de oyunun o küt, o tekinsiz havasını gezen taretlerle yapmak istemiyorum, bu videoda görünen gibi olmasını istiyorum"; görünüm düz renkli mobil değil, gore ve gerçekçi korkuya yakın, PS1 korku; yalnız CC0 ve CC-BY.
- **Video:** `docs/taret_notlari.md` notlarına dayandım (`claude/taret-notlari-0cdf09` dalında). Anlamadığım bir şey çıkmadı, videonun kendisine bu oturumda bakmadım. Notlardaki önemli sonuç: videoda taret ve düşman yok, makine dili var: ağır, sabit, tek işlik, elle beslenen, dar boğazı hiç bitmeyen. Yayıncının özeti: "asla seni full otomasyona bırakmıyor".
- **Üretim temeli:** `claude/angry-yonath-6994c0`, `data/machines.json` (`bant`, `cekici`, `sokucu`, `ezici`, `kasa`), `data/items.json`, `data/recipes.json`. Bu dal okunarak bakıldı, buraya birleşmedi. Malzeme adları oradan: demir, çelik, ahşap, kauçuk, bakır. Yakıt ve mermi temelde yok, yeni kaynak olurlar.

## Dil testi (benim önerim)

Bir fikir şu beş soruya evet demeli:

1. **Ağır ve sabit mi?** Kolay taşınmaz, kovalamaz, oyuncunun peşinden gelmez.
2. **Birinin eli değiyor mu?** Hep bir yakıt, kol, tıkanıklık, boşaltma işi kalır.
3. **Bedeli var mı?** Gürültü, yakıt, arıza, savunmasız kalan bir adam.
4. **Bozulunca gece dışarı çıkma sebebi mi oluyor?** Bu, otomasyonu korkuya bağlayan en ucuz bağ.
5. **Birinci şahıstan okunuyor mu, elle yapılmış mı?** Hurdadan kaynak, kaba ahşap, boyası kalkmış sac.

Video şunu da söylüyor: her satın alma bir **acıyı** siler. O yüzden her fikirde "oyuncunun neyini değiştirir" diye yazdım.

## En iyi 8 fikir (sıra benim önerim)

Sıra yapım ve oynanış sırası: öndeki, arkadakinin temelini kurar. Zorluk: düşük bir oturum, orta birkaç oturum, yüksek bir hafta ve üstü (tahmin).

### 1. Çuval ve el arabası

- **Ne yapar:** Dağın önünde E'ye basılı tutarak çuval doldurursun. Çuvalı arabaya atarsın (6 çuval, tahmin) ve arabayı iki elle iterek makineye götürürsün.
- **Oyuncunun neyini değiştirir:** Tek tek parça taşımak biter. Gün artık "kaç sefer yetişir" hesabına döner.
- **Hava:** Besler: arabayı iterken silah elde değil, tekerlek gıcırdıyor, gün kararıyor. Bozabilir: araba hızlı ve hafif olursa oyuncak olur; ağır ve yokuşta yavaş olmalı.
- **Gece:** Dışarıda kalan araba engel olur, videoda da öyle kullanılıyor. Zombi çarparsa devrilir, çuvallar saçılır (benim önerim). Sabah toplanır.
- **Kaynak:** Yapım demir, ahşap, kauçuk. Çalışırken yalnız beden.
- **Co-op:** Herkes çuval doldurur, araba tek kişiyle yürür, ikincisi hızlandırır. Yük ortak, kasa zaten ortak.
- **Zorluk:** Düşük-orta. İki elle tutuş, silah indirme, ağ durumu.

| Aday | Yazar | Lisans | Üçgen | Rig, animasyon | Doku | Neden uyar | PS1 çevirisi |
|---|---|---|---|---|---|---|---|
| [Rusty Wheelbarrow](https://sketchfab.com/3d-models/rusty-wheelbarrow-2be2971dbfa742c292bfff11451d5bb8) ★ | MrM0lten | CC-BY 4.0 | 4.628 | animasyon yok | 5 doku, 1 malzeme | Paslı, gerçek el arabası, boya kalıntısı var. Oyuna en doğrudan oturan. | **uygun.** Üçgeni düşük, doku tek set. 1.500'e rahat iner (tahmin). |
| [Wooden Wheelbarrow](https://sketchfab.com/3d-models/wooden-wheelbarrow-48314bafaffc4593ba1d7a5af31810c6) | Peter Nox | CC-BY 4.0 | 1.492 | animasyon yok | 4 doku, 1 malzeme | Tamamen ahşap, elle çakılmış görünüyor. Dağdan yapılan ilk şey için iyi. | **uygun.** Zaten çok düşük üçgen, olduğu gibi girer. |
| [Wheelbarrow (old, rusty)](https://sketchfab.com/3d-models/wheelbarrow-old-rusty-a101a06aedd14d90a0992e32c27d64fc) | artgromov | CC-BY 4.0 | 10.580 | animasyon yok | 4 doku, 1 malzeme | İkinci paslı seçenek, daha derin tekne, çuval sığdırmak kolay. | **uygun.** Üçgeni fazla ama yapısı düz, iner. |
| [Old burlap bag photo scan](https://sketchfab.com/3d-models/old-burlap-bag-photo-scan-d52b9c947f994d528e872f71a1cabba1) ★ | Teilor Andersen | CC-BY 4.0 | 4.906 | animasyon yok | 5 doku, 1 malzeme | Taranmış eski çuval, ağzı bağlı. Çuval için en inandırıcısı. | **uygun.** Tarama ama üçgeni düşük. 128 px yeter. |

Çuvalın dolu hâli var; boş ve yarım hâli üretilir.

### 2. Kollu öğütücü

Kullanıcı sökücüyü kaldırdı; aynı fikir zincirin ilk makinesine, öğütücüye geçti (benim önerim). Tablodaki adaylar öğütücü gövdesi olarak değerlendirilir.

- **Ne yapar:** Öğütücünün ilk hâli. Hazneye 40 parça doldurursun (tahmin), kolu basılı tutup çevirirsin. Çeviren yoksa durur. Sonra aynı makineye motor bağlanır.
- **Oyuncunun neyini değiştirir:** Hurda düşünmeden girer, ince iş yok, kafa geceye kalır. Biri makineye bağlı kalır. Videodaki "kollu soyma makinesi" basamağının aynısı.
- **Hava:** Besler: ses, ritim, sırtın dönük. Hazneden mayın ya da bomba çıkabilir; ses verir, fark edip fırlatmak gerekir (videoda yığında var). Bozabilir: yok denecek kadar az, ağır kol zaten bu dilin kalbi.
- **Gece:** Kol sesi uzaktan duyulur. Sıkışınca levyeyle açmak gerekir, gece bu tek başına bir korku anı.
- **Kaynak:** Yapım çelik. Çalışırken beden.
- **Co-op:** Biri besler, biri çevirir, biri nöbet tutar. İki kişi çevirince az hızlanır (tahmin, 1,3 kat).
- **Zorluk:** Düşük. Makine satırı var, kol etkileşimi eklenir. Hazne tıkanması biraz daha.

| Aday | Yazar | Lisans | Üçgen | Rig, animasyon | Doku | Neden uyar | PS1 çevirisi |
|---|---|---|---|---|---|---|---|
| [Old wood splitter](https://sketchfab.com/3d-models/old-wood-splitter-7d416be344604eeb9143af39c21e007b) ★ | Lassi Kaukonen | CC-BY 4.0 | 137.978 | animasyon yok | 3 doku, 2 malzeme | Taranmış gerçek kütük ayırıcı: kaba ahşap çerçeve, volan, el çarkı. Aradığım elle yapılmış, küt dil. | **dikkat.** Tarama, 138 bin üçgen, altında yuvarlak zemin diski var. Disk kesilir. psx_props'ta tarama için ızgara yolu yalnız orman grubunda açık, burada da açılmalı. Tek deriyse çark dönmez; indirmeden doğrulanmadı. |
| [Hand Cranked Grinder - GAP Tool](https://sketchfab.com/3d-models/hand-cranked-grinder-gap-tool-84b281490ba34620a4ed8bf0dd6c68be) | Tatyana_Petrova | CC-BY 4.0 | 4.034 | animasyon yok | 4 doku, 1 malzeme | El çarkı açıkça okunan döküm öğütücü. Büyütülünce kollu öğütücü olur. | **uygun.** Temiz, 2.000 üçgene iner (tahmin). Kırmızı boyası pas rampasına çekilir. |
| [Low Poly Meat Grinder "ALEXANDERWERK Nº 22"](https://sketchfab.com/3d-models/low-poly-meat-grinder-alexanderwerk-no-22-89137f6445fb4c55bc58bde6047ff2ba) | ArtemMoiseev | CC-BY 4.0 | 4.930 | animasyon yok | 5 doku, 1 malzeme | Dev bir kıyma makinesi: hurda ağzı, delikli ayna, sap. Gore ile iyi gider. | **dikkat.** Adında gerçek marka var (ALEXANDERWERK). Görselde logo görmedim, gövde ve dokuda ayrıca bakılmalı. Kırmızı boya pasa çekilir. |
| [RG Ross & Sons Steam Hammer](https://sketchfab.com/3d-models/rg-ross-sons-steam-hammer-d80b52dc800e4c76b6b27749bbd8e782) | Scottish Maritime Museum | CC0 | 70.069 | animasyon yok | 4 doku, 1 malzeme | 1907'den kalma, müzede taranmış buhar çekici. Motorlu aşamanın ezicisi için çok ağır ve güzel. CC0. | **dikkat.** 70 bin üçgen, üstünde kurulu zemin de var. Çekiç ayrı parça değilse inip kalkmaz; indirince bakılmalı. |

Kol ve hazne çoğu adayda ayrı değil. Kolun dönmesi için indirince parçalara bakılacak; gerekirse kol Blender'da ayrılır.

### 3. Dizel motor ve kayış

- **Ne yapar:** Üsse tek tek enerji kablosu yerine **tek motor** kurulur, kalın kayışla yanındaki 2-3 makineyi döndürür. Elle kolla marş edilir, bazen tutmaz. Yakıt elle dökülür.
- **Oyuncunun neyini değiştirir:** Kol başındaki kişi serbest kalır. Dar boğaz yakıta ve makine yerleşimine kayar.
- **Hava:** Besler: gündüz güven veren motor sesi, gece tehlike olur. **Motorun durması oyunun en korkunç anı olabilir:** sessizlik, sonra marş kolu, tutmuyor. Bozabilir: temiz bir jeneratör ve kablo ağı şebeke hissi verir, bu yüzden kablo değil kayış.
- **Gece:** Motor çalışırsa düşman sese doğru gelir. Kod bugün bunu desteklemiyor (`otomasyon_hazirlik.md`, düşmanın yapıya saldırması yok). Motoru kapatmak da bir seçim olur.
- **Kaynak:** Yakıt (temelde yok). Yapım çelik, bakır, kauçuk.
- **Co-op:** Biri marş eder, biri kapı tutar. Yakıt taşımak ayrı bir iş.
- **Zorluk:** Orta. Enerji kullanıcı kararı bekliyor (`otomasyon_hazirlik.md` soru 2), bu fikir o soruya bir cevap önerisi.

| Aday | Yazar | Lisans | Üçgen | Rig, animasyon | Doku | Neden uyar | PS1 çevirisi |
|---|---|---|---|---|---|---|---|
| [Abandoned Soviet Generator (Game Ready UE5 Prop)](https://sketchfab.com/3d-models/abandoned-soviet-generator-game-ready-ue5-prop-0f11d8e9b59b431295e42ddf579c38ce) ★ | olegolegperepelica | CC-BY 4.0 | 15.128 | animasyon yok | 5 doku, 1 malzeme | Terk edilmiş, paslı, korku oyunu için yapılmış Sovyet tarzı jeneratör. En uyanı. | **uygun.** 15 bin üçgen, tek doku seti. 2.000'e iner (tahmin). Adında UE5 geçiyor; Sketchfab sayfası CC-BY ve indirilebilir. |
| [Rusty Petrol Generator](https://sketchfab.com/3d-models/rusty-petrol-generator-f02b85c8698e48ab9b1c6845fab57c23) | Showdoze | CC-BY 4.0 | 17.060 | animasyon yok | 9 doku, 3 malzeme | Motor gövdesi çerçeve içinde açıkta, daha endüstriyel. | **uygun.** 3 malzeme, doku sayısı yüksek; 256 px'e indirilir. |
| [Flywheel with Cylinder](https://sketchfab.com/3d-models/flywheel-with-cylinder-2d60d641ab7348249a523bdc0587c85b) ★ | patspet | CC-BY 4.0 | 21.692 | 1 animasyon; rig indirmeden görünmüyor | 8 doku, 2 malzeme | Gerçekten dönen volan ve silindir, kayış düzeneğinin görünen parçası. | **dikkat.** 1 animasyon var. Rig'liyse psx_props üçgen düşürmez (skinned mesh atlanır); indirip bakılmalı. Yeşil oksit güzel. |
| [Old Military Compressor](https://polyhaven.com/a/old_military_compressor) | Brian Speight | CC0 | 79.042 | yok | PBR set | Tanklı, tekerlekli, askeri kompresör. CC0, ayrintilar.md'de zaten kayıtlı. | **uygun.** 79 bin üçgen; projede kayıtlı olduğu için önce mevcut dosyaya bakılır. |

Kayış ve kasnak hazır bulunmadı: basit silindir ve kayan dokuyla üretilir.

### 4. Elle beslenen mazgal

Taret kararı kullanıcının, "gezen olmasın" sözü de. Bu, `taret_notlari.md`'deki önerinin model için hâli.

- **Ne yapar:** Cıvatayla sabit, 90-120° yayı olan (tahmin), ağır dönen, isabeti kötü silah. Kuşak ya da kutu elle takılır.
- **Oyuncunun neyini değiştirir:** Geceyi çözmez, bir yönü tutar. Kişi diğer yöne gider, kuşak taşır.
- **Hava:** Besler: mermi bitince tık tık sesi karanlıkta bir korku anı; tutukluk açmaya dışarı çıkılır. Bozabilir: güçlü ve çok sayıda olursa oyuncu seyirci kalır. Az olmalı, 4-6 tane (tahmin).
- **Gece:** Namlu alevi yer belli eder, düşman oraya akar (kod bugün desteklemiyor). Görmediğini vurmaz; projektör ya da ayaklı lamba ister.
- **Kaynak:** Mermi, elle kasadan. Kasadan kendi almaması benim önerim; bugünkü `otomasyon_hazirlik.md` tersini yazıyor (soru 5, `taret_notlari.md`).
- **Co-op:** Kuşak taşıyan ve çözen rol iyi çıkar. Kombo vermez, para az verir, eski not da böyle.
- **Zorluk:** Orta-yüksek. Hedef seçme, atış, ağ; ses ve düşman tepkisi ayrı.

| Aday | Yazar | Lisans | Üçgen | Rig, animasyon | Doku | Neden uyar | PS1 çevirisi |
|---|---|---|---|---|---|---|---|
| [Post Apocalyptic Turret](https://sketchfab.com/3d-models/post-apocalyptic-turret-d561bde953754ceca06e38737ffea40d) ★ | jimgunzel | CC-BY 4.0 | 17.078 | animasyon yok | 30 doku, 6 malzeme | Mermi kutusu, sac kalkan ve tabureye benzer sehpa: birinin elde yaptığı belli. Bulduğum en doğru dil. | **dikkat.** Yazarı oyun için optimize değil diyor: 6 malzeme, 30 doku, 17 bin üçgen. Çevirince iner; dönen kısım ayrı mı bakılmalı. |
| [Twin Dshk Shielded Tri-pod emplacement](https://sketchfab.com/3d-models/twin-dshk-shielded-tri-pod-emplacement-df0a97950c1140d087541734ed597743) | Sleepykingzzz | CC-BY 4.0 | 12.809 | animasyon yok | 3 doku, 6 malzeme | Tek parça kalın sac kalkan, üç ayak. Sabit ve ağır. | **uygun.** 13 bin üçgen, 3 doku. Yeşil boya kir rampasına çekilir. |
| [Machine Gun Maxim](https://sketchfab.com/3d-models/machine-gun-maxim-c3be4e0b9ddc4297a8356852b21bdc37) | tomasz0p0 | CC-BY 4.0 | 10.488 | 1 animasyon; rig indirmeden görünmüyor | 4 doku, 5 malzeme | Tekerlekli eski makineli, kalkanı var, 1 animasyon. Sürüklenir ama yürümez. | **dikkat.** Biraz temiz ve yeşil; pas gerekir. Animasyon rig'e bağlıysa çeviride bakılmalı. |
| [Twin DShK Assault rig.](https://sketchfab.com/3d-models/twin-dshk-assault-rig-a33c21782c874e508d252ff2f8a6c939) | Sleepykingzzz | CC-BY 4.0 | 23.199 | 1 animasyon; rig indirmeden görünmüyor | 1 doku, 3 malzeme | Çift namlu ve açıkta kuşak: kuşak bitti anı için en okunur. | **dikkat.** Yazarına göre sırtta taşınan bir düzenek, sehpası yok. Yalnız silah ve kuşak alınır. |

Gerçek silahlar logosuz ama adları gerçek: oyunda genel ad verilir. Kaide ve kuşak kutusu elle eklenebilir.

### 5. Zincirli ölü

Bulduğum en özgün fikir, oyunun dünyasından doğuyor: motor yakıtla döner, kol insanla döner, peki ya ölüyle?

- **Ne yapar:** Geceden kalan, bacağı kopmuş bir zombiyi (uzuv kopması oyunda var, `docs/ayrintilar.md`) sürükleyip kollu makinenin başına zincirlersin. Kolu çevirip durur. Yakıt istemez.
- **Oyuncunun neyini değiştirir:** Videodaki köpek basamağı gibi ucuz, bedeli olan bir yardımcı. Kol başındaki kişi kurtulur.
- **Hava:** Çok besler: üssün ortasında inleyip duran bir şey, gündüz bile rahat değilsin. Oyuncu kendine kızar, videodaki vicdan katmanına yakın. Bozabilir: komik görünürse her şey gider; animasyon ağır ve yorgun olmalı. Oyuncuyu tiksindirmesi amaç, yani bir ton kararı.
- **Gece:** Zincir yıprandıkça kopma ihtimali artar. Koparsa üssün içinde serbest bir zombi var. İniltisi diğerlerini çeker (benim önerim, kod desteklemiyor).
- **Kaynak:** Et ya da ceset (yem). Yapım çelik.
- **Co-op:** Yakalamak iki kişilik: biri sürükler, biri tutar. Yem işi de birine kalır. Sayı üste 1-2 ile sınırlı (tahmin).
- **Zorluk:** Orta. Zombi var, dönerek itme animasyonu yok; bu animasyon Mixamo'dan değil elle yapılmalı. Ceset ve yakalama yeni iş.

| Aday | Yazar | Lisans | Üçgen | Rig, animasyon | Doku | Neden uyar | PS1 çevirisi |
|---|---|---|---|---|---|---|---|
| [Capstan / Anchor Winches](https://sketchfab.com/3d-models/capstan-anchor-winches-e8537c1d32d4401b91d0332107a4560d) ★ | max_imum | CC-BY 4.0 | 13.548 | animasyon yok | 10 doku, 2 malzeme | İki tane gemi ırgatı, kollu. Zombi kola zincirlenip döner: görüntü tek başına yeter. | **uygun.** 13 bin üçgen, ikisi birlikte; birini al. Ahşap olanı daha iyi durur. |
| [Rusted Chain Shackles](https://sketchfab.com/3d-models/rusted-chain-shackles-924c7cc2ee074e57a81cc82b58e0ac6f) ★ | SangeetBlaze | CC-BY 4.0 | 608 | animasyon yok | 5 doku, 1 malzeme | Paslı halka ve zincir, boyuna geçecek gibi. Çok ucuz. | **uygun.** 608 üçgen, olduğu gibi girer. |
| [Shackle](https://sketchfab.com/3d-models/shackle-b95cdb57e14f44e0a517c82d1617ac1d) | VisceralError | CC-BY 4.0 | 1.206 | animasyon yok | 3 doku, 1 malzeme | Korku oyunu için yapılmış pranga, ağır duruyor. | **uygun.** 1.206 üçgen, olduğu gibi girer. Tek halka: zincir ayrı gerekir. |
| [Rusty Chains](https://sketchfab.com/3d-models/rusty-chains-be9648f8e0324bbd967c10b44007bee1) | amanda_98 | CC-BY 4.0 | 57.600 | animasyon yok | 5 doku, 1 malzeme | Paslı kaba zincir, uzun bir parça. | **dikkat.** 57 bin üçgen yalnız zincir için fazla. Birkaç halka alınıp dizilir. |

Zombinin kendisi oyunda var. Burada yalnız ırgat ve zincir aranıyor; dönerek itme animasyonu ayrı iş.

### 6. Teleferik

- **Ne yapar:** Dağın eteğinden üsse **tek** hat. Ahşap direkler, halat, üstünde yürüyen kovalar. Kovaları dağda biri doldurur ya da bir çekici; üstte boşaltma haznesine döker.
- **Oyuncunun neyini değiştirir:** Dağ ile üs arası yürüyüş biter. Dar boğaz alt ve üst istasyona kayar. `bant`ın iri kardeşi; videoda bant yok, teleferik var.
- **Hava:** Besler: gece karanlıktan gıcırdayarak gelen kovalar. Bir kovada hurda yerine başka bir şey gelir (ceset, canlı bir şey; host rastgele). Bozabilir: çok hat kurulabilirse Factorio'ya döner, bu yüzden bir hat.
- **Gece:** Direğe saldırılırsa (kod desteklemiyor) hat kopar; sabah biri halatı yeniden çeker. Hattın altında yürümek rahatsız edici.
- **Kaynak:** Yapım çelik, ahşap. Çalışırken motor ve yakıt.
- **Co-op:** Biri altta doldurur, biri üstte boşaltır, aralarında göz teması yok.
- **Zorluk:** Orta-yüksek. Kovalar MultiMesh ile kolay; hat yerleştirmesi serbestse zor, sabit yuvadaysa orta.

| Aday | Yazar | Lisans | Üçgen | Rig, animasyon | Doku | Neden uyar | PS1 çevirisi |
|---|---|---|---|---|---|---|---|
| [ropeway cart](https://sketchfab.com/3d-models/ropeway-cart-108f3d42beca4992bedd273238f60280) ★ | miloslavsky | CC-BY 4.0 | 3.476 | animasyon yok | 1 doku, 1 malzeme | Askısı olan açık taşıyıcı, kovası hazır. Etiketinden anladığım kadarıyla bir korku oyunu modu için yapılmış. | **uygun.** 3.476 üçgen, tek doku. Aynı anda çok görüneceği için 800'e inmeli (tahmin). |
| [Old Mining Winch](https://sketchfab.com/3d-models/old-mining-winch-80189ebe42d941f6bbeabdab0483ad2b) | heritagerat | CC-BY 4.0 | 56.661 | animasyon yok | 3 doku, 1 malzeme | Elle çalışan gerçek maden vinci taraması. İstasyondaki halat tamburu olur; kollu vinç olarak da çalışır. | **dikkat.** 56 bin üçgen, tarama. Tek deriyse tambur dönmez. |
| [Wooden Utility Pole / Дерев'яний опорний стовп](https://sketchfab.com/3d-models/wooden-utility-pole-6daa230ee64446ff87b932ca5fc28f4f) ★ | Amaranthus_retroflexus | CC-BY 4.0 | 7.303 | animasyon yok | 4 doku, 1 malzeme | Ahşap direk, beton kaide. Direğin kendisi için en basit. | **uygun.** Üst kısma makara eklenir; 7 bin üçgen 800'e iner (tahmin). |
| [Modular Electricity Poles](https://polyhaven.com/a/modular_electricity_poles) | James Ray Cock | CC0 | 200.610 | yok | PBR set | Poly Haven ahşap ve beton direk seti, parçalı. CC0. | **uygun.** Bütün set 200 bin üçgen; tek direk çok daha az. Parçalardan makara kolu çıkarılır. |

Direk başı makara ve halat için uyan model yok: üretilir. Aşağıdakiler kova, tambur ve direk.

### 7. Pençeli vinç

- **Ne yapar:** Dağın yanına kurulan dev vinç. Oyuncu kabine girer, pençeyle bir hamlede yüzlerce parça alır, hazneye boşaltır. Sonra otopilot: kendi çalışır, hazne dolunca durur.
- **Oyuncunun neyini değiştirir:** Oyunun asıl ödülü. Videoda hız 360 kat artıyor ve dağın yarısı son çeyrekte gidiyor; `taret_notlari.md` bunu yazıyor. Dağ gözle görülür erir, yamaç kayar.
- **Hava:** Besler: kabindeki kişi kör ve savunmasız, vinç sesi her yerden duyulur, gece silueti ormanın üstünde. Bozabilir: yeni, temiz, parlak sarı vinç; ya da otopilot her şeyi bitirirse. Otopilot sonrası tıkanıklık ve boşaltma insan ister.
- **Gece:** Üsten uzak durur, savunması ayrı bir iş. Otopilot gece açık kalırsa düşman oraya gider. Tepesinde lamba olursa tek uzak ışık odur.
- **Kaynak:** Çok çelik, yakıt. Boss sonrası açılır.
- **Co-op:** Bir operatör, bir-iki koruma, biri haznede. Kabine zombi tırmanması güzel bir an.
- **Zorluk:** Yüksek. Kabin kamerası, pençe animasyonu, dağa bağ (`pile.gd`, `claude/busy-gagarin-6b30aa`), ağ.

| Aday | Yazar | Lisans | Üçgen | Rig, animasyon | Doku | Neden uyar | PS1 çevirisi |
|---|---|---|---|---|---|---|---|
| [Port crane "Sokol"](https://sketchfab.com/3d-models/port-crane-sokol-4964eaa7634e47c9bac4c2a74fa91c20) ★ | Vitaliy Kovalchuk | CC-BY 4.0 | 14.356 | 1 animasyon; rig indirmeden görünmüyor | 16 doku, 3 malzeme | Paslı, sarı-kırmızı liman vinci, sabit kaide, kanca. Videodaki dev vinç hissine en yakını, 1 animasyon var. | **dikkat.** 14 bin üçgen, 16 doku. Kum zemini çıkarılır. Rig'liyse psx_props üçgen düşürmez; dönen bölümler için indirip bakılmalı. |
| [EO-4121](https://sketchfab.com/3d-models/eo-4121-11029572467b45329ffd48e22e8752f6) | hans1240 | CC-BY 4.0 | 13.389 | animasyon yok | 1 doku, 1 malzeme | Eski Sovyet paletli kazıcı. Kabinine oyuncu oturabilir gibi. | **dikkat.** Tek doku, biraz temiz. Pas boyası lazım. Parçaları ayrı mı belli değil. |
| [Scrapyard magnet](https://sketchfab.com/3d-models/scrapyard-magnet-3d2f69184faa49529bbfaeefc4248ef0) ★ | aisyahtriwulandari1 | CC-BY 4.0 | 5.842 | animasyon yok | 5 doku, 1 malzeme | Zincirli hurda mıknatısı: pençe gelene kadar ağız olarak hazır. | **uygun.** 5.800 üçgen, tek doku seti. Sarı rengi kirletilir. |
| [Crusher Shear](https://sketchfab.com/3d-models/crusher-shear-98e280a7583c46b8a592ad1078a62811) | gelber | CC-BY 4.0 | 67.054 | animasyon yok | dokusuz, düz malzeme | Yıkım makası: dişli, tiksindirici bir ağız. Pençe yerine geçer. | **zor.** Dokusu yok, düz sarı malzeme, 67 bin üçgen. Elle boyanmazsa istenmeyen düz renkli görünüme gider. |

Hurdaya uygun pençe (portakal kabuğu kepçe) bulamadım: üretilir. Aşağıda vinç gövdeleri ve iki geçici ağız var.

### 8. Kişisel takım

Kullanıcı kararı: kişisel geliştirmelerde otomatikleştirme olacak. Hepsi eziyet siler, hiçbiri oyuncunun peşinden kendi gezmez.

- **Mıknatıs sopası:** Yerde kalan küçük parçaları 3 m'den çeker (tahmin), sırtta ağırlık yapar. Videodaki süpürgenin elde hâli. Sopayı tutan silah tutamaz.
- **Sırt sepeti:** Taşıma artar, koşma biter. Düşen sepet parçaları saçar.
- **Kas hafızası:** E'yi basılı tutunca eller kendi söker, kafa serbest kalır, etrafa bakabilirsin. Videoda aynı isimle var. Yeni model istemez.
- **Kuşak kemeri:** Şarjörü elle değil kendi doldurur, ama yavaş. Yeni model istemez.
- **Hava:** Besler: her biri bedende görünür, ağırlık ve ses verir. Bozabilir: otomatik toplama aurası hava öldürür, onun yerine **yakınlık, elde tutma, ağırlık** şart (benim önerim).
- **Gece:** Sepetle kaçamazsın, gece bırakılır. Mıknatıs sesi demirleri tıkırdatır.
- **Kaynak:** Kişisel puan (videodaki iki birim: para ve rütbe). Kasa ortak, bu kişisel, kullanıcının sözüyle aynı yapı.
- **Co-op:** Herkes kendi yolunu seçer, roller kendiliğinden ayrılır.
- **Zorluk:** Düşük, parça parça eklenir.

| Aday | Yazar | Lisans | Üçgen | Rig, animasyon | Doku | Neden uyar | PS1 çevirisi |
|---|---|---|---|---|---|---|---|
| [Metal Detector](https://polyhaven.com/a/metal_detector) ★ | Kuutti Siitonen | CC0 | 15.518 | yok | PBR set | Sopa, sap ve disk zaten var: disk mıknatısa dönüşür. CC0. | **uygun.** 15 bin üçgen, elde görüneceği için 1.500'e iner (tahmin). |
| [Wicker Basket 02](https://polyhaven.com/a/wicker_basket_02) ★ | Kuutti Siitonen | CC0 | 17.850 | yok | PBR set | Kapaklı örgü sepet: sırt çerçevesi takılırsa sırt sepeti. CC0. | **uygun.** 17 bin üçgen, küçük eşya; 500'e iner (tahmin), kapak atılır. |
| [Wicker basket](https://sketchfab.com/3d-models/wicker-basket-7c30d436083045be803ea11b3ce22271) | Incg5764 | CC-BY 4.0 | 9.456 | animasyon yok | 4 doku, 1 malzeme | Daha kaba, derin örgü sepet. | **uygun.** 9 bin üçgen; aynı şekilde iner. |
| [Crowbar 01](https://polyhaven.com/a/crowbar_01) | Alexander Otterbeck | CC0 | 2.300 | yok | PBR set | Hurda sökme levyesi: kişisel söküm aşamasının eldeki eşyası. CC0. | **uygun.** 2.300 üçgen, ince; psx_props'un kalınlaştırması işine yarar. |

Mıknatıs sopası ve sırt çerçevesi tek parça olarak yok: aşağıdakilerden birleştirilir.

## Yedek

Beş soruyu geçiyor ama ilk sekizin önüne geçmiyor. Modeller galeride, "Yedek fikirlerin modelleri" grubunda. Hepsi benim önerim.

| Fikir | Ne yapar | Bedeli ve gece | Neden yedek |
|---|---|---|---|
| **Leş kazanı** | Geceden kalan cesetler tankta eritilir, motor yakıtı çıkar | Koku düşman çeker; gündüz ceset taşımak gerekir | Gore için çok iyi, ama ceset sistemi ister. Yakıt kararından sonra ilk sıraya çıkabilir |
| **Çıkrıklı kızak** | Dağa kızak götürülür, üsteki çıkrıkla çekilir | İki kişilik; halat gece kesilir | Araba ile teleferik arası, biri çıkarılabilir |
| **Sac oluk** | Dağın eteğinden yerçekimiyle hurda kayar | Tıkanır, levye ister; sesi uzaktan gelir | Dağ eğimine bağlı. Bant yerine geçebilir, model yok denecek kadar az |
| **Raylı maden arabası** | Ray üstünde elle ya da çıkrıkla | Rayda takılır, gece önüne bir şey çıkar | Teleferikle aynı işi yapar |
| **Zincirli köpek** | Yem karşılığı bağlı durur, gece önce o havlar, susunca korkarsın | Yem ister, ölebilir | Video ile aynı, ama sevimlilik riski; doğru model yok. Yayıncının köpek sesinden şikâyeti var, ses kapatılabilmeli |
| **Teneke ipi** | Ağaçlar arası ip ve teneke, ses verir | Yanlış alarm, rüzgâr | Çok ucuz. Model gerekmez, belki 1. fikirle birlikte yapılır |
| **Elle çevrilen projektör** | Motora bağlı, biri çevirir | Yakıt; ışık düşman çeker | Mazgalın ihtiyacı, onunla gelir |
| **Kapan ve çivili çukur** | Tek kullanımlık gece hazırlığı | Toplanması, kurulması gündüz işi | Otomasyondan çok savunma |
| **Patlatma düzeneği** | Dağa dinamit, yığın kayar, çok hurda düşer | Çok gürültü, üst üste gelirse dalga | `pile.gd` çöküşüne bağlı, ayrı iş; model yok, küçük üretim |
| **Et yemi direği** | Asılı et, dalganın yönünü çeker | Et ister | Dalga yönü kodu ister |

## Havayı bozacağını düşündüklerim

| Fikir | Neden |
|---|---|
| **Gezen taret** | Kullanıcı açıkça istemiyor |
| **Drone, uçan toplayıcı** | `otomasyon_hazirlik.md`'de soru olarak geçiyor. Bence hayır: temiz, sessiz, oyuncunun yerine bakar; korkunun karşısına uçan oyuncak koyar |
| **Sevimli robot, yoldaş** | Yalnızlığı bitirir. Bir korku oyununda arkadaş olan makine, makine olmaktan çıkar |
| **NPC işçi ve kolonist** | Görev ekranı, ücret, yemek getirir, başka bir oyun olur. Ayrıca co-op'ta oyuncuların işini alır |
| **Robot kol dizisi** | Bizde `bant` var, ama Factorio'daki taşıyıcı kol temiz ve hızlı okunur. Yerine zincir, kaldıraç, insan elini koyarım |
| **Sınırsız ızgara, taret duvarı** | Plan oyunu başlar, korku biter. Videoda yerleştirme ekranı görülmüyor, not da bunu söylüyor; soru `taret_notlari.md` 2 |
| **Üstten harita, akış grafiği** | Her şey birinci şahıstan görülmeli (`taret_notlari.md`) |
| **Parlak arayüz, ekranlı panel, hologram** | Kullanıcı kuralları: az yazı, gerçek aset. Kol, kadran, etiket yeter |
| **Lazer, enerji kalkanı, ışınlanan kasa** | Dil dışı. Kasa yüzde yüz ortak, ama eşya kendi kendine ışınlanmamalı (benim önerim) |
| **Sürülen kamyon, yürüyen makine** | Kaçışı ve yorgunluğu siler, ayrıca çok pahalı |
| **Otomatik toplama aurası** | Hurdayı görünmez yapar; videoda da uzaktan görünmez çekim yok |
| **Güneş paneli, sessiz enerji** | Gürültü bedeli gider |

## Sıralama önerisi (benim önerim, sayılar tahmin)

`taret_notlari.md`'deki takvimle uyumlu: tam oyun 14 gece, demo 5 gece. Oyun içinde denenmedi.

### Demo, ~1 saat

| Gece (dakika) | Açılan |
|---|---|
| 1 (0-12) | El, torba, ilk silah |
| 2 (12-24) | Çuval ve el arabası, kollu öğütücü, kasa; kişisel olarak kas hafızası |
| 3 (24-36) | Dizel motor ve kayış, ilk mazgal |
| 4 (36-48) | Kısa bant, ikinci mazgal; kişisel olarak sırt sepeti |
| 5, boss (48-60) | Pençeli vinç, boss öncesi kurulur, gecede dağın yanında kalır |

Demoda yok: teleferik, otopilot, ikinci boss. Katalogda kilitli satır olarak görünür. **Zincirli ölü**yü demoda mutlaka denerdim, çünkü sayfada ve fragmanda oyunu en çok ayıran şey o olur; 4. gecede, istenirse. Bu bir öneri, kullanıcının ton kararına bağlı.

### Tam oyun, 5-6 saat

| Gece (saat) | Açılan |
|---|---|
| 1-2 (0:00-0:50) | El, torba, ilk silah |
| 3 (~1:00) | Çuval ve el arabası, kollu öğütücü, kasa |
| 4 (~1:30) | Kas hafızası, sırt sepeti |
| 5, boss (~2:00) | İlk mazgal, boss öncesi kurulur |
| 6-7 (~2:30) | Motor ve kayış, kısa bant, zincirli ölü |
| 8 (~3:15) | Ezici, mıknatıs sopası, ikinci mazgal grubu |
| 9 (~3:30) | Teleferik |
| 10, boss (~4:00) | Pençeli vinç |
| 12 (~4:45) | Otopilot; yeni dar boğaz haznede, boşaltmada, yakıtta |
| 14 (~5:30) | Son gece. Yeni makine yok, kurduğunu korursun |

**Dikkat:** Videoda son basamaklar yalnız hız artırıyor, yayıncı beklemekten söz ediyor. Bizde gece bu boşluğu dolduruyor, ama son iki saatte yeni bir elle iş kalmalı.

## Modeller hakkında

- **Kaynak:** Sketchfab (arama ve model verisi), Poly Haven (API). Kenney, Quaternius ve ambientCG'ye baktım. ambientCG'de işe yarar makine modeli bulamadım; malzemesi hâlâ işe yarar (projede zaten kullanılıyor). Kenney ve Quaternius düz renkli.
- **Lisans:** Hepsi CC0 ya da CC-BY 4.0. Sketchfab modellerinin lisansı API'den okundu; beşinde sayfayı açıp karşılaştırdım (Rusty Wheelbarrow, Port crane Sokol, Post Apocalyptic Turret, RG Ross Steam Hammer, Poly Haven Overhead Crane), hepsi tuttu. CC-BY olanlar jenerikte isim ister. `docs/ayrintilar.md` listesine ancak gerçekten alınanlar yazılır, bu yapmadım.
- **Üçgen:** Sketchfab `faceCount` (sayfadaki "Triangles" ile aynı, bir örnekte doğruladım), Poly Haven `polycount` (seti olanlarda bütün set).
- **Doğrulanmayanlar:** Hiçbir model indirilmedi, çünkü Sketchfab indirmesi hesap ister. **Rig, parçaların ayrı olup olmadığı ve doku çözünürlüğü dosya açılmadan belli değil.** Yazdığım animasyon sayısı API'den. "Benim önerim" işaretli modeller yine de görselden ve açıklamadan seçildi, makinede dönen parça isteyen her aday önce açılıp bakılmalı.
- **PS1 çevirisi:** `tools/psx_props.gd` üçgeni düşürür, doku 64-256 px filtresiz, normal haritası atılır, renk rampaya çekilir. Skinned mesh düşürülmüyor (`psx_props.gd:260-261`), yani rig'li adaylar elle düşürülür. Dokusuz modellerde çevirecek doku yok, düz renkli kalır. Bu yüzden "zor". Bugünkü makinelerin üçgen bütçesi 800-4.000 (`BENCH`).
- **Marka:** Görselde logo görmedim. Adında gerçek ad geçenler (ALEXANDERWERK, DShK, Sokol, Maxim) oyunda genel adla çıkmalı, doku da açılınca kontrol edilmeli.

### Yedek fikirlerin modelleri

| Aday | Yazar | Lisans | Üçgen | Rig, animasyon | Doku | Neden uyar | PS1 çevirisi |
|---|---|---|---|---|---|---|---|
| [Horizontal fuel Tank](https://sketchfab.com/3d-models/horizontal-fuel-tank-7bbdac355b1d42cea956cfe502290de3) | castleonsandYT | CC-BY 4.0 | 10.874 | animasyon yok | 8 doku, 2 malzeme | Leş kazanı: yatık, paslı tank. Üstüne bir ağız açılır. | **dikkat.** Üstünde Flammable yazısı var, boyanmalı. |
| [Low Poly Old Generator Oven - Game Ready](https://sketchfab.com/3d-models/low-poly-old-generator-oven-game-ready-d64bfec33ca5438cbbab2dc5d909dc3d) | Rashad Ibrahimli | CC-BY 4.0 | 3.084 | animasyon yok | 6 doku, 1 malzeme | Leş kazanı: bacalı küçük ocak. Kir ve pas iyi. | **uygun.** Turuncu yerler kirletilir. |
| [Pig Carcass](https://sketchfab.com/3d-models/pig-carcass-5c73c8653a584dee9ebb6d2956416afe) | oparaskos | CC-BY 4.0 | 2.052 | animasyon yok | 3 doku, 2 malzeme | Leş kazanı ya da et yemi: askıda yarım domuz. | **uygun.** Düşük üçgen, sayfada kemik var deniyor; gore için güzel. |
| [Mine cart Rusted](https://sketchfab.com/3d-models/mine-cart-rusted-0b391322171c449fa0eb9092416fd2a6) | Gustavo Simas | CC-BY 4.0 | 7.462 | animasyon yok | 15 doku, 3 malzeme | Raylı araba: raylarıyla paslı maden arabası. | **uygun.** 7 bin üçgen, 3 malzeme. |
| [Basic Mine Cart](https://sketchfab.com/3d-models/basic-mine-cart-dc081b6e60544218baf91027b0251485) | Blender3D | CC-BY 4.0 | 4.208 | 3 animasyon; rig indirmeden görünmüyor | 5 doku, 1 malzeme | Raylı araba: boş, 3 animasyon. | **uygun.** 4 bin üçgen. |
| [Modular Metal Gutter](https://polyhaven.com/a/modular_metal_gutter) | Maxim Domnin | CC0 | 16.490 | yok | PBR set | Sac oluk: parçalı sac oluk seti, büyütülür. CC0. | **dikkat.** Çok ince ve yağmur oluğu; ölçek büyüyünce belli olur. |
| [wolf animated](https://sketchfab.com/3d-models/wolf-animated-79bd16a8c36a45c78ccd13b84b7ca99c) | Paleo Modelist | CC-BY 4.0 | 3.884 | 4 animasyon; rig indirmeden görünmüyor | 1 doku, 1 malzeme | Köpek yerine: 4 animasyonlu kurt, açıklamada kullanım izni var. | **dikkat.** Kurt, köpek değil; zincirle köpek gibi durur mu bakılmalı. |
| [Arctic wolf PSX](https://sketchfab.com/3d-models/arctic-wolf-psx-0bd6a72972e74576829e050201564ebf) | vinrax | CC-BY 4.0 | 852 | animasyon yok | 1 doku, 1 malzeme | Köpek yerine: doğrudan PS1 tarzı kurt. | **dikkat.** Rig yok, yazarı söylüyor. Beyaz rengi kirletilir. |
| [Searchlight](https://sketchfab.com/3d-models/searchlight-45dc771c96e44e438c1d92f70858be19) | Kuba "Volant" Wójcik | CC-BY 4.0 | 13.718 | animasyon yok | 5 doku, 1 malzeme | Projektör: askeri, mercekli, ayaklı. Elle çevirmeye çok uygun. | **uygun.** 13 bin üçgen. Işıyan malzeme StandardMaterial kalır. |
| [Portable Searchlight](https://polyhaven.com/a/portable_searchlight) | Elijah Cragg | CC0 | 18.802 | yok | PBR set | Projektör: elde taşınan kalın fener. CC0. | **uygun.** Kişisel takıma da girer. |
| [Bear Trap](https://sketchfab.com/3d-models/bear-trap-f435ec05d607424594134cd91c5056aa) | kirbinator505_ | CC-BY 4.0 | 564 | 1 animasyon; rig indirmeden görünmüyor | 1 doku, 1 malzeme | Kapan: animasyonlu ayı kapanı. | **uygun.** 564 üçgen, doğrudan PS1 ölçüsünde. |

### Temeldeki makinelere görünüş (ek)

Bant ve kasa bugün yer tutucu modellerle duruyor. Aset oturumu için ek öneri.

| Aday | Yazar | Lisans | Üçgen | Rig, animasyon | Doku | Neden uyar | PS1 çevirisi |
|---|---|---|---|---|---|---|---|
| [Industrial Conveyer Roller (modular)](https://sketchfab.com/3d-models/industrial-conveyer-roller-modular-4736d0c18e7047969639988883f0ad56) ★ | atharva_parab | CC-BY 4.0 | 2.434 | animasyon yok | 3 doku, 1 malzeme | Bant: paslı, modüler makaralı hat. Kayış yerine hurda makaradan yuvarlanır, ağır ve küt okunur. | **uygun.** 2.400 üçgen, tek set. |
| [Industrial Conveyer Roller Angular (modular)](https://sketchfab.com/3d-models/industrial-conveyer-roller-angular-modular-328a5290650147d5a8816de8d7ebe4b6) ★ | atharva_parab | CC-BY 4.0 | 1.322 | animasyon yok | 3 doku, 1 malzeme | Bant köşesi: aynı setin kavisli parçası. | **uygun.** 1.300 üçgen. |
| [Industrial Machine](https://sketchfab.com/3d-models/industrial-machine-40cd1d22f6bd40dd904e37faf0c214d8) ★ | jimbogies | CC-BY 4.0 | 40.500 | animasyon yok | 21 doku, 11 malzeme | Motorlu tezgâh: paslı sac, kayış ve kasnak görünür. Yazarı amacı olmayan uydurma makine demiş. Radyasyon levhası var. | **dikkat.** 40 bin üçgen, 11 malzeme, 21 doku. Çeviride sadeleşir. |
| [Post Apocalytpic style Container](https://sketchfab.com/3d-models/post-apocalytpic-style-container-363b36fdbae940a7bee619e17da4803a) ★ | Sousinho | CC-BY 4.0 | 2.340 | animasyon yok | 14 doku, 2 malzeme | Kasa: paslı sarı dökme konteyner, merdiveni ayrı. Ortak kasa için büyük ve okunur. | **uygun.** 2.340 üçgen. |
| [Rusted waste container low poly](https://sketchfab.com/3d-models/rusted-waste-container-low-poly-6e6e05f6c6814cec96f24524ddd3ceac) | Robal | CC-BY 4.0 | 628 | animasyon yok | 2 doku, 1 malzeme | Kasa ya da istasyon haznesi: daha küçük paslı konteyner. | **uygun.** 628 üçgen. |
| [PSX Industrial Pack](https://sketchfab.com/3d-models/psx-industrial-pack-12cb749961974f94a4063e67dafb2d76) | Tomitos | CC-BY 4.0 | 8.622 | animasyon yok | doku sayısı alınamadı | Süs: PSX paketi, boru, tank, tambur, konteyner. Makinelerin çevresi için. | **uygun.** Doğrudan PS1 ölçüsünde, çevirinin etkisi denenmeli. |
| [Emergency Power Station (PS1)](https://sketchfab.com/3d-models/emergency-power-station-ps1-389f5331f49744dfa82a45fabb75d740) | S1lMoon | CC-BY 4.0 | 38 | animasyon yok | 1 doku, 1 malzeme | Süs: 38 üçgenlik römorklu jeneratör, doğrudan PS1. | **uygun.** Turuncu ama kirli; görünüm bizim çeviriden farklı kalabilir. |

### Elenenler

| Model | Lisans | Neden elendi |
|---|---|---|
| [Kenney, Factory Kit](https://kenney.nl/assets/factory-kit) | CC0 | Düz renkli, mor-turuncu izometrik oyuncak. Kullanıcının istemediği mobil görünüm. |
| [Quaternius, Steampunk Turret Pack](https://quaternius.com/packs/turretpack.html) | CC0 | Sayfada dokusuz (Textured: yok), düz turuncu oyuncak taretler. |
| [Quaternius, Zombie Apocalypse Kit](https://quaternius.com/packs/zombieapocalypsekit.html) | CC0 | Düz renkli, parlak. Kullanıcı bu paketlere 2026-11-02'de mobil oyun gibi demişti. |
| [DShK Metro 2033 Redux (Rika)](https://sketchfab.com/3d-models/241e63baecbc42b8b8cd6abe610d85a3) | CC-BY görünüyor | Adından başka bir oyundan alınmış gibi; etiketine güvenmedim (benim kararım). |
| [DShK (Enlisted) (KojfDiscord)](https://sketchfab.com/3d-models/cd23bb42a18e419b96bf8d50dfc125f4) | CC-BY görünüyor | Aynı sebep. |
| [Meat Hook (Donstereo)](https://sketchfab.com/3d-models/4659d6c6722645e4a4b4e580e4cbf45a) | CC-BY | Yazarı Dota'daki Pudge kancasının kendi yorumu diyor; tanınan karakter eşyası. |
| [Soviet Trash Container (dimmeyster)](https://sketchfab.com/3d-models/5479edd9d486456a8885cf9c55e51acc) | CC-BY | Meshy ile yapay zekâ üretimi, sayfasında yazıyor. Kural değil, benim kararım; bkz. sorular. |
| [Industrial metal chute (MrPumpkinDev)](https://sketchfab.com/3d-models/430d21376388479abd1a3af9f8319b1e) | CC-BY | Aynı sebep, ayrıca dokusuz. |
| [Treadwheel Crane (sheffrator)](https://sketchfab.com/3d-models/1129cebe176442d19aee2ef2459e1e1f) | CC-BY | Fikri güzel, oyuncu tekerlekte yürür; ama dokusuz, gemi ve taşlarla bir arada, 67 bin üçgen. |
| [Small Diesel engine (MrFox), Low-Poly Winch (TepidGames)](https://sketchfab.com/3d-models/62cd7031950348c59c2fd7c314ccd791) | CC-BY | Tek renk ya da dokusuz; elle boyanmazsa düz renkli kalır. |
| [Leaf Blower (jterry7484)](https://sketchfab.com/3d-models/237ccd0ea03e466bbef30424dc631d6f) | CC-BY | Parlak sarı, marka ürünü gibi. Süpürge için uymuyor. |
| [Medical BackPack (deangothard)](https://sketchfab.com/3d-models/2aedfbd7581f47f5abcf89d39de57b67) | CC-BY | Temiz, üstünde büyük haç. Sırt sepeti yerine geçmiyor. |
| [French Bulldog PSX (Bonvikt)](https://sketchfab.com/3d-models/647fa9e3f53b4898826ef398f0a9f6dd) | CC-BY | İyi yapılmış ama sevimli, tekinsizliği bozar. |
| [Horseshoe Magnet (ArchieCGD)](https://sketchfab.com/3d-models/9daa7e197807443cab2f1953372f92f2) | CC-BY | Çizgi film mıknatısı. |
| [Rusty Cableway wagon (Sain Zhu)](https://sketchfab.com/3d-models/ab93ce83584645ea8850269e4ce1bbc8) | CC-BY | Paslı ve iyi, ama yolcu kabini; hurda kovası değil. |

### Üretilmesi gerekenler

Projede bu yol zaten var (`tools/atolye/parts.py`, `tools/cukur/build.py`, Blender'da koddan). Her biri küçük iş (tahmin).

| Parça | Neden |
|---|---|
| Hurda pençesi (portakal kabuğu kepçe, 4-6 tırnak) | Sketchfab'da CC0 ve CC-BY arasında bulamadım |
| Direk başı makara, halat | Aynı şekilde; halat zaten kod çizgisi olabilir |
| Kayış ve kasnak | Dönmesi için ayrı parça olmalı, UV kaydırmalı |
| Sırt çerçevesi ve sepet bağı | Modelde yok |
| Mıknatıs ucu | Dedektör gövdesine birleştirilir |
| Kollu öğütücünün haznesi | Aday makinelerin çoğunda kol var, hazne yok |
| Dolu ve boş çuval, araba yükü | Durum başına ayrı şekil |

## Kullanıcıya sorular

1. **Zincirli ölü olur mu?** Oyunun tonunu değiştiren tek fikir bu. Olursa demoda da görünmeli derim.
2. **Enerji:** tek motor ve kayış mı, kablo mu, hiç enerji yok mu?
3. **Taşıyıcılar:** bant yanında teleferik de olsun mu, bant küçülüp teleferik mi öne çıksın?
4. **Vinç:** büyük ve sabit liman vinci mi (benim önerim), paletli kazıcı mı? Ağız: üretilecek pençe mi, mıknatıs mı?
5. **Mazgal:** elde yapılmış kutu mu (benim önerim), tanınan ağır makineli silah gövdesi mi?
6. **Yapay zekâ üretimi modeller:** CC-BY görünse de eledim. Bu tercihim doğru mu, aday olsun mu?
7. **Modeller:** galeride beğendiklerini seçip listeyi aset oturumuna verirsen o oturum bunları indirir, açar, rig ve parçalara bakar.
8. **Bu görevin dışında:** görev tanımı Mixamo'yu aday listesinden çıkarıyor, oysa oyunda 14 zombi ve 5 oyuncu karakteri Mixamo kökenli (`docs/ayrintilar.md` 38, 306). Oyuna gömülü kullanım ile dosyayı dağıtmak ayrı şeyler, burada bakmadım; ayrıca sormak isterim.
