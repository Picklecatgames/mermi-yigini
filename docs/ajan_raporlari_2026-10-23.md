# Ajan raporları (2026-10-23)

13 ajan başlatıldı, kota yüzünden 5'i yarıda durduruldu. Raporu tam olanlar: yazı, tasarım, ışık, UI, görsel, co-op, ekonomi, ses. Yarım kalanlar: bug (checkleri çalıştırmaya başlamıştı), performans (yalnız profil ölçümü), çevre, oyun hissi, aset/lisans. Ajanların hepsi yalnız okudu, oyun koduna dokunmadı.

Tur sırasında bir ajan `default_bus_layout.tres`'te bütün bus'ları -80 dB'ye çekmişti (oyun tamamen sessizdi); geri alındı. Geride kalan `tools/agent_*.gd` dosyaları silindi.

## 1. Hemen düzeltilmeli (küçük iş, büyük etki)

| # | Sorun | Yer | Düzeltme | Süre | Kaynak |
|---|---|---|---|---|---|
| 1 | İstemci her upgrade'i bedava alabiliyor, release build'de de (denendi) | `game_state.gd:185`, `:503-510` `request_debug_level_up` | `if not OS.is_debug_build(): return` | 5 dk | co-op |
| 2 | Host ateş hızını zorlamıyor: Deagle'da 0,28 sn arayla 20/20 atış kabul edildi | `game_state.gd:688,693` | `p.cooldown += interval` | 10 dk | co-op |
| 3 | Var olmayan dökülen mermi id'si kabul ediliyor; bilinmeyen peer hayalet oyuncu açıyor | `game_state.gd:575-591`, `:279-284` | id aralığı + mesafe kontrolü; `_players.get()` | 35 dk | co-op |
| 4 | Yerleştirme alanı korkuluğa 1 m: hedef dibe konur, %100 kafa, x20 zincir → baskın strateji (önceki turdan **hâlâ açık**) | `game_state.gd:194` `PLACE_ZONES` | x ≥ 20 | 10 dk | ekonomi |
| 5 | Uzak Atış sınırsız (+%208'e kadar), Altın'ı eziyor | `game_state.gd:754-755` | `behind = minf(…, 12.0)` | 10 dk | ekonomi, tasarım |
| 6 | Viewmodel ortamında SSR açık kalıyor: boşa tam ekran geçiş | `player.gd:280-295` | `_vm_env.ssr_enabled = false` | 2 dk | ışık |
| 7 | B + Q birlikte → imleç kayboluyor; Q açıkken yürüme/1-4/E çalışıyor | `player.gd:329,424`, `placement.gd:109` | Menü açıkken bunları yut | 35 dk | UI |
| 8 | Altın her değişince Q menüsü kapalıyken bile 6 ms'lik `_refresh` yapıyor (minigun'da saniyede 20 kez) | `upgrade_menu.gd` `_refresh` | Görünmüyorsa atla | 10 dk | performans |
| 9 | Co-op'ta isim "Oyuncu 1739204857" (ham peer id) | `game_state.gd:499`, `remote_players.gd:273` | slot numarası | 15 dk | yazı |

## 2. Demo için şart (büyük iş)

