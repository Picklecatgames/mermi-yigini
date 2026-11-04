# Durum ve otomasyon hazırlığı (2026-11-05)

Kullanıcının kararı (2026-11-05): dağ bir yerden sonra otomatikleşir, oyun Factorio'ya bağlanır. Bant sistemi, taret sistemi, hurdaları dönüştürme, dönüşenleri kasaya alma. **Kasa yüzde yüz ortak.** Kişisel geliştirmelerde otomatikleştirmeler olur. Gereken aset, shader ve HDRI indirilebilir (lisans kuralları CLAUDE.md'de).

Bu dosyada kullanıcı kararı olarak yazılan yalnız yukarıdaki paragraftır. Geri kalan her öneri ve sayı benim tahminimdir, kural değil.

## 1. Kontrollerin durumu

50 headless kontrol 2026-11-05'te `f8d31158` sonrası main'de (`7d79f864`) çalıştırıldı. Godot penceresi açılmadı. Beckett bağlanamadı (`ECONNREFUSED`, yalnız editör açıkken çalışıyor), Godot MCP yalnız proje bilgisi için kullanıldı.

**`net_check` geçiyor:** yığın iki tarafta bit bit aynı (fark 0), istemci isabeti, itme, dost ateşi, görevler tamam. `join_check` de geçiyor.

43 geçti, 6 düştü, 1'i geçti ama hatası var:

| Kontrol | Sonuç | İlk okuma |
|---|---|---|
| `fence_check` | korkuluk direği bulamıyor (0) | Korkuluk açık alanda yok; kontrol eski |
| `hitbox_check` | "the railing is there" düşüyor | Aynı, kontrol eski |
| `head_pop_check` | kafadan öldürme ipucu gelmiyor (0) | Korkuluğa bağlı kurulum olabilir, doğrulanmadı |
| `keys_check` | 240 sn'de bitmedi, doğrulama hatası | Kontrol hâlâ eski çukuru bekliyor olabilir |
| `waves_check` | 240 sn'de bitmedi, satır 79'da boş düğüm | Kontrol eski arayüze bakıyor olabilir |
| `zombie_roles_check` | `waves.gd:703` sıfıra bölme, 69 hata | **Gerçek hata olabilir,** doğma listesi boş kalıyor |
| `wood_mix_check` | geçti, ama başta derleme hatası yazıyor | Araç `GameState` görmeden yüklüyor; kontrol sonucunu etkilemiyor |

Çalışırken görülen hatalar (kontrolleri düşürmüyor):
- `gun_table.gd:43`: `shader_parameter/glow` diye bir parametre yok, tween boşa gidiyor.
- `Tween started with no Tweeners` (`GunTable`).
- Dalga gezinme ağında "aynı yere 2'den çok kenar" uyarısı.
- `net_check`te dost ateşi için beklemeyi 0,5 sn'den 2 sn'ye çıkarmıştım; poz neden geç geliyor, bilinmiyor.

Hâlâ doğrulanmayanlar: hiçbir görsel iş oyun içinde hareketle denenmedi; `tools/*_check.gd` iki pencereli gerçek bir co-op oturumunun yerini tutmuyor.

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
| Düşmanların yapılara saldırması | Yalnız çit ve oyuncu (`fence_bays`) | **Yok** |
| Açık alanda dalga | B tuşuyla ormandan baskın var, gece döngüsüne bağlı gerçek gece akışı yok | **Kısmen** |

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
1. Düşen kontrolleri onar ya da eskiyse kaldır; sıfıra bölmeyi çöz.
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
| `kontrol-onarim` | `tools/*_check.gd`, `waves.gd` hatası, `gun_table.gd` | 50 kontrol geçiyor ya da gerekçeyle kaldırıldı |
| `hurda-dagi` | `scripts/pile.gd`, `scrap_hills.gd`, `build_scrap_face.gd`, `heap_proof.gd` | Ön kısım gerçek fizikli, alttan çekince kayıyor, performans ölçülmüş |
| `uretim-temeli` | yeni `scripts/factory/`, `data/`, `tools/factory_check.gd`, `GameState` yeni blok | Hurda → dönüştürücü → bant → kasa headless iki oyuncuda çalışıyor |
| `aset-uretim` | yeni `assets/factory/`, `docs/aset_adaylari_otomasyon.md` | Aday listesi ve işlenmiş asetler, sahneye konmadan |

Sonra (temel bitince): taret, üretim menüleri, gece akışı, kişisel geliştirmeler, temizlik.
