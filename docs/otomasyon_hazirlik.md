# Durum ve otomasyon hazırlığı (2026-11-05)

Kullanıcının kararı (2026-11-05): dağ bir yerden sonra otomatikleşir, oyun Factorio'ya bağlanır. Bant sistemi, taret sistemi, hurdaları dönüştürme, dönüşenleri kasaya alma. **Kasa yüzde yüz ortak.** Kişisel geliştirmelerde otomatikleştirmeler olur. Gereken aset, shader ve HDRI indirilebilir (lisans kuralları CLAUDE.md'de).

Bu dosyada kullanıcı kararı olarak yazılan yalnız yukarıdaki paragraftır. Geri kalan her öneri ve sayı benim tahminimdir, kural değil.

## 1. Kontrollerin durumu

2026-11-05 onarımından sonra 47 headless kontrolün hepsi çıkış kodu 0 ile geçiyor; hata satırlarını ve sonuçlarını okudum. Godot penceresi açılmadı. `net_check` ve `join_check` boşta 4'er kez, `net_check` ağır yük altında 3 kez daha üst üste geçti. Bunlar iki pencereli gerçek bir co-op oturumunun ya da elle oynamanın yerini tutmaz: dalgaları oyun içinde hareketle denemedim.

| Kontrol | Kök neden | Ne yaptım |
|---|---|---|
| `zombie_roles_check` | **Gerçek hata.** Açık alanda ağıl işaretçisi yok, `_spawns` boş; şalterin eski yerinde (8,2; -27,6) görünmeyen şalter E'ye açıktı, dalga başlıyor, `_spawn_next` sıfıra bölüyordu. Kuyruk boşalıyor, zombi çıkmıyor, dalga FIGHT'ta takılı kalıyordu | Şalter yoksa E teklif edilmiyor. Dalga çağrılırsa orman kenarından çıkıp en yakın oyuncuyu avlıyor. Kontrolü bu akışa yazdım; korkuluğa bağlı adımlar çıktı |
| `waves_check` | Eski salonu bekliyordu (ağıl, kapı, tabela) | Açık alana yeniden yazdım: ormandan çıkış, temizleme, oyuncu gerçekten düşünce kayıp dalga, ortada katılma, istemcinin dalga çağırması, host gidince sıfırlanma |
| `fence_check` | Korkuluk yok; denediği her şey korkuluğun kendisi | **Kaldırdım.** Kayıp dalga ve ağ eşitliği `waves_check`'te |
| `hitbox_check` | Yalnız korkuluk adımı eskiydi | O adımı çıkardım, zombi isabetleri aynen duruyor |
| `head_pop_check` | Dalganın ağılda hazır beklemesini varsayıyordu | Kuyruğu gerçek doğma yolundan boşaltıyor |
| `keys_check` | `assert` düşünce kontrol hiç bitmiyordu (240 sn'lik zaman aşımı buydu). Düşme nedeni: kazı sınırı artık tutmuyor | `assert` yerine çıkış koduyla düşüyor. **Sınır denetimini ve nadir anahtar kazısını çıkardım, oyunda bir şey düzeltmedim:** aşağıdaki açık maddeye bak |
| `wood_mix_check` | `_init`'te yüklüyordu, autoload'lar henüz yoktu | `_initialize`'a aldım, derleme hatası gitti |

Oyunda düzelen diğer hatalar:
- **`net_check` poz gecikmesi:** ENet'in güvenilir olmayan paket kısması. Tek bir uzun kare gidiş-dönüşü uzatınca kısma 0'a kadar iniyor, pozlar atılıyor. Ölçtüm: düşen koşuda istemcide kısma 0'dı, host 0,9 sn poz almadı, atış pozdan önce vardı ve dost ateşi olayı hiç gelmedi. Yani bekleme süresi değil gerçek bir co-op hatasıydı: yavaş bir anda oyuncunun atışları yutulabiliyordu. `net.gd` artık kısmayı kapatıyor, bekleme yine 0,5 sn, kontrol kısmanın kapalı olduğuna da bakıyor. Steam'e geçince bu ayar ENet'le birlikte gider, oradaki davranış ayrıca bakılmalı.
- **Gezinme ağı uyarısı:** eski düz zemin katmanı gerçek zeminin üstüne ikinci yüzey olarak ekleniyordu. Kaldırdım, uyarı gitti, yedi orman noktasından yollar aynı çıktı.
- **`gun_table.gd`:** `glow` parametresi aslında var; renderer'sız çalışınca malzeme parametre listelemediği için `tween_property` ölüyor (benim okumam), boş tween hatası da ondan geliyordu. Artık ada göre ayarlanıyor, iki hata da gitti. Pencerede parlamaya bakmadım.
- **`Tween started with no Tweeners`:** `GunTable`'ınkine ek olarak `Waves` de veriyordu (kayacak kapı yok). Kapı yoksa tween kurulmuyor.
- Açık alanda: şişko patlaması görünmeyen korkuluğa hasar vermiyor, pençe mesafesi tepede yanlış ölçülmüyor, istemcideki zombi yüksekliği host'u izliyor.

Açık kalanlar (kontrolleri düşürmüyor):
- **Anahtarların kazı sınırı artık geçerli değil.** `min_take`, yığının `LOCK_SLOPE`'tan dik durmadığını varsayıyor, hurda dağları ise daha dik (benim okumam). Bir denemede 508 sınırlı anahtar 150 parçada çıktı. Anahtarlar temizlik listesinde; tutulacaksa sınır yeniden düşünülmeli.
- **Zıplayan, atlayan ve altından geçen türler açık alanda özelliklerini kullanmıyor,** yalnız yürüyüp pençe atıyorlar; bu davranışlar korkuluk yoluna bağlı. Çığlıkçı da yalnız `x < 28`'de bağırıyor.
- **B baskını FIGHT dışında çalışıyor:** bu yüzden çığlık, kükreme ve can yenileme onda devreye girmiyor. Çağrılan dalgada giriyor.
- **Oyunda dalgayı çağıran bir şey yok:** `request_pull_lever` duruyor ama şalter olmadığı için oyuncu ulaşamıyor; gerçek dalga yalnız B ile geliyor. 4. bölüm madde 7 (gece akışı) bunu bağlayacak.
- `psx_screen.gd:63`: `_ps1_materials.call_deferred` silinmiş düğümle çağrılabiliyor (`zombie_body_check` ve `specials_check` çıktısında yüzlerce satır). Zararsız görünüyor, çıktıyı kirletiyor.
- `press_check`: bir malzemenin üretilen shader'ı derlenmiyor (`ROUGHNESS = roughness`, köşe başına gölgeleme). Hangi malzeme olduğuna bakmadım.
- Her ana sahneli kontrolde: `psx_screen.gd:47` shader uyarısı (`custom_samplers`), çıkışta RID sızıntısı satırları. Sonuçları etkilemiyor.

## 2. Factorio'ya bağlanmak için kodda ne var, ne yok

| Gereken | Bugün | Durum |
|---|---|---|
| Elle hurda alma | `request_pick_up`, `Pile` | Var |
| Hurdanın malzeme bilgisi | `hurda.json` `materyal`, `kutle_kg` | Veri var, oyunda kullanılmıyor |
| Host otoriter istek ve olay düzeni | `REQUESTS`, `EVENTS`, `_world` | Var, makineler de bunu kullanmalı |
| Ortak para | `vault` (float), yalnız co-op'ta; tek başına `gold` kullanılıyor | **Kısmen.** Kasa para, eşya tutmuyor |
| Malzeme ve eşya envanteri | Yok; yalnız `carried`, `melt_bin`, `brass`, `rounds` | **Yok** |
| Dönüştürme | `request_melt`, `request_press`: eski mermi-kovan zinciri | **Eski tasarım** |
| Tarif tablosu | Yok | **Yok** |
| Yerleştirme (hayalet, döndürme, host onayı) | Yol haritası 10. adım yapıldı dedi, kodda `can_place` ve `request_place_*` artık yok | **Kayıp; git geçmişinden bakılabilir** |
| Bant, makine, taşıyıcı kol | Yok; `rail_mover.gd` başka iş için | **Yok** |
| Taret | Yok (eski tasarımda "taret yok" kararı vardı, yeni karar onun önüne geçer) | **Yok** |
| Enerji | Yok | **Yok,** kullanıcı henüz karar vermedi |
| Kayıt | Yok; yalnız `_saved` oturum içi kişisel durum | **Yok.** Fabrikasız da gerekli |
| Ortada katılan fabrikayı görür | `pile.snapshot()` dağ için var, fabrika için yok | **Yok** |
| Düşmanların yapılara saldırması | Yalnız oyuncu (çit yolu ölü kod) | **Yok** |
| Açık alanda dalga | Dalga akışı ormandan çalışıyor (`waves_check`), ama yalnız B tetikliyor; geceye bağlı değil | **Kısmen** |

## 3. Önerdiğim teknik temel (kural değil)

- **Fabrika tek simülasyon:** host'ta sabit adımlı (örn. saniyede 10), düğümsüz, dizi tabanlı. Bant üstündeki eşya başına düğüm yok; çizim MultiMesh (mevcut kuralla aynı).
- **Istemci hesaplamaz, olay da çok yollamaz:** yapı kurma ve yıkma `request_*` ve `_world` ile; bant akışı her eşya için ayrı paket değil, ortak saat ve durum özetiyle. Her iki tarafın aynı sonucu bulduğunu `tools/factory_check.gd` doğrular (dağın `heap_clock` düzeni gibi).
- **Veri tablosu:** `data/items.json`, `data/recipes.json`, `data/machines.json`. Yeni makine kod değil satır olsun.
- **Izgara:** üs çevresinde 1 m'lik yerleştirme ızgarası (benim tahminim), bant yön verisiyle komşusuna bağlanır.
- **Kasa:** `GameState` içinde tek bir ortak envanter, tek başına da aynı kasa. Parayı da kasaya almak ayrı karar; bkz. Sorular.
- **Dağ ile bağ:** taşıyıcı hurdayı yerdeki parçadan değil dağın sayısından (`GameState.pile`) çeker, kaldığı yerde dağ "gıdım gıdım" azalır; çizim kuralı değişmez.
- **Performans hedefi:** 2000 eşya, 300 yapı için host'ta kare başına 2 ms altı (benim tahminim), kontrolle ölçülür.
- **Kayıt:** fabrikayı tasarlarken serileştirme baştan düşünülür; dünya host'ta.

## 4. Yapılacaklar

### Olmazsa olmaz (demo için)
1. ~~Düşen kontrolleri onar ya da eskiyse kaldır; sıfıra bölmeyi çöz.~~ Yapıldı, bkz. 1. bölüm.
2. Hurda dağının önü: gerçek fizikli sıkı yığın (`tools/heap_proof.gd`, kullanıcı referansı patates yığını), yalnız çekilen yerin çevresi hareketli.
3. Üretim temeli: envanter, ortak kasa, tarifler, ızgara, yerleştirme, bant simülasyonu, ağ, kayıt.
4. Dönüştürme zinciri: hurda → sökme → malzeme → kasa. Eski eritme ve mermi presi bununla değişir.
5. Taret: yapılır, kurulur, kasadan mermi alır, gece vurur.
6. Üretim masası ve menüleri (gerçek asetle, az yazı: kullanıcı kuralları).
7. Gece akışı: dalgalar saate bağlı, her gece zorlaşıyor, ormandan çıkıyor; çit yerine üs ve yapılar hedef.
8. Kişisel geliştirmeler (taşıma, hız, otomatik toplama vb.); ağaç kişisel, kasa ortak.
9. Silahların malzemeyle üretimi; dağdan mermi çıkma kalkar.
10. Ana menü, dünya oluşturma, kayıt, Steam (GodotSteam), demo sayfası.
11. 1, 2 ve 4 oyuncuyla denge; 60 dakikalık tur.

### Temizlik (kullanıcı onayıyla)
Salondan kalanlar hâlâ kodda ve `main.tscn`'de: `chests.gd`, anahtarlar (`key_cache.gd`), çit (`fence.gd`, `waves.gd` içinde 29 yer), mermi fırlatma, eritici ve pres, görev panosu, `arena.tscn`, `docs/yol_haritasi.md`'nin Faz 3-5'i ve eski bölümler. `docs/ayrintilar.md` 577 uzun satır; yeni yönle karışıyor.

### Yapılabilirler (iyi olur)
- Dağın derininden çıkan nadir bulgular, gömülü kasalar.
- Bandı gece kesen, makineye saldıran düşman türü; fabrikaya sızan yaratık.
- Hurda dağında çökme tehlikesini otomasyonla tetikleme: alttan çok çekersen yamaç iner.
- Boss gecesi için özel taret ve savunma görevleri.
- Bantlardan geçen parçalar gerçek hurda modelleri olur; dağın dili fabrikada sürer.
- Çalışan makine sesleri, kıvılcım, duman; geceleri makinelerin ışığı tehlike ve güven verir (ses dosyaları kullanıcıdan).
- Co-op rolleri: biri kazar, biri kurar, biri nişancı. Ping ve emote.

## 5. Aset listesi (indirilecek)
CC0 tercih; yeni aset `docs/ayrintilar.md` → "Kullanılan asetler"e yazılır, PS1 çevirisi `tools/psx_props.gd`.
- Bant: düz, köşe, yükselen, ayırıcı, yükleme kolu.
- Makine: öğütücü, parçalayıcı, sökme tezgâhı, fırın, pres, jeneratör, boru ve kablo.
- Kasa: büyük ortak depo, raf, varil, konteyner.
- Savunma: sabit ve dönen taret, alev, elektrik, tuzak, projektör, barikat, kum torbası.
- Üs: çalışma masası, levye, gösterge, uyarı lambası.
- Ortam: gece ve alacakaranlık HDRI'ları, sis ve duman dokuları; kıvılcım ve erimiş metal için shader örnekleri.

## 6. Kullanıcıya sorular (cevap gelene kadar temel işi bunlara bağlı değil)
1. Otomasyon ne zaman açılır: kaçıncı gece ya da hangi görevle?
2. Enerji olacak mı (jeneratör, kablo), yoksa makineler kendiliğinden mi çalışır?
3. Kasa eşya mı tutar, para da mı? Altın kalıyor mu, yoksa her şey malzeme mi olur?
4. Kişisel otomatikleştirmeler nedir: otomatik toplama, sırtta küçük bant, drone?
5. Dağ gerçekten tükenebilir mi? Tükenirse oyun biter mi?
6. Fabrika nereye kurulur: yalnız beton üs mü, dağa kadar arka bahçe mi?
7. Demo kaç geceyle biter, kaybetme koşulu ne (herkes baygın mı, üs yıkılınca mı)?
8. Eski eritici, pres, görev panosu, anahtar ve kasalar tamamen gidiyor mu?

## 7. Oturumlar (2026-11-05)
Her oturum kendi çalışma ağacında; dosya sahipliği çakışmaz.

| Oturum | Sahibi | Bitti sayılması |
|---|---|---|
| `kontrol-onarim` | `tools/*_check.gd`, `waves.gd` hatası, `gun_table.gd` | Bütün kontroller geçiyor ya da gerekçeyle kaldırıldı |
| `hurda-dagi` | `scripts/pile.gd`, `scrap_hills.gd`, `build_scrap_face.gd`, `heap_proof.gd` | Ön kısım gerçek fizikli, alttan çekince kayıyor, performans ölçülmüş |
| `uretim-temeli` | yeni `scripts/factory/`, `data/`, `tools/factory_check.gd`, `GameState` yeni blok | Hurda → dönüştürücü → bant → kasa headless iki oyuncuda çalışıyor |
| `aset-uretim` | yeni `assets/factory/`, `docs/aset_adaylari_otomasyon.md` | Aday listesi ve işlenmiş asetler, sahneye konmadan |

Sonra (temel bitince): taret, üretim menüleri, gece akışı, kişisel geliştirmeler, temizlik.
