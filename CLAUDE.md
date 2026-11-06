# Mermi Yığını

Godot 4, 3D FPS, 4 kişilik co-op. Post-apokaliptik açık alanda bir çöplüğün önündeki üs; gündüz topla ve üret, gece gelen dalgalara karşı savun. "Mermi Yığını" yalnız geçici proje adı; tasarımı ada bağlama. Hedef: 5-6 saatlik tam oyun (2026-11-05, kullanıcı kararı), ondan kısa, ~1 saatlik ücretsiz Steam demosu. Sistem ayrıntıları ve sayılar: `docs/sistemler/` (dizin: `README.md`; yalnız dokunduğun sistemin dosyasını oku, üstte 3-5 satır özet var). Sıra: `docs/yol_haritasi.md`.

## Oyun özeti

**Yeni yön (2026-11-02, kullanıcı kararı): açık alanda gece-gündüz hayatta kalma.** Ayrıntı: `docs/sistemler/acik_alan.md`. Plan ve oturumlar: `docs/devam_promptu.md`.
- Bugüne kadar kurulan yapıların hepsi gidiyor (salon, korkuluk ve atış alanı, hurda çukuru). Oyun açık alanda geçer.
- Üssün arkasında dağ şeklinde, ucu bucağı görünmeyen bir çöplük var. Oradan alınan hurda sökülüp işlenir.
- Gündüz malzeme toplanır, sökülür; otomasyon, taret, silah vb. üretilir. Gece zombiler, yaratıklar, canavarlar gelir; her gece bir öncekinden zor.
- Kullanıcının çizimi: önde dikdörtgen bir üs alanı (üstünde masa ve oyuncu), arkasında sivri tepeli büyük çöp dağı, çevresi geniş açık arazi.
- Silahlar post-apokaliptik (şimdilik tabanca → Deagle → UZI → Scorpion → Minigun). Eski tasarımlardan kodda kalanlar: `docs/sistemler/eski_tasarimdan_kalanlar.md`.

## Teknik kurallar

- Hurda yığını yükseklik alanı + yüzde gerçek parçalar, altında gömülü parçalar (`scripts/pile.gd`); çamur yüzeyi hiç çizilmez (kullanıcı kuralı). Atış izi, kovan ve uçan mermi görselleri MultiMesh + havuz, mermi başına node yok.
- Co-op: bütün durum `GameState` autoload'unda, her oyuncu eylemi `request_*`, host otoriter, bağlantı yalnız `scripts/net.gd`. Yeni dünya sinyali `_world` ile, `EVENTS`'e yaz; yeni istemci komutu `REQUESTS`'e. Rastgelelik yalnız host'ta. Kontrol: `tools/net_check.gd`.
- Viewmodel: tek kol rig'i, her silah aynı eldivende (`tools/build_arms.py`); ayarlar `viewmodel.gd` `SETS`.
- `scenes/world.tscn` elle düzenlenmez: `tools/build_world.gd`'yi değiştirip çalıştır (kurucu betik, elle düzenleme yok; eski `arena.tscn` ve `build_arena.gd` silindi).
- Ses: gerçek kayıtlar kullanıcıdan gelir, kodla ses üretilmez.
- Headless kontroller `tools/*_check.gd`; değişiklikten sonra ilgili olanı çalıştır. Test tuşları: T sınırsız mermi (debug), Z zombi çağırma, N gece-gündüz, B gece + ormandan dalga, F7/F8 host/join, F2-F6 fabrika (parça, döndür, kur, yık, kasa). J dans, F fener (oyun tuşları).

## Ekip ve süreç

- 2 kişi, ayrı Claude hesapları. Her `.tscn` sahnesinin tek sahibi var.
- Commit mesajları Türkçe, birinci tekil şahıs, samimi ("Zombiler çok fazla gold kazandırıyordu, çarpanı yarıya indirdim."). AI imza satırı (`Co-Authored-By` vb.) eklenmez.
- Yalnız kullanıcının verdiği kararları kural diye yaz; kendi tasarım tercihini kural yapma.

## Asetler

- Low poly (2026-11-02, kullanıcı kararı; PS3 tarzı değil). Düz renkli "mobil" görünüm istenmiyor, gore ve gerçekçi korkuya yakın olmalı; PS1 korku tarzı 3 zombide deneniyor. Ayrıntı `docs/sistemler/acik_alan.md` → "Low poly" ve "PS1 korku denemesi". Kaynak ve lisans listesi `docs/sistemler/asetler.md`; yeni aset oraya yazılır.
- CC0 tercih; CC-BY ise jenerikte isim. NC, ND, "personal use only", yalnız Unreal ve Lyra kaynaklı asetler alınmaz. Gerçek marka isimleri ve logolar yok.

## Araçlar

- Godot MCP, Beckett MCP (yalnız editör açıkken), Blender MCP (yalnız Blender açıkken). Kapalı bir araç gerekirse kullanmaya çalışma, söyle.
- Çoklu agent ya da uzun iş öncesi maliyeti söyleyip onay iste.

## Dosya dizini ve çalışma

- Hangi dosya nerede: `docs/sistemler/README.md` (sistem başına özetli dosyalar), `docs/devam_promptu.md` (kurallar ve güncel durum), `docs/yol_haritasi.md` (kalan işler). Biten ya da geçersiz belgeler `docs/arsiv/`, silinmez.
- Kontrolleri `powershell -File tools/run_checks.ps1 <ad> ...` ile koş (tek satır özet, tam günlük `%TEMP%\mermi_checks\`, `--import`'u kendisi yapar); uzun Godot çıktısını okuma. `git diff`: dünya sahnesi `-diff` işaretli, boyut için `--stat`.
- Godot: `C:/Users/vedat/projeler/Godot_v4.7.2-stable_win64.exe`; pencere açma, isimle öldürme (yalnız kendi PID'in). Ayrıntı `docs/devam_promptu.md`.
