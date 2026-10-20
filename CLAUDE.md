# Mermi Yığını

Godot 4, 3D FPS, 4 kişilik co-op incremental oyun. Ortada 100M mermilik yığın; hedef onu bitirmek. Ayrıntılar (her sistemin sayıları, ayar değerleri, aset kaynakları): **`docs/ayrintilar.md`** — bir sisteme dokunmadan önce ilgili bölümünü oku. Sıra: `docs/yol_haritasi.md`. Hedef: ~1 saatlik ücretsiz Steam demosu, 4 kişilik co-op.

## Oyun

- Yığından mermi al, şarjöre koy, hedeflere ateş et. İsabet = $ (dummy $1, kafa ×2). Ateş hızı sabit 0,42 sn; Q menüsü (kişisel, bütün hedeflere): El Kapasitesi, Şarjör, Kombo Tavanı (x2→x20), Altın (+%60), Uzak Atış (korkuluğun gerisinde %/m).
- Silah sırası: tabanca → revolver → Uzi → AK. Kasadan çıkan benzersiz silahlar: orta oyun (6. anahtar, seçilmedi) ve minigun (12. anahtar, final).
- **Yığın hem hedef hem yakıt.** Hiçbir mekanik yığına/envantere mermi eklemez; modifiyeler yalnız gold'u çarpar.
- Kombo: 1,5 sn içindeki isabetler zinciri büyütür; ödenen çarpan = zincir, tavanı Kombo Tavanı upgrade'i (x2→x20). Kafa ve gövde ayrı zincir. Taret/bant zinciri büyütmez.
- Hedefler doğu duvarında, x = 14'teki korkuluğun arkasında; korkuluğun ötesinden atış para vermez. Küçük/hareketli/zamanlı hedef daha çok öder.
- 12 anahtar yığına gömülü (derinlik nadirliğe bağlı, `scripts/key_cache.gd`); her biri bir kasa açar (mermi tipi, benzersiz silah, özel dummy). Kasa açılınca özellik bütün takıma açılır. Kasalar henüz yok.
- Planlananlar: kovan → fırın → külçe (taret geliştirme), taretler, tek yönlü grid bantlar, bant modifiyeleri (seken mermi vb.), robotlar, HP'li dummy.
- Yok: ürün zinciri, kablolama, büyük tech tree, idle ağırlık, konuşma animasyonu, dummy yıpranması.

## Teknik kurallar

- **Mermi mantıkta yalnız bir sayı.** Görseller MultiMesh + havuz; mermi başına node/fizik yok. Yığın bir yükseklik alanı (`scripts/pile.gd`), 30°'yi aşan eğim kayar.
- **Co-op:** bütün durum `GameState` autoload'unda; her oyuncu eylemi `request_*` komutu; host otoriter. Bağlantı yalnız `scripts/net.gd`. **Yeni dünya sinyali: `emit` yerine `_world` kullan, `EVENTS`'e yaz. Yeni istemci komutu: `REQUESTS`'e yaz.** Gold kişisel, dünyaya kurulan her şey ortak kasadan. Rastgelelik yalnız host'ta (`cue_target` / `key_layout` ile yayılır); süsler yerel. Kontrol: `tools/net_check.gd`.
- Viewmodel: bumstrum kolları, tek `allanims` klibi `play_section` ile bölümlenir, idle klibi kullanılmaz; ayrı SubViewport, render katmanı 2.
- `scenes/arena.tscn` elle düzenlenmez: `tools/build_arena.gd`'yi değiştirip yeniden çalıştır.
- Ses: gerçek kayıtlar kullanıcıdan gelir, kodla ses üretilmez. Perde kaydırma ve kompresör kullanılmaz. `AudioStreamRandomizer` + `max_polyphony`.
- Headless kontroller `tools/*_check.gd` içinde; değişiklikten sonra ilgili olanı çalıştır.
- Test: T sınırsız mermi (yalnız debug build), B yerleştirme modu, F7/F8 host/join.

## Ekip ve süreç

- 2 kişi, ayrı Claude hesapları. Her `.tscn` sahnesinin tek sahibi var.
- **Commit mesajları:** Türkçe, birinci tekil şahıs, samimi; ne fark edildi, ne yapıldı ("Mermiler çok fazla gold kazandırıyordu, çarpanı yarıya indirdim."). "Add X / Fix Y" kalıbı yok. `Co-Authored-By: Claude` ve benzeri AI imza satırları **eklenmez** (commit ve PR).
- Yeni karar ya da tamamlanan sistem: ayrıntıyı `docs/ayrintilar.md`'ye yaz, burada yalnız kural niteliğindeyse bir satır ekle.

## Asetler

- Görünüm gerçekçi PBR (low-poly reddedildi). Kaynak ve lisans listesi `docs/ayrintilar.md` → "Kullanılan asetler"; yeni aset eklenince oraya yaz.
- CC0 tercih; CC-BY ise jenerikte isim. NC, ND, "personal use only", yalnız Unreal (`.uasset`) ve Lyra kaynaklı asetler alınmaz. Silah başına < 50 bin poligon. Gerçek marka isimleri ve logolar yok.

## Araçlar

- Açık: godot, disciplines, context7, ponytail, session-report, i-have-adhd plugin'leri; godot MCP; Beckett MCP (yalnız Godot editörü açıkken; oyunu editörde çalıştırıp ekran görüntüsü alır, `run_project` yerine bunu kullan; `.mcp.json` git'e girmez); `.claude/agents/` içinde 8 agent. Graphify, superpowers, caveman ve video kapalı.
- Kapalı bir araç gerekirse kullanmaya çalışma; hangisi, neden ve nasıl açılacağını söyle.
- Çoklu agent, büyük klasör taraması ya da uzun iş öncesi maliyeti söyleyip onay iste.
