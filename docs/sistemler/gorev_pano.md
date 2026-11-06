# Görev ağacı, görev tahtası, pano

> **Özet (2026-11-06):**
> Kullanıcı kararı (2026-10-27): yeni mekanikler kasadan değil görevlerden açılır; tezgâh ilk görevlerle açılır, parçalı blueprint'ler panoda birleşir.
> Ödül panodan alınır, panoda hep 5 kart asılı; sayılar yer tutucu.
> Uygulama sırası: `docs/gorev_sistemi_plani.md`.
> Tam eski belge: `docs/arsiv/ayrintilar_tam_2026-11-06.md`. Dizin: `docs/sistemler/README.md`.

### Görev ağacı ve görev tahtası (2026-10-27, kullanıcı kararı)

Kasa sisteminin yerini alır: yeni mekanikler kasadan değil görevlerden açılır. Amaç oyuncunun zar zor birkaç parça işlediği başlangıçtan, yarım saat sonra çok hızlı ürettiği yere tırmandığını görmesi ("kurtulma" hissi). Uygulama sırası: `docs/gorev_sistemi_plani.md`.

- **Süre:** tam oyun 4-5 saat. Şimdilik odak ~1 saatlik demo; tam sürüme yeterince mekanik ve silah kalmalı.
- **Akış (kullanıcının örneği, numaralar yer tutucu):** açılışta pop-up'larla oyun anlatılır. 1. görev para kazanmak; tezgâhı açar. **Tezgâh = geliştirme ağacı:** şimdi Q'da parayla alınan geliştirmeler orada, animasyonla (silah masaya gelir, yeni şarjör takılır, yeni dipçik, yeni nişangâh). Sonra ~5. görev blueprint'leri, ~10. görev slot makinesini, sonraki görevler üretim zincirini parça parça açar (eski örnekteki eritme aracının hurdalıktaki karşılığı öğütücü).
- **Parçalı blueprint:** bir blueprint tek görevde gelmez, ör. çift tabanca parça parça farklı görevlerden (kullanıcının örneği 4., 8., 16. görev). Panoda yarım blueprint asılı durur, her parça üstüne eklenir. Parça sayısı ve yüzdeler denge turunda.
- **Ustalık görevleri:** açılan bir merminin perkleri (ör. klonun) ayrıca yan görevlerle açılır ("klonla 500 isabet" gibi; tek mermiye kilitleyen "yalnız klon kullan" türü yok).
- **Görev tahtası (soruşturma panosunda):** 1 sabit **ana görev** slotu (mekanik açılışları buradan, sırayla, atlanamaz) + 4 seçmeli slot: 1 kolay, 2 orta, 1 zor. Her slotun ödülü farklı (kolay: para/küçük geliştirme, orta: blueprint parçası, zor: nadir parça/ustalık perki). Biten slot kendi zorluk havuzundan sıradakini çeker, sıradaki daha zordur: sürekli merdiven hissi. Slotlar zorluğa bağlı olduğu için tahta zor görevlerle tıkanmaz. **Kabul adımı yok:** tahtadaki görevlerin hepsi aynı anda ilerler, oyuncu hangisine odaklanacağını seçer (co-op'ta 4 kişi "hangisini alalım" tartışmaz). HUD'da 5 görevin hepsi ilerlemesiyle görünür, ödül panodan alınır (aşağıda "Pano = teslim yeri").
- **Görev hedefleri** üretim cinsinden olur, boş "50 zombi vur" sayımları değil: her görev yeni açılanı kullandırır ya da sıradakini açar (aç → kullandır → ödüllendir). Sayılı hedefler oyuncu sayısıyla büyür (oran bot testiyle bulunacak). Kodda hâlâ mermi cinsinden hedefler var (`bullets_melted` vb.).
- **Slot makinesi parayla oynanır** (hurdayla olsaydı bol hurdayla bütün ödüller açılırdı; "slota mı basayım, geliştirme mi alayım" ikilemi asıl his). İstismara karşı: her çekişte fiyat ×~1,5 artar; ödül havuzu sınırlı (her blueprint/kozmetik bir kez çıkar, havuzdan düşer; havuz bitince yalnız küçük ödül); kalıcı güç vermez (geçici çarpan, kozmetik, troll mermi, nadiren blueprint parçası); beklenen değeri geliştirmeden düşük; 10 çekişte nadir çıkmadıysa 11. garanti. Model kullanıcıdan gelecek. Co-op: kişisel paradan mı, ortak kasadan mı açık (öneri kişisel, blueprint çıkarsa takıma).
- **Anahtarlar ve kasa sırası (açık):** öneri anahtarların dağda kalıp bazı görevlerin hedefi olması ve kilitli blueprint açması; kasa duvarının ve `chests.gd`'nin yerine sergi ya da tamamen kaldırma kullanıcı kararını bekliyor.

### Pano = teslim yeri ve ısınma zinciri (2026-10-27, kullanıcı kararı)

Görevler HUD'a taşınınca panonun işi kalmamıştı. Karar: **ödül panodan alınır, blueprint parçaları panoda birleşir**; oyunun girişi de ayrı prolog değil, ana slotta kısa bir ısınma zinciri. Ayrıntılar öneri, sayılar yer tutucu. Uygulama: `docs/gorev_sistemi_plani.md` adım 5 ve 5b.

**Pano (soruşturma panosu, `range_dressing.gd`, tezgâhın yanında 8,85, 0, 26,72):**
- HUD ilerlemeyi gösterir; biten görevin kartı yeşile döner ve "Panoda teslim et" yazar. C'yle her yerden alma kalkar: panonun önünde E'ye basılır.
- Co-op: panoya kim gelirse bekleyen bütün ödülleri takım için alır (bugünkü `request_claim_quests`; host oyuncunun panoya yakınlığını da kontrol eder).
- Teslimde panoda: bitmiş kartın üstüne damga basılır, kart sökülür, havuzdan gelen yeni kart iğnelenir (ses kullanıcıdan). Panoda her zaman 5 kart asılı, yakına gelince okunur.
- **Blueprint parçaları:** panoda yarım blueprint asılı durur; teslim edilen her parça üstüne iğnelenir, eksik parçalar soluk/boş çerçeve. Son parça gelince blueprint tamamlanır ve mekanik açılır (blueprint'in nereye gittiği, ör. tezgâha, sonra karar).
- Bekleyen ödül varken pano hafif parlar, HUD'da kartın yanında küçük bir yön işareti çıkar. Pano tezgâhın yanında olduğu için teslim ve geliştirme tek yürüyüşte yapılır.
- Bot testi (`quest_sim.gd`) teslimi anında sayıyordu; her teslim gezisine yürüme süresi eklenir (~10 s, yer tutucu), görev süreleri yeniden ölçülür.

**Isınma zinciri (ilk ~2-3 dakika, ana slotta m01'den önce; `GameState.QUESTS` t00-t03):** her görev tek bir şeyi öğretir, 10-30 saniyede biter. Bu görevler biter bitmez sıradakine geçer (panoya gidilmez); ödül yalnız sondakinde (t03), panoda ($10, ilk geliştirme alınabilir olsun diye). Hedefler oyuncu sayısıyla büyümez. Bot testinde tek kişi orta beceri ısınmayı ~3,2 dk'da, m01'i (tezgâh) ~4,9 dk'da bitiriyor; 4 kişi ~0,7 ve ~2,2 dk.

**Yeniden (2026-10-28, kullanıcı isteği):** oyuncu **$20** ile başlar (bir saman kuklanın fiyatı; co-op'ta takım kasası da $20), sahnede hazır kukla yoktur (`main.tscn`'den kalktı; checkler kendi kuklasını koyar), ilk kuklayı oyuncu kendisi alıp koyar. Isınma sürerken sağ üstteki görev kâğıdı görünmez; o anki görevin tuşu ve tek satırı ekranın altında, silahların üstündedir. Kuklanın üstündeki yeşil "Vur, para kazan" yazısı kaldırıldı. Kafa vuruşu görevi çıkarıldı.

**Kaldırıldı (2026-10-31, kullanıcı: dummyleri kaldır, B ve Teçhizat da gitsin): kukla adımları.** "Kukla al", "Kuklayı yerleştir" ve "Kuklaya sık" çıktı; kalanlar aynı sırayla yeniden numaralandı. Oyuncu yine $20 ile başlar (`START_GOLD`; artık bir kuklanın fiyatı değil). İlk isabet m01'de, ilk dalgada gelir.

| | Görev | Ne olur | Açılan HUD |
|---|---|---|---|
| t00 | Tabancayı al | masadaki tabanca ışıl ışıl yanıp söner, üstünde ok; alınca altta 5 sn bir giriş metni (eskisi yığına göreydi, yeniden yazılacak) | yazı bitince altın ve Q |
| t01 | Hurda topla | hurda dağının üstünde "Hurda" oku; E ile alınan parça küçülüp ekranın alt ortasına gelir, silah iner | el ve silahlar |
| t02 | Hurdadan mermi yap | R elde tutulan hurdayı şarjöre doldurur (öğütücü çalışana kadar mermi buradan gelir); ipucu "Hurdayı mermiye çevir" | — |
| t03 | Görevlerine bak | panoda ok; E panonun ekranını açar (ana görev, yan görevler, ödüller, açtıkları), $10 | sağ üstte görev listesi, 4 yan slot |

Sonra m01 başlar. Yan görev kartları isim değil ne yapılacağını yazar ("Kombo zinciri 5").

**Açılış gösterisi (2026-10-27, kullanıcı isteği):** bir görev mekanik açınca (`unlock`), o mekaniğin nesnesi o ana kadar sahnede yoktur (görünmez, çarpışmasız); açılınca ~2,4 m yukarıdan yerine düşer, ezilip toparlanır, üstünde ~10 s sıcak bir ışık sütunu durur. Yığının altında "Tezgâh açıldı" yazısı çıkar, ekranda nesnenin üstünde ad + mesafe, ekran dışındaysa kenarda ok ve mesafe görünür (pano da ödül bekledikçe aynı okla gösterilir). Kamera oyuncunun elinden alınmaz. Kod: `scripts/reveal.gd` (`Reveal.hold(nesne, unlock, ad)`), şimdilik tezgâh (`bench_top.gd`); huni ve öteki mekanikler kendi nesneleri yapılınca aynı satırla bağlanır. Ses henüz yok (kullanıcıdan gelecek). Görsel kontrol: `tools/intro_shots.gd`.

- **HUD parça parça açılır:** öğrenilmemiş mekaniğin göstergesi ekranda yok. Isınması bitmiş takıma sonradan katılan oyuncu bütün HUD'u görür.
- **İpuçları kişiye özel ve duruma bağlı:** ısınma görevinin tuşu ve ne yapılacağı görev satırının altında; nişangâhın altında yığına bakınca E, panonun önünde E, silah elde şarjör boş ve elde mermi varken R. İpucu yalnız o makinenin arayüzü: `GameState`'e girmez, ağdan geçmez. (Açık: "bir kez göster" ve ayarlarda kapatma henüz yok.)
- **Co-op:** ısınma görevleri takımındır, biri yapınca ilerler; ipuçları herkese ayrı.
- Açılıştaki pop-up'lar (yukarıda "Akış") bu ipuçlarıdır: baştan yazı duvarı yok, her şey ilk gerektiği anda bir satır.
