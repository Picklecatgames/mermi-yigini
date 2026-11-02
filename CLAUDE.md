# Mermi Yığını

Godot 4, 3D FPS, 4 kişilik co-op. Post-apokaliptik bir hurdalık kalesi, dalga dalga gelen zombiler. "Mermi Yığını" yalnız geçici proje adı; tasarımı ada bağlama. Hedef: ~1 saatlik ücretsiz Steam demosu. Sistem ayrıntıları ve sayılar: `docs/ayrintilar.md` (yalnız dokunduğun sistemin bölümünü oku). Sıra: `docs/yol_haritasi.md`.

## Oyun özeti

- Korkuluğun (x = 14) ötesinden gelen zombilere ateş et; isabet = $ (kafa ×2). Dalgayı oyuncu şalterle başlatır; çitin bölmeleri yıkılınca zombiler içeri girer, herkes baygın düşünce dalga kaybedilir. Tezgâhta kişisel geliştirmeler ve çit onarımı.
- Salonun batısı tavana kadar hurda dağı. Her şey hurdalıktan gelen malzemeden yapılır: hurda öğütülür, çıkan malzeme oyuncunun seçimiyle barutta ya da kovanda kullanılır. Yeni kovanlar ve mermi türleri açıldıkça daha çok hurda gerekir.
- Silahlar post-apokaliptik silahlara geçiyor (şimdilik tabanca → Deagle → UZI → Scorpion → Minigun). 12 anahtar dağa gömülü; ne açtıkları açık.
- Mermi yığını tasarımı (yığını bitirme hedefi, mermi tarifi, yığından çıkan özel mermiler, kasa sırası, taretler) bırakıldı. Kodda kalanlar: `docs/ayrintilar.md` → "Eski tasarımdan kodda kalanlar".

## Teknik kurallar

- Hurda dağı yükseklik alanı + yüzde gerçek parçalar (`scripts/pile.gd`). Atış izi, kovan ve uçan mermi görselleri MultiMesh + havuz, mermi başına node yok.
- Co-op: bütün durum `GameState` autoload'unda, her oyuncu eylemi `request_*`, host otoriter, bağlantı yalnız `scripts/net.gd`. Yeni dünya sinyali `_world` ile, `EVENTS`'e yaz; yeni istemci komutu `REQUESTS`'e. Rastgelelik yalnız host'ta. Kontrol: `tools/net_check.gd`.
- Viewmodel: tek kol rig'i, her silah aynı eldivende (`tools/build_arms.py`); ayarlar `viewmodel.gd` `SETS`.
- `scenes/arena.tscn` elle düzenlenmez: `tools/build_arena.gd`'yi değiştirip çalıştır.
- Ses: gerçek kayıtlar kullanıcıdan gelir, kodla ses üretilmez.
- Headless kontroller `tools/*_check.gd`; değişiklikten sonra ilgili olanı çalıştır. Test tuşları: T sınırsız mermi (debug), F7/F8 host/join.

## Ekip ve süreç

- 2 kişi, ayrı Claude hesapları. Her `.tscn` sahnesinin tek sahibi var.
- Commit mesajları Türkçe, birinci tekil şahıs, samimi ("Zombiler çok fazla gold kazandırıyordu, çarpanı yarıya indirdim."). AI imza satırı (`Co-Authored-By` vb.) eklenmez.
- Yalnız kullanıcının verdiği kararları kural diye yaz; kendi tasarım tercihini kural yapma.

## Asetler

- Gerçekçi PBR; hurdalık için paslı, hafif karikatürize asetler de olur. Kaynak ve lisans listesi `docs/ayrintilar.md` → "Kullanılan asetler"; yeni aset oraya yazılır.
- CC0 tercih; CC-BY ise jenerikte isim. NC, ND, "personal use only", yalnız Unreal ve Lyra kaynaklı asetler alınmaz. Gerçek marka isimleri ve logolar yok.

## Araçlar

- Godot MCP, Beckett MCP (yalnız editör açıkken), Blender MCP (yalnız Blender açıkken). Kapalı bir araç gerekirse kullanmaya çalışma, söyle.
- Çoklu agent ya da uzun iş öncesi maliyeti söyleyip onay iste.