1. **Silah sırası kodda yok.** UZI ve Scorpion ilk saniyeden 2/3 tuşuyla bedava (`game_state.gd:104-107`, `gun_open :642`). Öneri: kişisel satın alma (Mikro SMG ~$1.500, Kompakt SMG ~$6.000). 2-3 sa. *(tasarım + ekonomi, ikisi aynı şeyi buldu)*
2. **Demonun sonu yok.** 4 kişi 1 saatte yığının ~%0,04-0,07'sini harcıyor. 6. ve 12. anahtar otomasyonsuz bulunamıyor, minigun finali imkânsız. Kişisel para 9-19. dakikada tükeniyor, sonrası ölü. Karar gerekiyor: küçük demo yığını (2-5M) ya da "N. kasa açılınca jenerik". Ayrıca taret ve bant demoya girmezse oyun ~15. dakikada tıkanıyor.
3. **Kasalar açılmıyor.** Anahtar bulunuyor ama ödül yok (`chests.gd` yalnız model). Ortak açılma durumu da yok (anahtarlar kişisel `PlayerState.keys`). 6-8 sa.
4. **Çerçeve ekranlar yok:** ana menü, duraklat/çıkış (Esc yalnız imleci bırakıyor, tek çıkış Alt+F4), ayarlar (hassasiyet, ses, FOV, grafik). **Release build'de co-op'a girilemiyor**: F7/F8 yalnız debug (`net.gd:58`). 1-1,5 gün.
5. **Grafik kalite seviyesi yok.** SSAO, SSIL, SSR, sis, glow, 19 gölgeli ışık ve 4 bölmeli güneş herkeste açık. 720p'de 3-4 bin draw call. Düşük/Orta/Yüksek seviyesi ve gölge diyeti (19 → ~9 gölgeli ışık, güneş 2 bölme / 50 m). 3-4 sa.
6. **Jenerik ekranı yok**, oysa ~25 CC-BY aset var: Steam'de lisans ihlali olur. Minigun, chest_01 dokuları ve steel sesleri için lisans doğrulanmamış. Skull Key Sketchfab Standard (şüpheli). 0,5 gün + araştırma.
7. **Reload sesleri bağlı değil**, dört silah aynı tabanca sesini çalıyor, minigun sesi `max_polyphony=4` ile kesiliyor. Mermi alma, para, kombo, upgrade ve menü için ses yok. Ses ayarı için bus yok (yalnız Master/Dunya/Adim). Kayıtlar kullanıcıdan gelmeli.
8. **Host düşünce** istemcinin parası/upgrade'leri 0 görünüyor, "Host ayrıldı" ekranı yok. Steam/NAT yok (ENet UDP 24680, port yönlendirme şart) → GodotSteam relay (Faz 6).

## 3. Görsel ve ışık

- Silahlar artık siyah değil ama tutarsız: Deagle en koyu, Scorpion ×4 albedo nişanda tebeşir gibi düz gri. Öneri: Scorpion 4 → 2,5, Deagle 1 → 1,4; kalıcı çözüm dokuları bir kez düzeltmek. Ayrıca `viewmodel.gd:276` `albedo_color = Color(k,k,k)` orijinal tonu eziyor, `*= k` olmalı.
- Namlu alevi ateş çekimlerinde görünmüyor (şüpheli: çekim zamanlaması ya da `Flash` render katmanı 2'de değil). Oyunda bakılmalı.
- Hedefler arka plandan ayrışmıyor: açık gri dummy, açık bej toprak setin önünde 20 m'de kayboluyor. Set koyulaşsın ya da hedefe ayrı anahtar ışık verilsin. Set de dokusuz bir prizma gibi.
- Yığında patlamış beyaz lekeler: HeapSpot 8 → 6, `adjustment_saturation` 1,15 → 1,05.
- Ortam dolgusu 0,42 holü "loş ama düzgün" yapmış, ışık havuzları kaybolmuş: 0,32 önerisi (estetik karar). Yükleme kapısı simsiyah bir delik, altından sızma okunmuyor.
- 110 dokuda mipmap kapalı, 134'ünde VRAM sıkıştırması yok (decal'lar uzaktan titrer). 4K silah ve kasa dokuları → `size_limit` 2048/1024. Kol rig'inde 4K UV checker test dokusu bağlı.
- Korkuluk hâlâ BoxMesh. Kauçuk zeminde tekrar deseni var. Dokusuz kırmızı dikdörtgenler duruyor.

## 4. UI ve yazılar

