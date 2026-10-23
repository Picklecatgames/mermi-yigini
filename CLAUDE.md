# Mermi Yığını

Godot 4, 3D FPS, 4 kişilik co-op incremental oyun. Ortada 100M mermilik yığın; hedef onu bitirmek. Hedef: ~1 saatlik ücretsiz Steam demosu. Sistem ayrıntıları ve sayılar: `docs/ayrintilar.md` (yalnız dokunduğun sistemin bölümünü oku). Sıra: `docs/yol_haritasi.md`.

## Oyun özeti

- Yığından mermi al, şarjöre koy, korkuluğun (x = 14) arkasındaki hedeflere ateş et; isabet = $ (kafa ×2). Q menüsünde kişisel geliştirmeler ve takım teçhizatı, B yerleştirme modu.
- Silahlar: yumruk → Deagle → UZI (3. kasa) → Scorpion (6. kasa) → Minigun (12. kasa). 12 anahtar yığına gömülü, her biri bir kasa açar; demoda ilk 6 kasa açılır.
- Hiçbir mekanik yığına mermi eklemez; modifiyeler yalnız gold'u çarpar.

## Teknik kurallar

- Mermi mantıkta yalnız bir sayı; görseller MultiMesh + havuz, mermi başına node yok. Yığın yükseklik alanı (`scripts/pile.gd`).
- Co-op: bütün durum `GameState` autoload'unda, her oyuncu eylemi `request_*`, host otoriter, bağlantı yalnız `scripts/net.gd`. Yeni dünya sinyali `_world` ile, `EVENTS`'e yaz; yeni istemci komutu `REQUESTS`'e. Rastgelelik yalnız host'ta. Kontrol: `tools/net_check.gd`.
- Viewmodel: tek kol rig'i, her silah aynı eldivende (`tools/build_arms.py`); ayarlar `viewmodel.gd` `SETS`.
- `scenes/arena.tscn` elle düzenlenmez: `tools/build_arena.gd`'yi değiştirip çalıştır.
- Ses: gerçek kayıtlar kullanıcıdan gelir, kodla ses üretilmez.
- Headless kontroller `tools/*_check.gd`; değişiklikten sonra ilgili olanı çalıştır. Test tuşları: T sınırsız mermi (debug), F7/F8 host/join.

## Ekip ve süreç

- 2 kişi, ayrı Claude hesapları. Her `.tscn` sahnesinin tek sahibi var.
- Commit mesajları Türkçe, birinci tekil şahıs, samimi ("Mermiler çok fazla gold kazandırıyordu, çarpanı yarıya indirdim."). AI imza satırı (`Co-Authored-By` vb.) eklenmez.
- Yalnız kullanıcının verdiği kararları kural diye yaz; kendi tasarım tercihini kural yapma.

## Asetler

- Gerçekçi PBR. Kaynak ve lisans listesi `docs/ayrintilar.md` → "Kullanılan asetler"; yeni aset oraya yazılır.
- CC0 tercih; CC-BY ise jenerikte isim. NC, ND, "personal use only", yalnız Unreal ve Lyra kaynaklı asetler alınmaz. Gerçek marka isimleri ve logolar yok.

## Araçlar

- Godot MCP, Beckett MCP (yalnız editör açıkken), Blender MCP (yalnız Blender açıkken). Kapalı bir araç gerekirse kullanmaya çalışma, söyle.
- Çoklu agent ya da uzun iş öncesi maliyeti söyleyip onay iste.