- Q menüsü ve yerleştirme arayüzü `fit_screen` kullanmıyor; 1440p'de küçük kalıyor. Kombo göstergesi, payout pop ve isabet işareti UiStyle dışında (varsayılan font, kendi renkleri). Kaydırma çubuğu varsayılan temada. `key_cache.gd:232` `set_anchors_preset` kullanıyor (kurala aykırı).
- Kilitli kasa silahına basınca hiçbir tepki yok. "yığında kalan · anahtar 0/12" satırı "yığında kalan anahtar" gibi okunuyor; ana hedef sayısı yalnız 15 px.
- Kafa isabeti yalnız renkle ayrılıyor (renk körleri için sorun). Gamepad desteği yok.
- Şarjör kartı 7 yazıyor, HUD "/ 28" gösteriyor (silah çarpanı karta yansımıyor). "Altın" upgrade'i para birimiyle ve "Altın Kukla"yla karışıyor. "Uzak Atış +1%/m" kartında birim anlaşılmıyor.
- Tuş yazımı karışık (q/b küçük, R/T büyük, "[E]" parantezli), bildirimlerde bazen tamamı büyük harf. Bazı yerlerde binlik nokta yok (`upgrade_menu.gd:438`, `payout_pop.gd:44`).
- Yerelleştirme altyapısı sıfır: ~110 metin kodda, ~75 tabela `arena.tscn`'de. İngilizce için ~1,5 gün.
- Türkçe yazım temiz, ekranda gerçek silah adı yok. Ancak UZI/Scorpion/Minigun dokularında logo silinmedi; aydınlatma çarpanından sonra görünür olabilir (şüpheli, yakından bakılmalı).

## 5. Denge (ekonomi ajanının önerileri)

| Ne | Eski → yeni |
|---|---|
| El Kapasitesi | en fazla 10 → `[1..7, 10, 15, 20, 30, 35]` (SMG şarjörüne yetişsin) |
| İlk alımlar | El `[6,15…]` → `[5,12…]`, Şarjör `[8,20…]` → `[5,15…]` (ilk gerçek artış ~30 sn'de) |
| Kombo Tavanı fiyatı | `[15,60,180,450]` → `[15,120,1500,5000]` |
| Patlayan Varil | komşu taban toplamı tavansız → kök hedef başına 1 kez, en çok $20 |
| Çift Gong `PAIR_MULT` | 5 → 3; tasarım ajanı ayrıca "iki farklı atıcı" şartı ve 0,25 sn pencere öneriyor |
| Teçhizat (4 kişi) | fiyat ×2,5, kopya başına ×1,5; kişisel paradan kasaya bağış komutu |
| Zincir | ıska zinciri sıfırlamasın, yarıya indirsin: kolay hedefte saklanmayı kırar (tasarım) |

## 6. Belge ↔ kod çelişkileri (yazı ajanı)

- `ayrintilar.md:194` eğimi 30° diyor, `pile.gd:13` 45°.
- Kasa sırası x: belgede −20, kodda −23.
- HUD metinleri: "SINIRSIZ MERMİ" artık "test modu · T", "Kasa $N" artık "takım kasası $N".
- Anahtar listesi belgede eski: 10 ad, kodda 12.
- Silah sırası belgede revolver/Uzi/AK.
- Silinmiş hedefler belgede hâlâ duruyor (`steel_silhouette.tscn` vb.).
- Ortam dolgusu belgede 0,3, kodda 0,42.
- Dummy sesi: belgede 18 varyant, kodda 6.
- Perde kayması: ±%3-4 var (`viewmodel.tscn:78,88`), CLAUDE.md ise perde kaydırmayı yasaklıyor.
- CLAUDE.md "alttaki çubukla seçilir" diyor, çubuk tıklanmıyor.
- CLAUDE.md "HP'li dummy planlanıyor" diyor, Zırhlı Kukla zaten HP'li.

## 7. Diğer

- `project.godot:19`'daki `BeckettRuntime` autoload'u release build'e de giriyor; export'tan önce çıkarılmalı.
- `net_check` bir çalıştırmada Texas Star 0,509 rad farkla FAIL verdi. O sırada başka Godot süreçleri de çalışıyordu (şüpheli). Açı cue zamanına göre ileri sarılmalı.
- `shop_check` çıkışta "ObjectDB leaked" uyarısı veriyor.
- Paralel check'ler aynı ENet portunu kullandığı için çakışıyor.

## İyi olanlar, kalsın

Host otoritesi ve `_request` kimlik kontrolü sağlam. Geç katılma kapsamlı ve testli. Rastgelelik kuralına uyuluyor. "Yığın hem hedef hem yakıt" kuralı ihlal edilmiyor. 12 hedefin her biri ayrı bir beceri istiyor (sarkaç ve Altın Kukla özellikle iyi). Yığın uzaktan da yakından da güzel. Silah ve kol birleşimi temiz. Işık renk dili atmosferi anlatıyor. HUD simetrisi ve ölçeği doğru. Türkçe yazım temiz.
